variable "aws_region" {
  type        = string
  description = "Region passed from Ansible env"
}

variable "secret_name" {
  type        = string
  description = "Name of the secret passed from Ansible env"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Plaintext password decrypted in-memory by Ansible"
}
