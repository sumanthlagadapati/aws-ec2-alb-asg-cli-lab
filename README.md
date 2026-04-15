# AWS EC2 + ALB + Auto Scaling CLI Lab

A hands-on lab project to provision, manage, and tear down a scalable, highly available web infrastructure on AWS using only the AWS CLI and Bash scripts. This project is designed for learning and demonstration purposes, focusing on core AWS services: EC2, Application Load Balancer (ALB), and Auto Scaling Groups (ASG).

---

## Features
- **Automated Provisioning:** Deploys a complete AWS web stack (VPC, subnets, security groups, ALB, EC2, ASG) using `setup.sh`.
- **Automated Teardown:** Cleans up all resources with `teardown.sh` to avoid unnecessary costs.
- **User Data Bootstrapping:** EC2 instances are initialized with a sample web server via `user-data.sh`.
- **Error Handling:** Scripts include robust error handling for common AWS CLI issues.
- **Tagging:** All resources are tagged for easy identification and cleanup.

---

## Architecture Overview

```
+-------------------+        +-------------------+
|    Public Subnet 1|        |   Public Subnet 2 |
+-------------------+        +-------------------+
         |                           |
         |                           |
         |         +-----------------+
         |         |   Application   |
         +-------->| Load Balancer   |<--------+
                   +-----------------+         |
                      |        |              |
                +-----+        +-----+        |
                |                    |        |
         +-------------+      +-------------+ |
         | EC2 Instance|      | EC2 Instance| |
         +-------------+      +-------------+ |
                |                    |        |
                +--------------------+--------+
                        (Auto Scaling Group)
```

---

## Prerequisites
- AWS CLI installed ([installation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- AWS credentials configured (`aws configure`)
- Bash shell (Linux, macOS, or WSL recommended)
- Sufficient IAM permissions (see below)

---

## Setup Instructions

1. **Clone the repository:**
   ```bash
   git clone https://github.com/sumanthlagadapati/aws-ec2-alb-asg-cli-lab.git
   cd aws-ec2-alb-asg-cli-lab
   ```

2. **Provision AWS resources:**
   ```bash
   ./setup.sh
   ```
   - Creates VPC, subnets, security groups, ALB, target group, launch template, and ASG.
   - Outputs the ALB DNS name for access.

3. **Access your application:**
   - Open the ALB DNS name in your browser (displayed at the end of setup).

4. **Tear down the environment:**
   ```bash
   ./teardown.sh
   ```
   - Deletes all resources created by setup.sh.

---

## IAM Permissions Required

Attach these AWS managed policies to your IAM user/role, or use a custom policy with equivalent permissions:
- `AmazonEC2FullAccess`
- `ElasticLoadBalancingFullAccess`
- `AutoScalingFullAccess`
- `IAMReadOnlyAccess` (for AMI lookup)

**Custom Policy Example:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    { "Effect": "Allow", "Action": [
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "iam:Get*",
      "iam:List*",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms"
    ], "Resource": "*" }
  ]
}
```

---

## Troubleshooting
- Ensure your AWS credentials are valid and have the required permissions.
- If a script fails, check the error message for details.
- Use the AWS Console to verify resource creation or deletion.
- For network issues, verify security group and subnet configurations.
- Re-run `teardown.sh` if resources remain after a failed setup.

---

## File Overview
- `setup.sh` – Provisions all AWS resources for the lab.
- `teardown.sh` – Deletes all resources created by setup.sh.
- `user-data.sh` – Bootstraps EC2 instances with a sample web server.
- `lab-guide.md` – Step-by-step instructions for the lab.

---

## License
MIT License

---

## Author
[Sumanth Lagadapati](https://github.com/sumanthlagadapati)
