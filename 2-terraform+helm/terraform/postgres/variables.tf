variable "env" {
  type        = string
  description = "Environment name (dev, staging, prod). Becomes the DB instance suffix."
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace where the connection Secret is created."
}

variable "secret_name" {
  type        = string
  description = "Name of the Kubernetes Secret carrying DATABASE_* env vars for the app."
  default     = "guestbook-postgres"
}

variable "region" {
  type        = string
  description = "AWS region."
  default     = "us-east-1"
}

variable "instance_class" {
  type        = string
  description = "RDS instance class."
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  type        = number
  description = "Allocated storage in GiB."
  default     = 20
}

variable "security_group_ids" {
  type        = list(string)
  description = "Existing security groups to attach to the DB instance."
  default     = []
}

variable "db_subnet_group_name" {
  type        = string
  description = "Existing DB subnet group name."
  default     = null
}

variable "kubeconfig" {
  type        = string
  description = "Path to a kubeconfig file with permission to create Secrets in var.namespace."
  default     = "~/.kube/config"
}

variable "localstack_endpoint" {
  type        = string
  description = "If set, point the AWS provider at this LocalStack RDS endpoint (e.g. http://localhost:4566)."
  default     = ""
}
