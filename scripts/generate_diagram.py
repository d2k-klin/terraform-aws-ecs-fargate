#!/usr/bin/env python3
"""Generate an AWS-icon architecture diagram straight from the .tf files.

No terraform init/state needed: we parse HCL, map each resource/module to a
`diagrams` AWS node, and infer edges from one block referencing another.
"""
import glob
import importlib
import json
import os
import sys

import hcl2

# resource type / module keyword -> first diagrams class that imports wins.
# Fallback is aws.general.General so an unknown type never breaks CI.
ICONS = {
    "aws_ecs_service": ["diagrams.aws.compute:ECS"],
    "aws_ecs_task_definition": ["diagrams.aws.compute:Fargate"],
    "aws_ecr_repository": ["diagrams.aws.compute:ECR"],
    "aws_ecr_lifecycle_policy": ["diagrams.aws.compute:ECR"],
    "aws_efs_file_system": ["diagrams.aws.storage:EFS"],
    "aws_efs_mount_target": ["diagrams.aws.storage:EFS"],
    "aws_cloudwatch_log_group": ["diagrams.aws.management:Cloudwatch"],
    "aws_iam_role": ["diagrams.aws.security:IAMRole", "diagrams.aws.security:IAM"],
    "aws_iam_role_policy_attachment": ["diagrams.aws.security:IAM"],
    "aws_appautoscaling_target": ["diagrams.aws.compute:EC2AutoScaling", "diagrams.aws.compute:AutoScaling"],
    "aws_appautoscaling_policy": ["diagrams.aws.compute:EC2AutoScaling", "diagrams.aws.compute:AutoScaling"],
}
# module names are freeform, so match by keyword.
MODULE_ICONS = {
    "vpc": ["diagrams.aws.network:VPC"],
    "alb": ["diagrams.aws.network:ALB", "diagrams.aws.network:ELB"],
    "cdn": ["diagrams.aws.network:CloudFront"],
    "cloudfront": ["diagrams.aws.network:CloudFront"],
    "rds": ["diagrams.aws.database:RDS"],
    "db": ["diagrams.aws.database:RDS"],
    "ecs": ["diagrams.aws.compute:ECS"],
    "fargate": ["diagrams.aws.compute:Fargate"],
    "sg": ["diagrams.aws.security:IAM"],
}
FALLBACK = ["diagrams.aws.general:General"]


def _resolve(candidates):
    for c in candidates + FALLBACK:
        mod, cls = c.split(":")
        try:
            return getattr(importlib.import_module(mod), cls)
        except (ImportError, AttributeError):
            continue
    raise RuntimeError("no diagrams class resolved, is `diagrams` installed?")


def _icon_for(addr):
    if addr.startswith("module."):
        name = addr.split(".", 1)[1].lower()
        if name.endswith("sg") or name.endswith("_sg"):
            return MODULE_ICONS["sg"]
        for kw, cands in MODULE_ICONS.items():
            if kw in name:
                return cands
        return FALLBACK
    rtype = addr.split(".", 1)[0]
    return ICONS.get(rtype, FALLBACK)


def _unq(s):
    # some python-hcl2 versions keep the surrounding quotes inside the key.
    return s.strip('"')


def parse(tf_dir):
    """Return {address: body-as-json-string} for every resource and module."""
    bodies = {}
    for f in glob.glob(os.path.join(tf_dir, "*.tf")):
        with open(f) as fh:
            data = hcl2.load(fh)
        for block in data.get("resource", []):
            for rtype, insts in block.items():
                for name, body in insts.items():
                    bodies[f"{_unq(rtype)}.{_unq(name)}"] = json.dumps(body)
        for block in data.get("module", []):
            for name, body in block.items():
                bodies[f"module.{_unq(name)}"] = json.dumps(body)
    return bodies


def infer_edges(bodies):
    """Edge dep -> user when `user`'s body mentions `dep`'s address."""
    edges = set()
    for user, body in bodies.items():
        for dep in bodies:
            if dep != user and dep in body:
                edges.add((dep, user))
    return edges


def _tier(addr):
    if addr.startswith("module."):
        name = addr.split(".", 1)[1].lower()
        if name.endswith("sg") or name.endswith("_sg"):
            return "Security Groups"
        if "vpc" in name:
            return "Network"
        if "cdn" in name or "cloudfront" in name:
            return "Edge"
        if "alb" in name or "lb" in name:
            return "Load Balancing"
        if "db" in name or "rds" in name:
            return "Data"
        return "Compute"
    rtype = addr.split(".", 1)[0]
    if any(k in rtype for k in ("efs", "rds", "_db", "s3")):
        return "Data"
    if "ecr" in rtype or "cloudwatch" in rtype:
        return "Regional"  # AWS-managed, lives outside the VPC
    return "Compute"


def _label(addr):
    # drop noise: module.x -> x ; aws_ecr_repository.main -> ecr_repository
    if addr.startswith("module."):
        return addr.split(".", 1)[1]
    return addr.split(".", 1)[0].removeprefix("aws_")


def _find(bodies, tier, *keywords):
    """First node in `tier` matching any keyword (by priority), else any."""
    cands = [a for a in bodies if _tier(a) == tier]
    for kw in keywords:
        for a in cands:
            if kw in a:
                return a
    return cands[0] if cands else None


def render(bodies, out="images/architecture-diagram"):
    from collections import defaultdict

    from diagrams import Cluster, Diagram, Edge

    groups = defaultdict(list)
    for addr in bodies:
        groups[_tier(addr)].append(addr)

    nodes = {}

    def place(addr):
        nodes[addr] = _resolve(_icon_for(addr))(_label(addr))

    def cluster(label, tier):
        if groups[tier]:
            with Cluster(label):
                for addr in groups[tier]:
                    place(addr)

    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    graph_attr = {"ranksep": "1.3", "nodesep": "0.6", "pad": "0.6",
                  "splines": "ortho", "compound": "true"}
    with Diagram("AWS ECS Fargate", filename=out, outformat="png",
                 show=False, direction="LR", graph_attr=graph_attr):
        cluster("Edge / CDN", "Edge")
        cluster("Regional (AWS-managed)", "Regional")
        with Cluster("VPC"):
            for addr in groups["Network"]:  # the VPC itself, no wrapping subbox
                place(addr)
            cluster("Load Balancing", "Load Balancing")
            cluster("Application (ECS / Fargate)", "Compute")
            cluster("Data (RDS / EFS)", "Data")
            for addr in groups["Security Groups"]:  # placed by their protects-edge
                place(addr)

        # curated flow backbone: internet -> cdn -> alb -> ecs -> data.
        cdn = _find(bodies, "Edge")
        lb = _find(bodies, "Load Balancing")
        svc = _find(bodies, "Compute", "ecs_service", "service", "ecs")
        ecr = _find(bodies, "Regional", "ecr_repository", "ecr")
        cw = _find(bodies, "Regional", "cloudwatch")
        far = _find(bodies, "Compute", "fargate")
        data = [a for a in bodies if _tier(a) == "Data" and "mount" not in a]

        def link(a, b, **kw):
            if a and b and a in nodes and b in nodes:
                nodes[a] >> Edge(**kw) >> nodes[b]

        link(cdn, lb)
        link(lb, svc)
        link(ecr, svc)
        link(far, svc)
        link(svc, cw)
        for d in data:
            link(svc, d)
        # intra-tier sub-resource links (ecr->lifecycle, efs->mount).
        for dep, user in infer_edges(bodies):
            if _tier(dep) == _tier(user) and _tier(dep) in (
                    "Compute", "Data", "Regional"):
                link(dep, user)
        # tie each security group to the resource it actually protects.
        def _sg_target(sg):
            name = sg.split(".", 1)[1].lower()
            if any(k in name for k in ("http", "alb", "lb")):
                return lb
            if any(k in name for k in ("rds", "db")):
                return _find(bodies, "Data", "db", "rds")
            if "efs" in name:
                return _find(bodies, "Data", "efs_file_system", "efs")
            return svc  # ecs_task_sg and anything else guards the service

        for sg in groups["Security Groups"]:
            link(sg, _sg_target(sg), style="dashed", label="protects")


def _selfcheck():
    bodies = {
        "module.vpc": json.dumps({"cidr": "10.0.0.0/16"}),
        "module.alb": json.dumps({"vpc_id": "${module.vpc.vpc_id}"}),
        "aws_ecs_service.main": json.dumps({"lb": "${module.alb.arn}"}),
    }
    edges = infer_edges(bodies)
    assert ("module.vpc", "module.alb") in edges
    assert ("module.alb", "aws_ecs_service.main") in edges
    assert ("module.alb", "module.vpc") not in edges  # direction matters
    print("selfcheck ok")


if __name__ == "__main__":
    if "--selfcheck" in sys.argv:
        _selfcheck()
    else:
        render(parse("."))
        print("wrote images/architecture-diagram.png")
