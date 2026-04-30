# Wild-west Postgres module

Provisions an RDS Postgres instance and writes a Kubernetes Secret carrying the connection details into the app's namespace. The Helm chart in [`../../charts/guestbook/`](../../charts/guestbook/) reads the Secret via `envFrom` on the deployment.

**This module is intentionally NOT GitOps-managed.** Argo CD does not see it. Kargo does not promote it. There is no drift detection. That is the whole point of tier 2 — to demonstrate why it's a problem.

## Apply (LocalStack, for review)

```bash
cd 2-terraform+helm/terraform/postgres
terraform init
terraform apply \
  -var env=dev \
  -var namespace=guestbook-dev \
  -var secret_name=guestbook-postgres-dev \
  -var localstack_endpoint=http://localhost:4566
```

Repeat per environment. There is no orchestration that says "if dev is up, also bring up staging" — because each team runs this on their own laptop.

## Apply (real AWS)

Drop `localstack_endpoint`, supply real `security_group_ids` and `db_subnet_group_name`, and configure your AWS credentials however you normally do. There's no enforcement that you do any of this consistently.

## What's wrong with this picture

- **The DB password is plaintext in two places.** `random_password.postgres` generates a 24-character secret; that secret lands in (a) `terraform.tfstate` wherever it ends up, and (b) a `kubernetes_secret` of type `Opaque` written into the app namespace. Anyone with `get secret` on the namespace gets prod creds; anyone with read on the tfstate location gets the same.
- **State location is unknowable.** This module does not declare a backend (`main.tf` carries a commented-out S3 example). Whoever runs it picks one — or accepts local state and loses it. The included `terraform/.gitignore` blocks the most common accidental commit (`terraform.tfstate*`) but does nothing about a developer's `~/Documents` folder leaking via backup software.
- **No review gate.** Anyone with the AWS creds and kubeconfig can `terraform apply` straight to prod.
- **Drift is silent.** A console click in the AWS UI changes the live DB; the next `terraform apply` quietly reverts it (or, worse, doesn't, because the team never re-runs it).
- **No standards.** Want Postgres 16? db.t4g.micro? Encryption at rest? You're hoping each team picked the same defaults. They didn't.
- **No rotation path.** `random_password.postgres` regenerates only on `taint` or `replace`. There is no scheduled rotation; the password lives forever until someone notices.
- **Composition with the app deployment is a wish.** The Secret name is conventionally `guestbook-postgres-<env>`, but nothing enforces it. If the Terraform output and the Helm `database.secretName` ever drift, the deployment crashes with no clear error pointing at the cause.

Tier 3 fixes all of these by handing the abstraction to the platform team as a Crossplane XRD. App teams file claims; the XRD enforces standards; the connection Secret is mediated by ESO with a documented rotation; everything is reconciled in git.
