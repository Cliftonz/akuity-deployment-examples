output "endpoint" {
  description = "RDS endpoint hostname:port."
  value       = "${aws_db_instance.guestbook.address}:${aws_db_instance.guestbook.port}"
}

output "secret_name" {
  description = "Kubernetes Secret name created in var.namespace."
  value       = kubernetes_secret.postgres.metadata[0].name
}

output "secret_namespace" {
  description = "Kubernetes namespace the Secret was created in."
  value       = kubernetes_secret.postgres.metadata[0].namespace
}
