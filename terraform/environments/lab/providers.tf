provider "proxmox" {
  # Authentication is read from environment variables:
  # PROXMOX_VE_ENDPOINT
  # PROXMOX_VE_API_TOKEN
  insecure = var.proxmox_insecure

  # Required when importing non-import type disk images via file_id.
  ssh {
    agent       = var.proxmox_ssh_agent
    username    = var.proxmox_ssh_username
    private_key = var.proxmox_ssh_private_key_path == null ? null : file(pathexpand(var.proxmox_ssh_private_key_path))

    node {
      name    = var.proxmox_node_name
      address = var.proxmox_ssh_node_address
      port    = var.proxmox_ssh_node_port
    }
  }
}
