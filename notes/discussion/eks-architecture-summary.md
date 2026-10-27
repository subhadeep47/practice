# AWS and Amazon EKS Reference Architecture Manual

This comprehensive reference document outlines the core architectural paradigms, networking frameworks, security topologies, and infrastructure automation layers discussed during our engineering session. It is designed to serve as an enterprise-ready technical specification and documentation manual for storage in GitHub repositories, corporate wikis, or internal engineering reference modules.

---

## 1. Domain Resolution Architecture: Route 53 Resource Records

When designing public-facing routing entry points in Amazon Route 53 for containerized workloads, selecting the correct record type directly dictates query performance, zone management capabilities, and cloud billing structures.

### Structural Comparison Matrix

| Core Architectural Dimension | Standard A Record | Standard CNAME Record | Route 53 Alias Record |
| :--- | :--- | :--- | :--- |
| **Target Translation Mapping** | Maps a domain directly to a static, physical IPv4 address (e.g., `192.0.2.1`). | Maps a domain alias to a canonical domain name (e.g., `app.my-elb.amazonaws.com`). | Maps a domain to a native, dynamically tracked internal AWS resource pointer. |
| **Zone Apex Support (`example.com`)** | **Supported.** Fully compatible with the root of a DNS zone. | **Prohibited.** Violates DNS RFC specifications when combined with SOA/NS records. | **Supported.** Virtual resolution layers allow seamless deployment at the root zone apex. |
| **Client Resolution Latency** | **Low.** Single iterative lookup returns the definitive target IP immediately. | **High.** Requires a minimum of two sequential DNS lookup cycles. | **Low.** Single lookup; Route 53 resolves the AWS resource target IP internally. |
| **Data Plane Billing Impact** | Billed at standard Route 53 query-volume pricing structures. | Billed at standard Route 53 query-volume pricing structures. | **Free of Charge** when targeting supported AWS resources (ELB, CloudFront, S3). |
| **Infrastructure Lifecycle Adaptability** | **Poor.** Requires manual or custom automated modification if infrastructure IPs rotate. | **Good.** Automatically handles IP rotations since it references a persistent host name. | **Excellent.** Natively monitors and updates tracking changes in the AWS resource runtime layer. |

### Technical Deep Dive & Core Constraints

#### The Zone Apex CNAME Restriction (RFC 1034 / RFC 2181)
Per core internet engineering specifications, a `CNAME` record cannot coexist with any other resource record type for the exact same host name. Because a root zone apex (e.g., `company.com`) strictly requires the presence of Start of Authority (`SOA`) and Name Server (`NS`) records to establish zone validity, it is mathematically and protocol-wise impossible to place a standard `CNAME` record at the root domain level. Attempting to do so breaks standard DNS parsing libraries.

#### The Route 53 Alias Optimization Layer
Amazon Route 53 circumvents this structural RFC limitation through a proprietary virtual mechanism. When an **Alias Record** is configured (under the hood as an `A` record type with an internal AWS pointer reference), Route 53 acts as an active resolver on behalf of the client. 

When a DNS client queries the zone apex:
1. The query hits the Route 53 authoritative nameserver.
2. Route 53 detects the internal resource pointer (e.g., an AWS Application Load Balancer).
3. Route 53 fetches the currently active, dynamic public IPv4 addresses assigned to that ALB.
4. Route 53 responds to the client with a standard, flat `A` record payload.

This architecture simultaneously achieves standard RFC protocol compliance, allows root-level mapping to dynamic cloud load balancers, eliminates secondary lookup latency for the client, and removes DNS processing costs for internal AWS routing paths.

---

## 2. API Gateway to Kubernetes (EKS) Connectivity Patterns

Integrating AWS API Gateway with a Spring Boot application residing within an Amazon EKS cluster requires bridging the network boundary between the managed AWS API plane and the secure, isolated VPC hosting your containerized worker nodes.

### Pattern A: The Secure Private Route (VPC Link Topology)

This pattern is the definitive enterprise standard for production workloads requiring absolute network isolation. The Kubernetes worker nodes and internal load balancers reside in private subnets with zero direct public ingress routes.

```
[ Public Internet Client ]
           │
           ▼ (HTTPS Ingress)
┌────────────────────────────────────────────────────────┐
│               AWS Managed Network Plane                │
│  [ AWS API Gateway (HTTP / REST API Engine) ]           │
│                          │                             │
│                          ▼                             │
│  [ AWS API Gateway VPC Link Integration ]               │
└──────────────────────────┼─────────────────────────────┘
                           │ (Secure Hyperplane Transit)
┌──────────────────────────▼─────────────────────────────┐
│                   Customer AWS VPC                     │
│  Private Subnets (No Public Internet Ingress)          │
│                          │                             │
│                          ▼                             │
│  [ Internal AWS Network Load Balancer (NLB) ]           │
│                          │                             │
│                          ▼ (Layer 4 Forwarding)        │
│  [ Kubernetes AWS Load Balancer Controller Node ]       │
│                          │                             │
│                          ▼ (K8s Service / Kube-Proxy)  │
│  [ Spring Boot App Pods (Default Port 8080/8443) ]     │
└────────────────────────────────────────────────────────┘
```

#### Mechanical Deep Dive
1. **AWS VPC Link:** Utilizes AWS Hyperplane technology to provision high-throughput, low-latency private elastic network interfaces directly inside your targeted VPC private subnets.
2. **Internal NLB:** A dedicated Network Load Balancer configured within private subnets. It registers the target IPs of your Kubernetes worker nodes (or targets the Pod IPs directly via IP-target routing profiles).
3. **Data Transit:** Traffic travels from the API Gateway engine, across the private AWS backbone through the VPC Link, and lands directly on the private NLB. The public internet never interacts with or discovers the networking configuration of the Kubernetes cluster.

### Pattern B: The Edge-Secured Public Route (Public Load Balancer Topology)

This pattern is applied when routing across decoupled cloud networks, or when utilizing existing public ingress layers where a public Application/Network Load Balancer is already exposed to the edge.

```
[ Public Internet Client ] ──► [ AWS API Gateway ]
                                      │
                                      ▼ (Encrypted Transit via Public WAN)
                         [ Public Internet Route ]
                                      │
                                      ▼
┌────────────────────────────────────────────────────────┐
│                   Customer AWS VPC                     │
│  Public Perimeter Subnets                              │
│                          │                             │
│                          ▼                             │
│  [ Public AWS Application Load Balancer (ALB) ]        │
│                          │                             │
│                          ▼ (mTLS Verification Gate)    │
│  [ Kubernetes Ingress Layer (NGINX / ALB Controller) ] │
│                          │                             │
│                          ▼                             │
│  [ Spring Boot App Pods (Default Port 8080/8443) ]     │
└────────────────────────────────────────────────────────┘
```

#### Mechanical Deep Dive & Perimeter Hardening
1. **Public Integration Point:** API Gateway is configured with a standard HTTP proxy integration targeting the public DNS entry point of the AWS ALB or Ingress gateway.
2. **Mutual TLS (mTLS) Implementation:** To prevent malicious parties from discovering the public ALB URL and bypassing the API Gateway authorization, throttling, and WAF rules, strict **mTLS** must be enforced. API Gateway passes a configured client certificate during the TLS handshake, which the Kubernetes Ingress layer validates against a trusted Certificate Authority (CA) bundle.
3. **Network Access Control Lists (NACLs):** Security Groups on the public load balancer are tightly constrained to accept incoming traffic *only* from the published public IP CIDR ranges of the regional AWS API Gateway service components.

---

## 3. Core Compute Networking: ENIs and Prefix Delegation

The Amazon VPC CNI (Container Network Interface) plugin dictates how IP addressing behaves within an Amazon EKS cluster. By default, it operates by natively attaching real VPC IP addresses to individual Kubernetes Pods, exposing them as true first-class citizens within your corporate network.

### The Traditional ENI Capacity Constraint (The Pod Density Bottleneck)

Every EC2 instance size within AWS possesses a hardware-bound maximum limit governing:
1. The absolute number of **Elastic Network Interfaces (ENIs)** that can be attached to the virtual machine.
2. The absolute number of **Secondary Private IPv4 addresses** that can be bound to each individual ENI.

This leads to a strict mathematical constraint calculating maximum pod density. The standard Amazon VPC CNI formula for calculating pod capacity per node is:

$$	ext{Maximum Pods per Node} = \left( 	ext{Max ENIs Available} 	imes \left( 	ext{Private IPs per ENI} - 1 ight) ight) + 2$$

*(Note: The subtraction of 1 accounts for the primary IP utilized by the ENI itself, while the addition of 2 accounts for host-networking system components like the Amazon VPC CNI daemon and kube-proxy).*

#### Practical Scenario: The `t3.medium` Constraint
An infrastructure engineer deploys a standard `t3.medium` instance as an EKS worker node. Per AWS hardware specifications:
* Max ENIs = 3
* Private IPv4 addresses per ENI = 6

Applying the structural formula:

$$	ext{Maximum Pods} = (3 	imes (6 - 1)) + 2 = (3 	imes 5) + 2 = 17 	ext{ Pods}$$

If your Spring Boot microservices are lightweight (e.g., requiring only 250m CPU and 512MB RAM), a `t3.medium` instance possesses enough compute resources to comfortably run 40 to 50 active pods. However, under standard CNI configurations, the node will experience **IP exhaustion** at exactly 17 pods, causing the Kubernetes scheduler to mark the node as `FailedScheduling` due to unavailable network resources.

### The Engineering Solution: `ENABLE_PREFIX_DELEGATION`

By modifying the VPC CNI configuration setting `ENABLE_PREFIX_DELEGATION=true` within the `aws-node` DaemonSet, you transition the IP allocation model from a single IP allocation mechanism (`/32` addresses) to a contiguous **Prefix Block Allocation** mechanism (`/28` address subnets).

```
Traditional IP Allocation Mode:
[ ENI Slot 1: Primary IP ] [ ENI Slot 2: Pod 1 IP ] [ ENI Slot 3: Pod 2 IP ]

Prefix Delegation Mode:
[ ENI Slot 1: Primary IP ] [ ENI Slot 2: /28 Prefix Block (16 Contiguous IPs) ] ──► Allocates 16 Pod IPs instantly
```

#### Mechanical Underpinnings
* Instead of issuing a call to the AWS EC2 API plane to bind a single secondary IP every time a Spring Boot Pod initializes, the CNI requests an entire **`/28` prefix block** (16 contiguous IPv4 addresses).
* This single prefix block occupies only **one single slot** on the parent ENI.
* The `t3.medium` instance can now hold multiple `/28` prefixes across its available slots, theoretical capacity limits increase dramatically, enabling the node to scale up to the true Kubernetes container runtime capacity limit for that instance tier (**110 Pods**).

### High-Density Risk Mitigation Parameters

While Prefix Delegation completely resolves pod density issues, it introduces architectural risks regarding network space consumption that must be managed via specific CNI environment variables:

* **`WARM_PREFIX_TARGET`:** Dictates how many unassigned `/28` prefix blocks the node should pre-allocate and hold in reserve. If left at default settings, a newly provisioned node will aggressively hoard multiple blocks of 16 IPs from your VPC subnet, leading to rapid **subnet starvation** in small networks. For enterprise Spring Boot deployments, explicitly configure `WARM_PREFIX_TARGET=1`. This tells the CNI to only hold a single extra block of 16 IPs warm, returning idle blocks back to the corporate subnet pool when workloads scale down.

---

## 4. Modern Workload Identity Taxonomy

Securing application integration across the Kubernetes control plane and the AWS infrastructure plane requires clear separation of identity types. The table below outlines the precise execution, credential lifecycle, and domain boundaries separating traditional security entities from containerized identities.

| Structural Dimension | AWS IAM User | AWS IAM Role | Kubernetes Service Account | IAM Roles for Service Accounts (IRSA) / Pod Identity |
| :--- | :--- | :--- | :--- | :--- |
| **Native Runtime Domain** | AWS Identity and Access Management Engine. | AWS Identity and Access Management Engine. | Kubernetes Cluster Control Plane Core (`etcd`). | Unified Cross-Platform Hybrid Identity System. |
| **Credential Security Profile** | Long-lived, permanent static text strings (Access Key / Secret Key pairs). | Ephemeral, cryptographically signed temporary tokens generated on demand. | Local JWT tokens minted natively by the Kubernetes API server. | Short-lived, dynamically rotated temporary AWS tokens automatically managed by runtime agents. |
| **Authentication Flow Mechanism** | Direct validation via cryptographic signature matching against AWS API endpoints. | Assumed via AWS Security Token Service (`sts:AssumeRole`) api operations. | Local token verification handled internally by the cluster API control plane. | Automated token exchange via regional OIDC providers or direct node-agent sidecar daemons. |
| **Primary Structural Target** | Human engineers, legacy workflows, external continuous integration (CI) systems. | Internal AWS compute planes (EC2 Instance profiles, Lambda, ECS task structures). | Internal cluster processes, system tracking daemons, internal cron jobs. | Specific, scoped application container processes (Pods) running inside the cluster. |
| **Least-Privilege Isolation Granularity** | Broad, account-wide capabilities. Difficult to safely restrict across highly fluid runtimes. | Coarse-grained. Applied broadly to the underlying infrastructure hosting many distinct applications. | Highly granular within the cluster boundaries, completely blind to the external AWS cloud plane. | **Microscopic.** Bound strictly to a single application process or isolated namespace profile. |

---

## 5. Architectural Infrastructure Operations: The Chain of Responsibility

To understand the inter-operability of these technologies, we must track the end-to-end infrastructure lifecycle. The following detailed breakdown maps exactly how a developer-defined declarative Ingress configuration manifest translates into a physical, public-facing AWS Application Load Balancer, highlighting the security checks managed by the **AWS Load Balancer Controller's `IAMServiceAccount`**.

```
[ Developer ] ──► (Applies Ingress YAML) ──► [ K8s etcd Database ]
                                                   │
                                                   ▼ (State Divergence Detected)
                                      [ AWS LB Controller Pod ]
                                                   │
                (Fetches Dynamic Token via Pod Identity / OIDC Provider)
                                                   ▼
                                      [ AWS Security Token Service ]
                                                   │
                     (Validates Token & Returns Temporary Role Credentials)
                                                   ▼
                                      [ AWS Load Balancer Controller ]
                                                   │
                                                   ▼ (Executes Secure Outbound AWS API Calls)
                           ┌───────────────────────┴───────────────────────┐
                           ▼                                               ▼
         [ Native EC2 VPC Security Groups ]              [ Physical AWS ALB Infrastructure ]
                           │                                               │
                           ▼                                               ▼
         (Configures Ingress Access Matrix)              (Deploys Target Groups & Listeners)
```

### Deep-Dive Lifecycle Step Analysis

#### Step 1: Control Plane Declaration & Ingress Registration
An infrastructure engineer executes `kubectl apply -f spring-boot-ingress.yaml`. The request passes authentication checks at the Kubernetes API server and is written to the persistent cluster state store (`etcd`). This manifest declares that all public traffic hitting `api.company.com/v1/orders` must be routed to the internal cluster target service named `order-service` on port `8080`.

#### Step 2: Controller State Loop & Discovery
The **AWS Load Balancer Controller** runs as a standard Kubernetes deployment inside the cluster. Its internal reconciliation loops are constantly tracking the Kubernetes API server for state modifications. The controller detects the new Ingress object, parses the annotations (e.g., `alb.ingress.kubernetes.io/scheme: internet-facing`), and concludes that its current real-world state diverges from the user's declared target state. It initializes an action plan to provision physical AWS infrastructure to match.

#### Step 3: Identity Assumption & Token Exchange (The Security Verification Gate)
Before making calls to the AWS cloud infrastructure, the controller container must prove it is authorized to do so. 
* Under **EKS Pod Identity / IRSA**, an internal mutating webhook has already injected a local web identity token file path (`/var/run/secrets/pods.eks.amazonaws.com/serviceaccount/token`) and environment variables (`AWS_ROLE_ARN`) straight into the controller pod.
* The AWS SDK embedded within the controller intercepts these variables and calls the **AWS Security Token Service (STS)** using the `AssumeRoleWithWebIdentity` operation.
* AWS STS verifies the token authenticity against the cluster's trusted identity platform. If valid, STS generates short-lived, temporary AWS security credentials valid for a restricted window and sends them securely back to the controller pod.

#### Step 4: Outbound AWS API Execution
Armed with valid, short-lived cryptographic credentials, the controller pod now makes direct, secure outbound HTTPS API calls across the internet or private VPC endpoints to the public AWS Elastic Load Balancing endpoint. 
It executes sequence demands including:
* `elasticloadbalancing:CreateLoadBalancer`
* `elasticloadbalancing:CreateTargetGroup`
* `elasticloadbalancing:RegisterTargets`

#### Step 5: Physical Cloud Infrastructure Realization
The AWS control plane receives the authorized commands from your cluster controller and provisions the real-world hardware resources:
1. **Application Load Balancer Provisioning:** AWS deploys a physical, highly available ALB into the designated public subnets across multiple Availability Zones, establishing unique public DNS names.
2. **Security Group Mutation:** The controller alters AWS EC2 Security Group rules to permit edge traffic through port 80/443 on the load balancer, while opening firewall rules on the downstream Kubernetes worker node instances so the ALB can seamlessly pass traffic forward.
3. **Dynamic Target Group Management:** The controller continuously discovers the individual private VPC IP addresses of your Spring Boot Pods within the Kubernetes cluster and registers them directly into the ALB's active Target Group. 

When a pod dies or scales out, the controller detects the change instantly and triggers `RegisterTargets` or `DeregisterTargets` operations, ensuring the cloud load balancer maintains an accurate map of your application container fleet in real-time.
