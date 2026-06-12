# EKS Deployment Guide

## Prerequisites

```bash
brew install awscli eksctl skaffold kubectl terraform
```

## 1. AWS SSO Login

```bash
aws sso login --profile dev-us-east-1
```

## 2. Provision ECR Repositories (Terraform)

```bash
cd terraform-eks
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set aws_profile, region, cluster_name
terraform init
terraform plan -out=plan.out
terraform apply plan.out
```

> **Note:** Terraform only manages ECR repos. The EKS cluster is created separately via eksctl.
>
> If the apply fails partway through, re-run `terraform apply -auto-approve` to create any missing repos before continuing.

## 3. Create the EKS Cluster

> **Note:** AWS default limit is 5 VPCs per region. If you're at the limit, reuse an existing VPC by passing `--vpc-public-subnets` (see below). Do NOT use the Terraform VPC module in this repo — it will hit the same limit.

### Check existing VPCs

```bash
aws ec2 describe-vpcs --region us-east-1 --profile dev-us-east-1 \
  --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock,Default:IsDefault,Name:Tags[?Key==`Name`]|[0].Value}' \
  --output table
```

### Get subnets from the default VPC

```bash
aws ec2 describe-subnets --region us-east-1 --profile dev-us-east-1 \
  --filters "Name=vpc-id,Values=<default-vpc-id>" \
  --query 'Subnets[*].{ID:SubnetId,AZ:AvailabilityZone,Public:MapPublicIpOnLaunch}' \
  --output table
```

Pick one **public** subnet from each of 3 different AZs.

### Create the cluster

```bash
eksctl create cluster \
  --name online-boutique-01 \
  --region us-east-1 \
  --nodegroup-name default \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 5 \
  --vpc-public-subnets <subnet-az1>,<subnet-az2>,<subnet-az3> \
  --profile dev-us-east-1
```

Takes ~15 minutes. kubeconfig is updated automatically on completion.

### Verify

```bash
kubectl get nodes
```

## 4. Authenticate Docker to ECR

Required before the first push — tokens expire after 12 hours.

```bash
aws ecr get-login-password --region us-east-1 --profile dev-us-east-1 \
  | docker login --username AWS --password-stdin \
    <account-id>.dkr.ecr.us-east-1.amazonaws.com
```

The ECR registry URL is printed by `terraform output ecr_registry`.

## 5. Deploy the App

```bash
cd /path/to/microservices-demo
skaffold run -p eks --default-repo=<account-id>.dkr.ecr.us-east-1.amazonaws.com
```

First run takes longer — all images are built and pushed to ECR. Subsequent runs use the local cache.

### Get the frontend URL

```bash
kubectl get service frontend-external
```

Open the `EXTERNAL-IP` in a browser. Allow 1-2 minutes for the load balancer to become reachable.

## Teardown

```bash
# Delete the app from the cluster
skaffold delete -p eks

# Delete the cluster and node group (~5 min)
eksctl delete cluster --name online-boutique-01 --region us-east-1 --profile dev-us-east-1

# Delete ECR repos
cd terraform-eks && terraform destroy
```

## Troubleshooting

| Error | Fix |
|---|---|
| `VpcLimitExceeded` | AWS default limit is 5 VPCs per region. Use `--vpc-public-subnets` to reuse an existing VPC. |
| `AlreadyExistsException: Stack ... already exists` | A previous failed attempt left a CloudFormation stack. Run `eksctl delete cluster --name <name> --region us-east-1 --profile dev-us-east-1` then retry. |
| `no basic auth credentials` | Docker is not authenticated to ECR. Run the `aws ecr get-login-password` command in step 4. |
| `repository does not exist in the registry` | An ECR repo is missing. Run `terraform apply -auto-approve` in `terraform-eks/` to create it. |
| `command not found: skaffold` | `brew install skaffold` |
| `command not found: eksctl` | `brew install eksctl` |
