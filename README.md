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

![example](https://viewer.diagrams.net/?highlight=0000ff&edit=_blank&layers=1&nav=1&title=AWS%20samlpe%20app#R7V1bd6M4Ev41eQwHcefR15k%2B27Ob7WR2dvbFh4Ds6DQGL8iJM79%2BJEAYJDkmjsC52OnTsQosyVXfV5JKJXJlTta7X7Jg8%2FBbGsH4ytCj3ZU5vTLIyzXILyp5LiXAc8xSsspQVMn2glv0F6yEeiXdogjmrRtxmsYYbdrCME0SGOKWLMiy9Kl92zKN261ughUUBLdhEIvSP1CEH0qpZ%2Bt7%2Ba8QrR5Yy0CvrqwDdnMlyB%2BCKH1qiMzZlTnJ0hSX79a7CYyp9pheys%2FND1ytO5bBBHf5QBTP%2FzG9%2B%2FP23%2F%2FL7cna%2Btdyfo%2Buq1oeg3hbfeHRH7dEMInTbVT1Gz8zZWxSlOBCofaY%2FCPtTfQrm1yZ0JJm2JyAL7ttARBLtI62gC%2B7bQHgqwdc%2B4DvYEMglFrV61z7eqOD5J85Trc4Rgmc1NDTiXCVBREiJpmkcZoRWZImRHvjB7yOSQmQt08PCMPbTRBSrT4R3hDZMk1wBX5gsHKleForAc%2BGvl%2FvVpRoWvCUW9oqS7eboslvBP7SqwvydhFSYy6CGNOKcJb%2BhKxzV4ZJfuYUMOMlimOu048ww4hwYRSjFa0fp7S5oCrFcFnUSL4JSlbfi9LU1Kvey5qIgvwBRtVXqpBHmoC7g5AGNVGIi4HpGuLsmdxSfeAaMDfxzASMbU97svp%2BJXtoENVxKmFQOYhVXfueQ%2BRNRaNXUMoyBE7NfiflH3CFiJUunPrwnMpKS0rIBCx3Nh71Sqa6iZpMQA2ZLJ5Kukglz5RQyQZ9UUlk0n9uJhcGfXwGPW5C6VhkeR6weqXPaDR2x14PYxHwOP54In0cV0Ify%2BuLPqZAn5sMPQYYUv5s7xOIL1z6%2BFzKYbjNEH5e7G%2B%2BLYjFKu40SBH5zJkbc6%2FPkUoR1Syfo5olUs2UjVSW0dukT6Ta9j5G4YVpX5lp0vGMMs0n6yFH4QKLtaOaaQY%2FqEmYVg98wzDNESMWmw1hWoCL1ZX%2BPQ0i8osoMUhCmAm8kwLt0IL1AAAFQy%2BLl2ho%2BcqXWf17cA%2FjmzRHRdcJ5FAUxbK5zn2KcbpuICMkfSLf7VVU0DkqgD20KKwOEWOTpdE2xCUrxhspPYK9BRYx0f%2FinmlfCQprX16hUDKzkmEQ9LYucUUMroO%2FCvgVgbNlRvR8Qd4AyAv36lYTUXI4hwfsM2ONVdwA25XhFLG8e%2FJmRd%2F8c3RHQ%2BVkZv8UPLOrpLX6hmGwKA0lNjHaCYs15F4eHGVAPDbyB%2Fmm%2FLZLtKP9kOMug3m6zUJYAY8UZchLArxgGlfj5bgAjOF64gJSFsnsDXli%2BEVA3jdqhGJ6W13I2JULGodEI6rsoBaSwG5DEjjnhqS4zppNyv2qbY4lsz3O9pENvciSocUz7k3HOYSKttF5QyrQtC0JttY7h03Vmv3pVgwXlXuB8yBbFUGjy3ym9%2FnMstK1GlBxqzci6DaZ0fvCmCfSd34rAEsaGpGGR2QhEmmYRAyVtG4rgheSFnihTOaKQiDexuIdolAmkwV3%2BE8DyacB9%2BnDoZWuPL2iHmdkmm7j2hRlpKKSaUmaUSgJdHVdAJwXCf6Zhl%2B4zBc5DpIoyCI13HW5Na8vjg9sftikLpOpHx3EuMssDnJchDi%2F3ZCpHbHtjkZ7R1FEtJRfJnnqUVYqfIE2i6BSsppxglv02o6ANVsyTNi9zUTE%2BMoFa58Ua8ARAyzDgs0XwFZPeHUc5D97ARcHoaluT4ArgK66%2Bd3hqpigwWz2CMt5GjiENQIsHBBdZQtDDXwcNg4ddlWyYbE39LAl2gU9HxE9MuczLHwO5t%2BmEbxBG0ihcll4D7GRQBS%2BYQpXs5XArb4tSWrqsFsJhhjQ3aNtCjdx%2BnzB2kBYi0p1q9mlN94d0sRYItsIiNDjfh%2FgyG5Ce9OglrWq4PAqjjYwQ%2BRLUfNPSc%2FRJoc3e1ETEQJa6hMbOg%2FJCgh3dHAssIDWxTkS9nuK1ivS0RiR7s%2BDEKNHuIiKqElKtTuvw%2FXF%2FqWWP64U%2BRx%2Bqxyw4zbNhA0ANABEOLi9ocE%2BCQ3tvA5xh%2Bk1KDne2u853T44GXeXFedbV5zbXFW%2ByLWpW5pltYkgycYdcufKEONnAoZgEo3okTVqDLL8zlHYtkaJD3YMbT8nhpFwho1TFV2LZCuIX%2BigK1dpx2V5BuOAerlWmzIlVi3c0DVAw2IG57cszg4lgKpP7U0hVmTxQ2G7nlINQj2FSetv%2FQYri5ErBVaGO4T%2FSxmn2VXpz6Lk%2B6AqT3cVIYvCc6PQGOsae5VdEFOq%2FBhiOiCrzCM4H7RAT9Di6jkALWJrmgVR31Ztbr3QX24E9z0OqWWNanErbsypwG1CekWBCzTd8JigxK7tAibYg7coPTdLPHz3VNABaJHB9sxzkoElyxxlQzk1%2FqpsUAZYMWo76HB6HA%2F6%2B%2FaObFvR0nTdr1%2BucxoahEQh39X8xst1e%2FGV%2FKzB1L0Xu8nfP4hvZW2%2BGqo50RI%2B1eVSB9n2uMbbPG7b21rA%2FxDe1jmns%2BV9LfBPdLZCRXxAWhWf%2BHaqcr%2F8EKOS%2FfFDIQadrg7%2BrBi0dM6k5okYNPl5qeVrTuNlD7vSMmURxiG8qsG5VcdxT3Gr3YF4HGBnXbpbvM84FWA2f8rH10zXHhZUYnrxh3BFLIfhKFS8T%2BGK3gNSZCHt%2Ft1P2%2FW4dr%2Be5yjujK6LnLPizvFNshixDc%2F1bdvRWZ57HRi2Nd92fM8yfGB7lmeeBko%2BYROwJepQiDxzgPk4WLrO2cFZIyT8DprJJ8OfPGn3udxcRZN2h9%2F9rVxhv5P2XgLdKodEryPajPPEX3YcujjjvRptPAqEc0KK0OY70v72C7ZeotMqXduB%2FchhMORylj85yiA4EktzPd9yTYcMjkC3egGUKzQ6AKDeffTY7DpW6mf1XobfCvPatqKhU3%2Bx3rePpKonX2z3423LAfHxNiLIXn%2BgtWhijugXUj7%2F7zql%2BxxhWCG5yvK0juvOV0di2VHNeq08gFu0xGxkIU1qTC8Z818yCGlWVpk1uqbI6XLQH8MdliH8hfz2SiRkKfHJTHU2qCyxM0u3SaT0EWTcMRaLYbUBaUsC6f4eQHZqPHSo%2FCJw1hgA%2F3ANkzdE551OtvJhFZlv3dpUPhZ1CGKyNL1lDHcVJMavRwcznWFqOtGobXvA9G3T8svaqsRBV9N913EtC3iObjk2%2BEy4uuYfm3sysLh5MOCfCtpz%2BMiShY843z%2F5RqqekEv6%2FmjKV3L6ZJ3naZ7P8V90%2FPXzE4bx%2FB1CMYzvLE29YQt5UvDRXOKYXhgH4c9VoWZZcnLR2IhlCEvThVm6%2FAPG9O85jKgmjHkYJZaGwjRZImLATAtJi8Y8CnBAU%2BeJPKe59ekqza%2BDJLq%2Bz8j%2FOf1TBnObJgbMfXcxTcOfMFvQmxblncDwtE2yUgEDbj5ZU%2FfI2M%2BnSKlDgCw%2BwnH3dvJbJ7J%2BOKQYR5FCk9avgyeYE3WTInB9qu8Vwtf5%2F7fE6iqhIck8N3wgwGPQ1HNLFu3g4PHr3d3N7Vfz5ge2I881hWdTEtljJX9Mxcfk9Hs073MfwcuiXAymjIsfNejitwNlB1CGffYSEEeJGl6zyY%2BB4fU1T37CUNERJ7u9CqW5nX2hixT3f6SqXG7s%2F9aXOfsb "Architecture Diagram")

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





