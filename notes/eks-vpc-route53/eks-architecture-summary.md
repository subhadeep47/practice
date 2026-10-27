# AWS EKS & Networking Architecture Reference Guide

This document summarizes the core architecture, security, and networking concepts discussed for hosting Spring Boot applications within an Amazon EKS (Elastic Kubernetes Service) cluster connected to AWS infrastructure.

---

## 1. Route 53: A Records vs. CNAME vs. Alias Records
When configuring domain routing in AWS Route 53, choosing the right record type affects cost, performance, and compliance with DNS standards.

| Feature | A Record | CNAME Record | Route 53 Alias Record |
| :--- | :--- | :--- | :--- |
| **Maps To** | An IPv4 address (e.g., `192.0.2.1`) | Another domain name (e.g., `app.my-elb.amazonaws.com`) | An internal AWS resource pointer (e.g., ELB, S3, CloudFront) |
| **Zone Apex Support (example.com)** | Yes | **No** (Prohibited by DNS RFC standards) | **Yes** (Route 53's specialized capability) |
| **DNS Resolver Hops** | 1 lookup (Returns the IP directly) | 2 lookups (Returns the name, forcing a second lookup) | 1 lookup (Route 53 resolves the AWS resource IP internally) |
| **AWS Query Costs** | Standard query rates | Standard query rates | **Free** when targeting supported AWS resources |
| **IP Changes** | Manual updates required if infrastructure changes | Automatically handles changes (points to a name) | Automatically tracks and handles AWS resource IP changes |

### Core Architectural Takeaway
* Always use **Alias Records** when targeting AWS resources (like Application Load Balancers or CloudFront distributions). It supports the zone apex (`example.com`), optimizes DNS resolution latency, and eliminates Route 53 query costs for those resources.

---

## 2. Integrating AWS API Gateway with Kubernetes
You can securely route traffic from AWS API Gateway to a Spring Boot microservice running inside a Kubernetes cluster using two main patterns:

### A. The Private Route (Production Standard)
* **Flow:** `Client` → `API Gateway` → `VPC Link` → `Private Network Load Balancer (NLB)` → `Kubernetes Ingress / Service` → `Spring Boot Pods`.
* **Details:** The cluster remains fully isolated within private VPC subnets. API Gateway accesses it securely through an AWS VPC Link hooked to an internal NLB provisioned by Kubernetes.

### B. The Public Route (Simpler, Less Secure)
* **Flow:** `Client` → `API Gateway` → `Public Internet` → `Public Load Balancer` → `Kubernetes Ingress` → `Spring Boot Pods`.
* **Details:** API Gateway treats the public DNS endpoint of your Kubernetes cluster's load balancer as a standard HTTP integration target. Mutual TLS (mTLS) or security group restrictions are required to ensure clients do not bypass the API Gateway.

---

## 3. Amazon VPC CNI: ENIs & Prefix Delegation
The Amazon VPC CNI plugin assigns real VPC IP addresses to Kubernetes Pods. Managing this efficiently prevents constraints on node capacity.

* **ENI (Elastic Network Interface):** A virtual network interface card attached to an EC2 instance. Every EC2 instance size has a strict limit on the number of ENIs it can hold and the number of secondary IP addresses allowed per ENI.
* **The Pod Density Bottleneck:** In standard mode, every Pod requires its own secondary IP address. A `t3.medium` instance is capped at **17 Pods** due to these hardware limits, even if CPU and memory are underutilized.
* **`ENABLE_PREFIX_DELEGATION`:** A setting that configures the CNI to allocate IP addresses in contiguous blocks of 16 (a `/28` prefix) rather than single (`/32`) IPs. Enabling this increases the capacity of a `t3.medium` from 17 Pods to the maximum Kubernetes runtime limit of **110 Pods**.

> ⚠️ **Caution:** Prefix delegation consumes IP blocks aggressively. Ensure your VPC subnets are large enough (e.g., `/22` or greater) and configure `WARM_PREFIX_TARGET=1` to minimize idle IP hoarding.

---

## 4. Kubernetes Service Accounts vs. AWS IAM
To implement the principle of least privilege, workloads must access AWS resources without global infrastructure node credentials or hardcoded keys.

### Core Identities Defined
* **IAM User:** A static, permanent identity created in AWS IAM intended for humans, CI/CD pipelines, or systems outside AWS. Uses long-lived Access/Secret keys.
* **IAM Role:** An abstract AWS identity with permissions that trusted entities (like EC2 instances or Lambda functions) can temporarily assume via short-lived security tokens.
* **Kubernetes Service Account:** A native Kubernetes identity scoped to a specific namespace, used by containers running inside Pods.

### IRSA & EKS Pod Identity
By binding a Kubernetes Service Account to an AWS IAM Role via **IRSA (IAM Roles for Service Accounts)** or **Amazon EKS Pod Identity**, individual Pods receive scoped access.
* **Why it's used:** If a Spring Boot Pod needs access to an S3 bucket, permissions are granted *only* to that specific Pod's Service Account. The underlying EC2 host node and all other unrelated adjacent Pods retain zero access to the bucket.

---

## 5. Exposing Services: LoadBalancer Service vs. Ingress Controller
When exposing your Spring Boot application to the public internet, an Ingress Controller is the enterprise standard.

* **`LoadBalancer` Service:** Provisions a dedicated, unique AWS Load Balancer for every single service. This leads to high cloud infrastructure costs, offers no Layer 7 (URL path/host) routing intelligence, and fragments SSL/TLS management.
* **Ingress Controller (e.g., AWS Load Balancer Controller):** Provisions **one** single Application Load Balancer (ALB) that can be shared across dozens of microservices. It performs Layer 7 routing (e.g., routing `/users` to `user-service` and `/orders` to `order-service`), cuts AWS infrastructure costs significantly, and centralizes SSL termination using AWS Certificate Manager (ACM).

### Infrastructure Component: The AWS Load Balancer Controller
A common point of confusion is why the **AWS Load Balancer Controller** needs its own `IAMServiceAccount`. 

The controller is not an abstract cloud configuration; it is an open-source operator running inside regular agent pods on your EC2 worker nodes. Because this controller software must dynamically call AWS APIs (`elasticloadbalancing:CreateLoadBalancer`, etc.) to create or modify physical AWS Application Load Balancers when you deploy an Ingress manifest, it **must** possess an `IAMServiceAccount` bound to an infrastructure-managing IAM Role.