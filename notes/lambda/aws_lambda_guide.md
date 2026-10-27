# AWS Lambda: Comprehensive Deep-Dive Reference

AWS Lambda is a serverless, event-driven compute service that lets you run code for any application or backend service without managing servers, scaling automatically from zero to thousands of concurrent executions.

---

## 1. Core Compute Models & Families

* **Lambda Event Functions (On-Demand):** Stateless, serverless model spinning up in response to events.
* **Lambda Web Functions:** Runs standard HTTP frameworks directly without adaptors, serving multiple concurrent requests within a single warm environment.
* **Lambda Managed Instances:** Runs event functions on dedicated EC2 instances inside your account managed by AWS.
* **Lambda MicroVMs:** Isolated, stateful microVMs built from Dockerfiles with dedicated HTTPS endpoints supporting long-running execution (up to 8 hours) and WebSockets.

---

## 2. Architecture & Execution Lifecycle

1. **The Event Source / Trigger:** Invokes the function synchronously or asynchronously.
2. **The Execution Environment:** 
   * **Cold Start:** Provisions a MicroVM (powered by Firecracker), downloads the package, and runs initialization code if no idle container exists.
   * **Warm Start:** Reuses an active execution environment for lower latency.
3. **SnapStart:** Takes a memory state snapshot after initialization for Java and .NET runtimes, cutting cold start times by up to 90%.
4. **Scaling:** Scales horizontally automatically with a unique execution environment per concurrent request.

---

## 3. Runtimes & Packaging

* **Supported Runtimes:** Node.js, Python, Java, Go, .NET, Ruby, Rust, and Custom runtimes.
* **Packaging Formats:** Compressed ZIP archives or OCI-compliant container images (up to 10 GB) hosted in Amazon ECR.

---

## 4. Configuration & Hardware Settings

* **Memory Allocation:** 128 MB to 10 GB, proportionally assigning CPU power, network bandwidth, and disk I/O.
* **Architecture Options:** x86_64 or AWS Graviton (Arm-based) for up to 34% better price-performance ratio.
* **Timeouts:** Configurable up to **15 minutes** per invocation.
* **Ephemeral Storage (`/tmp`):** Configurable temporary scratch space from 512 MB up to 10 GB.

---

## 5. Integrations & Event Sources

* **Synchronous Invocations:** Caller waits for a response (e.g., API Gateway, ALB).
* **Asynchronous Invocations:** Events placed in an internal queue with automatic retries and routing to DLQs or Destinations.
* **Poll-based (Event Source Mappings):** Polls streams or queues (SQS, Kinesis, DynamoDB Streams, Kafka) in batches.

---

## 6. Security, VPC & Permissions

* **IAM Execution Role:** Defines granular permissions to access downstream AWS resources.
* **VPC Integration:** Connects functions securely to private RDS databases, ElastiCache, or internal microservices.
* **Environment Variables & Secrets:** Integrates with AWS Secrets Manager and Parameter Store with KMS encryption.
* **Tenant Isolation:** Execution environments can be isolated securely per tenant ID.

---

## 7. Monitoring, Logging & Troubleshooting

* **Amazon CloudWatch Metrics:** Tracks `Invocations`, `Duration`, `Errors`, `Throttles`, and `ConcurrentExecutions`.
* **CloudWatch Logs:** Captures `stdout`/`stderr` outputs for querying via CloudWatch Logs Insights.
* **AWS X-Ray:** Distributed tracing across API Gateway, Lambda, and databases.
* **Lambda Powertools:** Utilities for tracing, logging, and metrics parsing.

---

## 8. Pricing Structure

* **Free Tier:** 1 million requests and 400,000 GB-seconds per month.
* **Request Charges:** $\$0.20$ per 1 million requests.
* **Duration Charges:** Billed per millisecond based on allocated memory (GB-seconds). Arm architectures are roughly 20% cheaper.
* **Provisioned Concurrency:** Billed at a flat hourly rate per GB-second of provisioned capacity.

---

## 9. Concurrency Controls: Reserved vs. Provisioned Concurrency

Concurrency controls how many execution environments actively process events at any given time.

### A. Reserved Concurrency
* **Definition:** Sets the *maximum* number of concurrent instances that a specific Lambda function can run.
* **Purpose:** Protects the regional concurrency pool from runaway functions or traffic spikes starving other critical workloads (prevents the **"noisy neighbor"** effect).
* **Throttling:** If set to a limit and hit, incoming requests are throttled (returning `429 Too Many Requests`).
* **Disabling:** Setting reserved concurrency to `0` completely blocks a function from executing.

### B. Provisioned Concurrency
* **Definition:** Initializes a specified number of execution environments *ahead of time* to keep them warm and eliminate cold starts.
* **Requirement:** Must have a corresponding **Reserved Concurrency** limit configured.
* **Auto-Scaling:** Supports target tracking scaling to automatically scale warm environments based on traffic patterns.

### Summary Table: Concurrency Types

| Feature | Primary Goal | Behavior on Spike | Billing Impact |
| :--- | :--- | :--- | :--- |
| **Unreserved Concurrency** | Default scaling; shares account pool. | Scales freely until limits or backpressure hits. | Pay-per-invocation (duration) only. |
| **Reserved Concurrency** | Protects downstream resources / isolates functions. | Throttles requests when the limit is reached. | Pay-per-invocation (duration) only. |
| **Provisioned Concurrency** | Eliminates cold starts for ultra-low latency. | Instant response from pre-warmed environments. | Continuous billing for capacity + invocation time. |