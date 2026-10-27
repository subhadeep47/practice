output "s3_bucket_name" {
  value       = aws_s3_bucket.react_frontend.id
  description = "Name of the S3 bucket hosting the React build"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.s3_distribution.domain_name
  description = "CloudFront URL to access the React application"
}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.s3_distribution.id
  description = "Distribution ID, needed to invalidate the cache after a frontend deploy"
}
