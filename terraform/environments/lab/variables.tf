variable "proxmox_insecure" {
  description = "Allow insecure TLS when connecting to Proxmox VE API."
  type        = bool
  default     = false
}

variable "proxmox_node_name" {
  description = "Target Proxmox node name."
  type        = string
  default     = "pve"
}

variable "proxmox_image_datastore_id" {
  description = "Datastore used to store the downloaded Talos image file."
  type        = string
  default     = "local"
}

variable "proxmox_vm_disk_datastore_id" {
  description = "Datastore used for the template VM disk."
  type        = string
  default     = "local-lvm"
}

variable "proxmox_network_bridge" {
  description = "Proxmox bridge used by the template network interface."
  type        = string
  default     = "vmbr0"
}

variable "proxmox_network_vlan_id" {
  description = "Optional VLAN ID for the template network interface."
  type        = number
  default     = null
}

variable "proxmox_ssh_agent" {
  description = "Use SSH agent for Proxmox SSH operations."
  type        = bool
  default     = true
}

variable "proxmox_ssh_private_key_path" {
  description = "Optional path to an unencrypted private key used for Proxmox SSH operations."
  type        = string
  default     = null
}

variable "proxmox_ssh_username" {
  description = "SSH username for Proxmox node operations."
  type        = string
  default     = "root"
}

variable "proxmox_ssh_node_address" {
  description = "SSH address of the Proxmox node."
  type        = string
  default     = "pve"
}

variable "proxmox_ssh_node_port" {
  description = "SSH port of the Proxmox node."
  type        = number
  default     = 22
}

variable "talos_version" {
  description = "Talos version tag to download."
  type        = string
  default     = "v1.12.4"
}

variable "talos_arch" {
  description = "Talos image architecture."
  type        = string
  default     = "amd64"
}

variable "talos_image_content_type" {
  description = "Proxmox content type used for the downloaded Talos image."
  type        = string
  default     = "iso"

  validation {
    condition     = var.talos_image_content_type == "iso"
    error_message = "talos_image_content_type must be 'iso' for compressed Talos raw.zst downloads."
  }
}

variable "talos_template_name" {
  description = "Proxmox VM template name."
  type        = string
  default     = "talos-1.12.4-amd64-template"
}

variable "talos_template_vmid" {
  description = "Reserved VMID for the Talos template."
  type        = number
  default     = 9000
}

variable "talos_template_cpu_cores" {
  description = "CPU cores assigned to the Talos template."
  type        = number
  default     = 2
}

variable "talos_template_memory_mb" {
  description = "Memory assigned to the Talos template (MB)."
  type        = number
  default     = 4096
}

variable "talos_template_disk_size_gb" {
  description = "Disk size assigned to the Talos template (GB)."
  type        = number
  default     = 20
}

variable "talos_template_tags" {
  description = "Tags applied to the Talos template VM."
  type        = list(string)
  default     = ["lab", "talos", "template"]
}

variable "k8s_nodes" {
  description = "Kubernetes node definitions keyed by VM name."
  type = map(object({
    role        = string
    ip          = string
    vm_id       = number
    mac_address = string
  }))

  validation {
    condition     = alltrue([for node in values(var.k8s_nodes) : contains(["control-plane", "worker"], node.role)])
    error_message = "Each k8s_nodes.role must be either 'control-plane' or 'worker'."
  }

  validation {
    condition     = alltrue([for node in values(var.k8s_nodes) : can(regex("^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$", node.mac_address))])
    error_message = "Each k8s_nodes.mac_address must be a valid MAC address (format XX:XX:XX:XX:XX:XX)."
  }
}

variable "k8s_control_plane_cpu_cores" {
  description = "CPU cores for control plane nodes."
  type        = number
  default     = 2
}

variable "k8s_control_plane_memory_mb" {
  description = "Memory (MB) for control plane nodes."
  type        = number
  default     = 6144
}

variable "k8s_worker_cpu_cores" {
  description = "CPU cores for worker nodes."
  type        = number
  default     = 4
}

variable "k8s_worker_memory_mb" {
  description = "Memory (MB) for worker nodes."
  type        = number
  default     = 16384
}

variable "k8s_gateway_ipv4" {
  description = "Planned IPv4 gateway for Kubernetes nodes."
  type        = string
  default     = "192.168.1.254"
}

variable "k8s_dns_servers" {
  description = "Planned DNS servers for Kubernetes nodes."
  type        = list(string)
  default     = ["8.8.8.8"]
}
