# Flask Auth App with AWS Infrastructure

This project demonstrates a complete DevOps workflow for deploying a Flask authentication application on AWS infrastructure using Terraform and GitLab CI/CD.

## Project Overview

The solution includes:
- A Flask authentication application container
- AWS infrastructure provisioning (VPC, subnets, security groups)
- Private S3 bucket for sensitive data
- IAM roles for secure S3 access
- Automated CI/CD pipeline with testing and deployment

## Infrastructure Components

### AWS Resources Provisioned:
- **VPC** with public and private subnets
- **Internet Gateway** and **NAT Gateway** for network traffic
- **EC2 Instance** running Docker with the Flask app
- **Private S3 Bucket** for sensitive data storage
- **IAM Role** for secure S3 access from EC2
- **Security Groups** controlling access to the Flask app

## CI/CD Pipeline

The GitLab CI/CD pipeline includes the following stages:

[![pipeline status](https://gitlab.com/Sanders003/DevOps-Project/badges/main/pipeline.svg)](https://gitlab.com/Sanders003/DevOps-Project/-/pipelines)

### Pipeline Stages:
1. **Lint**: Code quality checks using flake8
2. **Test**: Unit tests execution with pytest
3. **Build**: Docker image build and push to Docker Hub
4. **Deploy (Staging)**: Terraform infrastructure provisioning
5. **Test (Staging)**: Smoke tests against deployed infrastructure
6. **Cleanup (Staging)**: Manual cleanup of staging resources

### Successful Pipeline Run:
[Pipeline](https://gitlab.com/Sanders003/DevOps-Project/-/pipelines/1984341003)

## Getting Started

### Prerequisites
- AWS account with appropriate permissions
- Terraform v1.0+
- Docker

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/Sanders003/DevOps-Project.git
   cd DevOps-Project
   ```

3. Initialize Terraform:
   ```bash
   cd terraform
   terraform init
   terraform validate
   ```

### Deployment
1. Review the Terraform plan:
   ```bash
   terraform plan
   ```

2. Apply the infrastructure:
   ```bash
   terraform apply -auto-approve
   ```


## Security Features
- Private S3 bucket with restricted access
- IAM role with least-privilege permissions
- Security group restricting access to necessary ports
- Sensitive credentials managed through environment variables

## Cleanup
To destroy all created resources:
```bash
terraform destroy -auto-approve
```

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss proposed changes.
