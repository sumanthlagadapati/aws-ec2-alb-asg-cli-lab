# ✅ Hands-on Lab: EC2 + ALB + Auto Scaling using AWS CLI

> Automated a scalable architecture using AWS CLI where an Auto Scaling Group launches EC2 instances behind an ALB. Configured target groups, health checks, and scaling policies to ensure high availability and dynamic scaling based on CPU metrics.

---

## 🏗️ Lab Architecture

```
Internet → ALB → Target Group → Auto Scaling Group → EC2 Instances
```

| Component | Details |
|---|---|
| **VPC** | Custom VPC `10.0.0.0/16` with Internet Gateway & Route Table |
| **Subnets** | 2 Public Subnets in different Availability Zones |
| **Load Balancer** | Internet-facing Application Load Balancer (ALB) |
| **Target Group** | HTTP health checks on port 80 |
| **Launch Template** | Amazon Linux 2023 + Nginx via User Data |
| **Auto Scaling Group** | Min: 2, Max: 4, Desired: 2 instances |
| **Scaling Policy** | Target Tracking — 50% average CPU utilization |
| **Web Server** | Nginx serving instance ID & AZ per request |

---

## ⚙️ Prerequisites

- AWS CLI installed: `aws --version`
- Credentials configured: `aws configure`
- IAM permissions: EC2, ELB, Auto Scaling, CloudWatch
- Bash-compatible terminal (Linux / macOS / WSL / Git Bash)

---

## 🚀 Quick Start (Automated)

```bash
# Clone the repo
git clone https://github.com/<your-username>/aws-ec2-alb-asg-cli-lab.git
cd aws-ec2-alb-asg-cli-lab

# Deploy everything
bash setup.sh
```

The script will print the ALB DNS at the end:
```
---> http://cli-lab-alb-xxxxxxxxxx.us-east-1.elb.amazonaws.com
```

Open it in your browser. Refresh a few times — you'll see different **Instance IDs** confirming the ALB is load balancing across your EC2 instances!

---

## 🛠️ Step-by-Step Manual Walkthrough

Follow the detailed guide: [lab-guide.md](./lab-guide.md)

---

## 🔍 Testing Auto Scaling

SSH or use AWS Session Manager to connect to an instance, then generate CPU load:

```bash
stress --cpu 2 --timeout 300
```

After ~1–2 minutes, CloudWatch will trigger the scaling policy and launch new instances automatically.

---

## 🧹 Cleanup

> [!CAUTION]
> Always clean up to avoid unexpected AWS charges.

```bash
bash teardown.sh
```

This removes in order: Scaling Policy → ASG (force terminates instances) → Launch Template → ALB Listeners → ALB → Target Group → Security Groups → Subnets → Route Table → IGW → VPC.

---

## 📁 File Structure

```
aws-ec2-alb-asg-cli-lab/
├── setup.sh          # Full automated deployment script
├── teardown.sh       # Full automated cleanup script
├── user-data.sh      # EC2 bootstrap script (Nginx + instance info page)
├── lab-guide.md      # Step-by-step manual CLI walkthrough
└── README.md         # This file
```

---

## 🏷️ Key Concepts Practiced

- ✅ Custom VPC with Internet Gateway and Route Tables
- ✅ Security Group chaining (ALB → EC2 only)
- ✅ ALB Target Groups with HTTP Health Checks
- ✅ EC2 Launch Templates with User Data
- ✅ Auto Scaling Groups with multi-AZ placement
- ✅ Target Tracking Scaling Policies (CPU-based)
- ✅ IMDSv2 token-based instance metadata retrieval
