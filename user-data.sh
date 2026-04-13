#!/bin/bash
# user-data.sh - Installs Nginx web server and creates an index page

# Update packages and install nginx
yum update -y
yum install -y nginx stress

# Start and enable the service
systemctl start nginx
systemctl enable nginx

# Get the IMDSv2 token
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Retrieve the instance ID and availability zone using the token
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Create a simple HTML page to demonstrate ALB routing
# Nginx default document root on Amazon Linux is /usr/share/nginx/html/
cat <<EOF > /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>AWS CLI Lab</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; background-color: #f4f4f9; }
        .container { background: white; padding: 40px; border-radius: 10px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); display: inline-block; }
        h1 { color: #333; }
        .metadata { font-size: 1.2em; color: #0066cc; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Hello from the AWS CLI Lab!</h1>
        <p>You have successfully reached an EC2 instance behind the Application Load Balancer.</p>
        <p>Powered by <strong>Nginx</strong></p>
        <p><strong>Instance ID:</strong> <span class="metadata">$INSTANCE_ID</span></p>
        <p><strong>Availability Zone:</strong> <span class="metadata">$AZ</span></p>
    </div>
</body>
</html>
EOF
