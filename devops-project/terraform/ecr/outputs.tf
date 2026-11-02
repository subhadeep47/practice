output "repository_url" {
  value       = aws_ecr_repository.backend.repository_url
  description = "Image repository: <account>.dkr.ecr.<region>.amazonaws.com/<name>. Goes into image.repository in helm values-<env>.yaml"
}

output "repository_arn" {
  value       = aws_ecr_repository.backend.arn
  description = "ARN of the backend repository"
}

output "ci_push_role_arn" {
  value       = aws_iam_role.github_ci_push.arn
  description = "Role GitHub Actions assumes to push images (store it as the AWS_ROLE_ARN variable in the backend repo)"
}
