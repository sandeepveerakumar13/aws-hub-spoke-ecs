# AWS Hub-Spoke ECS Deployment

## 1. Project Overview

This project implements a Hub-Spoke architecture in AWS with two containerized microservices running on Amazon ECS Fargate.

Terraform is used to provision the AWS infrastructure, Amazon ECR is used to store Docker images, and GitHub Actions is used to automate the infrastructure and application deployment.

The project is deployed in the AWS Mumbai region (`ap-south-1`).

The main application traffic flow is:

User → Application Load Balancer → Hub VPC → Transit Gateway → Spoke VPC → ECS Fargate

The project demonstrates:

- Hub-Spoke networking
- AWS Transit Gateway
- Application Load Balancer
- ECS Fargate
- Amazon ECR
- Docker
- Terraform
- GitHub Actions
- GitHub OIDC authentication
- ALB to ECS communication across VPCs
- CI/CD deployment

---

## 2. Architecture

The project uses two VPCs.

The Hub VPC contains the Application Load Balancer and Transit Gateway attachment.

The Spoke VPC contains the ECS Fargate workloads.

Traffic flows from the internet-facing ALB in the Hub VPC through the Transit Gateway to the ECS services running in the Spoke VPC.

Architecture:

    USER
      |
      v
    APPLICATION LOAD BALANCER
    HTTP :80
      |
      v
    HUB VPC
    10.0.0.0/16
      |
      v
    TRANSIT GATEWAY
      |
      v
    SPOKE VPC
    10.1.0.0/16
      |
      v
    ECS FARGATE CLUSTER
      |
      +-------------------+
      |                   |
      v                   v
    API SERVICE         UI SERVICE
    Port 5000           Port 80

---

## 3. Networking

### Hub VPC

The Hub VPC is the central VPC in the architecture.

- CIDR: `10.0.0.0/16`
- Region: `ap-south-1`

The Hub VPC contains:

- Internet Gateway
- NAT Gateway
- Public subnets
- Transit Gateway attachment subnets
- Application Load Balancer
- Route tables

### Hub Public Subnets

| Subnet | CIDR | Availability Zone |
|---|---|---|
| Hub Public Subnet 1 | `10.0.1.0/24` | `ap-south-1a` |
| Hub Public Subnet 2 | `10.0.2.0/24` | `ap-south-1b` |

These subnets are used by the internet-facing Application Load Balancer.

### Hub Transit Gateway Subnets

| Subnet | CIDR | Availability Zone |
|---|---|---|
| Hub TGW Subnet 1 | `10.0.3.0/24` | `ap-south-1a` |
| Hub TGW Subnet 2 | `10.0.4.0/24` | `ap-south-1b` |

These subnets are used for the Transit Gateway attachment.

### Spoke VPC

The Spoke VPC contains the ECS Fargate workloads.

- CIDR: `10.1.0.0/16`
- Region: `ap-south-1`

The ECS services run in private subnets.

### Spoke Private Subnets

| Subnet | CIDR | Availability Zone |
|---|---|---|
| Spoke Private Subnet 1 | `10.1.1.0/24` | `ap-south-1a` |
| Spoke Private Subnet 2 | `10.1.2.0/24` | `ap-south-1b` |

### Transit Gateway

AWS Transit Gateway is used to connect the Hub VPC and Spoke VPC.

The routing path is:

`Hub VPC 10.0.0.0/16 → Transit Gateway → Spoke VPC 10.1.0.0/16`

Routes are configured in the VPC route tables to allow communication between the two VPCs.

The Hub route tables contain routes for the Spoke VPC CIDR.

The Spoke route tables contain routes for the Hub VPC CIDR.

This allows the Application Load Balancer in the Hub VPC to communicate with the ECS tasks in the Spoke VPC.

---

## 4. Internet Gateway and NAT Gateway

The Hub VPC has an Internet Gateway attached to it.

The public subnets use the Internet Gateway for internet connectivity.

A NAT Gateway is deployed in the Hub public subnet.

The NAT Gateway provides outbound internet connectivity for resources in private subnets when required.

The ECS services remain in the private subnets of the Spoke VPC.

---

## 5. Security Groups

Security groups are used to control traffic between the ALB and ECS services.

### ALB Security Group

The ALB security group allows HTTP traffic on port 80.

- Protocol: TCP
- Port: 80
- Traffic: HTTP

### ECS Security Group

The ECS security group allows application traffic from the ALB security group.

API service:

- Port: 5000

UI service:

- Port: 80

The ECS tasks are deployed in private subnets and are not directly exposed to the internet.

---

## 6. ECS Fargate

An ECS Fargate cluster is deployed in the Spoke VPC.

The cluster contains two separate ECS services.

| ECS Service | Container Port | Target Group |
|---|---:|---|
| `user-api-service` | `5000` | `user-api-tg` |
| `user-ui-service` | `80` | `user-ui-tg` |

Each service has its own:

- ECS task definition
- ECS service
- Container
- Target group
- Health check

The ECS tasks use `awsvpc` networking.

Fargate tasks receive their own private IP addresses, so the ALB target groups use IP target type.

Target type:

`IP`

---

## 7. API Service

The API application is deployed as an ECS Fargate service.

Service name:

`user-api-service`

Container port:

`5000`

Target group:

`user-api-tg`

The service runs inside the private subnets of the Spoke VPC.

The ALB forwards traffic to the API target group.

---

## 8. UI Service

The UI application is deployed as a separate ECS Fargate service.

Service name:

`user-ui-service`

Container port:

`80`

Target group:

`user-ui-tg`

The UI service also runs inside the private subnets of the Spoke VPC.

---

## 9. Application Load Balancer

The Application Load Balancer is deployed in the Hub VPC public subnets.

It is internet-facing and uses the two public subnets.

### Listener

- Protocol: HTTP
- Port: 80

The ALB uses separate target groups for the API and UI services.

Traffic path:

`ALB → user-api-tg → API ECS Service :5000`

`ALB → user-ui-tg → UI ECS Service :80`

The target groups use IP targets because the ECS services are running on Fargate using `awsvpc` networking.

Health checks are configured for both target groups.

The final deployment showed healthy targets for both services.

---

## 10. Amazon ECR

Two Amazon ECR repositories are used for the application images.

- `user-api`
- `user-ui`

GitHub Actions builds the Docker images and pushes them to these repositories.

Example image names:

`553336999743.dkr.ecr.ap-south-1.amazonaws.com/user-api:latest`

`553336999743.dkr.ecr.ap-south-1.amazonaws.com/user-ui:latest`

---

## 11. Docker

Each microservice has its own Dockerfile.

The application images are built during the GitHub Actions deployment workflow.

The process is:

Application Source → Dockerfile → Docker Image → Amazon ECR → ECS Fargate

Docker is used only for packaging the applications. ECS Fargate handles running the containers.

---

## 12. Terraform

Terraform is used to provision and manage the AWS infrastructure.

The Terraform configuration covers:

- Hub VPC
- Spoke VPC
- Public subnets
- Private subnets
- Route tables
- Internet Gateway
- NAT Gateway
- Transit Gateway
- Transit Gateway attachments
- Security groups
- Application Load Balancer
- ALB listener
- Target groups
- Listener rules
- ECS cluster
- ECS task definitions
- ECS services
- IAM roles
- ECR repositories

Terraform commands used during the project:

`terraform init`

`terraform fmt`

`terraform validate`

`terraform plan`

`terraform apply`

For automated deployment through GitHub Actions, Terraform apply is executed with:

`terraform apply -auto-approve`

---

## 13. Terraform State

Terraform state is stored remotely in Amazon S3.

Backend configuration:

- S3 Bucket: `aws-hub-spoke-ecs-terraform-state-553336999743`
- Key: `aws-hub-spoke-ecs/terraform.tfstate`
- Region: `ap-south-1`

The Terraform state file is not committed to the repository.

The `.terraform` directory and local Terraform state files are excluded using `.gitignore`.

---

## 14. GitHub Actions

GitHub Actions is used for infrastructure provisioning and application deployment.

The workflow performs the following steps:

1. Checkout the repository
2. Configure AWS credentials
3. Verify AWS identity
4. Initialize Terraform
5. Run Terraform format check
6. Validate Terraform
7. Run Terraform plan
8. Apply Terraform on the `master` branch
9. Build Docker images
10. Login to Amazon ECR
11. Push images to ECR
12. Update ECS services
13. Wait for ECS services to become stable

The deployment flow is:

GitHub → GitHub Actions → Terraform → AWS Infrastructure

GitHub → GitHub Actions → Docker Build → ECR → ECS Fargate

---

## 15. Branch Promotion

The branch promotion process used for this project is:

`feature/project-setup → dev → qa → master`

Changes are promoted using Pull Requests.

### Feature to Dev

Changes from `feature/project-setup` are promoted to `dev`.

The workflow runs Terraform checks and plan.

Infrastructure is not automatically applied from the feature branch.

### Dev to QA

Changes are promoted from `dev` to `qa`.

Terraform checks and plan are run again.

### QA to Master

The final Pull Request is:

`qa → master`

After the Pull Request is merged, a push event occurs on the `master` branch.

The `master` workflow performs the actual deployment.

---

## 16. Deployment Conditions

The workflow is configured so that normal branches perform validation and planning.

For feature, dev and qa branches:

- Terraform Init
- Terraform Format Check
- Terraform Validate
- Terraform Plan

For a push to `master`:

- Terraform Plan
- Terraform Apply
- Docker Build
- ECR Push
- ECS Deployment

This provides a controlled promotion process before the final deployment.

---

## 17. GitHub OIDC Authentication

GitHub Actions authenticates to AWS using OpenID Connect.

Long-lived AWS access keys are not stored in GitHub Actions.

Two IAM roles are used:

- `github-actions-terraform-role`
- `github-actions-ecs-deploy-role`

The Terraform role is used for infrastructure operations.

The ECS deployment role is used for:

- ECR authentication
- ECR image push
- ECS deployment

The IAM trust policies restrict which GitHub repository and branches can assume the roles.

The ECS deployment role is restricted to the `master` branch.

---

## 18. IAM

IAM roles are used for AWS access.

The ECS task execution role is used by ECS tasks during startup and for pulling images from ECR.

GitHub Actions uses separate roles for Terraform and ECS deployment.

The GitHub Actions roles are assumed using OIDC rather than long-lived access keys.

---

## 19. CI/CD Deployment Flow

The application deployment flow is:

GitHub Repository
→ GitHub Actions
→ Docker Build
→ Amazon ECR
→ ECS Fargate
→ Application Load Balancer
→ Application

The infrastructure flow is:

GitHub Repository
→ GitHub Actions
→ Terraform
→ AWS Infrastructure

When the `master` branch is updated, GitHub Actions builds the latest application images and pushes them to ECR.

The ECS services are then forced to start a new deployment so that the latest images are used.

The workflow waits for the ECS services to reach a stable state.

---

## 20. Troubleshooting

### GitHub OIDC AssumeRoleWithWebIdentity Error

During the initial GitHub Actions setup, the workflow failed while trying to authenticate to AWS.

The error was:

`Not authorized to perform sts:AssumeRoleWithWebIdentity`

The problem was related to the AWS IAM trust policy used by the GitHub OIDC provider.

The repository uses GitHub's newer immutable repository subject format.

The trust policy was updated to use the correct repository owner ID, repository ID and required branch references.

After updating the trust policy, GitHub Actions was able to assume the AWS IAM role successfully.

### Terraform Apply EOF Error

The first Terraform apply in GitHub Actions attempted to wait for interactive approval.

GitHub Actions does not provide an interactive terminal for this step.

The job therefore failed with an EOF error.

The apply command was changed to:

`terraform apply -auto-approve`

After this change, Terraform was able to apply the infrastructure without waiting for manual confirmation.

### Terraform Format Check Error

The workflow initially failed at:

`terraform fmt -check`

There were formatting differences in the Terraform backend configuration.

The Terraform files were formatted using:

`terraform fmt`

After formatting the files, the workflow passed the format check.

### Terraform State After Changing the Checkout

The project was being worked on from a separate checkout directory.

The new checkout initially did not contain the existing Terraform state.

Running:

`terraform state list`

did not show the resources that had already been deployed.

The existing state was carried into the correct working directory and the S3 backend was initialized.

Terraform then recognized the existing infrastructure correctly.

The final Terraform plan showed:

`No changes. Your infrastructure matches the configuration.`

The Terraform state file is not committed to the repository.

---

## 21. Deployment Verification

The final deployment completed successfully.

The following items were verified:

- Terraform initialization completed successfully
- Terraform validation completed successfully
- Terraform plan completed successfully
- Terraform apply completed successfully
- Docker images were built
- Images were pushed to ECR
- ECS services were updated
- ECS deployments reached a stable state
- ALB target groups reported healthy ECS targets

The API service runs on port `5000`.

The UI service runs on port `80`.

---

## 22. Project Structure

The main repository structure is:

aws-hub-spoke-ecs/

    .github/
        workflows/
            terraform.yml

    api/
        Dockerfile
        ...

    ui/
        Dockerfile
        ...

    terraform/
        backend.tf
        provider.tf
        variables.tf
        ...

    .gitignore

    README.md

---

## 23. Main AWS Resources

### Networking

- Hub VPC
- Spoke VPC
- Internet Gateway
- NAT Gateway
- Public subnets
- Private subnets
- Route tables
- Transit Gateway
- Transit Gateway attachments

### Load Balancing

- Application Load Balancer
- ALB listener
- ALB listener rules
- API target group
- UI target group

### ECS

- ECS Fargate cluster
- API task definition
- UI task definition
- API ECS service
- UI ECS service

### Container Registry

- `user-api` ECR repository
- `user-ui` ECR repository

### IAM

- ECS task execution role
- GitHub Actions Terraform role
- GitHub Actions ECS deployment role

### State

- S3 Terraform backend

---

## 24. AWS Region

All AWS resources for this project are deployed in:

`ap-south-1`

---

## 25. Final Result

The completed setup provides:

Internet
→ ALB in Hub VPC
→ Transit Gateway
→ Spoke VPC
→ ECS Fargate
→ API and UI services

Terraform manages the AWS infrastructure.

Amazon ECR stores the Docker images.

GitHub Actions handles the CI/CD process.

GitHub OIDC is used for AWS authentication.

The final ECS deployment completed successfully and the ALB target groups reported healthy ECS targets.

---

## 26. Project Status

| Component | Status |
|---|---|
| Hub VPC | Completed |
| Spoke VPC | Completed |
| Transit Gateway | Completed |
| VPC Routing | Completed |
| Internet Gateway | Completed |
| NAT Gateway | Completed |
| Security Groups | Completed |
| Application Load Balancer | Completed |
| ALB Listener | Completed |
| Target Groups | Completed |
| ECS Fargate Cluster | Completed |
| API ECS Service | Completed |
| UI ECS Service | Completed |
| Amazon ECR | Completed |
| Terraform | Completed |
| S3 Remote State | Completed |
| GitHub Actions | Completed |
| GitHub OIDC | Completed |
| CI/CD Deployment | Completed |
| Health Checks | Completed |

## Project Status

Completed.
