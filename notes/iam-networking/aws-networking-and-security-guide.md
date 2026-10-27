# AWS Core Architecture, Networking & IAM Security Study Guide

This comprehensive reference document compiles deep-dives into AWS multi-VPC networking strategies and advanced IAM security paradigms. It serves as a production-grade blueprint for modern, secure cloud infrastructure design.

---

## 🌐 Section 1: Multi-VPC Networking Architectures

When scaling multi-VPC environments, selecting the optimal network topology requires analyzing architectural scale, data flow directionality, and IP address management (IPAM) overlap strategies.

### 📋 Direct Comparison
| Architectural Feature | VPC Peering | Transit Gateway (TGW) | AWS PrivateLink |
| :--- | :--- | :--- | :--- |
| **Connectivity Type** | One-to-One (Network-to-Network) | Many-to-Many (Network-to-Network) | One-to-Many (Consumer-to-Service) |
| **Routing Topology** | Full-Mesh Architecture | Hub-and-Spoke (Centralized) | Interface Endpoint-Driven (Local ENI) |
| **Transitive Routing** | ❌ Not Supported |  Supported | ❌ Not Supported |
| **Traffic Initiation** | Bidirectional | Bidirectional | Unidirectional (Consumer $\rightarrow$ Service) |
| **Overlapping CIDRs** | ❌ Forbidden (Routing Conflicts) | ❌ Forbidden |  Fully Supported (Local Injection) |
| **Bandwidth Limits** | Uncapped (Line rate of AWS fabric) | Up to 50 Gbps per VPC attachment | Scalable to millions of RPS |
| **Cost Profile** | Lower (No hourly charges; data fees only) | Higher (Hourly attachment fees + data fees) | Moderate (Hourly endpoint fees + data fees) |

---

### 1️⃣ VPC Peering: The Point-to-Point Bridge
AWS VPC Peering establishes a Layer 3 routing connection between two distinct VPCs, enabling them to communicate using private IPv4 or IPv6 addresses as if they resided within the identical network fabric.

*   **The Non-Transitive Routing Constraint (The Mesh Problem):** VPC Peering strictly prohibits routing packets through an intermediate VPC. If $VPC\;A$ is peered with $VPC\;B$, and $VPC\;B$ is peered with $VPC\;C$, packets from $VPC\;A$ **cannot** traverse $VPC\;B$ to reach $VPC\;C$. As an infrastructure grows to $N$ networks, the connection scaling factor increases exponentially according to the full-mesh complexity formula:
    $$\text{Total Connections} = \frac{N(N - 1)}{2}$$
*   **Production Deployment Criteria:** Best reserved for low-scale operations (fewer than 10 VPCs) requiring raw performance, minimum latency overhead, and direct network-to-network data replication where IP CIDR spaces are cleanly partitioned.

---

### 2️⃣ Transit Gateway (TGW): The Central Network Hub
AWS Transit Gateway acts as a highly scalable cloud router that centralizes network connectivity. Instead of establishing independent routing mesh paths, every VPC, VPN tunnel, or AWS Direct Connect circuit connects directly to the TGW via a singular attachment interface.

*   **Centralized Security Inspection:** Because TGW natively supports transitive routing, organizations can architect a "Centralized Inspection VPC". All outbound internet traffic or inter-VPC traffic can be force-routed through a centralized firewall array (e.g., AWS Network Firewall or third-party appliance clusters) before reaching its destination.
*   **Production Deployment Criteria:** Essential for large-scale enterprise foundations spanning tens or hundreds of AWS Accounts, multiple geographical Regions, and hybrid corporate data centers requiring unified routing tables and simplified edge architecture.

---

### 3️⃣ AWS PrivateLink: The Secure Service Window
AWS PrivateLink decouples application consumption from standard network-to-network routing. It leverages an Interface VPC Endpoint, which injects a local Elastic Network Interface (ENI) with a private IP directly into the consumer's private subnet. This ENI maps strictly to a Network Load Balancer (NLB) backing a service in a distinct provider network.

*   **Asymmetric Security & IP Freedom:** Because networks are never linked at Layer 3, the consumer and producer networks can have overlapping IP address blocks (e.g., both utilizing `10.0.0.0/16`) without experiencing routing conflicts. The connection is strictly unidirectional: the consumer can call the service endpoint, but the provider application has zero ability to scan, ping, or initiate network connections backward into the consumer network.
*   **Production Deployment Criteria:** The gold standard for safely consuming multi-tenant SaaS platforms, exposing internal shared microservices across structurally isolated business entities, or connecting to native AWS services securely without traversing the public internet.

---

## 🔑 Section 2: AWS IAM & Resource Security Mechanisms

Implementing true Zero-Trust security within AWS requires a granular understanding of identity-based policies, resource-based policies, temporary credential generation, and programmatic permission guardrails.

### 📝 Core Components Definitions

#### 1. IAM User
An IAM User is an identity entity created inside an AWS account that represents a specific physical person or a long-lived programmatic workload. 
*   **Security Flaw:** Programmatic IAM Users rely on static, long-term Access Keys (`AccessKeyId` and `SecretAccessKey`). If hardcoded into application source code, configuration management tools, or exposed via Git repository leaks, the compromise is permanent until manually rotated or revoked.

#### 2. IAM Policy
An IAM Policy is a formal JSON document that defines authorization permissions. It specifies exactly **what actions** (e.g., `s3:GetObject`, `ec2:RunInstances`) can be performed against **which specific resources**, and under **what explicit conditions**.

#### 3. IAM Role
An IAM Role is an abstract identity entity that does not possess permanent passwords or access keys. Instead, it serves as a temporary container for permission policies that can be assumed dynamically by authorized identities (Users, EC2 instances, Lambda functions, or external AWS accounts).

---

### 🔄 AssumeRole: How Temporary Credentials Work
`AssumeRole` is a core API action within the AWS Security Token Service (STS) that facilitates Just-In-Time (JIT) access token generation.

```
┌──────────────┐     1. sts:AssumeRole Call     ┌──────────────┐
│  IAM User /  │ ─────────────────────────────> │  AWS STS     │
│  Application │ <───────────────────────────── │  (Token Svc) │
└──────────────┘    2. Short-Lived Tokens       └──────────────┘
       │               (AccessKey, SecretKey, SessionToken)
       │
       ▼ 3. Signs Requests with Short-Lived Keys
┌──────────────────────────────────────────────────────────────┐
│            Target AWS Resource (S3, EC2, RDS)               │
└──────────────────────────────────────────────────────────────┘
```

#### The Real-World Handshake Mechanics:
1. **The Request:** An IAM user or external compute resource calls the `sts:AssumeRole` API endpoint, targeting a specific Role ARN.
2. **The Verification:** AWS evaluates the Target Role's **Trust Policy** (see below). If the requesting identity matches the authorized principal list, the request is approved.
3. **Token Issuance:** AWS STS returns a cryptographic credential block consisting of three components:
    *   `AccessKeyId`
    *   `SecretAccessKey`
    *   `SessionToken`
4. **Lifecycle:** These credentials are valid for a configurable window (15 minutes to 12 hours). Once the expiration window closes, the credentials instantly become invalid, leaving zero persistent attack vectors if leaked.

---

### 🛡️ Core Security Policies: Syntax and Implementations

#### 1. Trust Policy (The Role's Guard)
A Trust Policy is a mandatory, resource-based policy attached to an **IAM Role**. It defines the **Principals** (Who) are trusted to assume the role.

*   *Production Use Case:* Restricting a deployment role inside a Production Account so that only a specific automation tool user from a Shared-Tools Account can execute it.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSpecificAutomationIdentity",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::111122223333:user/awx-runner"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

#### 2. Permissions Boundary (The Structural Guardrail)
A Permissions Boundary is an advanced identity-based policy constraint used to define the **absolute maximum authority** an IAM User or Role can ever exercise. 

*   *The Intersect Rule:* A boundary does **not** grant permissions. For an action to succeed, it must be explicitly allowed in **both** the attached IAM Policy **AND** the attached Permissions Boundary.
*   *Production Use Case:* Allowing an automation utility (like AWX/Jenkins) to dynamically generate new IAM profiles for application testing, while applying a boundary ensuring those new profiles can never grant administrative account control, change billing settings, or delete production databases.

```
   ┌─────────────────────────────────────┐
   │          IAM Permission Policy      │
   │   (Allowed: S3:* and DynamoDB:*)    │
   └──────────────────┬──────────────────┘
                      │
                      ▼  [ Evaluation Intersect ]
            👉 Allowed ONLY: S3:* 👈
                      ▲
   ┌──────────────────┴──────────────────┐
   │          Permissions Boundary       │
   │     (Allowed: S3:* and EC2:*)       │
   └─────────────────────────────────────┘
```

#### 3. S3 Bucket Policy (Resource-Level Enforcement)
An S3 Bucket Policy is a resource-based access control policy attached directly to an individual S3 bucket. While identity policies control what an identity can go out and do, bucket policies control who is allowed to come inside the resource.

*   *Production Use Case:* Permitting cross-account file uploads from an external enterprise automation suite, or enforcing structural compliance rules (e.g., explicitly denying any payload transmission that does not enforce `aws:SecureTransport` via HTTPS).

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EnforceSSLOnlyAccess",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::production-data-storage",
        "arn:aws:s3:::production-data-storage/*"
      ],
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
```

---

## 🛠️ Section 3: End-to-End External Automation Implementation
### Scenario: Connecting an Off-AWS AWX/Ansible Server to a Production Account

This structural workflow illustrates how to eliminate persistent admin keys inside an external automation machine (AWX, Jenkins, or on-premises worker nodes) by using a low-privilege entry identity that assumes a high-privilege automation role via runtime code injection.

```
┌─────────────────┐ 1. Authenticate (Low-Priv) ┌──────────────────────────┐
│   AWX Server    │ ─────────────────────────> │ AWS Identity Account (A) │
│ (Static Keys)   │                            └──────────────────────────┘
└────────┬────────┘                                         │
         │                                                  │ 2. AssumeRole Request
         │ 3. Returns Temp 1-Hour Token                     ▼
         │ <─────────────────────────────────── ┌──────────────────────────┐
         │                                      │ Production Account (B)   │
         ▼ 4. Provisions Resources              │                          │
┌─────────────────────────────────────────────┐ │  ┌────────────────────┐  │
│   Production S3, EC2, VPC Infrastructure     │ │  │ AWX-Deployer-Role  │  │
└─────────────────────────────────────────────┘ │  └────────────────────┘  │
                                                └──────────────────────────┘
```

### Step 1: Provisions within Identity Account (Account A)
Generate an IAM User named `awx-runner`. Store its Access Key and Secret Key inside the AWX Credential Vault. Attach only this single policy to the user:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAssumeRoleToProduction",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::222233334444:role/AWX-Production-Deployer"
    }
  ]
}
```

### Step 2: Provisions within Target Production Account (Account B)
Create the target IAM Role named `AWX-Production-Deployer`. Attach the required execution privileges (e.g., `AmazonVPCFullAccess`, `AmazonEC2FullAccess`) along with this configuration:

*   **Attach this Trust Policy to the Role:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TrustIdentityAccountRunner",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::111122223333:user/awx-runner"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### Step 3: Pipeline Configuration Integration
Configure the infrastructure code pulled by the AWX worker engine to seamlessly invoke the runtime credential switch.

#### For Infrastructure Provisioned via HashiCorp Terraform:
Configure the AWS provider block inside your root configuration module to specify the structural target role:

```hcl
provider "aws" {
  region = "us-east-1"
  
  # The provider initializes using Account A's static environmental keys,
  # then immediately requests a short-lived token for the target role below:
  assume_role {
    role_arn     = "arn:aws:iam::222233334444:role/AWX-Production-Deployer"
    session_name = "AWX_Pipeline_Prod_Deployment"
  }
}
```

#### For Configuration Managed via Red Hat Ansible Playbooks:
Leverage the native `sts_assume_role` module at the initialization tasks of the orchestration playbook:

```yaml
- name: Authenticate and Assume Production Role
  amazon.aws.sts_assume_role:
    role_arn: "arn:aws:iam::222233334444:role/AWX-Production-Deployer"
    role_session_name: "AWX_Playbook_Prod_Run"
  register: assumed_role_tokens

- name: Provision Core Production Infrastructures
  amazon.aws.ec2_instance:
    name: "prod-web-server"
    key_name: "prod-ssh-key"
    instance_type: t3.medium
    image_id: ami-0c55b159cbfafe1f0
    aws_access_key: "{{ assumed_role_tokens.sts_creds.access_key }}"
    aws_secret_key: "{{ assumed_role_tokens.sts_creds.secret_key }}"
    aws_security_token: "{{ assumed_role_tokens.sts_creds.session_token }}"
    region: "us-east-1"
```

---

## 🎯 Interview Check-List Summary

*   **VPC Peering vs. TGW vs. PrivateLink:** 
    *   *Peering* is point-to-point, free, and cannot transit.
    *   *TGW* is an enterprise routing hub that supports transitive inspections.
    *   *PrivateLink* passes single application endpoints via an NLB/ENI map, entirely bypassing Layer 3 IP address collision boundaries.
*   **The IAM Evaluation Framework Rule:** 
    1. An explicit **Deny** statement anywhere always overrides any explicit Allows.
    2. An identity action is blocked unless it exists within the overlap intersect of the **Identity Policy** and the **Permissions Boundary**.
    3. Access to data objects requires authorization from either the identity **IAM Policy** or the resource **Bucket Policy** (assuming no absolute boundary block is declared).
