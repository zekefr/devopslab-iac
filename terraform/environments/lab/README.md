# Terraform lab environment

This folder contains the first Terraform building block for Proxmox:

- provider declaration (`bpg/proxmox`)
- API authentication via environment variables
- Talos image download (`v1.12.4` by default)
- Talos base VM template creation

The current scope creates a single Talos template VM.

## Recommended auth setup (`.env` + `direnv`)

1. Install and enable `direnv` for your shell:

```bash
# bash (~/.bashrc)
eval "$(direnv hook bash)"

# zsh (~/.zshrc)
eval "$(direnv hook zsh)"

# fish (~/.config/fish/config.fish)
direnv hook fish | source
```

2. Create local files from examples:

```bash
cd terraform/environments/lab
cp .env.example .env
cp .envrc.example .envrc
```

3. Edit `.env` with your real values.

4. Allow `direnv` in this directory:

```bash
direnv allow
```

5. Validate provider wiring:

```bash
terraform init
terraform validate
terraform plan
```

Do not commit `.env` or `.envrc` (they are ignored).

From repository root, you can run:

```bash
make tf-init
make tf-validate
make tf-plan
```

These `make tf-*` targets use `direnv exec terraform/environments/lab ...` so Proxmox environment variables are loaded automatically.

or:

```bash
mise run tf-init
mise run tf-validate
mise run tf-plan
```

To create the Talos template:

```bash
terraform apply
```

or from repo root:

```bash
make tf-plan
terraform -chdir=terraform/environments/lab apply
```

## Variable overrides

Use a local `terraform.tfvars` file based on `terraform.tfvars.example`:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Common values in this lab:

- `proxmox_node_name = "pve"`
- `proxmox_image_datastore_id = "local"`
- `proxmox_vm_disk_datastore_id = "local-lvm"`
- `proxmox_network_bridge = "vmbr0"`
- `talos_template_vmid = 9000`
- `proxmox_ssh_username = "root"`
- `proxmox_ssh_node_address = "<pve-ip-or-fqdn>"`
- `proxmox_ssh_agent = false`
- `proxmox_ssh_private_key_path = "~/.ssh/id_ed25519"`

`talos_image_content_type` is `iso` for Talos compressed images (`raw.zst`).
This workflow uses `disk.file_id` and requires SSH access to the Proxmox node from the Terraform runner.
If your SSH agent is not loaded, disable agent and provide `proxmox_ssh_private_key_path`.
`overwrite` is disabled for the downloaded image because Proxmox reports decompressed file size in datastore, which differs from URL size for compressed artifacts.

## Temporary fallback (manual `fish` export)

If `direnv` is not available, export variables in the current session:

```fish
set -x PROXMOX_VE_ENDPOINT "https://pve.example.lan:8006/"
set -x PROXMOX_VE_API_TOKEN "terraform@pve!iac=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
set -x TF_VAR_proxmox_insecure true
```
