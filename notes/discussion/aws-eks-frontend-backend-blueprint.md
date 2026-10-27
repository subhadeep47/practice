# AWS Frontend Architecture & EKS Networking Blueprint

This comprehensive guide serves as an architectural blueprint and reference manual for deploying modern frontend and backend applications using Amazon Web Services (AWS) and Amazon Elastic Kubernetes Service (EKS). 

---

## 1. Frontend Hosting Strategy: S3 + CloudFront vs. Kubernetes (EKS)

The industry benchmark for static frontend delivery is **Amazon S3 coupled with Amazon CloudFront**. However, when using Server-Side Rendering (SSR) frameworks, containerising inside EKS becomes a viable alternative.

### Comprehensive Comparison Matrix

| Architectural Feature | AWS S3 + Amazon CloudFront (Recommended for Static/SPA) | Kubernetes / Amazon EKS (Required for Dynamic SSR) |
| :--- | :--- | :--- |
| **Ideal Workloads** | Single Page Applications (SPAs) like React (Vite/CRA), Vue, Angular, or Next.js using Static Site Generation (`next export`). | Server-Side Rendered (SSR) architectures like standard Next.js Node.js servers, Remix, or workloads bound by multi-cloud compliance. |
| **Financial Cost** | **Ultra Low-Cost / Serverless**. Charges scale based strictly on data volume and storage (fractions of a cent per GB). | **High Core Overhead**. Incurs non-stop compute charges for EC2/Fargate instances, plus AWS Application Load Balancer (ALB) processing units. |
| **Latency & Performance** | **Ultra-Low Edge Performance**. Files are cached globally across CloudFront Edge Points of Presence (PoPs) directly adjacent to users. | **Centralized Network Hops**. Traffic routes through an ALB into a regional VPC cluster, introducing processing overhead. |
| **Scalability Profile** | **Instant & Infinite**. Handles viral traffic spikes transparently without scale-up rules or pre-warming mechanisms. | **Reactive Autoscaling**. Requires tweaking the Horizontal Pod Autoscaler (HPA) and Karpenter/Cluster Autoscaler to spin up nodes dynamically. |
| **Operational Maintenance** | **Zero Infra Overhead**. No underlying operating systems, runtimes, or virtual machinery to update, track, or secure. | **High Complexity**. Demands maintaining Dockerfiles, tracking Node version updates, monitoring cluster memory, and styling Ingress controllers. |

---

## 2. Decoupled Frontend Communication Architectures

When decoupling a static frontend (hosted on S3/CloudFront) from a dynamic API backend, choose one of the following integration vectors:

### Option A: Single Domain Reverse Proxy via CloudFront Routing (Best Practice)
In this layout, CloudFront orchestrates the routing for both static components and programmatic APIs under a shared top-level domain name (e.g., `example.com`).

```
                              ┌──► Default Behavior (*) ──► Amazon S3 Bucket (Static Assets)
                              │
[ User Browser ] ──► example.com (CloudFront)
                              │
                              └──► Path Behavior (/api/*) ─► Backend Application Load Balancer
```

#### Strategic Advantages:
* **Eliminates CORS Errors:** The web browser evaluates the origin holistically, matching schemes, hostnames, and ports. This side-steps Cross-Origin Resource Sharing restrictions entirely.
* **Hardened Cookie Governance:** Enables the secure execution of standard `HttpOnly`, `Secure`, and `SameSite=Strict` browser cookies for identity management.
* **Consolidated SSL Management:** You only need to bind a single ACM (AWS Certificate Manager) SSL/TLS certificate to the CloudFront distribution.
* **Environment Agility:** Frontend development builds can leverage relative endpoints (`fetch('/api/v1/resource')`) bypassing hardcoded environmental parameters.

### Option B: Split Domain Architecture
The application layout segregates layers structurally using dedicated DNS domain addresses (e.g., frontend at `example.com` and programmatic APIs at `api.example.com`).

#### Technical Requirements & Limitations:
* **Explicit CORS Policies Required:** The API backend layers must inject valid headers (`Access-Control-Allow-Origin: https://example.com`) to allow data visibility to the client's browser engine.
* **Relaxed Cookie Security:** Session sharing across varying subdomains forces configuration compromises down to `SameSite=Lax` or `SameSite=None`, creating potential tracking vulnerabilities.
* **CI/CD Injection Dependency:** The exact destination hostname must be injected directly into the frontend artifacts at compile time using environment variables (e.g., `VITE_API_URL=https://api.example.com npm run build`) before pushing payloads into the S3 bucket.

---

## 3. Production VPC Tiering & Core EKS Subnet Topology

To insulate compute logic from structural exploits, build a resilient **3-Tier VPC Subnet Strategy** spanning a minimum of 2 (preferably 3) Availability Zones (AZs).

```
VPC Boundary (e.g., 10.0.0.0/16)
 ├── Public Subnets (AZ-a / AZ-b)      ──► [ NAT Gateways & Public ALBs Only ]
 │    └── Routing: 0.0.0.0/0 -> Internet Gateway (IGW)
 │
 ├── Private Subnets (AZ-a / AZ-b)     ──► [ EKS Worker Nodes: Frontend & Backend Pods ]
 │    └── Routing: 0.0.0.0/0 -> NAT Gateways
 │
 └── Isolated Subnets (AZ-a / AZ-b)    ──► [ Managed Databases / Stateful Storage ]
      └── Routing: Local VPC Only (No Internet Path)
```

### Component Placement Architecture

1. **Public Subnets:** Strictly limited to public-facing network devices like AWS NAT Gateways and external Application Load Balancers. **Never deploy EKS worker nodes or application layers here.**
2. **Private Subnets:** Houses the EKS cluster worker nodes (Managed Node Groups or Fargate profiles). These layers hold the runtime engines for both **Backend API Pods** and **Frontend Containerized Servers (if opting for SSR EKS delivery)**. These workloads securely pull Docker images or hit third-party web gateways using the NAT instances inside the public tier.
3. **Isolated Subnets:** Reserved entirely for databases (like Amazon RDS instances or local cluster StatefulSets). This grid possesses no structural pathways out to the public internet, insulating production records from external scanning.

---

## 4. Workload Isolation: Multi-Node Group Strategy within Kubernetes

When handling compute infrastructure, selecting both public and private subnets inside a single EKS Node Group defaults to placing worker nodes randomly across public and private spaces. To establish rigorous security barriers, build dedicated Node Groups matched to targeted VPC networks.

### Configuration Blueprints for Separated Node Groups

#### 1. Cluster Infrastructure Definiton (Infrastructure-as-Code / `eksctl`)
This configuration establishes two distinct pools of infrastructure, pinning workloads exactly to chosen network paths using custom Kubernetes labels:

```yaml
# eksctl-cluster-config.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: production-core-cluster
  region: us-east-1
  version: "1.31"

vpc:
  subnets:
    public:
      us-east-1a: { id: subnet-01111111111111111 }
      us-east-1b: { id: subnet-02222222222222222 }
    private:
      us-east-1a: { id: subnet-03333333333333333 }
      us-east-1b: { id: subnet-04444444444444444 }

managedNodeGroups:
  # Node group executing frontend & backend application logic
  - name: application-workers
    instanceType: t3.medium
    desiredCapacity: 3
    subnets:
      - subnet-03333333333333333
      - subnet-04444444444444444
    labels:
      workload: application-tier
    tags:
      nodegroup-type: private-apps

  # Dedicated node group for handling database storage components (if run within EKS)
  - name: database-workers
    instanceType: r6i.large
    desiredCapacity: 2
    subnets:
      - subnet-05555555555555555 # Isolated Subnet AZ-A
      - subnet-06666666666666666 # Isolated Subnet AZ-B
    labels:
      workload: database-tier
    taints:
      - key: database-only
        value: "true"
        effect: NoSchedule
```

#### 2. Pod Target Engineering via Manifests
To take advantage of these separated node groups, explicitly declare scheduling rules using `nodeSelector` properties and `tolerations`:

**Backend & Frontend Application Deployments:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-service-deployment
spec:
  replicas: 3
  template:
    spec:
      nodeSelector:
        workload: application-tier # Restricts pods strictly to Private Subnet worker instances
      containers:
      - name: api-runtime
        image: 111122223333.dkr.ecr.us-east-1.amazonaws.com/backend:v1.0.0
```

**Cluster Database Workloads (StatefulSet):**
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-cluster
spec:
  template:
    spec:
      nodeSelector:
        workload: database-tier # Encapsulates the execution loop inside Isolated Subnet nodes
      tolerations:
      - key: "database-only"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
      containers:
      - name: postgres
        image: postgres:16-alpine
```

---

## 5. End-to-End AWS Load Balancer Controller Automation Lifecycle

Applying an Ingress manifest containing an AWS ALB class requires installing the **AWS Load Balancer Controller** into your EKS control plane first.

### Step-by-Step EKS to Cloud Infrastructure Automation Pipeline

#### Step 1: Subnet Pre-requisite Tagging (Auto-Discovery Setup)
Before anything else, tag your subnets in AWS so the cluster controller can automatically identify them when generating network interfaces.

* **Public Subnets (For Web-Facing ALBs):**
  * Tag Key: `kubernetes.io/role/elb`
  * Tag Value: `1`
* **Private Subnets (For Internal/Microservice ALBs):**
  * Tag Key: `kubernetes.io/role/internal-elb`
  * Tag Value: `1`

#### Step 2: Establish the IAM OIDC Provider Relationship
Map the cluster's native identity schema to the cloud IAM ecosystem:
```bash
eksctl utils associate-iam-oidc-provider     --cluster=production-core-cluster     --approve
```

#### Step 3: Configure the Controller Target IAM Security Matrix
Download the official AWS structural capabilities map and construct a verified IAM operational policy:
```bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy     --policy-name AWSLoadBalancerControllerIAMPolicy     --policy-document file://iam_policy.json
```

#### Step 4: Map Service Accounts to IAM Policies
Create a dedicated Kubernetes Service Account linked directly to an authorized AWS IAM role:
```bash
eksctl create iamserviceaccount   --cluster=production-core-cluster   --namespace=kube-system   --name=aws-load-balancer-controller   --role-name AmazonEKSLoadBalancerControllerRole   --attach-policy-arn=arn:aws:iam::111122223333:policy/AWSLoadBalancerControllerIAMPolicy   --approve
```

#### Step 5: Helm Installation Deployment
Inject the runtime engine controller into the cluster's system configuration space:
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller   -n kube-system   --set clusterName=production-core-cluster   --set serviceAccount.create=false   --set serviceAccount.name=aws-load-balancer-controller
```

---

## 6. Unified Production Application Ingress Manifest

Once the system controller infrastructure is active, use this single ingress configuration to deploy an external Application Load Balancer across your public subnets. The ALB then securely targets your isolated frontend and backend pods sitting side-by-side inside the private network tier.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: unified-production-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: alb
    
    # 1. Configures the ALB to run as an internet-facing entry point
    alb.ingress.kubernetes.io/scheme: internet-facing
    
    # 2. Roots targets to Pod IPs directly, bypassing extra cluster routing overhead
    alb.ingress.kubernetes.io/target-type: ip
    
    # 3. Security Best Practice: Restricts incoming ALB traffic strictly to CloudFront using a secret header
    alb.ingress.kubernetes.io/actions.custom-header-check: >
      {"type":"fixed-response","fixedResponseConfig":{"statusCode":"403","contentType":"text/plain","content":"Access Denied: Direct requests bypassed CDN."}}
spec:
  rules:
    - http:
        paths:
          # Custom validation rule mapping secret incoming header keys
          - path: /
            pathType: Prefix
            backend:
              service:
                name: custom-header-check
                port:
                  name: use-annotation
                  
          # Dynamic Backend API Traffic Rule Route
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: backend-core-service
                port:
                  number: 8080
                  
          # Catch-All Rule Route pointing to Frontend Application Components
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-web-service
                port:
                  number: 3000
```

### Complete End-to-End Traffic Execution Flow
1. **User Action:** The web browser sends a request to `https://example.com/api/v1/users`.
2. **CloudFront Delivery:** CloudFront catches the request at a global edge location. It evaluates its internal behavior configurations and forwards the payload to the custom backend origin address (the public AWS ALB).
3. **ALB Network Evaluation:** The ALB processes the request within your **Public Subnets**. It verifies the required firewall properties, reviews the path mapping `/api`, and forwards the traffic.
4. **Target Ingress Delivery:** The request crosses your secure firewall boundary into your **Private Subnets**, routing directly to the private IP address of an active backend API container pod.