# Amazon API Gateway: Comprehensive Deep-Dive Reference

Amazon API Gateway is a fully managed service that makes it easy for developers to create, publish, maintain, monitor, and secure APIs at any scale. It handles all the heavy lifting of accepting and processing hundreds of thousands of concurrent API calls.

---

## 1. Core API Types

API Gateway offers three primary types of APIs designed for different communication patterns:

### A. HTTP APIs (v2)
* **Purpose:** Built for high-performance, low-cost, and low-latency proxying to AWS Lambda functions or HTTP backends.
* **Protocols:** HTTP/1.1.
* **Key Features:** Native support for OIDC/OAuth 2.0 via JSON Web Tokens (JWT), automatic deployments, built-in CORS support, and cross-account integrations.
* **Cost:** Most cost-effective option (~71% cheaper than REST APIs).

### B. REST APIs (v1)
* **Purpose:** Fully featured APIs providing rich management capabilities, enterprise security, and granular control.
* **Endpoint Types:**
  * **Regional:** Hosted in a specific AWS Region; best for clients within the same region or behind a custom CloudFront distribution.
  * **Edge-Optimized:** Fronted by an Amazon CloudFront distribution globally, routing requests to the closest AWS edge location. Ideal for geographically distributed clients.
  * **Private:** Accessible only within your Amazon Virtual Private Cloud (VPC) via an interface VPC endpoint (AWS PrivateLink).
* **Key Features:** API keys, usage plans, request/response transformation, execution caching, AWS WAF integration, and client SDK generation.

### C. WebSocket APIs
* **Purpose:** Real-time, two-way (bidirectional) communication applications (e.g., chat apps, streaming dashboards, multiplayer games).
* **Mechanism:** Maintains a persistent connection using the WebSocket protocol. Messages are routed to backends (Lambda, Kinesis, or HTTP endpoints) based on route keys.

---

## 2. Architecture & Request Flow

1. **Client Request:** A client sends an HTTP/HTTPS or WebSocket request.
2. **Domain & DNS Resolution:** Route 53 resolves the custom domain name to the API Gateway endpoint.
3. **Edge Security & WAF:** AWS WAF evaluates the request against security rules.
4. **Authorizers:** API Gateway validates identity via IAM, Cognito User Pools, or a custom Lambda Authorizer.
5. **Caching (REST APIs Only):** Returns cached responses instantly on cache hits.
6. **Request Validation & Transformation:** Validates parameters and utilizes Mapping Templates (VTL) to transform payloads.
7. **Integration Endpoint:** Forwards the request to the backend target.

---

## 3. Backend Integrations

* **Lambda / HTTP Proxy Integration:** Passes the incoming request straight through with minimal modification for lower latency and simplified wiring.
* **Lambda / HTTP / AWS Service Custom Integration:** Enables full customization, such as integrating REST APIs directly with AWS services (e.g., DynamoDB or SQS) without compute code.
* **VPC Links:** Allows private integration with resources inside a private VPC (ALBs, ECS, EC2) without exposing them to the public internet.

---

## 4. Security & Access Control

* **IAM Authorization:** Uses AWS Signature Version 4 (SigV4) for service-to-service communication.
* **Cognito User Pools:** Native integration for user authentication via JWTs.
* **Lambda Authorizers (Custom Authorizers):** Custom logic controlling access using bearer tokens or OAuth scopes.
* **JWT Authorizers:** Native validation for HTTP APIs validating standard JWTs from identity providers.
* **Resource Policies:** JSON-based policies controlling who can invoke the API from specific IP ranges, VPCs, or accounts.
* **WAF Integration:** Protects against common web exploits and DDoS attacks.
* **API Keys & Usage Plans:** Restricts access and enforces throttling/quotas per client.

---

## 5. Traffic Management, Throttling & Caching

* **Throttling:** Protects your backend using a token-bucket algorithm at the account, stage, or method level.
* **Usage Plans:** Associates API keys with rate and quota limits.
* **API Caching (REST Only):** Caches backend responses for a specified TTL to reduce backend load and lower latency.

---

## 6. Lifecycle, Deployment & Versioning

* **Stages:** Named environments (e.g., `dev`, `staging`, `prod`) representing unique snapshots of your API configuration.
* **Deployment & Rollback:** Supports instant rollbacks to previous deployments.
* **Canary Deployments:** Directs a specific percentage of traffic to a new version to test changes safely.
* **OpenAPI / Swagger:** Programmable definition, versioning, and deployment using OpenAPI 3.0 specification files or IaC tools.

---

## 7. Monitoring, Logging & Tracing

* **Amazon CloudWatch Metrics:** Tracks `Count`, `Latency`, `IntegrationLatency`, `4XXError`, and `5XXError`.
* **Execution & Access Logs:** Execution logs capture deep tracing; access logs record caller identity, IP, method, and status.
* **AWS X-Ray:** End-to-end distributed tracing across API Gateway and downstream services.

---

## 8. Pricing Structure

* **HTTP APIs:** $\approx \$1.00$ per million requests (first 300M tier).
* **REST APIs:** $\approx \$3.50$ per million requests (first 333M tier).
* **WebSocket APIs:** $\approx \$1.00$ per million messages + $\$0.25$ per million connection-minutes.
* **Additional Costs:** Data transfer out fees, REST API caching hourly rate, and VPC Link processing fees.