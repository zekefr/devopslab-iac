# Terraform Lab Environment

Detailed Terraform documentation is centralized in:

- `docs/20-terraform.md`

Use repository wrappers from root:

```bash
make tf-init
make tf-validate
make tf-plan
make tf-apply
```

This environment instantiates the reusable module:

- `terraform/modules/talos-proxmox-cluster`

Local configuration files in this directory are operator-specific:

- `.env` / `.envrc`
- `terraform.tfvars`

Do not commit them.
