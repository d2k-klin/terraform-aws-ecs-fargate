# Compliance guide

This stack is a workload baseline: it ships the network, compute, data, and
logging controls that auditors ask about first, so a new service starts from a
passing position instead of a remediation backlog. It does not make an
organization compliant on its own. Account-level controls, processes, and
human sign-off remain your responsibility.

The control IDs below use the same model as
[WardBee by ScanComb](https://scancomb.com): each capability is anchored to a
NIST SP 800-53 Rev. 5 control, then crosswalked to ISO/IEC 27001:2022 Annex A,
SOC 2, CIS Controls v8, and NIS2 Article 21. Crosswalked mappings are partial
evidence: they show that a control addresses the same subject, not that the
target control is fully met.

## Scanner parity

Two scanners check this stack. Both are the ones WardBee runs:

| Layer | Scanner | Where it runs | What it proves |
|---|---|---|---|
| Code (Layer 1) | Checkov | CI on every pull request and release; WardBee on connected GitHub/GitLab repositories | The Terraform declares the control |
| Runtime (Layer 2) | Prowler | WardBee's read-only AWS integration, or `prowler aws` locally | The deployed account still has the control |

CI fails on any new Checkov finding. A finding may only be suppressed with an
inline `checkov:skip` comment that states the reason, so every exception is
reviewable in Git history and appears as *skipped*, not *passed*, in scan
results.

Run the same code scan locally:

```bash
checkov -d . --framework terraform --compact
```

## Control matrix

| Capability | Where | NIST 800-53 | ISO 27001 | SOC 2 | CIS v8 | NIS2 Art. 21 | Runtime check (Prowler) |
|---|---|---|---|---|---|---|---|
| Tasks, ALB (with CDN), and database in private subnets; no public task IPs | `vpc.tf`, `ecs_fargate.tf`, `alb.tf` | SC-7 | A.8.20, A.8.22 | CC6.6 | 4.4, 13.4 | (2)(a), (g), (i) | `ecs_service_no_assign_public_ip`, `vpc_subnet_separate_private_public`, `rds_instance_no_public_access` |
| Security-group chain: CloudFront or allowed CIDRs → ALB → tasks → RDS/EFS; default SG has no rules | `security-groups.tf`, `vpc.tf` | SC-7, AC-6 | A.8.20, A.8.2 | CC6.6, CC6.3 | 4.4, 5.4 | (2)(a), (i) | `ec2_securitygroup_default_restrict_traffic` |
| ALB reachable only through CloudFront when `create_cdn = true` | `security-groups.tf`, `cloudfront.tf` | SC-7(3) | A.8.20 | CC6.6 | 12.2 | (2)(a) | `elbv2_internet_facing` |
| HTTPS at the edge; TLS 1.3 policy on the direct ALB listener | `cloudfront.tf`, `alb.tf` | SC-8 | A.8.24 | CC6.7 | 3.10 | (2)(h) | `cloudfront_distributions_https_enabled`, `elbv2_ssl_listeners`, `elbv2_insecure_ssl_ciphers` |
| Security headers (HSTS, frame, content-type, referrer) | `cloudfront.tf` | SC-8 | A.8.24 | CC6.7 | 3.10 | (2)(h) | — |
| Invalid HTTP headers dropped at the ALB | module default | SI-10 | A.8.26 | CC6.8 | 16.1 | (2)(e) | `elbv2_alb_drop_invalid_header_fields_enabled` |
| Optional WAF on CloudFront | `cloudfront_web_acl_arn` | SC-5, SI-4 | A.8.20, A.8.16 | A1.1, CC7.2 | 13.10 | (2)(a) | `cloudfront_distributions_using_waf` |
| Encryption at rest: RDS, EFS, ECR, CloudWatch Logs | `rds.tf`, `efs.tf`, `ecr.tf` | SC-28 | A.8.24 | CC6.1 | 3.11 | (2)(g), (h) | `rds_instance_storage_encrypted`, `efs_encryption_at_rest_enabled` |
| EFS encrypted in transit | `ecs_fargate.tf` | SC-8 | A.8.24 | CC6.7 | 3.10 | (2)(h) | — |
| PostgreSQL 16 enforces TLS (`rds.force_ssl` default) | `rds.tf` | SC-8 | A.8.24 | CC6.7 | 3.10 | (2)(h) | `rds_instance_transport_encrypted` |
| Database password generated, stored, and rotated by RDS in Secrets Manager; IAM auth enabled | `rds.tf` | IA-5 | A.5.17 | CC6.1 | 5.2 | (2)(j) | `secretsmanager_automatic_rotation_enabled`, `rds_instance_iam_authentication_enabled` |
| App secrets injected from Secrets Manager/SSM ARNs, never plain environment values | `container_secrets` | IA-5 | A.5.17 | CC6.1 | 5.2 | (2)(j) | `ecs_task_definitions_no_environment_secrets` |
| Separate task and execution roles; secret access scoped to listed ARNs | `ecs_fargate.tf` | AC-6 | A.8.2 | CC6.3 | 5.4, 6.8 | (2)(i) | — |
| VPC flow logs | `vpc.tf` | AU-12, SI-4 | A.8.15, A.8.16 | CC7.2 | 8.2, 13.6 | (2)(e), (g) | `vpc_flow_logs_enabled` |
| Container, RDS, and ECS Exec logs | `ecs_fargate.tf`, `rds.tf` | AU-12 | A.8.15 | CC7.2 | 8.2 | (2)(e) | `ecs_task_definitions_logging_enabled`, `rds_instance_integration_cloudwatch_logs` |
| One-year log retention by default | `log_retention_days` | AU-11 | A.5.33, A.8.15 | CC7.2 | 8.10 | (2)(e) | `cloudwatch_log_group_retention_policy_specific_days_enabled` |
| Container Insights | `main.tf` | SI-4 | A.8.16 | CC7.2 | 13.1 | (2)(e) | `ecs_cluster_container_insights_enabled` |
| Image scanning on push; immutable tags; lifecycle policy | `ecr.tf` | RA-5, CM-2 | A.8.8, A.8.9 | CC7.1 | 7.5, 4.1 | (2)(e) | `ecr_repositories_scan_images_on_push_enabled`, `ecr_repositories_tag_immutability`, `ecr_repositories_lifecycle_policy_enabled` |
| Automated RDS backups (cannot be set to zero) and final snapshot | `rds.tf` | CP-9 | A.8.13 | A1.2 | 11.2 | (2)(c) | `rds_instance_backup_enabled` |
| Deletion protection on ALB and RDS | `deletion_protection` | CP-9, CM-3 | A.8.13, A.8.32 | A1.2, CC8.1 | 11.2 | (2)(c) | `elbv2_deletion_protection`, `rds_instance_deletion_protection` |
| Multi-AZ tasks and optional Multi-AZ RDS; rolling deploys with automatic rollback | `ecs_fargate.tf`, `db_multi_az` | CP-10, SC-5 | A.8.14 | A1.2 | 11.1 | (2)(c) | `elbv2_is_in_multiple_az`, `rds_instance_multi_az` |
| Infrastructure as code: pinned modules, locked providers, validation, tests, Checkov, Gitleaks | repository, `.github/` | CM-2, CM-6, SA-11 | A.8.9, A.8.25 | CC7.1, CC8.1 | 4.1, 16.1 | (2)(e) | — |
| Consistent ownership and cost tags on every resource | `locals.tf`, `providers.tf` | CM-8 | A.5.9 | CC6.1 | 1.1 | (2)(i) | — |

## Accepted exceptions

Every exception is either an inline `checkov:skip` in the code or listed here.

| Check | Status | Reason |
|---|---|---|
| `CKV_TF_1` module source commit hash | Skipped inline | Registry modules cannot be referenced by commit. Each is pinned to an exact version and Dependabot proposes reviewed updates. |
| `CKV_AWS_136` ECR KMS encryption | Skipped inline | Images are encrypted at rest with AES-256. Moving an existing repository to KMS replaces it and deletes its images. Use KMS in a new repository if your key-management policy requires customer-managed keys. |
| `CKV_AWS_2` ALB listener uses HTTP | Configure | With `create_cdn = true`, only CloudFront reaches the internal ALB over the AWS network. With the CDN off, set `certificate_arn` for HTTPS. |
| `CKV_AWS_174` CloudFront TLS 1.2 minimum | Configure | The default `*.cloudfront.net` certificate cannot set a minimum protocol. Add a custom domain and ACM certificate to enforce `TLSv1.2_2021`. |
| `CKV_AWS_111`, `CKV_AWS_356` IAM `*` resource | False positive | `ecr:GetAuthorizationToken` and log-stream creation in the ECS modules do not support resource-level permissions. |
| `CKV_AWS_97`, `CKV_AWS_133`, `CKV_AWS_259`, `CKV_AWS_304` | False positive | Checkov evaluates unused module branches without resolved inputs. The stack sets EFS transit encryption, backups, and the managed security-headers policy; RDS rotates its managed master secret automatically. |

Only the inline skips appear in the root-configuration scan that CI and
WardBee run. The other rows appear when Checkov also expands the registry
modules (`--download-external-modules true`).

## Outside this stack

These account-level controls are expected by every framework above and are
flagged by Prowler, but belong in a landing zone or account baseline rather
than in each workload:

- CloudTrail in every region with log-file validation (AU-2, AU-12)
- GuardDuty, Security Hub, and AWS Config (SI-4, CA-7, CM-8)
- IAM Identity Center with MFA; no long-lived access keys (IA-2, AC-2)
- AWS Backup plans and tested restores (CP-9, CP-4)
- Alarms and on-call routing (IR-4, SI-4)
- ALB and CloudFront access logs if your retention policy requires request-level
  records (AU-12)

## Evidence workflow

1. Fork the template, apply it, and connect the repository and the AWS account
   to WardBee with read-only access.
2. WardBee runs Checkov on the repository and Prowler on the account, maps both
   to the frameworks you enable, and keeps unconfirmed results out of the pass
   count.
3. Review the remaining gaps; they should be the account-level items above and
   your application's own controls.
4. Export evidence for the review. A person still signs off.
