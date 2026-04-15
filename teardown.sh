#!/bin/bash
# teardown.sh - Deletes all resources created by setup.sh including Custom VPC

set +e

# --- Robust Error Handling ---
function check_error() {
    local exit_code=$1
    local msg="$2"
    if [ $exit_code -ne 0 ]; then
        echo "[ERROR] $msg"
        exit $exit_code
    fi
}
# --------------------------------

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
echo "AWS EC2 + ALB + Auto Scaling CLI Lab Teardown"
echo "================================================="

echo "1/8 Deleting Auto Scaling Policy..."
aws autoscaling delete-policy --auto-scaling-group-name cli-lab-asg --policy-name cli-lab-cpu-tracking-policy 2>/dev/null
check_error $? "Failed to delete Auto Scaling Policy."

echo "2/8 Deleting Auto Scaling Group (Force deleting instances)..."
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name cli-lab-asg --force-delete 2>/dev/null
check_error $? "Failed to delete Auto Scaling Group."

echo "   -> Waiting for ASG to be deleted and instances to terminate (This can take 2-4 mins)..."
while aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names cli-lab-asg 2>/dev/null | grep -q "cli-lab-asg"; do
    printf "."
    sleep 10
done
echo " Done."

echo "3/8 Deleting Launch Template..."
aws ec2 delete-launch-template --launch-template-name cli-lab-launch-template 2>/dev/null
check_error $? "Failed to delete Launch Template."

ALB_ARN=$(aws elbv2 describe-load-balancers --names cli-lab-alb --query "LoadBalancers[0].LoadBalancerArn" --output text 2>/dev/null)
if [ "$ALB_ARN" != "None" ] && [ -n "$ALB_ARN" ]; then
    echo "4/8 Deleting ALB Listeners..."
    LISTENERS=$(aws elbv2 describe-listeners --load-balancer-arn $ALB_ARN --query "Listeners[*].ListenerArn" --output text 2>/dev/null)
    for LISTENER in $LISTENERS; do
        aws elbv2 delete-listener --listener-arn $LISTENER
        check_error $? "Failed to delete ALB Listener $LISTENER."
    done

    echo "5/8 Deleting Application Load Balancer..."
    aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN
    check_error $? "Failed to delete Application Load Balancer."
    echo "   -> Waiting for ALB to be completely deleted..."
    aws elbv2 wait load-balancers-deleted --load-balancer-arns $ALB_ARN
    check_error $? "Failed while waiting for ALB deletion."
else
    echo "4/8 and 5/8 Application Load Balancer not found, skipping..."
fi

TG_ARN=$(aws elbv2 describe-target-groups --names cli-lab-tg --query "TargetGroups[0].TargetGroupArn" --output text 2>/dev/null)
if [ "$TG_ARN" != "None" ] && [ -n "$TG_ARN" ]; then
    echo "6/8 Deleting Target Group..."
    aws elbv2 delete-target-group --target-group-arn $TG_ARN
    check_error $? "Failed to delete Target Group."
else
    echo "6/8 Target Group not found, skipping..."
fi

echo "7/8 Deleting Security Groups..."
EC2_SG_ID=$(aws ec2 describe-security-groups --group-names cli-lab-ec2-sg --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)
if [ "$EC2_SG_ID" != "None" ] && [ -n "$EC2_SG_ID" ]; then
    aws ec2 delete-security-group --group-id $EC2_SG_ID
    check_error $? "Failed to delete EC2 Security Group."
fi

ALB_SG_ID=$(aws ec2 describe-security-groups --group-names cli-lab-alb-sg --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)
if [ "$ALB_SG_ID" != "None" ] && [ -n "$ALB_SG_ID" ]; then
    aws ec2 delete-security-group --group-id $ALB_SG_ID
    check_error $? "Failed to delete ALB Security Group."
fi

echo "8/8 Deleting Custom VPC..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=cli-lab-vpc" --query "Vpcs[0].VpcId" --output text 2>/dev/null)

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    # Dissasociate and delete Route Tables
    RT_IDS=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=cli-lab-rt" --query "RouteTables[*].RouteTableId" --output text 2>/dev/null)
    for RT_ID in $RT_IDS; do
        ASSOC_IDS=$(aws ec2 describe-route-tables --route-table-ids $RT_ID --query "RouteTables[*].Associations[*].RouteTableAssociationId" --output text 2>/dev/null)
        for ASSOC_ID in $ASSOC_IDS; do
            aws ec2 disassociate-route-table --association-id $ASSOC_ID 2>/dev/null
            check_error $? "Failed to disassociate Route Table Association $ASSOC_ID."
        done
        aws ec2 delete-route-table --route-table-id $RT_ID 2>/dev/null
        check_error $? "Failed to delete Route Table $RT_ID."
    done

    # Delete Subnets
    SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text 2>/dev/null)
    for SUBNET in $SUBNET_IDS; do
        aws ec2 delete-subnet --subnet-id $SUBNET 2>/dev/null
        check_error $? "Failed to delete Subnet $SUBNET."
    done

    # Detach and Delete IGW
    IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[0].InternetGatewayId" --output text 2>/dev/null)
    if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
        aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID 2>/dev/null
        check_error $? "Failed to detach Internet Gateway $IGW_ID."
        aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID 2>/dev/null
        check_error $? "Failed to delete Internet Gateway $IGW_ID."
    fi

    # Delete VPC
    aws ec2 delete-vpc --vpc-id $VPC_ID 2>/dev/null
    check_error $? "Failed to delete VPC $VPC_ID."
    echo "   -> Custom VPC $VPC_ID deleted."
else
    echo "   - Custom VPC not found, skipping."
fi

echo "================================================="
echo "Teardown Complete!"
echo "================================================="
