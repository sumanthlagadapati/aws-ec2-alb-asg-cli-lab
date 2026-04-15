# vmware-ad-rhel-automation

![CI](https://github.com/<OWNER>/<REPO>/actions/workflows/python-tests.yml/badge.svg)

## Grafana Dashboards for Infrastructure Metrics

This project recommends using Grafana to visualize and monitor metrics from your VMware, Active Directory, and RHEL infrastructure. Below are setup instructions and dashboard suggestions for each system.

### 1. Prerequisites
- [Grafana](https://grafana.com/get) installed (locally or on a server)
- [Prometheus](https://prometheus.io/) or another supported data source

### 2. Metric Collection
- **VMware**: Use the [vmware_exporter](https://github.com/pryorda/vmware_exporter) for Prometheus to collect vSphere/ESXi metrics.
- **Active Directory**: Use [wmi_exporter](https://github.com/prometheus-community/windows_exporter) (now called windows_exporter) on your AD servers.
- **RHEL**: Use [node_exporter](https://github.com/prometheus/node_exporter) on RHEL systems for OS metrics.

### 3. Example Dashboards
- **VMware**: [Community vSphere Overview Dashboard](https://grafana.com/grafana/dashboards/8159)
- **Active Directory**: [Windows Node Dashboard](https://grafana.com/grafana/dashboards/2129)
- **RHEL/Linux**: [Node Exporter Full Dashboard](https://grafana.com/grafana/dashboards/1860)

### Step-by-Step: Importing a Grafana Dashboard

1. **Open Grafana in your browser** (e.g., http://localhost:3000 or your server address).
2. **Log in** with your credentials (default is admin/admin if not changed).
3. In the left sidebar, click the **four squares icon** ("Dashboards") > **Import**.
4. **Upload the JSON file**:
    - Click **Upload JSON file** and select one of the dashboard files from `grafana-dashboards/` (e.g., `vmware-cpu-memory-disk-vmstatus.json`).
    - Alternatively, paste the dashboard ID from Grafana.com or the raw JSON content.
5. **Select your Prometheus data source** from the dropdown menu.
6. Click **Import**.
7. The dashboard will appear in your list—repeat for each dashboard you wish to import.

You can now view and customize the dashboards for VMware, Active Directory, and RHEL metrics.

### Troubleshooting Tips for Dashboard Import

- **Dashboard not displaying data:**
  - Ensure your Prometheus data source is configured and connected in Grafana.
  - Check that your exporters (vmware_exporter, windows_exporter, node_exporter) are running and accessible from Prometheus.
  - Verify that Prometheus is scraping the exporters and has recent data.
- **"No data" or missing panels:**
  - The dashboard panels expect standard metric names. If you customized exporter configs or use a different exporter, update the panel queries accordingly.
  - Make sure the time range in Grafana (top right) covers a period with data.
- **Import errors (invalid JSON):**
  - Ensure you are uploading the correct JSON file from the `grafana-dashboards/` directory.
  - If you edited the JSON, check for syntax errors (missing commas, brackets, etc.).
- **Permissions issues:**
  - Make sure your Grafana user has permission to import dashboards and add data sources.
- **Data source not listed:**
  - Add your Prometheus data source in Grafana under Configuration > Data Sources before importing dashboards.

If you encounter other issues, consult the [Grafana documentation](https://grafana.com/docs/grafana/latest/) or check the logs for more details.

---

## Prometheus Server Installation and Configuration

Follow these steps to install and configure Prometheus for collecting metrics from VMware, Active Directory, and RHEL exporters:

### 1. Download and Install Prometheus
- **Linux (x86_64):**
  ```bash
  wget https://github.com/prometheus/prometheus/releases/latest/download/prometheus-*.linux-amd64.tar.gz
  tar xvf prometheus-*.linux-amd64.tar.gz
  cd prometheus-*.linux-amd64
  ```
- **Windows:** Download the latest release from the [Prometheus downloads page](https://prometheus.io/download/), extract, and use `prometheus.exe`.

### 2. Configure prometheus.yml
Edit the `prometheus.yml` file to add scrape jobs for your exporters:

```yaml
scrape_configs:
  - job_name: 'vmware'
    static_configs:
      - targets: ['<exporter_host>:9272']

  - job_name: 'ad-windows'
    static_configs:
      - targets: ['<ad_server>:9182']

  - job_name: 'rhel-node'
    static_configs:
      - targets: ['<rhel_host>:9100']
```
Replace `<exporter_host>`, `<ad_server>`, and `<rhel_host>` with the actual hostnames or IP addresses of your exporter hosts.

### 3. Start Prometheus
- **Linux:**
  ```bash
  ./prometheus --config.file=prometheus.yml
  ```
- **Windows:**
  ```powershell
  .\prometheus.exe --config.file=prometheus.yml
  ```

Prometheus will start and listen on [http://localhost:9090](http://localhost:9090) by default.

### 4. Verify Targets
- In your browser, go to `http://localhost:9090/targets` to check that all exporters are listed and their status is "UP".
- If any target is down, check network/firewall settings and exporter status.

For advanced configuration, see the [Prometheus documentation](https://prometheus.io/docs/introduction/overview/).

---

## Exporter Setup for VMware, Active Directory, and RHEL

Follow these steps to install and configure Prometheus exporters for each environment:

### VMware: vmware_exporter
1. **Install Python 3 and pip** on the system where you want to run the exporter.
2. **Install vmware_exporter:**
   ```bash
   pip install vmware-exporter
   ```
3. **Create a config file** (e.g., `config.yml`) with your vCenter/ESXi credentials. See [vmware_exporter config example](https://github.com/pryorda/vmware_exporter#configuration).
4. **Run the exporter:**
   ```bash
   vmware_exporter -c config.yml
   ```
   By default, metrics are exposed at `http://localhost:9272/metrics`.
5. **Prometheus scrape config:**
   ```yaml
   - job_name: 'vmware'
     static_configs:
       - targets: ['<exporter_host>:9272']
   ```

### Active Directory: windows_exporter
1. **Download the latest windows_exporter** from the [releases page](https://github.com/prometheus-community/windows_exporter/releases) on your AD server.
2. **Install and run as a service:**
   - Run the installer or use the provided `.exe` to install as a Windows service.
   - Default metrics endpoint: `http://localhost:9182/metrics`
3. **Prometheus scrape config:**
   ```yaml
   - job_name: 'ad-windows'
     static_configs:
       - targets: ['<ad_server>:9182']
   ```

### RHEL: node_exporter
1. **Download and extract node_exporter** from the [releases page](https://github.com/prometheus/node_exporter/releases) on your RHEL server.
2. **Run node_exporter:**
   ```bash
   ./node_exporter &
   ```
   By default, metrics are exposed at `http://localhost:9100/metrics`.
3. **Prometheus scrape config:**
   ```yaml
   - job_name: 'rhel-node'
     static_configs:
       - targets: ['<rhel_host>:9100']
   ```

- Replace `<exporter_host>`, `<ad_server>`, and `<rhel_host>` with the actual hostnames or IP addresses.
- Ensure firewall rules allow Prometheus to access the exporter ports.

For advanced configuration, refer to each exporter's documentation:
- [vmware_exporter](https://github.com/pryorda/vmware_exporter)
- [windows_exporter](https://github.com/prometheus-community/windows_exporter)
- [node_exporter](https://github.com/prometheus/node_exporter)

---

### 4. Custom Dashboards
You can create custom dashboards tailored to your environment by selecting relevant metrics from your exporters.

---

## Running Python Tests

Automated tests are provided for the provisioning scripts in `scripts/python/`.

### Prerequisites
- Python 3.x
- [pytest](https://docs.pytest.org/en/stable/): Install with `pip install pytest`

### Running the Tests

From the project root, run:

```bash
pytest scripts/python/test_vm_provisioner.py
```

This will execute the test suite for the `vm-provisioner.py` script, including tests for the `clone` and `list` commands.

---

## Architecture Design

The automation suite is designed to monitor and manage VMware, Active Directory, and RHEL infrastructure using a modular approach:

```
+-------------------+        +-------------------+        +-------------------+
|    VMware ESXi    |        | Active Directory  |        |      RHEL         |
+-------------------+        +-------------------+        +-------------------+
         |                           |                           |
         |  vmware_exporter          |  windows_exporter         |  node_exporter
         |  (Prometheus)             |  (Prometheus)             |  (Prometheus)
         |                           |                           |
         +-----------+---------------+---------------+-----------+
                     |                           |
                +-------------------------------+
                |         Prometheus             |
                +-------------------------------+
                             |
                +-------------------------------+
                |           Grafana              |
                +-------------------------------+
```

- **Exporters**: Each system runs a Prometheus exporter to expose metrics.
- **Prometheus**: Centralized metrics collection from all exporters.
- **Grafana**: Visualization layer with dashboards for CPU, memory, disk, VM status, and error percentage.
- **Automation Scripts**: Scripts in this repo automate provisioning, reporting, and monitoring tasks for each environment.

### Dashboard Files
- Example dashboards for VMware, AD, and RHEL are provided in the `grafana-dashboards/` directory. Import these into Grafana for instant infrastructure visibility.

For more details, see the documentation for each exporter and the Grafana [getting started guide](https://grafana.com/docs/grafana/latest/getting-started/getting-started-prometheus/).

---

## Step-by-Step Deployment Instructions

Follow these instructions to deploy and tear down the AWS infrastructure using the provided automation scripts.

### Prerequisites
- **AWS CLI** installed ([installation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html))
- AWS credentials configured (via `aws configure` or environment variables)
- Sufficient IAM permissions to create and delete VPC, EC2, ALB, Auto Scaling, Security Groups, etc.
- (Optional) Bash shell for running the scripts

### Deployment Steps

1. **Clone this repository** (if you haven't already):
   ```bash
   git clone <REPO_URL>
   cd <REPO_DIR>
   ```

2. **Run the setup script to provision AWS resources:**
   ```bash
   ./setup.sh
   ```
   - The script will create a VPC, subnets, security groups, ALB, target group, launch template, and auto scaling group.
   - Progress and resource IDs will be displayed in the terminal.

3. **Find the Application Load Balancer (ALB) DNS name:**
   - The script will output the ALB DNS name at the end.
   - You can also find it in the AWS Console under EC2 > Load Balancers.
   - Access your deployed application via the ALB DNS name in your browser.

4. **Tear down the environment when finished:**
   ```bash
   ./teardown.sh
   ```
   - This will delete all AWS resources created by setup.sh.
   - The script handles missing resources gracefully and will skip any that do not exist.

### Troubleshooting
- Ensure your AWS credentials are valid and have the necessary permissions.
- If a script fails, check the error message for details.
- Use the AWS Console to verify resource creation or deletion if unsure.
- For network issues, verify your security group and subnet configurations.

---

## AWS Architecture Design

The AWS automation scripts (`setup.sh` and `teardown.sh`) provision and destroy a scalable, highly available web infrastructure using the following components:

<p align="center">
  <img src="aws-architecture.png" alt="AWS Architecture Diagram" width="600" />
</p>

**Components:**
- **VPC**: Custom Virtual Private Cloud for network isolation.
- **Subnets**: Two public subnets in different Availability Zones for high availability.
- **Internet Gateway**: Allows internet access for resources in the VPC.
- **Route Table**: Routes traffic from subnets to the Internet Gateway.
- **Security Groups**: Firewall rules for ALB and EC2 instances.
- **Application Load Balancer (ALB)**: Distributes HTTP traffic across EC2 instances.
- **Target Group**: Registered EC2 instances for load balancing.
- **Launch Template**: Defines EC2 instance configuration (AMI, type, SG, user data).
- **Auto Scaling Group (ASG)**: Manages EC2 fleet, ensures desired capacity and scaling.
- **Scaling Policy**: Automatically scales EC2 instances based on CPU utilization.

**Automation Flow:**
- `setup.sh` provisions all AWS resources above, creating a ready-to-use, scalable web environment.
- `teardown.sh` destroys all resources, ensuring a clean environment and no lingering costs.
- These scripts can be integrated into CI/CD pipelines or used for hands-on AWS infrastructure labs.

---

## Required IAM Permissions for setup.sh and teardown.sh

To successfully run the automation scripts, your AWS IAM user or role must have permissions to create, modify, and delete the following resource types:

- VPCs, Subnets, Route Tables, Internet Gateways
- Security Groups
- EC2 Instances, Launch Templates
- Elastic Load Balancers (ALB), Target Groups, Listeners
- Auto Scaling Groups and Scaling Policies
- Tags for all above resources

**Recommended Policy:**
Attach the following AWS managed policies to your IAM user/role, or create a custom policy with these permissions:

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

- For production, restrict resources by ARN and limit actions as needed.
- You must also have permission to describe and delete resources for teardown.

---

## FAQ: Common Deployment Issues

**Q1: setup.sh fails with 'AccessDenied' or 'UnauthorizedOperation'. What should I do?**
A: Ensure your AWS credentials are configured and have sufficient IAM permissions to create VPC, EC2, ALB, Auto Scaling, and related resources. Run `aws sts get-caller-identity` to verify your identity.

**Q2: teardown.sh does not delete all resources. Why?**
A: Some resources may have dependencies or may have already been deleted manually. Check the AWS Console for any remaining resources and delete them manually if needed. The script is designed to skip missing resources gracefully.

**Q3: ALB DNS name does not resolve or is unreachable.**
A: Make sure your security groups allow inbound HTTP/HTTPS traffic. Also, verify that your subnets are public and associated with a route table that routes 0.0.0.0/0 to an Internet Gateway.

**Q4: EC2 instances are not launching or remain in 'pending' state.**
A: Check your launch template configuration (AMI ID, instance type, subnet, security group). Ensure there is sufficient capacity and your AWS account limits are not exceeded.

**Q5: setup.sh or teardown.sh fails with 'ResourceLimitExceeded' or quota errors.**
A: Your AWS account may have reached resource limits (e.g., VPCs, EC2 instances, ALBs). Review your AWS quotas and request increases if necessary.

**Q6: How do I debug script errors?**
A: Review the terminal output for error messages. You can also add `set -x` at the top of the shell scripts for verbose debugging. Check the AWS Console for resource status and logs.

**Q7: How do I clean up resources if a script fails partway?**
A: Re-run `teardown.sh` to attempt cleanup. If resources remain, delete them manually in the AWS Console.

For additional help, consult the AWS documentation or open an issue in this repository.

---

## Tagging Strategy for AWS Resources

A consistent tagging strategy is used to simplify resource management, cost tracking, and automated cleanup. The automation scripts (`setup.sh` and `teardown.sh`) apply tags to all major AWS resources they create.

**Tag Keys and Values:**
- `Name`: Identifies the resource and its role in the lab (e.g., `cli-lab-vpc`, `cli-lab-subnet-1`, `cli-lab-alb`)
- (You may extend with tags like `Environment=Lab`, `Project=CLI-Automation`, or `Owner=<your-name>`)

**Resources Tagged:**
- VPC: `Name=cli-lab-vpc`
- Subnets: `Name=cli-lab-subnet-1`, `Name=cli-lab-subnet-2`
- Internet Gateway: `Name=cli-lab-igw`
- Route Table: `Name=cli-lab-rt`
- Security Groups: `Name=cli-lab-alb-sg`, `Name=cli-lab-ec2-sg`
- (Other resources like ALB, Target Group, Launch Template, and ASG may be tagged via the AWS Console or extended in the scripts)

**Benefits:**
- **Easy Identification:** Tags make it simple to find and manage lab resources in the AWS Console.
- **Automated Cleanup:** `teardown.sh` uses tags to identify and delete only lab-created resources, reducing risk of accidental deletion.
- **Cost Tracking:** Tags help track costs by project, environment, or owner in AWS billing reports.

**Best Practices:**
- Use a unique prefix (e.g., `cli-lab-`) for all lab resources.
- Add additional tags for environment, project, or owner as needed.
- Regularly review and clean up resources using tag filters in the AWS Console.

You can customize or extend the tagging strategy in `setup.sh` to fit your organization's standards.
