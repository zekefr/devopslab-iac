# Terraform lab environment

This folder contains the first Terraform building block for Proxmox:

- provider declaration (`bpg/proxmox`)
- API authentication via environment variables

No VM resources are defined yet.

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
```

Do not commit `.env` or `.envrc` (they are ignored).

From repository root, you can run:

```bash
make tf-init
make tf-validate
make tf-plan
```

or:

```bash
mise run tf-init
mise run tf-validate
mise run tf-plan
```

## Temporary fallback (manual `fish` export)

If `direnv` is not available, export variables in the current session:

```fish
set -x PROXMOX_VE_ENDPOINT "https://pve.example.lan:8006/"
set -x PROXMOX_VE_API_TOKEN "terraform@pve!iac=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
set -x TF_VAR_proxmox_insecure true
```
