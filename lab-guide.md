# ✅ Hands-on lab: EC2 + ALB + Auto Scaling using CLI

## ⚙️ Prerequisites

Make sure you have:
* **AWS CLI installed** (`aws --version`)
* **Configured credentials**: `aws configure`
* **Default region** (example: `us-east-1`)

---

## 🌐 Step 1: Create Custom VPC & Subnets

We will create a custom VPC with 2 public subnets and an Internet Gateway as requested.

**Create VPC:**
```bash
aws ec2 create-vpc --cidr-block 10.0.0.0/16
```
👉 *Copy `VpcId`*

**Create 2 Subnets (different AZs):**
```bash
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 10.0.1.0/24 --availability-zone us-east-1a
aws ec2 create-subnet --vpc-id <VPC_ID> --cidr-block 10.0.2.0/24 --availability-zone us-east-1b
```
👉 *Copy both `SubnetId`s as `<SUBNET1>` and `<SUBNET2>`*

**Enable Public IPs:**
```bash
aws ec2 modify-subnet-attribute --subnet-id <SUBNET1> --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id <SUBNET2> --map-public-ip-on-launch
```

**Add Internet Gateway (IGW) & Routes:**
```bash
aws ec2 create-internet-gateway
```
👉 *Copy `InternetGatewayId` as `<IGW_ID>`*

```bash
aws ec2 attach-internet-gateway --vpc-id <VPC_ID> --internet-gateway-id <IGW_ID>
aws ec2 create-route-table --vpc-id <VPC_ID>
```
👉 *Copy `RouteTableId` as `<RT_ID>`*

```bash
aws ec2 create-route --route-table-id <RT_ID> --destination-cidr-block 0.0.0.0/0 --gateway-id <IGW_ID>
aws ec2 associate-route-table --subnet-id <SUBNET1> --route-table-id <RT_ID>
aws ec2 associate-route-table --subnet-id <SUBNET2> --route-table-id <RT_ID>
```

---

## 🚀 Step 2: Create Security Groups

**ALB Security Group**
```bash
aws ec2 create-security-group \
--group-name alb-sg \
--description "ALB Security Group" \
--vpc-id <VPC_ID>
```
👉 *Copy GroupId as `<ALB_SG_ID>`*

**Allow HTTP:**
```bash
aws ec2 authorize-security-group-ingress \
--group-id <ALB_SG_ID> \
--protocol tcp \
--port 80 \
--cidr 0.0.0.0/0
```

**EC2 Security Group**
```bash
aws ec2 create-security-group \
--group-name ec2-sg \
--description "EC2 Security Group" \
--vpc-id <VPC_ID>
```
👉 *Copy GroupId as `<EC2_SG_ID>`*

**Allow traffic from ALB:**
```bash
aws ec2 authorize-security-group-ingress \
--group-id <EC2_SG_ID> \
--protocol tcp \
--port 80 \
--source-group <ALB_SG_ID>
```

---

## 🧱 Step 3: Create Target Group

```bash
aws elbv2 create-target-group \
--name my-targets \
--protocol HTTP \
--port 80 \
--vpc-id <VPC_ID> \
--target-type instance
```
👉 *Save `TargetGroupArn` as `<TG_ARN>`*

---

## ⚖️ Step 4: Create Load Balancer

```bash
aws elbv2 create-load-balancer \
--name my-alb \
--subnets <SUBNET1> <SUBNET2> \
--security-groups <ALB_SG_ID>
```
👉 *Save `LoadBalancerArn` as `<ALB_ARN>`*

---

## 🎯 Step 5: Create Listener

```bash
aws elbv2 create-listener \
--load-balancer-arn <ALB_ARN> \
--protocol HTTP \
--port 80 \
--default-actions Type=forward,TargetGroupArn=<TG_ARN>
```

---

## 🧩 Step 6: Create Launch Template

We pass a base64 string directly here. (Decodes to a script that installs **Nginx** and writes a Hello webpage over `/usr/share/nginx/html/index.html`).

```bash
aws ec2 create-launch-template \
--launch-template-name my-template \
--launch-template-data '{
  "ImageId":"ami-0c02fb55956c7d316",
  "InstanceType":"t2.micro",
  "SecurityGroupIds":["<EC2_SG_ID>"],
  "UserData":"IyEvYmluL2Jhc2gKeXVtIGluc3RhbGwgbmdpbnggLXkKc3lzdGVtY3RsIHN0YXJ0IG5naW54CnN5c3RlbWN0bCBlbmFibGUgbmdpbngKZWNobyAiSGVsbG8gZnJvbSAkKGhvc3RuYW1lKSIgPiAvdXNyL3NoYXJlL25naW54L2h0bWwvaW5kZXguaHRtbA=="
}'
```

👉 *This installs Nginx + sample webpage*

---

## 📈 Step 7: Create Auto Scaling Group

```bash
aws autoscaling create-auto-scaling-group \
--auto-scaling-group-name my-asg \
--launch-template LaunchTemplateName=my-template,Version=1 \
--min-size 2 \
--max-size 4 \
--desired-capacity 2 \
--vpc-zone-identifier "<SUBNET1>,<SUBNET2>" \
--target-group-arns <TG_ARN>
```

---

## 🔍 Step 8: Test Setup

**Get ALB DNS:**
```bash
aws elbv2 describe-load-balancers \
--query "LoadBalancers[0].DNSName" \
--output text
```

👉 **Open in browser:**
`http://<ALB_DNS>`

You should see:
`Hello from <hostname>`

---

## 📊 Step 9: Add Auto Scaling Policy

```bash
aws autoscaling put-scaling-policy \
--auto-scaling-group-name my-asg \
--policy-name cpu-scale-out \
--policy-type TargetTrackingScaling \
--target-tracking-configuration '{
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ASGAverageCPUUtilization"
  },
  "TargetValue": 50.0
}'
```
