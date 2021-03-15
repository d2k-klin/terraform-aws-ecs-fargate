# Terraform sample code for AWS ECS/Fargate with EFS(RDS) and ECR

This terraform setup can be used to setup the AWS infrastructure
for a dockerized application running on ECS with Fargate launch
configuration.

## Resources

This setup creates the following resources:

- VPC
- 3 public and 3 private subnet per AZ
- Routing tables for the subnets
- Internet Gateway for public subnets
- NAT gateways with attached Elastic IPs for the private subnet
- security groups
  - one that allows HTTP/HTTPS access
  - one that allows access to the specified container port
- An ALB + target group with listeners for port 80(443)
  - Additional Lister to port 8080 as secondary listener for Blue-Green Deployments through CodePipeline(CodeDeploy)
- An ECR for the docker images
- An ECS cluster with a service (incl. auto scaling policies for CPU, memory usage and number of ALB requests)
  and task definition to run docker containers from the ECR (incl. IAM execution role)
- Optional RDS module + security group the allows access only form ECS securutiy_group
- EFS storage as shared storage for all ECS tasks(containers)
- CloudFront Distribution connected to ALB

![Architecture Diagram](/images/Architecture Diagram.png)

### Get Started building your own infrastructure
Prerequisite:
 - Windows choco installation : https://chocolatey.org/

- Install terraform on MacOS with `choco install terraform`
- execute `terraform init`, it will initialize your local terraform and connect it to the state store, and it will download all the necessary providers
  - All terraform moudles are referenced from https://github.com/terraform-aws-modules (Collection of Terraform AWS modules supported by the community)

- execute `terraform plan -out="out.plan"` - this will calculate the changes terraform has to apply and creates a plan. If there are changes, you will see them. Check if any of the changes are expected, especially deletion of infrastructure.
- if everything looks good, you can execute the changes with `terraform apply out.plan`

### Setting up Terraform Backend

Sometimes we need to setup the Terraform Backend from Scratch, if we need to setup a completely separate set of Infrastructure or start a new project. This involves setting up a backend where Terraform keeps track of the state outside your local machine, and hooking up Terraform with AWS.


Here is a guideline:
1. Setup AWS CLI on Windows with `choco install awscli` (this will install aws-cli v2)
   1. Get access key and secret from IAM for your user
   1. execute `aws configure` .. enter your key and secret
   1. find your credentials stored in files within `~/.aws` folder
1. Create s3 bucket to hold our terraform state with this command: `aws s3api create-bucket --bucket my-terraform-backend-store --region eu-central-1 --create-bucket-configuration LocationConstraint=eu-central-1`
1. Because the terraform state contains some very secret secrets, setup encryption of bucket: `aws s3api put-bucket-encryption --bucket my-terraform-backend-store-[SOME HASH VALUE]--server-side-encryption-configuration "{\"Rules\":[{\"ApplyServerSideEncryptionByDefault\":{\"SSEAlgorithm\":\"AES256\"}}]}"`
1. Create IAM user for Terraform `aws iam create-user --user-name my-terraform-user`
1. Add policy to access S3 and DynamoDB access -

   - `aws iam attach-user-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --user-name my-terraform-user`
   - `aws iam attach-user-policy --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess --user-name my-terraform-user`

1. Create bucket policy, put against bucket `aws s3api put-bucket-policy --bucket my-terraform-backend-store-[SOME HASH VALUE] --policy file://policy.json`. Here is the policy file - the actual ARNs need to be adjusted based on the output of the steps above:

   ```sh
    cat <<-EOF >> policy.json
    {
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": {
                    "AWS": "arn:aws:iam::[AWS-ACCOUNT_ID]:user/my-terraform-user"
                },
                "Action": "s3:*",
                "Resource": "arn:aws:s3:::my-terraform-backend-store-[SOME HASH VALUE]"
            }
        ]
    }
    EOF
   ```

1. (Optional)Enable versioning in bucket with `aws s3api put-bucket-versioning --bucket terraform-remote-store --versioning-configuration Status=Enabled`
1. create the AWS access keys for your deployment user with `aws iam create-access-key --user-name my-terraform-user`, this will output access key and secret, which can be used as credentials for executing Terraform against AWS 
1. Create IAM policy for the Terraform User `aws iam create-policy --policy-name terraform-policy --policy-document file://terraform_policy.json`
   ```sh
    cat <<-EOF >> terraform_policy.json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "AllowSpecifics",
                "Action": [
                    "ec2:*",
                    "rds:*",
                    "s3:*",
                    "sns:*",
                    "sqs:*",
                    "iam:*",
                    "elasticloadbalancing:*",
                    "autoscaling:*",
                    "cloudwatch:*",
                    "cloudfront:*",
                    "route53:*",
                    "ecr:*",
                    "logs:*",
                    "ecs:*",
                    "application-autoscaling:*",
                    "logs:*",
                    "events:*",
                    "elasticache:*",
                    "es:*",
                    "kms:*",
                    "dynamodb:*"
                ],
                "Effect": "Allow",
                "Resource": "*"
            },
            {
                "Sid": "DenySpecifics",
                "Action": [
                    "iam:*User*",
                    "iam:*Login*",
                    "iam:*Group*",
                    "iam:*Provider*",
                    "aws-portal:*",
                    "budgets:*",
                    "config:*",
                    "directconnect:*",
                    "aws-marketplace:*",
                    "aws-marketplace-management:*",
                    "ec2:*ReservedInstances*"
                ],
                "Effect": "Deny",
                "Resource": "*"
            }
        ]
    }
    EOF
   ```
   Note: JSON strings must not have leading spaces
Attach policy to terraform user role   
   - `aws iam attach-user-policy --policy-arn arn:aws:iam::[AWS-ACCOUNT_ID]:policy/terraform-policy --user-name my-terraform-user`
1. execute initial terraforming





