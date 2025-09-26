import subprocess
import boto3
import time
import json
from langchain_openai import ChatOpenAI
from langchain.prompts import ChatPromptTemplate

llm = ChatOpenAI(model="gpt-4o-mini")
ec2 = boto3.client("ec2", region_name="eu-west-1")

GOAL = "Create an Ubuntu 22.04 t3.micro EC2 instance in eu-west-1, tagged 'ec2-ai'"

prompt = ChatPromptTemplate.from_template("""
Write a Terraform config (main.tf) to achieve this goal:
{goal}

Constraints:
- Must stay under $10/month (use cost-efficient/free-tier instance types only).
- Use Ireland region Ubuntu 22.04 AMI.
- Only deploy ONE EC2 instance.
- instance_type = t3.micro or cheaper.
- Root volume <= 8GB gp3.
- Assume SSH key "ec2-key" exists.
- Add tags:
    Budget = "10usd"
    Name   = "ec2-ai"
""")

terraform_code = llm.invoke(prompt.format(goal=GOAL)).content

with open("main.tf", "w") as f:
    f.write(terraform_code)

print("Terraform code generated.")

def run_terraform_cmd(cmd):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    print(result.stdout)
    if result.returncode != 0:
        print("Error:", result.stderr)
        return False
    return True

def check_infracost():
    result = subprocess.run(
        "infracost breakdown --path . --format json",
        shell=True, capture_output=True, text=True
    )
    if result.returncode != 0:
        print("Infracost error:", result.stderr)
        return False

    data = json.loads(result.stdout)
    total = data["summary"].get("totalMonthlyCost")
    if total is None:
        print("Could not parse Infracost output.")
        return False

    total = float(total)
    if total > 10:
        print(f"Estimated monthly cost ${total:.2f} exceeds budget ($10). Aborting.")
        return False

    print(f"Estimated monthly cost: ${total:.2f} (within budget).")
    return True

print("Running Terraform...")
run_terraform_cmd("terraform init")

if run_terraform_cmd("terraform validate"):
    if run_terraform_cmd("terraform plan -out=tfplan"):
        if check_infracost():
            run_terraform_cmd("terraform apply -auto-approve tfplan")
        else:
            print("Deployment skipped due to budget limit.")

print("Verifying EC2 instance...")
time.sleep(15)

reservations = ec2.describe_instances(
    Filters=[{"Name": "tag:Name", "Values": ["ec2-ai"]}]
)

instances = reservations["Reservations"][0]["Instances"] if reservations["Reservations"] else []
if instances and instances[0]["State"]["Name"] == "running":
    print(f"EC2 Instance is up: {instances[0]['InstanceId']}")
else:
    print("Instance not found or not running.")
