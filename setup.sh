#!/bin/bash
# setup.sh - Automates the creation of a Custom VPC, ALB, and Auto Scaling Group via AWS CLI

set -e

# --- Error Handling Function ---
function check_error() {
    local exit_code=$?
    local msg="$1"
    if [ $exit_code -ne 0 ]; then
        echo "[ERROR] $msg (exit code: $exit_code)" >&2
        exit $exit_code
    fi
}

# --- Windows Bash Compatibility Fix ---
function aws_cli_wrapper() {
    if command -v aws.exe &> /dev/null; then
        aws.exe "$@" | tr -d '\r'
    elif [ -f "/c/Program Files/Amazon/AWSCLIV2/aws.exe" ]; then
        "/c/Program Files/Amazon/AWSCLIV2/aws.exe" "$@" | tr -d '\r'
    elif [ -f "/mnt/c/Program Files/Amazon/AWSCLIV2/aws.exe" ]; then
        "/mnt/c/Program Files/Amazon/AWSCLIV2/aws.exe" "$@" | tr -d '\r'
    else
        command aws "$@"
    fi
}
shopt -s expand_aliases
alias aws='aws_cli_wrapper'
# --------------------------------------

echo "================================================="
echo "AWS EC2 + ALB + Auto Scaling CLI Lab Setup"
echo "================================================="

# 1. Create Custom VPC Infrastructure
echo "1. Creating Custom VPC and Network Infrastructure..."

VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query "Vpc.VpcId" --output text)
check_error "Failed to create VPC"
aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value=cli-lab-vpc
check_error "Failed to tag VPC $VPC_ID"
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames "{\"Value\":true}"
check_error "Failed to enable DNS hostnames for VPC $VPC_ID"
echo "   -> Custom VPC Created: $VPC_ID"

# Get 2 Availability Zones
AZS=$(aws ec2 describe-availability-zones --query "AvailabilityZones[0:2].ZoneName" --output text)
check_error "Failed to describe availability zones"
# Cross-platform safe way to split into two variables
AZ_ARRAY=($AZS)
AZ_1=${AZ_ARRAY[0]}
AZ_2=${AZ_ARRAY[1]}

SUBNET_1=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 --availability-zone $AZ_1 --query "Subnet.SubnetId" --output text)
check_error "Failed to create subnet 1 in $AZ_1"
aws ec2 create-tags --resources $SUBNET_1 --tags Key=Name,Value=cli-lab-subnet-1
check_error "Failed to tag subnet 1 ($SUBNET_1)"
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_1 --map-public-ip-on-launch
check_error "Failed to modify subnet 1 ($SUBNET_1) attributes"
echo "   -> Subnet 1 Created ($AZ_1): $SUBNET_1"

SUBNET_2=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 --availability-zone $AZ_2 --query "Subnet.SubnetId" --output text)
check_error "Failed to create subnet 2 in $AZ_2"
aws ec2 create-tags --resources $SUBNET_2 --tags Key=Name,Value=cli-lab-subnet-2
check_error "Failed to tag subnet 2 ($SUBNET_2)"
aws ec2 modify-subnet-attribute --subnet-id $SUBNET_2 --map-public-ip-on-launch
check_error "Failed to modify subnet 2 ($SUBNET_2) attributes"
echo "   -> Subnet 2 Created ($AZ_2): $SUBNET_2"

IGW_ID=$(aws ec2 create-internet-gateway --query "InternetGateway.InternetGatewayId" --output text)
check_error "Failed to create Internet Gateway"
aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value=cli-lab-igw
check_error "Failed to tag Internet Gateway $IGW_ID"
aws ec2 attach-internet-gateway --vpc-id $VPC_ID --internet-gateway-id $IGW_ID
check_error "Failed to attach Internet Gateway $IGW_ID to VPC $VPC_ID"
echo "   -> Internet Gateway Attached: $IGW_ID"

RT_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --query "RouteTable.RouteTableId" --output text)
check_error "Failed to create Route Table"
aws ec2 create-tags --resources $RT_ID --tags Key=Name,Value=cli-lab-rt
check_error "Failed to tag Route Table $RT_ID"
aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID > /dev/null
check_error "Failed to create route in Route Table $RT_ID"
aws ec2 associate-route-table --subnet-id $SUBNET_1 --route-table-id $RT_ID > /dev/null
check_error "Failed to associate Route Table $RT_ID with Subnet 1 ($SUBNET_1)"
aws ec2 associate-route-table --subnet-id $SUBNET_2 --route-table-id $RT_ID > /dev/null
check_error "Failed to associate Route Table $RT_ID with Subnet 2 ($SUBNET_2)"
echo "   -> Route Table Created and Associated"

# 2. Get Amazon Linux 2023 AMI
echo "2. Finding latest Amazon Linux 2023 AMI..."
AMI_ID=$(aws ec2 describe-images --owners amazon \
    --filters "Name=name,Values=al2023-ami-2023.*-x86_64" "Name=state,Values=available" \
    --query "sort_by(Images, &CreationDate)[-1].[ImageId]" --output text)
check_error "Failed to find latest Amazon Linux 2023 AMI"
echo "   -> Using AMI: $AMI_ID"

# 3. Create Security Groups
echo "3. Creating Security Groups..."
ALB_SG_ID=$(aws ec2 create-security-group \
    --group-name cli-lab-alb-sg \
    --description "SG for Application Load Balancer" \
    --vpc-id $VPC_ID \
    --query "GroupId" --output text)
check_error "Failed to create ALB Security Group"
aws ec2 authorize-security-group-ingress \
    --group-id $ALB_SG_ID \
    --protocol tcp --port 80 --cidr 0.0.0.0/0
check_error "Failed to authorize ingress for ALB Security Group $ALB_SG_ID"
echo "   -> ALB Security Group Created: $ALB_SG_ID"

EC2_SG_ID=$(aws ec2 create-security-group \
    --group-name cli-lab-ec2-sg \
    --description "SG for EC2 Instances in ASG" \
    --vpc-id $VPC_ID \
    --query "GroupId" --output text)
check_error "Failed to create EC2 Security Group"
aws ec2 authorize-security-group-ingress \
    --group-id $EC2_SG_ID \
    --protocol tcp --port 80 --source-group $ALB_SG_ID
check_error "Failed to authorize ingress for EC2 Security Group $EC2_SG_ID"
echo "   -> EC2 Security Group Created: $EC2_SG_ID"

# 4. Create Target Group
echo "4. Creating Target Group..."
TG_ARN=$(aws elbv2 create-target-group \
    --name cli-lab-tg \
    --protocol HTTP --port 80 \
    --vpc-id $VPC_ID \
    --health-check-path "/" \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 2 \
    --target-type instance \
    --query "TargetGroups[0].TargetGroupArn" --output text)
check_error "Failed to create Target Group"
echo "   -> Target Group ARN: $TG_ARN"

# 5. Create Application Load Balancer
echo "5. Creating Application Load Balancer..."
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name cli-lab-alb \
    --subnets $SUBNET_1 $SUBNET_2 \
    --security-groups $ALB_SG_ID \
    --scheme internet-facing \
    --type application \
    --query "LoadBalancers[0].LoadBalancerArn" --output text)
check_error "Failed to create Application Load Balancer"

echo "   -> Waiting for ALB to become available (this takes ~3 mins)..."
aws elbv2 wait load-balancer-available --load-balancer-arns $ALB_ARN
check_error "ALB did not become available"

ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --query "LoadBalancers[0].DNSName" --output text)
check_error "Failed to get ALB DNS name"
echo "   -> ALB Available. DNS Name: $ALB_DNS"

# 6. Create Listener
echo "6. Creating ALB Listener..."
aws elbv2 create-listener \
    --load-balancer-arn $ALB_ARN \
    --protocol HTTP --port 80 \
    --default-actions Type=forward,TargetGroupArn=$TG_ARN > /dev/null
check_error "Failed to create ALB Listener"
echo "   -> Listener created and forwarding to Target Group."

# 7. Create Launch Template
echo "7. Creating Launch Template..."
USER_DATA=$(base64 user-data.sh | tr -d '\n' | tr -d '\r')

cat <<EOF > launch-template-data.json
{
    "ImageId": "$AMI_ID",
    "InstanceType": "t2.micro",
    "SecurityGroupIds": ["$EC2_SG_ID"],
    "UserData": "$USER_DATA"
}
EOF

aws ec2 create-launch-template \
    --launch-template-name cli-lab-launch-template \
    --version-description "v1" \
    --launch-template-data file://launch-template-data.json > /dev/null
check_error "Failed to create Launch Template"
rm launch-template-data.json
echo "   -> Launch Template Created: cli-lab-launch-template"

# 8. Create Auto Scaling Group
echo "8. Creating Auto Scaling Group..."
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name cli-lab-asg \
    --launch-template LaunchTemplateName=cli-lab-launch-template,Version=\$Latest \
    --min-size 2 \
    --max-size 4 \
    --desired-capacity 2 \
    --vpc-zone-identifier "$SUBNET_1,$SUBNET_2" \
    --target-group-arns $TG_ARN > /dev/null
check_error "Failed to create Auto Scaling Group"
echo "   -> Auto Scaling Group created with Desired Capacity = 2."

# 9. Create Scaling Policy
echo "9. Creating Target Tracking Scaling Policy..."
cat <<EOF > target-tracking-config.json
{
  "TargetValue": 50.0,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ASGAverageCPUUtilization"
  }
}
EOF

aws autoscaling put-scaling-policy \
    --auto-scaling-group-name cli-lab-asg \
    --policy-name cli-lab-cpu-tracking-policy \
    --policy-type TargetTrackingScaling \
    --target-tracking-configuration file://target-tracking-config.json > /dev/null
check_error "Failed to create Target Tracking Scaling Policy"
rm target-tracking-config.json
echo "   -> CPU Target Tracking Policy set to 50%."

echo "================================================="
echo "Setup Complete!"
echo "It might take another 1-2 minutes for instances to boot and pass health checks."
echo "Access your environment:"
echo "---> http://$ALB_DNS"
echo "================================================="
