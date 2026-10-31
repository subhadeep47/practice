# terraform_runner

Runs Terraform for a single stack under `devops-project/terraform/<tf_service>` using the
values of the environment inventory that is loaded (`-i ansible/inventories/<env>`).

For one stack and one environment it:

1. builds the stack's variables: `tf_vars_common` merged with `tf_vars_<stack>`,
2. writes them to a temporary `*.json` var file (mode 0600, removed afterwards),
3. runs `terraform init -reconfigure` with `-backend-config=...` flags built from `tf_backend`,
   so every environment and stack has its own state file,
4. runs the action:
   - `plan`: `terraform plan -detailed-exitcode -var-file=<that file>`. Nothing in AWS changes.
     **Default.** Exit code 2 ("changes pending") counts as success.
   - `apply`: `terraform apply -auto-approve -var-file=<that file>`. It plans again and applies;
     put a human approval between a plan job and an apply job (see the project README).
   - `destroy`: `terraform destroy -auto-approve -var-file=<that file>` (the destroy playbook
     requires `destroy_confirmation` to equal the environment name).
   - `output`: `terraform output`.

The Terraform code itself contains no environment-specific values.

## Requirements

- `terraform` >= 1.10 on the machine running Ansible
- AWS credentials in the environment (profile, SSO or env vars)
- The S3 state bucket named in `tf_backend.bucket` must already exist

## Variables the environment inventory must define

| Variable | Meaning |
|---|---|
| `env_name` | Environment name (`dev`, `prod`); used in the state key and the messages |
| `tf_backend` | `bucket`, `region`, `key_prefix`, optional `encrypt` and `use_lockfile` (default `true`) |
| `tf_vars_common` | Values every stack receives (`environment`, `project`, `aws_region`) |
| `tf_vars_<stack>` | The stack's own values; `-` becomes `_` (`s3-cloudfront` -> `tf_vars_s3_cloudfront`) |

The state key is `<tf_backend.key_prefix>/<stack>/terraform.tfstate`.

## Variables of the role

| Variable | Default | Description |
|---|---|---|
| `tf_service` | (required) | Stack folder: `vpc`, `eks`, `rds`, `s3-cloudfront` |
| `tf_action` | `plan` | `plan` (default, changes nothing), `apply`, `destroy` or `output` |
| `tf_bin` | `terraform` | Terraform executable |
| `tf_root` | `<playbook_dir>/../../terraform` | Folder containing the stacks |
| `tf_process_env` | `{}` | Extra environment variables for the process, e.g. `AWS_PROFILE` |

## Example

```yaml
- ansible.builtin.include_role:
    name: terraform_runner
  vars:
    tf_service: vpc
    tf_action: plan
```

Run it with an environment inventory so the variables above exist: the AWX inventory sourced
from `ansible/inventories/<env>`, or `-i ansible/inventories/<env>` on the command line.

## License

MIT
