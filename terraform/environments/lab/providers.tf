provider "proxmox" {
  # Authentication is read from environment variables:
  # PROXMOX_VE_ENDPOINT
  # PROXMOX_VE_API_TOKEN
  insecure = var.proxmox_insecure
}
