# Production AWS Networking, EKS, & CloudFront Engineering Specification
This comprehensive technical manual serves as an enterprise-grade architectural blueprint detailing the design, integration, scaling, identity management, edge computing, and security operations of AWS Route 53, Amazon EKS, AWS API Gateway, and Amazon CloudFront.

---

## 1. Domain Resolution Architecture & Route 53 Deconstruction

### Deep Mechanical Record Analysis
Domain Name System (DNS) configurations inside Amazon Route 53 map human-readable domain names into network routable IP addresses or canonical records. The mechanics of the three foundational routing configurations differ significantly in execution path, resolution hops, and compliance with Internet Engineering Task Force (IETF) RFC specifications.

*   **A Record (Address Record):** A standard, native DNS record mapping a domain or subdomain directly to a static, 32-bit IPv4 address (e.g., `192.0.2.1`). The DNS resolver queries Route 53, which returns the literal IP address in a single network round-trip. It provides the lowest possible client-side resolution latency but offers zero agility; if the underlying target infrastructure changes its IP address, the A record becomes broken and routes traffic to a black hole until manually updated or modified via external health-check automation scripts.
*   **CNAME Record (Canonical Name Record):** A standard DNS record that creates an alias by mapping one domain name (the alias) to another target domain name (the canonical name, e.g., `app.my-loadbalancer.amazonaws.com`). When a client requests a CNAME, the DNS resolver receives the canonical target name instead of an IP address. The resolver must then execute a completely independent, secondary DNS lookup loop to resolve that target name down to an executable IP address. This inserts a multi-hop latency penalty on the client.
*   **Route 53 Alias Record:** An AWS-proprietary, virtual record layer built directly into the Route 53 control plane. An Alias record acts functionally like a CNAME because it points to an abstract target domain name (such as an AWS Application Load Balancer, a CloudFront Distribution, or an S3 bucket endpoint). However, it behaves like a standard A record during client resolution. When the Route 53 name server receives the query, it handles the secondary resolution internally across the AWS software-defined network, instantly returning the literal, current target IP address back to the client in a single network hop.

### The Zone Apex Protocol Restriction (RFC 1034 / RFC 2181)
The **Zone Apex** (also known as the root domain or naked domain, e.g., `example.com`) is the root level of a DNS zone. According to Internet Engineering Task Force RFC specifications (specifically RFC 1034 Section 3.6.2 and RFC 2181), a CNAME record **cannot coexist with any other record type for the same name**. 

Because a Zone Apex fundamentally requires an **SOA (Start of Authority)** record and **NS (Name Server)** records to exist at the root layer to validate the zone's presence, it is mathematically and legally impossible to place a standard CNAME record at the root domain (`example.com`). If a developer attempts to use a CNAME at the root to point to an AWS Application Load Balancer, standard internet resolvers will drop the lookup, resulting in complete domain resolution failure.

Route 53 Alias records completely bypass this internet protocol restriction. Because an Alias record is interpreted internally by AWS name servers as a pointer rather than a standard DNS CNAME, Route 53 is capable of dynamically querying the backend AWS infrastructure, extracting the target IPs, and presenting them to the world as pure A records at the Zone Apex. This allows seamless routing of root domains directly to variable-IP cloud infrastructure.

### Architectural Performance & Cost Matrix

| Feature Parameter | Standard A Record | Standard CNAME Record | Route 53 Alias Record |
| :--- | :--- | :--- | :--- |
| **Target Mapping Destination** | Direct Static IPv4 Address (e.g., `192.0.2.23`) | Target Canonical Hostname (e.g., `lb.aws.com`) | Internal AWS Resource Pointer (ALB, CloudFront, S3) |
| **Zone Apex Support (`example.com`)** | Supported natively by RFC design. | **Prohibited** by IETF RFC 1034 / 2181 specifications. | **Supported** via Route 53 internal pointer resolution. |
| **DNS Resolver Hops** | **1 Hop:** Returns the target IP address immediately. | **2+ Hops:** Returns a name, forcing a secondary lookup loop. | **1 Hop:** Route 53 resolves the AWS asset internally. |
| **AWS API Query Financial Cost** | Charged at standard Route 53 transactional query rates. | Charged at standard Route 53 transactional query rates. | **100% Free of charge** when targeting supported AWS resources. |
| **Infrastructure IP Agility** | **Zero:** Manual intervention needed upon backend IP mutations. | **High:** Automatically tracks endpoint names. | **High:** Natively tracks dynamic AWS target IP alterations. |

---

## 2. AWS API Gateway Connectivity Patterns into EKS

Bridging the boundary between AWS API Gateway (managed public edge network) and an internal Kubernetes cluster (private VPC subnets) requires carefully designed network ingress points. Two primary enterprise topologies exist, balancing security isolation against infrastructure complexity.

### Topology 1: Private Network Integration (VPC Link Strategy)
This pattern routes traffic from the public API Gateway edge directly into a locked-down, private VPC subnet via a highly scalable, internal hardware bridge called a VPC Link.

```
[ Public Client Client ]
            │
            ▼ (HTTPS Public Internet)
┌────────────────────────────────────────────────────────┐
│               AWS API Gateway (Managed)                │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼ (AWS Hyperplane Transport Layer)
┌───────────────────────────┴────────────────────────────┐
│                    AWS VPC Link                        │
└───────────────────────────┬────────────────────────────┘
                            │ (Cross-Account VPC Attachment)
                            ▼
┌───────────────────────────┴────────────────────────────┐
│         Private Network Load Balancer (NLB)            │
└───────────────────────────┬────────────────────────────┘
                            │ (TCP Port Pass-Through)
                            ▼
┌───────────────────────────┴────────────────────────────┐
│   Kubernetes Ingress Controller Pod (e.g., NGINX)       │
└───────────────────────────┬────────────────────────────┘
                            │ (Cluster Private Overlay Network)
                            ▼
┌───────────────────────────┴────────────────────────────┐
│             Spring Boot Application Pod                │
└────────────────────────────────────────────────────────┘
```

1.  **VPC Link Prototyping:** The API Gateway creates a managed VPC Link, which provisions dedicated Elastic Network Interfaces (ENIs) backed by AWS Hyperplane technology directly inside your private subnets.
2.  **Private NLB Anchoring:** Within the EKS cluster, the Spring Boot ingress layer is exposed via a native Kubernetes Service of type `LoadBalancer`. By leveraging the AWS Load Balancer Controller plugin annotations (`service.beta.kubernetes.io/aws-load-balancer-type: "external"`, `service.beta.kubernetes.io/aws-load-balancer-internal: "true"`), an internal AWS Network Load Balancer (NLB) is provisioned.
3.  **End-to-End Route Processing:** The client hits the public API Gateway stage. The gateway offloads global authentication or rate limiting and proxies the packet directly through the VPC Link. The VPC Link streams the payload over the private AWS backbone into the internal NLB, which hands the raw TCP stream down to the Kubernetes Ingress controller pods, ultimately arriving at the target Spring Boot JVM thread.

### Topology 2: Public Internet Edge Integration (mTLS Proxy Strategy)
This pattern uses a public Application Load Balancer (ALB) acting as an internet-facing ingress node for the EKS cluster. API Gateway communicates with it over the public internet, using cryptographic handshake validation rules to secure the link.

```
[ Client ] ──► [ API Gateway ] ──► (Public Internet via mTLS) ──► [ Public ALB ] ──► [ EKS Ingress ] ──► [ Spring Boot Pod ]
```

1.  **Public ALB Exposure:** The AWS Load Balancer Controller provisions a public-facing Application Load Balancer based on standard Kubernetes Ingress rules.
2.  **Mutual TLS (mTLS) Enforcement:** To block attackers from bypassing API Gateway and executing DDoS actions directly against the public ALB DNS endpoint, Mutual TLS (mTLS) is enforced. API Gateway is configured with a client certificate generated within AWS Certificate Manager (ACM). The public ALB is configured with an HTTPS listener rule that inspects incoming handshakes and rejects any connection that does not present API Gateway's unique cryptographic client certificate signature.
3.  **Security Group Hardening:** The Security Groups assigned to the public ALB are strictly locked down to accept inbound HTTPS requests solely from the official, published source IP address ranges (JSON CIDR blocks) of the regional AWS API Gateway service edge.

### Routing Logic Division: API Gateway vs. Kubernetes Ingress
*   **Option A: API-First Gateway Routing:** API Gateway acts as the intelligent director. Every unique API microservice endpoint is explicitly declared in the Gateway control panel (e.g., `/api/v1/users` routes to an HTTP integration for the User Service NLB; `/api/v1/orders` routes to a separate HTTP integration for the Order Service NLB). This shifts security policies, schema validations, CORS rules, and rate limits to the cloud edge, keeping the internal cluster lightweight.
*   **Option B: Dumb Proxy/Ingress-First Routing:** API Gateway is configured with a blind catch-all greedy proxy path parameter (`/{proxy+}`). It terminates the public SSL handshake, applies global WAF rules, and proxies the raw URL string directly down to a singular EKS Ingress Controller (like NGINX or AWS ALB Controller). The EKS Ingress Controller reads the path internal to the cluster and executes the microservice redirection. This gives developers complete control over routing using standard Kubernetes manifests, decoupling changes from manual AWS console or infrastructure updates.

---

## 3. Core Compute Networking: VPC CNI Scaling & Pod Density

Networking inside Amazon EKS is driven natively by the **Amazon VPC CNI (Container Network Interface) plugin**. Unlike standard Kubernetes overlay networks (such as Calico or Flannel) that encapsulate container traffic inside virtual tunnels, the VPC CNI assigns **real, primary or secondary private IP addresses directly from your AWS VPC subnets** to every scheduled pod.

### Detailed Mechanics of Elastic Network Interfaces (ENIs)
An ENI is a virtual dedicated network interface card attached to an EC2 instance. Every EC2 instance type possesses immutable hardware limits regarding the maximum number of ENIs that can physically plug into it, and the maximum number of secondary private IPv4 addresses each individual ENI can hold in memory.

#### The Mathematical Pod Density Constraint Formula
Under the default VPC CNI allocation model, each pod requires a unique secondary IP address. The host EC2 node itself consumes one primary IP address per ENI for its own operating system operations. Thus, the physical limit of pods that can exist on any EC2 worker node is governed by this equation:

$$	ext{Max Pod Capacity} = \left( 	ext{Active ENI Count Max} 	imes \left( 	ext{IPv4 Addresses Per ENI Max} - 1 ight) ight) + 2$$

*(Note: The trailing addition of 2 accounts for the Kubernetes host-network pods like kube-proxy and core DNS, which do not consume secondary ENI IPs).*

#### The Small-Node Bottleneck Case Study: `t3.medium`
Consider a standard `t3.medium` EC2 instance selected to host a Spring Boot cluster:
*   **Max ENIs allowed:** 3
*   **Max IPv4 addresses per ENI:** 6

Applying the configuration formula:
$$	ext{Max Pods} = (3 	imes (6 - 1)) + 2 = (3 	imes 5) + 2 = 17 	ext{ Pods}$$

If a dev team tries to scale out 30 lightweight, microservice-based Spring Boot pods onto this instance, Kubernetes will lock up, displaying `FailedCreatePodSandBox` and `NoMoreIPs` errors. Even if the node's CPU utilization is at 5% and RAM is 90% free, the node is completely paralyzed due to IP address exhaustion.

### Detailed Breakdown of `ENABLE_PREFIX_DELEGATION`
To shatter this scaling limitation, AWS introduced **Prefix Delegation** into the VPC CNI controller framework. When the environment variable configuration flag `ENABLE_PREFIX_DELEGATION` is toggled to `true`, the ENI stops requesting individual private `/32` IP addresses (e.g., `10.0.1.5/32`) from the AWS VPC subnet pool. Instead, it requests an entire contiguous block of 16 IPv4 addresses, known as a **`/28` Prefix** (e.g., `10.0.1.16/28`).

#### The Mechanical Execution Shift
1.  Instead of an ENI slot holding a singular IP, a single slot now holds a full `/28` network address prefix block.
2.  An individual `t3.medium` instance slot that previously accommodated 1 individual pod can now house 16 distinct pods out of that single assigned prefix block.
3.  The maximum theoretical addressable space scales exponentially. For a `t3.medium`, the interface can hold 3 ENIs, each managing up to 6 prefixes, with each prefix containing 16 addresses. This drives potential IP availability into the hundreds. However, EKS enforces a native container runtime safety ceiling based on system resource overhead, capping the `t3.medium` node at a maximum pod capacity of **110 Pods**.

### Subnet Exhaustion Risks & Optimization Strategies
While Prefix Delegation eliminates the node pod bottleneck, it introduces a severe risk of **VPC Subnet Exhaustion**. Because the VPC CNI requests IPs from AWS in chunks of 16 at a time, a single newly provisioned EC2 instance will instantly carve out dozens of IP addresses from your company's core subnet pool the moment it boot-straps, even if it is only running a single pod. If your EKS cluster is deployed inside a restrictive private subnet (like a small `/24` network containing only 254 total addresses), a few worker nodes will completely exhaust the entire subnet address pool, blocking database allocations, lambdas, and autoscaling events.

#### Mitigating Subnet Drains via CNI Warm Targets
To control this behavior, you must configure custom environmental tuning parameters inside the `aws-node` DaemonSet:
*   **`WARM_PREFIX_TARGET`:** Dictates how many unassigned `/28` prefix blocks the VPC CNI should maintain in reserve. By default, the CNI attempts to hold massive excess capacities. For small or medium VPC subnets, explicitly setting `WARM_PREFIX_TARGET=1` ensures that the node only pre-allocates **one single extra block of 16 IPs** ahead of active scheduling demands. This prevents idle instances from hoarding company network IP allocations.

---

## 4. Modern Workload Identity Taxonomy

Securing container workloads requires moving away from static cloud credentials (such as IAM User Access Keys packaged inside application code or injected via plain text variables). AWS and EKS decouple authentication boundaries by cross-linking Kubernetes native identities with IAM cloud layers.

### Structural Taxonomy of Workload Identities

| Feature Component | IAM User | IAM Role | Kubernetes Service Account | IRSA / EKS Pod Identity Framework |
| :--- | :--- | :--- | :--- | :--- |
| **Identity Definitional Core** | A permanent, long-lived resource entity defined natively within the global AWS IAM engine. | An abstract IAM identity definition that carries no permanent credentials and must be assumed. | A native, localized identity boundary object defined within a specific Kubernetes namespace. | A high-fidelity cryptographic bridge linking a Kubernetes Service Account to an AWS IAM Role. |
| **Credential Lifecycle Profile** | **Permanent:** Access keys and secret tokens remain valid indefinitely until manually rotated. | **Short-Lived:** Generates temporary security tokens with a maximum lifespan of 1 to 12 hours. | **Automated Token:** Managed by the cluster control plane; relies on localized JSON Web Tokens (JWT). | **Credentialless Runtime:** Container filesystems receive short-lived, auto-rotating AWS STS tokens. |
| **Authentication Flow Mechanism** | Direct validation via username/password signatures or symmetric HMAC cryptographic keys. | Explicit calls to the AWS Security Token Service (STS) API endpoint (`AssumeRole`). | Client validation against the Kubernetes API Server using cluster-internal certificate authorities. | The AWS SDK automatically detects the cluster token, executing transparent STS token exchanges. |
| **Architectural Execution Domain** | External pipelines, developer laptops, legacy on-premise VMs, third-party systems. | Native AWS compute platforms operating at the structural layer (EC2 instances, Lambda, ECS). | Localized cluster processes, configuration loops, basic service-to-service internal calls. | Granular microservices (e.g., Spring Boot Pods) executing specific transactions inside AWS. |
| **Security Blast Radius Boundaries** | **Global / High:** Compromise of keys grants perpetual access from any machine globally. | **Node-Wide:** If assigned to an EC2 instance profile, **every pod** on that node inherits all its permissions. | **Namespace-Bound:** Confined strictly to the software boundaries of the target Kubernetes cluster. | **Microscopic / Microservice-Specific:** Bounded exclusively to the designated pod thread container. |

---

## 5. The Infrastructure Chain of Responsibility

When deploying tools like the **AWS Load Balancer Controller**, you are installing an active piece of infrastructure software directly inside your EKS cluster nodes as regular containerized pods. These controller pods must actively contact the AWS cloud API to provision physical network hardware (ALBs, target groups, listener rules) whenever a developer applies an Ingress change. 

The step-by-step lifecycle execution path demonstrates the precise **Chain of Responsibility** driving this infrastructure loop:

```
[ Step 1: Ingress Manifest Application ]
                   │
                   ▼ (kubectl apply -f ingress.yaml)
┌────────────────────────────────────────────────────────┐
│             Kubernetes API Server / etcd               │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼ (Step 2: Reconcile Loop Intersection)
┌────────────────────────────────────────────────────────┐
│         AWS Load Balancer Controller Pods              │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼ (Step 3: Webhook Injection Engine)
┌────────────────────────────────────────────────────────┐
│     EKS Pod Identity Agent / Token File Mount          │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼ (Step 4: AWS STS Token Exchange)
┌────────────────────────────────────────────────────────┐
│           AWS Security Token Service (STS)             │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼ (Step 5: AWS IAM Authorization Gate)
┌────────────────────────────────────────────────────────┐
│             AWS IAM Evaluation Engine                  │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼ (Step 6: Hardware Provisioning Loop)
┌────────────────────────────────────────────────────────┐
│   Physical Cloud Infrastructure (ALB / EC2 Groups)     │
└────────────────────────────────────────────────────────┘
```

### Step 1: Ingress Manifest Application
A cloud engineer issues a declarative deployment manifest via `kubectl apply`. The target configuration file is received by the Kubernetes API Server, verified against schema validation rules, and committed directly into the persistent distributed data store (`etcd`).
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: spring-boot-api-ingress
  namespace: production
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
  - http:
      paths:
      - path: /api/v1
        pathType: Prefix
        backend:
          service:
            name: spring-boot-service
            port:
              number: 8080
```

### Step 2: The Reconcile Loop Intersection
The **AWS Load Balancer Controller Pod** runs an active control loop that continually monitors the Kubernetes API server for alterations to Ingress objects. The controller detects the newly created `spring-boot-api-ingress` configuration state and initiates an infrastructure alignment routine. It reads the annotations and calculates that it must contact the AWS cloud API to construct a physical Application Load Balancer.

### Step 3: The Webhook Injection Engine
To execute the API calls, the controller pod needs AWS authorization. This is where its pre-configured **Kubernetes Service Account** intersects with the **EKS Pod Identity Mutating Webhook**. 
*   During the initial pod boot lifecycle, the EKS Pod Identity agent intercepts the pod creation request.
*   It reads the Service Account configuration and mounts a local, short-lived cryptographic identity token file directly into the container filesystem at `/var/run/secrets/pods.eks.amazonaws.com/serviceaccount/token`.
*   It automatically injects the standard environment variable settings `AWS_CONTAINER_CREDENTIALS_FULL_URI` and `AWS_CONTAINER_AUTHORIZATION_TOKEN` right into the running container environment shell.

### Step 4: AWS STS Token Exchange
The AWS SDK embedded within the AWS Load Balancer Controller code detects these injected environment variables. It automatically extracts the localized Kubernetes token string and opens an outbound connection to the global **AWS Security Token Service (STS)** API endpoint. The SDK executes an `AssumeRoleWithWebIdentity` structural transaction, presenting the cluster-internal token as proof of origin.

### Step 5: The AWS IAM Authorization Gate
The AWS IAM evaluation engine receives the token request, cross-validates the token's signature against the EKS cluster's trusted OIDC/Identity Provider configuration, and confirms that this specific Service Account has permission to assume the designated infrastructure role. Upon validation, IAM generates a set of temporary, scoped AWS security credentials (Access Key, Secret Key, and Session Token) with a strict 1-hour expiration window, passing them back to the controller pod container memory.

### Step 6: Hardware Provisioning Loop
Armed with valid temporary cloud credentials, the AWS Load Balancer Controller pod bypasses the cluster and directly calls the real AWS Elastic Load Balancing API endpoints. It invokes `elasticloadbalancing:CreateLoadBalancer`, `elasticloadbalancing:CreateTargetGroup`, and `ec2:AuthorizeSecurityGroupIngress`. The AWS cloud fabric processes these authorized requests and provisions physical hardware: routing rules, security parameters, and an internet-facing Application Load Balancer that streams external traffic back into the Spring Boot application pods.

---

## 6. Amazon CloudFront Deep Mechanical Breakdown

Amazon CloudFront is a globally distributed, highly secure **Content Delivery Network (CDN)** designed to accelerate the delivery of both static content assets and dynamic multi-tier API transaction streams.

### Global Caching Infrastructure Anatomy
*   **Edge Locations (Points of Presence - POPs):** Highly distributed, dense data centers positioned in global metropolitan areas. POPs serve as the frontline termination layer for client network connections. They maintain localized RAM and SSD caching tiers to return popular files instantly without reaching out to primary backends.
*   **Regional Edge Caches (RECs):** Larger, centralized architectural data center hubs deployed between local Edge Locations and core AWS Regions. RECs maintain a massive storage footprint. If a local Edge Location suffers a cache miss, it queries the nearest REC first. This acts as a middle-tier shield, preserving storage life and preventing the primary origin servers from processing redundant requests.
*   **The AWS Global Fiber Network Backbone:** When a cache miss occurs at both the Edge and REC layers, the request is not routed over the wild, congested public internet. CloudFront catches the packet at the edge and routes it directly through AWS’s private global fiber-optic infrastructure network. This private backbone completely avoids public BGP routing inefficiencies, cross-carrier peering bottlenecks, and unpredictable packet loss.

### Core Configuration Parameters & Behavioral Taxonomy

```
[ Incoming Request ] ──► [ Cache Behavior Path Match: "/static/*" ] ──► [ Cache Policy: Evaluate Cache Key ] ──► Return Cache Hit
                     └──► [ Cache Behavior Path Match: "/api/*" ]    ──► [ Origin Request Policy: Forward Headers ] ──► Bypass Cache to Origin
```

#### 1. The Origin Configuration
The **Origin** defines the definitive, authoritative source upstream server where CloudFront fetches uncached source data.
*   **S3 Bucket Origins:** Houses static resources (e.g., compiled Angular/React HTML5 bundles, CSS sheets, media assets).
*   **Custom Origins:** Expressed as a fully qualified domain name (FQDN) targeting servers outside CloudFront's automatic scope, such as an AWS Application Load Balancer routing to EKS, an AWS API Gateway stage, or a bare-metal corporate mainframe.

#### 2. Cache Policies & The Cache Key
A **Cache Policy** dictates how CloudFront manages its internal data retention layer. The core setting is the **Cache Key**, which forms the unique mathematical string signature used to determine if an incoming request is a match for an existing cached file.
*   **Key Composition:** You can configure the Cache Key to incorporate specific HTTP Headers, Cookies, or URL Query Strings. For example, if you include the query string parameter `?theme` in the Cache Key, `style.css?theme=dark` and `style.css?theme=light` are saved as two completely unique objects in edge memory.
*   **TTL Boundaries:** Configured via `Min TTL`, `Max TTL`, and `Default TTL` settings (expressed in seconds). These parameters define the exact temporal boundaries for file survival at the edge before an internal re-validation request is forced against the Origin server.

#### 3. Origin Request Policies
An **Origin Request Policy** controls exactly what data elements from the client's request are forwarded up to your origin backend server during a cache miss event. This operates completely independently of the Cache Key. 
*   **Dynamic API Architecture Integration:** For a Spring Boot API, you must configure an Origin Request Policy that forwards all `Headers`, `Cookies`, and `Query Strings` (such as the `Authorization` bearer token header). If you omit this configuration, CloudFront strips these headers off the request at the edge POP before proxying the packet to EKS, causing your Spring Boot code to reject the request with `401 Unauthorized` errors due to missing credentials.

#### 4. Cache Behaviors
**Behaviors** act as the internal routing engine within a CloudFront Distribution. They use path pattern matching rules to apply specific policies based on the incoming request URL.
*   **Path Pattern `static/*`:** Mapped to an S3 origin, linked to a high-performance `CachingOptimized` policy, with HTTPS enforcement enabled.
*   **Path Pattern `api/*`:** Mapped to an EKS Application Load Balancer origin, linked to a `CachingDisabled` policy (TTL values set to 0), and connected to an Origin Request Policy that forwards all headers transparently.

### Native Integration Matrix with the AWS Ecosystem

```
               ┌──► [ AWS WAF ] (Inspects Layer 7 exploits / Bot blocking)
               │
[ User ] ──► [ CloudFront Distribution ] ──► [ Origin Access Control (OAC) ] ──► [ Amazon S3 Bucket ]
               │
               └──► [ AWS Certificate Manager (ACM) ] (Manages global SSL/TLS certificates)
```

*   **Amazon S3 via Origin Access Control (OAC):** When hosting a static frontend application on S3, exposing the bucket directly to the internet creates a security gap. CloudFront integrates via **Origin Access Control (OAC)**, a cryptographic signing method. The S3 bucket policy is locked down to block all public internet read requests, allowing access *only* if the request originates from your specific CloudFront Distribution identifier. This forces all traffic through your edge caching and security rules.
*   **AWS Certificate Manager (ACM):** CloudFront integrates seamlessly with ACM to deliver global HTTPS encryption. To bind a custom SSL certificate (e.g., `https://api.yourdomain.com`) to a CloudFront distribution, the certificate must be generated or imported within the `us-east-1` (N. Virginia) AWS region. CloudFront distributes the SSL certificate configurations to all global Edge POPs automatically.
*   **AWS WAF (Web Application Firewall):** You can bind an AWS WAF WebACL directly to the perimeter of your CloudFront distribution. This allows you to inspect incoming Layer 7 traffic and run custom rule matches (such as SQL injection blocking, cross-site scripting filtering, and geo-ip blocking) thousands of miles away from your primary computing infrastructure.

---

## 7. Lambda@Edge vs. CloudFront Functions: Advanced Edge Programmability

AWS provides programmable edge computing features that allow you to execute custom code right inside the global CloudFront network footprint, intercepting and transforming HTTP requests and responses in real-time.

```
                  [ Viewer Request ]              [ Origin Request ]
                         │                               │
  User Browser ──────────┼──────► [ Edge POP ] ──────────┼──────► AWS Origin
                         │                               │
                  [ Viewer Response ]             [ Origin Response ]
```

### Architectural Execution Hook Positions
Both execution engines can hook into four distinct interception points within the CloudFront request-response cycle:
1.  **Viewer Request:** Fires immediately when a client hits the local Edge POP, before CloudFront evaluates its cache layer.
2.  **Origin Request:** Fires *only* during a cache miss, right before CloudFront forwards the request up to the primary origin server.
3.  **Origin Response:** Fires when the primary origin server returns a payload to the CloudFront edge, before the data is written into cache storage.
4.  **Viewer Response:** Fires right before the final response payload is transmitted back to the client device.

### Deep Architectural Comparison Matrix

| Technical Metric | CloudFront Functions | Lambda@Edge |
| :--- | :--- | :--- |
| **Runtime Language Support** | Pure JavaScript (ECMAScript 5.1 compliant engine). | Node.js or Python. |
| **Deployment Footprint** | Executed directly at the highly distributed **Edge POP Locations**. | Executed within the slightly larger **Regional Edge Caches (RECs)**. |
| **Execution Hook Availability** | Bounded strictly to **Viewer Request** and **Viewer Response** hooks. | Full coverage across all 4 hooks: **Viewer Request, Viewer Response, Origin Request, Origin Response**. |
| **Max Execution Time Limit** | **< 1 Millisecond** (Ultra-fast execution constraint). | **5 Seconds** for Viewer hooks; **30 Seconds** for Origin hooks. |
| **Max Code Package Size** | Max **10 KB** total script capacity. | **1 MB** for Viewer hooks; **50 MB** for Origin hooks. |
| **Network & File System Access** | **Zero:** No internet access, no external API calling, no file systems. | **Full:** Complete internet access, external database querying, AWS SDK file reading. |
| **Cold Start Performance** | **Instantaneous:** Zero cold-start latency overhead. | Subject to occasional cold-start overhead delays. |
| **Primary Usecase Target** | High-volume URL rewrites, basic header injections, geo-redirection. | Edge authentication (JWT validation), dynamic A/B testing variations, edge data generation. |

---

## 8. Real-World Production Failures & Incident Post-Mortems

### Failure 1: The Stripped Authorization Token Blackout (CloudFront to EKS)
*   **Scenario:** A development team deployed a Spring Boot microservice architecture into an EKS cluster behind a public Application Load Balancer. To improve performance, they introduced a CloudFront distribution in front of the ALB, applying a catch-all behavior (`*`) configured to point to the ALB origin.
*   **The Symptom:** Immediately following deployment, users worldwide were blocked from logging into the platform. Every single API call targeting the system returned a `401 Unauthorized` or `403 Forbidden` error, despite no modifications being made to the underlying Spring Boot application code.
*   **Root Cause Analysis:** By default, when a new CloudFront distribution behavior is instantiated, it applies the standard `CachingOptimized` managed policy. This policy is pre-tuned under the assumption that all traffic is static asset delivery. To maximize cache hits, the policy **automatically strips all incoming HTTP headers, cookies, and query strings** off the request at the edge POP before proxying the packet forward. Consequently, the user's `Authorization: Bearer <JWT>` token header was deleted by CloudFront. When the packet arrived at the EKS ALB and passed to the Spring Boot JVM, the Spring Security framework found a completely blank request header, correctly throwing a `401 Unauthorized` exception.
*   **Resolution Protocol:** The engineering team removed the static `CachingOptimized` policy from the API path behavior. They instantiated a custom **Origin Request Policy** specifically configured to pass through `All Viewer Headers, Cookies, and Query Strings` transparently. Additionally, they linked a **Cache Policy** configured with caching completely disabled (`Managed-CachingDisabled`, setting Minimum, Maximum, and Default TTL values strictly to 0). This forced CloudFront to act as a transparent proxy for the dynamic endpoints, preserving the cryptographic Authorization headers intact.

### Failure 2: The EKS Cascading Subnet Blackout (Prefix Delegation Misconfiguration)
*   **Scenario:** A high-traffic enterprise cluster running hundreds of minor microservice pods experienced random worker node scaling issues due to IP exhaustion on standard `m5.large` instances. A cloud architect enabled Prefix Delegation by setting `ENABLE_PREFIX_DELEGATION=true` inside the `aws-node` VPC CNI configuration to resolve the issue. The EKS cluster sat inside a private VPC subnet allocated as a `/24` block (254 addressable IPs).
*   **The Symptom:** Within two hours of the update, during a standard deployment rollout, the cluster's Cluster Autoscaler began throwing continuous provisioning errors. New EC2 host instances failed to join the cluster, existing nodes lost connection to the control plane, and unrelated corporate applications operating inside the same VPC subnet lost all database connectivity.
*   **Root Cause Analysis:** An `m5.large` instance supports up to 3 ENIs, with each ENI accommodating up to 10 allocation slots. When Prefix Delegation was enabled, the default CNI engine behavior took effect: it attempted to pre-allocate an entire `/28` prefix block (16 IPs) into **every single available slot** across all ENIs to maintain a large pool of warm, instantly available addresses. As a result, a single `m5.large` instance instantly consumed multiple `/28` blocks from the VPC subnet the moment it booted, locking up to 160+ IP addresses per node, even if the instance was only executing a single test pod. The small `/24` VPC subnet was completely drained of all 254 addresses by just two worker nodes, causing the cascading infrastructure failure.
*   **Resolution Protocol:** The team executed an emergency rollback of the deployment and applied a remediation configuration to the VPC CNI daemon settings:
    1.  They set **`WARM_PREFIX_TARGET=1`**, forcing the VPC CNI engine to pre-allocate **only one single extra block of 16 IPs** ahead of immediate scheduling needs, rather than filling every available slot on the network interface card.
    2.  They introduced a new, secondary `/20` CIDR block into the core VPC architecture, migrating EKS worker node workloads into large, isolated subnets designed to handle dense IP allocation footprints.

### Failure 3: Lambda@Edge Dynamic Lookup Timeout Cascade
*   **Scenario:** An engineering team implemented a secure token validation architecture using a Lambda@Edge function hooked into the CloudFront **Viewer Request** interception point. The function was written in Node.js and was responsible for parsing incoming JWT tokens, making an outbound HTTPS call to an external identity provider database to check if the token had been blacklisted, and either passing the request forward or returning an immediate `403` block page.
*   **The Symptom:** During a morning traffic surge, the website's global response latency skyrocketed by over 5 seconds per request. Shortly after, the CloudFront distribution began returning generic `502 Bad Gateway` error pages to approximately 40% of all global users.
*   **Root Cause Analysis:** Lambda@Edge functions operating at the **Viewer Request** hook feature a hard, unalterable system execution timeout limit of **5 seconds**. During the morning traffic surge, the external identity provider database experienced a performance slowdown, causing its internal query response times to increase from 50 milliseconds to 6 seconds. Because the Lambda@Edge function was executing synchronously inside the critical viewer path, it hung waiting for the database HTTP response. The execution window crossed the 5-second architectural threshold, causing the CloudFront engine to forcefully terminate the Lambda container execution thread and return an immediate `502 Bad Gateway` error to the client.
*   **Resolution Protocol:** The architectural framework was redesigned using a multi-tiered mitigation approach:
    1.  The team added an aggressive **connection and read timeout configuration (set to 500 milliseconds)** to the outbound HTTP client inside the Lambda code. If the database failed to respond within that window, the call would gracefully fail-open or fail-closed based on architectural rules, preventing the function from hanging until the 5-second hard ceiling.
    2.  They implemented an in-memory caching mechanism using an **Amazon ElastiCache (Redis)** layer positioned close to the Lambda nodes, drastically reducing the need to make slow, external network lookups for repeated token validation requests.
