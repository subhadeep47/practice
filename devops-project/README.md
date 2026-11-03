# devops-project

DevOps setup for an e-commerce application: React (TypeScript) frontend, Spring Boot
backend, PostgreSQL on AWS RDS. Application source code lives elsewhere in the repo; this
folder only holds infrastructure and delivery.

- **Terraform** builds the AWS infrastructure (VPC, EKS, RDS, S3 + CloudFront). It describes
  structure only: it contains no environment-specific values.
- **Ansible** owns every environment-specific value (one folder per environment: `dev`,
  `prod`), passes them to Terraform and runs the stacks in the right order.
- **Helm** packages the Spring Boot backend for Kubernetes.
- **Argo CD** deploys the chart to EKS from git (GitOps).
- **Not built yet:** GitHub Actions CI, Prometheus/Grafana monitoring (see [What's next](#whats-next)).

## Contents

1. [Architecture](#architecture)
2. [Repository layout](#repository-layout)
3. [Environments and configuration](#environments-and-configuration)
4. [Prerequisites](#prerequisites)
5. [Step 1 - Provision the infrastructure](#step-1---provision-the-infrastructure)
6. [Step 2 - Connect to the cluster](#step-2---connect-to-the-cluster)
7. [Step 3 - AWS Load Balancer Controller](#step-3---aws-load-balancer-controller)
8. [Step 4 - Database credentials](#step-4---database-credentials)
9. [Step 5 - Bootstrap Argo CD and deploy the backend](#step-5---bootstrap-argo-cd-and-deploy-the-backend)
10. [Step 6 - Deploy the frontend](#step-6---deploy-the-frontend)
11. [Step 7 - Continuous integration](#step-7---continuous-integration)
12. [Day-2 operations](#day-2-operations)
13. [Tear down](#tear-down)
14. [Troubleshooting](#troubleshooting)
15. [Design decisions](#design-decisions)
16. [What's next](#whats-next)

## Architecture

```
                         Browser
                   |                  |
          static files            API calls (/api)
                   v                  v
             CloudFront            AWS ALB (internet-facing)
                   |                  |  created by the AWS Load Balancer
               S3 bucket (private)    |  Controller from the Ingress
                                      v
   VPC ───────────────────────────────────────────────────────────
    public subnets:  ALB, NAT gateway
    private subnets: EKS worker nodes ── Spring Boot pods ──> RDS PostgreSQL
                          |                                    (only reachable
                     Argo CD (namespace argocd)                 from the nodes)
                     watches this git repo and syncs the chart
```

Delivery flow: a push to the backend repository -> GitHub Actions tests, builds and pushes the
image to ECR, then commits the new tag to `values-dev.yaml` here -> Argo CD notices (within
about 3 minutes) -> renders `helm/spring-boot-backend` with that file -> applies it to the
cluster, where the nodes pull the image from ECR.

## Repository layout

```
devops-project/
├── ansible.cfg
├── ansible/
│   ├── inventories/
│   │   ├── dev/             ALL values of the dev environment
│   │   │   ├── hosts.yml
│   │   │   └── group_vars/all/   main.yml (env, region, state), vpc.yml, eks.yml,
│   │   │                         rds.yml, s3_cloudfront.yml
│   │   └── prod/            same files, prod values
│   ├── playbooks/
│   │   ├── 01-provision-infrastructure.yml   run Terraform for all stacks, in order
│   │   ├── 02-show-outputs.yml               print the outputs of all stacks
│   │   ├── 99-destroy-infrastructure.yml     destroy all stacks, reverse order
│   │   ├── roles -> ../roles                 symlink so AWX finds the role (see below)
│   │   └── vars/stacks.yml                   stack order (structure, not configuration)
│   └── roles/terraform_runner/               values -> var file, init (S3 backend), plan/apply/destroy
├── terraform/           structure only: variables have no defaults, there are no tfvars
│   ├── vpc/             VPC, subnets, NAT                    (apply 1st)
│   ├── eks/             EKS cluster + Argo CD (Helm)         (apply 2nd)
│   ├── rds/             PostgreSQL + security group          (apply 3rd)
│   ├── s3-cloudfront/   React hosting                        (independent)
│   └── ecr/             backend image registry + GitHub push role (independent)
├── helm/spring-boot-backend/   chart; values-dev.yaml = desired state of dev
├── argocd/
│   ├── root-app.yaml           applied by hand once; points Argo CD at argocd/apps
│   └── apps/                   AppProject + Application manifests (managed by Argo CD)
├── k8s/external-secrets/       ClusterSecretStore applied by hand (step 4A)
└── ci/                         pipeline templates to copy into the app repositories (step 7)
```

GitHub Actions checks for this folder itself are in `.github/workflows/devops-project-ci.yml`
at the repository root (GitHub only reads workflows from there).

`ansible/playbooks/roles` is a **symlink** to `ansible/roles` (not a second copy of the role).
Ansible finds roles in a `roles/` folder next to the playbook, and AWX starts from the
repository root, where it does not read `devops-project/ansible.cfg` (which sets `roles_path`).
The link makes the role found in both AWX and the command line.

## Environments and configuration

**Rule: Terraform has no environment-specific content; Ansible has all of it.**

- An environment is an Ansible inventory folder: `ansible/inventories/dev`,
  `ansible/inventories/prod`. You choose it with `-i`, and there is deliberately no default,
  so a forgotten flag can never touch the wrong environment.
- Everything that differs between environments is in that folder's `group_vars/all/`:

  | File | Contents |
  |---|---|
  | `main.yml` | `env_name`, region, the S3 state location (`tf_backend`), values shared by all stacks (`tf_vars_common`: environment, project, region), optional `tf_process_env` (e.g. `AWS_PROFILE` for a separate AWS account) |
  | `vpc.yml` | `tf_vars_vpc`: CIDRs, availability zones, single or per-AZ NAT |
  | `eks.yml` | `tf_vars_eks`: Kubernetes version, node types and counts, API endpoint access, Argo CD chart version |
  | `rds.yml` | `tf_vars_rds`: instance class, storage, engine version, multi-AZ, backups, snapshot and deletion protection, DB name and user |
  | `s3_cloudfront.yml` | `tf_vars_s3_cloudfront`: bucket name prefix, price class |

- On every run the `terraform_runner` role merges `tf_vars_common` with the stack's own
  dictionary, writes the result to a temporary JSON var file (mode 0600, deleted afterwards)
  and runs `terraform plan | apply | destroy -var-file=<that file>`, depending on `tf_action`
  (see [Plan, then apply](#plan-then-apply)). It also runs
  `terraform init -reconfigure` with `-backend-config` flags built from `tf_backend`, so every
  environment and stack has its own state file
  (`<key_prefix>/<stack>/terraform.tfstate`, e.g. `devops-project/dev/vpc/terraform.tfstate`).
- Every Terraform variable is **required and has no default**. If Ansible does not supply one,
  Terraform stops with "No value for required variable" instead of silently guessing.
- The `dev` values are exactly what the earlier `dev.tfvars` files and variable defaults
  contained. The `prod` values are sensible starting points that have never been applied
  (separate CIDR, three AZs, one NAT per AZ, multi-AZ RDS with deletion protection, bigger
  nodes): review them before the first prod apply.
- The playbooks default to `tf_action=plan`, which changes nothing. Changing infrastructure
  is always two deliberate steps, in every environment: a plan job, a human approval, then an
  apply job.
- What is **not** in Ansible: the Kubernetes side. Argo CD deploys from git, so per-environment
  chart values stay in git next to the chart (`helm/spring-boot-backend/values-<env>.yaml`)
  and the Argo CD applications in `argocd/apps/`.

**Add an environment** (for example `staging`): copy `ansible/inventories/dev` to
`ansible/inventories/staging`, change `env_name`, `key_prefix` and the values, then run the
playbooks with `-i ansible/inventories/staging`. No Terraform change is needed.

**Change a value:** edit the file in the environment's folder, push, run the plan job, read it,
approve, and the apply job runs.

### Plan, then apply

`01-provision-infrastructure.yml` has two modes, chosen by the variable `tf_action`:

| `tf_action` | What happens |
|---|---|
| `plan` (default) | `terraform plan` for each stack, in order. Changes nothing. The plan is in the job output, with a "CHANGES PENDING" or "No changes" line per stack. |
| `apply` | `terraform apply -auto-approve` for each stack, in order (it plans again and applies). |

`apply` does not need a plan from an earlier run: it works out its own. The human check is an
**approval between the two jobs**, not a file passed between them. The consequence: the apply
plans again, so if the code, the values or AWS itself changed after the plan was approved, the
apply does what the new plan says. Keep the window between approval and apply short and do
not push in between (see [Design decisions](#design-decisions)).

You never choose the stacks: the playbook walks the order in `ansible/playbooks/vars/stacks.yml`
(`vpc`, `eks`, `rds`, `s3-cloudfront`) by itself. `tf_services` exists only as an optional
override to limit a run to some stacks, for example `{"tf_services": ["vpc"]}`.

### Running from AWX / Ansible Tower

Provisioning is meant to run from AWX, not from a laptop. Set up once per environment:

1. **Project:** this git repository, branch `main`.
2. **Inventory** `devops-dev`: add an *inventory source* of type *Sourced from a Project*, using
   that project and the path `devops-project/ansible/inventories/dev`. That loads `hosts.yml`
   and `group_vars/all/*.yml`, so every `env_name`, `tf_backend` and `tf_vars_*` value comes
   from the environment folder. Do the same for prod with `.../inventories/prod`. Enable
   *Update on launch* so a push is picked up.
3. **Credentials:** an *Amazon Web Services* credential for the environment's account (its
   keys become environment variables of the job and reach Terraform), or run the job where an
   IAM role is attached.
4. **Execution environment:** it must contain `terraform` >= 1.10 and the `aws` CLI v2 (the
   EKS stack's Helm provider calls `aws eks get-token`). Build a custom execution environment
   image if yours does not.
5. **Job templates** (all with *Playbook* from the project, *Inventory* `devops-dev`):

   | Template | Playbook | Extra variables (JSON) |
   |---|---|---|
   | `dev: provision, plan` | `devops-project/ansible/playbooks/01-provision-infrastructure.yml` | `{"tf_action": "plan"}` |
   | `dev: provision, apply` | `devops-project/ansible/playbooks/01-provision-infrastructure.yml` | `{"tf_action": "apply"}` |
   | `dev: show outputs` | `devops-project/ansible/playbooks/02-show-outputs.yml` | (none) |
   | `dev: destroy` | `devops-project/ansible/playbooks/99-destroy-infrastructure.yml` | (none); add a *survey* question with variable name `destroy_confirmation` (text) asking the user to type the environment name |

   Two separate templates, rather than one with a prompt, mean nobody can apply by choosing
   the wrong value in the plan template.
6. **Workflow** `dev: provision` = `dev: provision, plan` -> **Approval** node -> `dev: provision, apply`.
   Under the approval node, set *On success* to the apply template. Restrict who may approve
   (and who may launch the apply template) with AWX roles. In AWX the playbook itself cannot
   pause for a human, which is why the approval is a workflow node.

**A brand-new environment.** Planning `eks` needs the VPC to exist (it finds it through the AWS
API), so the plan job fails at `eks` the first time. That is expected: read the `vpc` plan it
prints, then run the *apply* template. It plans and applies each stack in order, so `eks` sees
the VPC it needs. From the second run on, the workflow works as described. Alternatively launch
the plan template once with `{"tf_action": "plan", "tf_services": ["vpc"]}` (enable *Prompt on
launch* for extra variables).

**Without AWX** (for example for a quick first run), the same playbooks run from the command
line in the `devops-project` folder:

```bash
ansible-playbook -i ansible/inventories/dev ansible/playbooks/01-provision-infrastructure.yml                    # plan
ansible-playbook -i ansible/inventories/dev ansible/playbooks/01-provision-infrastructure.yml -e tf_action=apply # apply
```

## Prerequisites

Tools on the machine you run steps 2-6 from: `aws` CLI v2, `kubectl`, `eksctl`, `helm`, `jq`.

Tools for the **AWX execution environment** (or for the machine, if you run the playbooks from
the command line): `ansible`, `terraform` >= 1.10 and the `aws` CLI v2. The `aws` CLI is
needed there too, because the EKS stack's Helm provider uses `aws eks get-token` to reach the
cluster.

AWS: credentials for an IAM identity that can create VPC, EKS, RDS, IAM, S3, CloudFront
and Secrets Manager resources (check with `aws sts get-caller-identity`). That same identity
becomes the EKS cluster admin, so use the same one for `kubectl` later.

**Terraform state bucket.** State is stored in the S3 bucket `subhadeep-terraform-state-bucket`
(eu-north-1), created by the `remote-backend-terraform/` folder at the repository root.
Create it first if it does not exist (`terraform init && terraform apply` in that folder).
Locking uses S3's native lock file, so the DynamoDB table in that folder is not used.
Consider turning on versioning for the bucket.

**Edit these before the first run:**

| What | Where |
|---|---|
| Globally unique frontend bucket name | `ansible/inventories/<env>/group_vars/all/s3_cloudfront.yml` (`bucket_name_prefix`) |
| State bucket, region, sizes, CIDRs, anything else per environment | the other files in `ansible/inventories/<env>/group_vars/all/` |
| Your backend repository name (who may push images) | `ansible/inventories/<env>/group_vars/all/ecr.yml` (`github_oidc_subjects`) |
| Backend image, DB host, secret settings | `helm/spring-boot-backend/values-dev.yaml` (step 5) |

Everything below is run from the `devops-project` folder.

## Step 1 - Provision the infrastructure

Run the `dev: provision` workflow in AWX (see [Running from AWX](#running-from-awx--ansible-tower)):
the plan job runs, you read its output, approve, and the apply job creates everything in
order. For a brand-new environment follow the note about the first run in that section.
(CLI equivalent: the two `ansible-playbook` commands in that section.)

The playbook applies `vpc`, then `eks`, then `rds`, then `s3-cloudfront`. `plan` for `eks`
and `rds` only works after the stacks before them exist (see [Design decisions](#design-decisions)).
The rest of this guide shows `dev`; for another environment use that environment's inventory
and templates (and change `ENV` in step 2).

This creates a VPC with public and private subnets, an EKS cluster (Kubernetes 1.35,
managed node group, **Argo CD installed by Helm**), an encrypted RDS PostgreSQL 16 instance
whose password RDS generates and keeps in Secrets Manager, the S3 + CloudFront frontend, and
an ECR repository for the backend image with the GitHub Actions push role.
It takes about 20 minutes, mostly EKS and RDS. These resources cost money while they exist,
notably the EKS control plane, the NAT gateway, the nodes and RDS. [Tear down](#tear-down)
when you are not using them.

**Outputs.** Run the `dev: show outputs` template (CLI: `02-show-outputs.yml`) and read the job
output. Useful ones: `vpc_id`, `db_endpoint`, `db_master_secret_arn`, `cluster_name`,
`s3_bucket_name`, `cloudfront_domain_name`, `cloudfront_distribution_id`, `repository_url`,
`ci_push_role_arn`. Terraform runs in AWX,
not on your machine, so the commands later in this guide read what they need straight from AWS
with the `aws` CLI, or ask you to take a value from this job output.

Do not run `terraform apply` by hand in a stack folder: it has no variable values (they come
from Ansible), which is the point.

## Step 2 - Connect to the cluster

```bash
export ENV=dev                                   # the environment you provisioned
export AWS_REGION=us-east-1                      # aws_region in ansible/inventories/$ENV/group_vars/all/main.yml
export CLUSTER=app-cluster-$ENV                  # cluster name = app-cluster-<env_name>
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws eks update-kubeconfig --name $CLUSTER --region $AWS_REGION
kubectl get nodes                  # nodes in Ready state (dev: 2)
kubectl -n argocd get pods         # Argo CD pods Running
```

Keep these variables in your shell for the next steps. If you set `AWS_PROFILE` in the
environment's `tf_process_env`, export the same profile in your shell for `aws`, `eksctl` and
`kubectl`.

## Step 3 - AWS Load Balancer Controller

Manual, once per cluster. It turns the chart's Ingress into an ALB. The controller needs an
IAM role: `eksctl create iamserviceaccount` creates the role **and** the annotated
Kubernetes service account together (IRSA), and the Helm chart then reuses that account
(`serviceAccount.create=false`). There is deliberately no ServiceAccount manifest for it in
this repo: the role ARN is account-specific and `eksctl` owns the account.

```bash
# OIDC provider for IRSA (the EKS module creates it; this is a safe no-op if it exists)
eksctl utils associate-iam-oidc-provider --cluster $CLUSTER --region $AWS_REGION --approve

# IAM policy for controller v2.14.1 (create once per AWS account)
curl -o /tmp/lbc_iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.14.1/docs/install/iam_policy.json
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file:///tmp/lbc_iam_policy.json

# IAM role + service account in kube-system
eksctl create iamserviceaccount \
  --cluster $CLUSTER --region $AWS_REGION \
  --namespace kube-system --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts --approve

# The controller (chart 1.14.0 = controller v2.14.1)
VPC_ID=$(aws ec2 describe-vpcs --region $AWS_REGION --filters Name=tag:Name,Values=app-vpc-$ENV \
  --query 'Vpcs[0].VpcId' --output text)
helm repo add eks https://aws.github.io/eks-charts && helm repo update eks
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system --version 1.14.0 \
  --set clusterName=$CLUSTER --set region=$AWS_REGION --set vpcId=$VPC_ID \
  --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller

kubectl -n kube-system rollout status deploy/aws-load-balancer-controller
```

The VPC stack already tags the public subnets (`kubernetes.io/role/elb`), which is how the
controller places an internet-facing ALB. AWS lists the Gateway API CRDs as a prerequisite;
if the controller pods crash on missing `gateway.networking.k8s.io` CRDs, install them first:
`kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml`

## Step 4 - Database credentials

The backend reads the database username and password from a Kubernetes Secret named
`backend-db` (keys `username` and `password`) in the `ecommerce` namespace. Choose one way
to create it.

> RDS-managed master passwords **rotate automatically (every 7 days)**. Option B does not
> follow the rotation, so use option A for anything that stays up.

### Option A - External Secrets Operator (recommended)

Syncs the Secret from AWS Secrets Manager and keeps it current. Same pattern as step 3:
`eksctl` creates an IAM role (allowed to read **only** the database secret) and a service
account, Helm reuses it.

```bash
SECRET_ARN=$(aws rds describe-db-instances --region $AWS_REGION --db-instance-identifier app-postgres-$ENV \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' --output text)
cat > /tmp/eso-policy.json <<EOF
{"Version":"2012-10-17","Statement":[{"Effect":"Allow",
 "Action":["secretsmanager:GetSecretValue","secretsmanager:DescribeSecret"],
 "Resource":"${SECRET_ARN}"}]}
EOF
aws iam create-policy --policy-name ExternalSecretsDbRead-${ENV} --policy-document file:///tmp/eso-policy.json

kubectl create namespace external-secrets
eksctl create iamserviceaccount \
  --cluster $CLUSTER --region $AWS_REGION \
  --namespace external-secrets --name external-secrets \
  --attach-policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/ExternalSecretsDbRead-${ENV} \
  --override-existing-serviceaccounts --approve

helm repo add external-secrets https://charts.external-secrets.io && helm repo update external-secrets
helm search repo external-secrets/external-secrets      # pick a current version and pin it below
helm install external-secrets external-secrets/external-secrets -n external-secrets \
  --version <chart-version> \
  --set serviceAccount.create=false --set serviceAccount.name=external-secrets
kubectl -n external-secrets rollout status deploy/external-secrets

# Which API version does this operator serve? The chart defaults to external-secrets.io/v1.
kubectl get crd externalsecrets.external-secrets.io -o jsonpath='{.spec.versions[*].name}'

# Tell the operator how to reach Secrets Manager (region is set inside the file)
kubectl apply -f k8s/external-secrets/cluster-secret-store.yaml
```

Then, in `helm/spring-boot-backend/values-dev.yaml` (step 5 edits this file anyway):
`externalSecret.enabled: true` and `externalSecret.remoteSecretId: <the $SECRET_ARN value>`.
Add `externalSecret.apiVersion: external-secrets.io/v1beta1` only if the CRD check above
does not list `v1`. Argo CD will then create the `backend-db` Secret through the operator.

### Option B - copy the secret by hand (quick test only)

```bash
kubectl create namespace ecommerce
SECRET_ARN=$(aws rds describe-db-instances --region $AWS_REGION --db-instance-identifier app-postgres-$ENV \
  --query 'DBInstances[0].MasterUserSecret.SecretArn' --output text)
CREDS=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query SecretString --output text)
kubectl -n ecommerce create secret generic backend-db \
  --from-literal=username="$(echo "$CREDS" | jq -r .username)" \
  --from-literal=password="$(echo "$CREDS" | jq -r .password)"
unset CREDS
```

After a rotation, new database connections fail until you recreate this Secret and restart
the pods. To switch to option A later, delete it first: `kubectl -n ecommerce delete secret backend-db`.

## Step 5 - Bootstrap Argo CD and deploy the backend

Argo CD was installed by Terraform (chart `argo-cd` 10.8.3; a newer 10.11.x exists and can be
adopted by changing `argocd_chart_version` in `ansible/inventories/<env>/group_vars/all/eks.yml`).
Its UI is not exposed publicly.
The repository is public, so Argo CD needs no git credentials.

### 5.1 Open the Argo CD UI

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443       # leave running
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

Open https://localhost:8080 (accept the self-signed certificate) and log in as `admin`
with that password. Change the password under *User Info*, then you can delete the initial
secret: `kubectl -n argocd delete secret argocd-initial-admin-secret`.

### 5.2 Fill in the dev values and push them

Argo CD deploys what is in git, so the environment settings go in
`helm/spring-boot-backend/values-dev.yaml` (edit the section marked *EDIT BEFORE THE FIRST SYNC*):

| Key | Value |
|---|---|
| `image.repository` | the ECR repository: `repository_url` from the outputs job (the `ecr` stack is created in step 1) |
| `image.tag` | an immutable tag such as the git SHA (never `latest`). CI sets it after step 7; for a first manual test push an image yourself (see step 7) |
| `database.host` | `aws rds describe-db-instances --region $AWS_REGION --db-instance-identifier app-postgres-$ENV --query 'DBInstances[0].Endpoint.Address' --output text` (or `db_endpoint` from the outputs job) |
| `externalSecret.*` | only for step 4 option A |

```bash
git add helm/spring-boot-backend/values-dev.yaml
git commit -m "dev: set image and database host"
git push origin main
```

The image comes from ECR in the same account, which the worker nodes pull from with their IAM
role: no pull secret is needed. (Only for an image from another private registry, such as
Docker Hub, create a `docker-registry` secret in the `ecommerce` namespace and set
`imagePullSecrets: [{ name: regcred }]` in the values.)

Private git repository? Register it with Argo CD first (`argocd repo add <url> --username ... --password <token>`,
or *Settings -> Repositories* in the UI).

### 5.3 Apply the root application

```bash
kubectl apply -f argocd/root-app.yaml
kubectl -n argocd get applications
```

The `root` application reads `argocd/apps/` from git and creates the `ecommerce` project and
the `backend-dev` application, which deploys the chart into the `ecommerce` namespace
(release name `backend`). Everything syncs automatically; in the UI you will see the
resources appear and turn *Healthy*.

### 5.4 Verify

```bash
kubectl -n argocd get applications                      # root, backend-dev: Synced / Healthy
kubectl -n ecommerce get pods,svc,ingress

# ALB address (takes 2-3 minutes to appear)
kubectl -n ecommerce get ingress backend-spring-boot-backend \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'; echo
curl -i http://<alb-dns-name>/api/<your-endpoint>

# Actuator is internal only (not routed through the ALB)
kubectl -n ecommerce port-forward deploy/backend-spring-boot-backend 8080:8080
curl localhost:8080/actuator/health
```

What the chart gives you: Actuator probes (the app needs `spring-boot-starter-actuator`),
a non-root read-only container, resource requests and limits, 2 replicas with a
PodDisruptionBudget, and an Ingress that exposes **only `/api`** (change the path in
`values.yaml` if your routes differ). Autoscaling is off; turning it on needs metrics-server,
which EKS does not install.

## Step 6 - Deploy the frontend

```bash
cd <your React project>
npm run build            # output folder is build/ (Create React App) or dist/ (Vite)
# bucket = <bucket_name_prefix>-<env> (s3_cloudfront.yml); the distribution id is
# `cloudfront_distribution_id` in the "show outputs" job
BUCKET=<bucket_name_prefix>-$ENV
DISTRIBUTION_ID=<cloudfront_distribution_id from the outputs job>
aws s3 sync build/ s3://$BUCKET --delete
aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths "/index.html"
```

The site is served at the `cloudfront_domain_name` output. The bucket is private and only
CloudFront can read it. Missing paths fall back to `/index.html`, so React Router deep links
work. The frontend calls the backend at the ALB address, which is a different origin, so the
Spring Boot app needs CORS configured for the CloudFront domain.

## Step 7 - Continuous integration

The backend image is built and released by GitHub Actions. Because the backend source is in its
own repository, the workflow lives there; this project provides the template and the
infrastructure for it (`ci/` folder, full setup in `ci/README.md`).

What happens on every push to the backend repository's `main`:

1. `mvn verify` builds and tests (pull requests stop here).
2. The job assumes the AWS role `ci_push_role_arn` through **OIDC**, so no AWS keys are stored in
   GitHub, and pushes the image to ECR tagged with the git commit. The repository is
   immutable, so a tag always means the same image.
3. The job commits that tag to `helm/spring-boot-backend/values-dev.yaml` in this repository.
4. Argo CD syncs the change and Kubernetes rolls the pods over to the new image.

Set up once:

1. The `ecr` stack is created in step 1 with the rest. Make sure `github_oidc_subjects` in
   `ansible/inventories/dev/group_vars/all/ecr.yml` names your backend repository (do it before
   step 1; if you change it later, run the plan and apply jobs again).
2. Put `repository_url` into `image.repository` of `values-dev.yaml` and push.
3. Copy `ci/backend/build-and-deploy.yml` and `ci/backend/Dockerfile.example` into the backend
   repository and add the variables and the token secret listed in `ci/README.md`.
4. Push to the backend repository. Check the run in its *Actions* tab and the new tag in
   `values-dev.yaml`.

**A first manual push** (before CI exists), from the backend project folder:

```bash
REPO=$(aws ecr describe-repositories --region $AWS_REGION --repository-names fullstack-app/backend-$ENV \
  --query 'repositories[0].repositoryUri' --output text)
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${REPO%%/*}
docker build -t $REPO:manual-1 . && docker push $REPO:manual-1
```

Then set `image.tag: manual-1` in `values-dev.yaml` and push to this repository.

**Checks on this repository.** `.github/workflows/devops-project-ci.yml` runs on every pull
request and push that touches `devops-project/`: `terraform fmt` and `validate` for every
stack, `helm lint` and a schema check of the rendered chart, an Ansible syntax check of every
playbook for both environments, and a YAML lint. It never touches AWS or the cluster.

## Day-2 operations

**Release a new backend version.** Push to the backend repository's `main`: CI builds the image
and commits the new tag to `values-dev.yaml` (step 7). Argo CD syncs within about 3 minutes
(or press *Refresh* then *Sync* in the UI). To release by hand, push an image and set the tag
in `values-dev.yaml` yourself.

**Roll back.** `git revert <commit> && git push origin main`. (The UI's *Rollback* button is
disabled while auto-sync is on, and git stays the source of truth.)

**Change cluster state.** Edit files in git, not with `kubectl`: self-heal reverts manual
edits. For a temporary manual change, pause auto-sync on `backend-dev` in the UI first.

**Add an environment or app.** Add a `values-<env>.yaml`, copy `argocd/apps/backend-dev.yaml`
to a new file and change the name, values file and namespace (and add the namespace to the
`ecommerce` project's `destinations`). Argo CD picks it up from `argocd/apps/`.

**Change infrastructure.** For a value (size, CIDR, version, backup days, ...) edit the
environment's file in `ansible/inventories/<env>/group_vars/all/`; for structure edit the
Terraform. Push, run the plan job, read it, approve, and the apply job runs. A single stack can be run
on its own with `tf_services` (see above). Try changes in `dev` first.

**Upgrade versions.** Kubernetes: `cluster_version` in the environment's `eks.yml` (1.34
leaves standard support on 2 Dec 2026). Argo CD: `argocd_chart_version` in the same file.
Load balancer controller and External Secrets: `helm upgrade` with the new chart version
(CRDs are not upgraded by Helm; see each project's release notes).

## Tear down

Order matters: the ALB created for the Ingress holds network interfaces in the VPC, so it must
be gone before the VPC can be destroyed.

```bash
# 1. Remove the applications (deletes the Ingress and therefore the ALB)
kubectl -n argocd delete application root
kubectl -n ecommerce get ingress          # wait until empty
aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerName'   # ALB should be gone

# 2. Remove the add-ons and their IAM roles
helm -n kube-system uninstall aws-load-balancer-controller
eksctl delete iamserviceaccount --cluster $CLUSTER --region $AWS_REGION \
  --namespace kube-system --name aws-load-balancer-controller
# only if you did step 4A:
helm -n external-secrets uninstall external-secrets
eksctl delete iamserviceaccount --cluster $CLUSTER --region $AWS_REGION \
  --namespace external-secrets --name external-secrets

# 3. Destroy the infrastructure. In AWX run `dev: destroy` and type the environment name in the
#    survey. CLI equivalent:
ansible-playbook -i ansible/inventories/$ENV ansible/playbooks/99-destroy-infrastructure.yml -e destroy_confirmation=$ENV
```

The `ecr` stack is destroyed with the others. In `dev` it has `force_delete: true`, so the
repository goes even if it still holds images; `prod` keeps `false`, so empty it first.

The IAM policies you created by hand (`AWSLoadBalancerControllerIAMPolicy`,
`ExternalSecretsDbRead-<env>`) stay until you delete them with `aws iam delete-policy`.
What happens to the database is set per environment: `dev` has no final snapshot and no
deletion protection, so it is deleted at once; `prod` takes a final snapshot and has deletion
protection, so first set `deletion_protection: false` in `prod`'s `rds.yml`, apply, and only
then destroy.

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `plan` of `eks`/`rds` fails with "no matching VPC" or "expected at least 2 private subnets" | The `vpc` (or `eks`) stack has not been applied yet; apply in order. |
| Playbook stops with "No environment loaded" or "Missing input ... env_name" | You forgot `-i ansible/inventories/<env>`. |
| Playbook stops with "tf_action must be plan (default) or apply here" | The job template's extra variables hold another value. Use `{"tf_action": "plan"}` or `{"tf_action": "apply"}`. |
| The plan job of a **new** environment fails at `eks` | Expected the first time: the VPC does not exist yet. Run the apply template (see "A brand-new environment"). |
| Destroy stops with "Set destroy_confirmation to ..." | The survey answer (or `-e destroy_confirmation=`) is not exactly the environment name. |
| `terraform: command not found` in an AWX job | The execution environment has no Terraform >= 1.10. Use an execution environment that includes it. |
| Terraform says "No value for required variable X" | The variable is declared in `terraform/<stack>/variables.tf` but missing from the environment's `tf_vars_<stack>` (or `tf_vars_common`) in `ansible/inventories/<env>/group_vars/all/`. |
| Terraform warns "Value for undeclared variable" | A key in the environment's variables has no matching `variable` block in that stack; remove it or declare it. |
| Planning `prod` complains about the state bucket | The bucket in `tf_backend` does not exist or your AWS identity cannot reach it. |
| `kubectl` says unauthorized | You are using a different AWS identity than the one that created the cluster. Check `aws sts get-caller-identity`. |
| `backend-dev` shows *ComparisonError* "database.host is required" | `values-dev.yaml` still has an empty `database.host`, or the change is not pushed. |
| `backend-dev` shows "resource ... is not permitted in project ecommerce" | A new kind was added to the chart. Add it to `namespaceResourceWhitelist` in `argocd/apps/project-ecommerce.yaml`. |
| Sync error mentioning `ExternalSecret` / unknown kind | `externalSecret.enabled` is true but External Secrets Operator is not installed (step 4A). |
| Pods `CreateContainerConfigError`, secret `backend-db` not found | Step 4 not done, or the ExternalSecret is not ready: `kubectl -n ecommerce describe externalsecret`. |
| Pods `ImagePullBackOff` | Wrong `image.repository` / `image.tag` (does that tag exist in ECR?), or the repository is in another account/registry. For ECR also check the node role has `AmazonEC2ContainerRegistryReadOnly` (command in `ci/README.md`). |
| CI step "Configure AWS credentials" fails with "Not authorized to perform sts:AssumeRoleWithWebIdentity" | `github_oidc_subjects` in `ecr.yml` does not match the repository/branch running the workflow (it must read `repo:<owner>/<repo>:ref:refs/heads/main`), or the `ecr` stack was not applied after you changed it. |
| CI push fails with "tag invalid: The image tag ... already exists" | The ECR repository is immutable and that commit was already pushed. Re-run only the later jobs, or push a new commit. |
| CI cannot push to this repository ("Permission denied", protected branch) | `GITOPS_TOKEN` lacks *Contents: read and write* on this repository, or `main` is protected against it. |
| `ecr` plan fails with "no matching IAM OpenID Connect Provider" | `create_github_oidc_provider: false` but the account has none yet. Set it to `true` (only one environment per account should). |
| Creating the OIDC provider fails with "EntityAlreadyExists" | The account already has one: set `create_github_oidc_provider: false`. |
| `devops-project checks` fails at `terraform fmt` | Run `terraform fmt -recursive terraform/` and commit the result. |
| Pods crash-looping | `kubectl -n ecommerce logs <pod>`: usually a wrong DB host, a stale password or a missing Actuator dependency. |
| Ingress has no address | `kubectl -n kube-system logs deploy/aws-load-balancer-controller` (IAM/service account, or subnet tags). |
| ALB targets unhealthy | Pod not ready (`kubectl describe pod`), or the health-check path (`/actuator/health/readiness`) does not exist. |
| Application stuck *OutOfSync* after a push | Press *Refresh* in the UI; Argo CD polls git every ~3 minutes. |
| Destroy hangs on VPC or subnets | A load balancer or its network interfaces are still there; finish tear-down step 1. |

## Design decisions

- **Terraform is structure, Ansible is configuration.** One place per environment
  (`ansible/inventories/<env>/group_vars/all/`) answers "what is different in prod?", and the
  Terraform code is identical for every environment. Terraform variables have no defaults,
  and environment-name conditionals (`var.environment == "dev" ? ...`) were replaced by
  explicit variables (`single_nat_gateway`, `skip_final_snapshot`, `deletion_protection`, ...),
  so nothing about an environment is hidden in the code. The trade-off: you cannot run
  `terraform apply` by hand in a stack folder without a var file, and Ansible is now required.
  The `environment` variable that Terraform still receives is only a label for names and tags.
- **No cross-stack remote state.** A Terraform state file holds every attribute of every
  resource in the stack, so letting one pipeline read another stack's state would widen its
  access well beyond the few IDs it needs. Stacks look each other up through the AWS API
  with tag filters instead, so a stack's role needs only its own state key plus read-only
  `ec2:Describe*`. The tags are the contract between stacks and are marked "LOOKUP CONTRACT"
  in `terraform/vpc/main.tf` and `terraform/eks/main.tf`; renaming one means changing the
  matching `data.tf` in `eks` and `rds`. Ordering is not visible to Terraform, so the
  playbook provides it (`vpc` -> `eks` -> `rds`).
- **Plan job, approval, apply job.** Changing infrastructure is two jobs with a human approval
  between them, so nothing changes without someone having read the plan. The apply job plans
  again rather than replaying a stored plan: that avoids a plan file (it contains every
  variable value and would need private shared storage between AWX's throwaway job
  containers), at the cost that the applied plan is not guaranteed identical to the approved
  one if something changed in between. Terraform's own state lock still prevents concurrent
  runs. Both jobs use the project's current revision, so do not push between approval and apply.
- **Ordering lives in the playbook.** `vars/stacks.yml` holds the order and the playbook loops
  over it, so the operator never lists stacks.
- **The node IAM role is defined here, not left to a module default.** `terraform/eks/iam.tf`
  creates the role the worker nodes assume and attaches exactly three AWS-managed policies
  (worker node, CNI, ECR read-only). Pods do not get these permissions for their own AWS
  calls; those use IRSA service accounts. Changing the role of an **existing** node group makes
  Terraform replace the node group (the pods are rescheduled), so plan this for a quiet moment;
  on a new environment it makes no difference.
- **ECR rather than Docker Hub.** The nodes already authenticate to ECR with their IAM role, so
  there is no pull secret to create or rotate, private repositories are free, and there is no
  anonymous pull rate limit (dev's single NAT gateway makes all nodes look like one client to
  Docker Hub). Tags are immutable, images are scanned on push, and old images expire by a
  lifecycle rule. CI authenticates with OIDC instead of stored keys, and the role may only push
  to this one repository.
- **CI commits the image tag to git.** The tag in `values-dev.yaml` is the single record of what
  runs in dev, so a rollback is a `git revert`. CI only writes to the devops repository with a
  token limited to it; AWS access is never shared between the repositories.
- **No password in the repo.** RDS generates and rotates the master password and keeps it in
  Secrets Manager. It reaches the pods through a Kubernetes Secret (External Secrets
  Operator), never through git or Terraform variables.
- **Least-privilege network.** RDS accepts connections only from the EKS node security
  group. The Argo CD UI is a ClusterIP service reached by port-forward, and Actuator is not
  routed through the ALB.
- **Add-ons by hand, workloads by Argo CD.** The load balancer controller and External
  Secrets Operator need account-specific IAM roles, so they are a one-time manual step.
  Everything application-related is deployed by Argo CD from git.
- **Argo CD itself is managed by Terraform**, which avoids Argo CD managing its own
  installation. Upgrade it through `argocd_chart_version` in the environment's `eks.yml`.
- **Backend is public over HTTP for now.** The ALB serves plain HTTP on its own DNS name.

## What's next

1. **Frontend CI:** build the React app and deploy it to S3 + CloudFront from GitHub Actions
   (same OIDC pattern as the backend, with a role limited to the bucket and distribution).
2. **Monitoring:** Prometheus and Grafana (for example `kube-prometheus-stack`, deployed as
   another Argo CD application), with Spring Boot metrics from Actuator.
3. **HTTPS and a domain:** a Route 53 record and an ACM certificate for the ALB (annotations
   are prepared in `values.yaml`), CORS for the frontend origin.
4. **Prod:** review the starting values in `ansible/inventories/prod`, give it its own AWS
   account/profile and state bucket, then add `values-prod.yaml` and a `backend-prod`
   Argo CD application (see Day-2 operations).
