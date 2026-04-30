# Wild-west Postgres provisioning. Each team copy-pastes this module,
# tweaks it, and applies it from a laptop or a CI runner the platform team
# does not own. State lives wherever the team decided — sometimes S3,
# sometimes local, sometimes nowhere.
#
# This is on purpose. Tier 3 replaces this with a Crossplane XRD claim that
# the platform team owns; tier 2 exists to demonstrate the pain that
# motivates that move.

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }

  # NO BACKEND DECLARED — this is the wild-west outcome. Every team picks
  # their own state location (or none). Local state lands in
  # terraform.tfstate next to this file with the DB password in plaintext.
  # See README's "What's wrong with this picture" section.
  #
  # The shape a tier-3+ team would actually use:
  # backend "s3" {
  #   bucket         = "<your-org>-tfstate-prod"
  #   key            = "guestbook/postgres/${var.env}.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "<your-org>-tfstate-locks"
  #   encrypt        = true
  #   kms_key_id     = "<kms-key-arn>"
  # }
}

provider "aws" {
  region = var.region

  # LocalStack-friendly defaults so a reviewer without real cloud creds can
  # still `terraform apply`. Override these in real environments.
  access_key                  = var.localstack_endpoint != "" ? "test" : null
  secret_key                  = var.localstack_endpoint != "" ? "test" : null
  skip_credentials_validation = var.localstack_endpoint != "" ? true : false
  skip_metadata_api_check     = var.localstack_endpoint != "" ? true : false
  skip_requesting_account_id  = var.localstack_endpoint != "" ? true : false

  dynamic "endpoints" {
    for_each = var.localstack_endpoint != "" ? [1] : []
    content {
      rds = var.localstack_endpoint
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig
}

resource "random_password" "postgres" {
  length  = 24
  special = false
}

resource "aws_db_instance" "guestbook" {
  identifier             = "guestbook-${var.env}"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = var.instance_class
  allocated_storage      = var.allocated_storage
  db_name                = "guestbook"
  username               = "guestbook"
  password               = random_password.postgres.result
  skip_final_snapshot    = true
  publicly_accessible    = false
  storage_encrypted      = true
  vpc_security_group_ids = var.security_group_ids
  db_subnet_group_name   = var.db_subnet_group_name

  tags = {
    env       = var.env
    app       = "guestbook"
    managedBy = "terraform-wild-west"
  }
}

# The Secret the chart's deployment.envFrom references. Created in the
# guestbook namespace by this module — completely outside Argo CD's view.
resource "kubernetes_secret" "postgres" {
  metadata {
    name      = var.secret_name
    namespace = var.namespace
  }

  data = {
    DATABASE_HOST     = aws_db_instance.guestbook.address
    DATABASE_PORT     = tostring(aws_db_instance.guestbook.port)
    DATABASE_NAME     = aws_db_instance.guestbook.db_name
    DATABASE_USER     = aws_db_instance.guestbook.username
    DATABASE_PASSWORD = random_password.postgres.result
  }

  type = "Opaque"
}
