# EKS-Terraform

# Project Structure

```bash
.
├── main.tf
├── variable.tf
├── output.tf
├── README.md
└── deployment
    └── deployment.yaml
```

---

# AWS Infrastructure Structure

```text
VPC
 ├── Subnets
 │     └── Route Table
 │            └── Internet Gateway
 │
 ├── Security Groups
 │
 ├── EKS Cluster
 │
 └── EKS Node Group (EC2 worker nodes)
       └── IAM Roles & Policies
```

---

# Deploy Terraform Infrastructure

Initialize Terraform:

```bash
terraform init
```

Preview Infrastructure:

```bash
terraform plan
```

Create Infrastructure:

```bash
terraform apply
```

---

# Configure kubectl

```bash
aws eks update-kubeconfig \
  --region ap-south-1 \
  --name skyopsx-cluster
```

Verify Cluster:

```bash
kubectl get nodes
```

---

# Deploy Kubernetes Application

Move inside deployment directory:

```bash
cd deployment
```

Deploy application resources:

```bash
kubectl apply -f .
```

Verify resources:

```bash
kubectl get all -n amazon-ns
```

---

# Access Application

The application is exposed using AWS LoadBalancer Service.

Example:

```text
http://app.devopshackarena.xyz
```