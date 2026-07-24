#!/usr/bin/env python3
"""Generate the AWS architecture diagram from the Terraform configuration.

No Terraform state is needed. The HCL parser verifies the required stack blocks
before rendering the public, private, and database subnet placement.
"""
import glob
import json
import os
import sys

import hcl2

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


def render(bodies, out="images/architecture-diagram"):
    from diagrams import Cluster, Diagram, Edge
    from diagrams.aws.compute import ECR, Fargate
    from diagrams.aws.database import RDS
    from diagrams.aws.management import CloudwatchLogs
    from diagrams.aws.network import ALB, CloudFront, InternetGateway, NATGateway
    from diagrams.aws.storage import EFS
    from diagrams.onprem.client import Users

    required = {"module.vpc", "module.alb_ecs", "module.ecs_service"}
    missing = required - bodies.keys()
    if missing:
        raise ValueError(f"missing required Terraform blocks: {sorted(missing)}")

    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    graph_attr = {"ranksep": "1.4", "nodesep": "0.7", "pad": "0.5",
                  "splines": "ortho", "compound": "true"}
    with Diagram("AWS ECS Fargate — public and private subnet placement",
                 filename=out, outformat="png",
                 show=False, direction="LR", graph_attr=graph_attr):
        users = Users("Users")
        cdn = CloudFront("CloudFront\n(CDN on)")

        with Cluster("AWS Region"):
            ecr = ECR("ECR")
            logs = CloudwatchLogs("CloudWatch Logs")

            with Cluster("VPC"):
                internet_gateway = InternetGateway("Internet gateway")

                with Cluster("Public subnets (selected AZs)"):
                    nat = NATGateway("NAT gateway(s)")

                with Cluster("Private subnets (selected AZs)"):
                    internal_alb = ALB("Internal ALB")
                    service = Fargate("ECS Fargate\nUI + API")
                    efs = EFS("EFS mount targets\n(optional)")

                with Cluster("Database subnet group"):
                    database = RDS("RDS PostgreSQL\n(optional)")

        users >> Edge(label="HTTPS") >> cdn
        cdn >> Edge(label="VPC origin") >> internal_alb
        internal_alb >> Edge(label="ALB → task SG") >> service

        ecr >> Edge(label="image pull", constraint="false") >> service
        service >> Edge(label="logs", constraint="false") >> logs
        service >> Edge(label="NFS 2049", constraint="false") >> efs
        service >> Edge(label="PostgreSQL 5432") >> database
        service >> Edge(label="outbound", style="dashed",
                        constraint="false") >> nat
        nat >> Edge(style="dashed", constraint="false") >> internet_gateway


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
    try:
        render({}, out="/tmp/unused")
    except ValueError as error:
        assert "missing required Terraform blocks" in str(error)
    else:
        raise AssertionError("render must reject an incomplete configuration")
    print("selfcheck ok")


if __name__ == "__main__":
    if "--selfcheck" in sys.argv:
        _selfcheck()
    else:
        render(parse("."))
        print("wrote images/architecture-diagram.png")
