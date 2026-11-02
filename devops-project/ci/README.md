# CI templates

The application code lives in its own repositories, so its pipelines live there too. The files
here are ready to copy; the infrastructure they need (registry, push role) is created by this
project's `ecr` Terraform stack.

| Template | Copy to | What it does |
|---|---|---|
| `backend/build-and-deploy.yml` | backend repo: `.github/workflows/` | test, build image, push to ECR, commit the new tag to `values-dev.yaml` here |
| `backend/Dockerfile.example` | backend repo root as `Dockerfile` | image that fits the Helm chart (non-root, port 8080) |

Validation of this repository itself (Terraform, Helm, Ansible, YAML) is
`.github/workflows/devops-project-ci.yml` at the repository root.

## One-time setup for the backend pipeline

1. **Create the registry and the push role.** Edit `github_oidc_subjects` in
   `ansible/inventories/dev/group_vars/all/ecr.yml` so it names your backend repository
   (`repo:<owner>/<backend-repo>:ref:refs/heads/main`), push, then run the plan and apply jobs
   (the `ecr` stack is part of `01-provision-infrastructure.yml`). Read `repository_url` and
   `ci_push_role_arn` from the outputs job.
2. **Point the chart at the registry.** Set `image.repository` in
   `helm/spring-boot-backend/values-dev.yaml` to `repository_url`. Leave `image.tag` empty; CI
   fills it.
3. **Backend repository settings** (Settings > Secrets and variables > Actions):

   | Kind | Name | Value |
   |---|---|---|
   | Variable | `AWS_ROLE_ARN` | `ci_push_role_arn` |
   | Variable | `AWS_REGION` | the region of the ECR repository, e.g. `us-east-1` |
   | Variable | `ECR_REPOSITORY` | the repository name, e.g. `fullstack-app/backend-dev` |
   | Variable | `GITOPS_REPO` | this repository, `subhadeep47/practice` |
   | Secret | `GITOPS_TOKEN` | a fine-grained personal access token limited to **this** repository with *Contents: read and write* |

   (`GITOPS_TOKEN` is needed because the built-in token of the backend repository cannot push
   to a different repository.) If `main` here is protected, allow this token's owner to push,
   or change the last step to open a pull request.
4. Push to the backend repository's `main`. The workflow tests, pushes the image, and commits
   the tag; Argo CD deploys it within about 3 minutes.

## How the nodes pull the image

Nothing to configure. The EKS worker nodes pull from ECR with their node IAM role, so there is
no image pull secret. To check on your cluster:

```bash
ROLE=$(aws eks describe-nodegroup --cluster-name app-cluster-dev --nodegroup-name <name> \
  --query nodegroup.nodeRole --output text | awk -F/ '{print $NF}')
aws iam list-attached-role-policies --role-name "$ROLE" | grep ContainerRegistryReadOnly
```
