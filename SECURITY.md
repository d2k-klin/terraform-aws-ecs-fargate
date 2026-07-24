# Security policy

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for this repository. Do not
open a public issue containing exploit details, credentials, account IDs, or
other sensitive information.

## Secrets and AWS account data

- Never commit AWS access keys, session tokens, private keys, passwords,
  Terraform state, plans, `.env` files, or non-example `.tfvars` files.
- Use AWS IAM Identity Center or another short-lived credential provider.
- Store application secrets in AWS Secrets Manager or Systems Manager Parameter
  Store and pass only their ARNs to Terraform.
- Treat every secret found in Git history as compromised and rotate it before
  removing it from the repository.

Pull requests and releases run Gitleaks across the full reachable Git history.
