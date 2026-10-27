# terraform_runner

Runs Terraform for a single stack under `devops-project/terraform/<tf_service>`:
`terraform init` (S3 remote backend) followed by `plan`, `apply` or `destroy`.

## Requirements

- `terraform` >= 1.10 on the machine running Ansible
- AWS credentials in the environment (profile, SSO or env vars)
- The S3 state bucket referenced in `environments/<env>.backend.hcl` must already exist

## Variables

| Variable      | Default                      | Description                                            |
|---------------|------------------------------|--------------------------------------------------------|
| `tf_service`  | (required)                   | Stack folder: `vpc`, `eks`, `rds`, `s3-cloudfront`     |
| `target_env`  | `dev`                        | Selects `environments/<env>.tfvars` and `.backend.hcl` |
| `tf_action`   | `apply`                      | `plan`, `apply` or `destroy`                           |
| `tf_bin`      | `terraform`                  | Terraform executable                                   |
| `tf_root`     | `<playbook_dir>/../../terraform` | Folder containing the stacks                       |

## Example

```yaml
- ansible.builtin.include_role:
    name: terraform_runner
  vars:
    tf_service: vpc
    tf_action: plan
```

## License

MIT
