variable "proxmox_insecure" {
  description = "Allow insecure TLS when connecting to Proxmox VE API."
  type        = bool
  default     = false
}

variable "proxmox_node_name" {
  description = "Target Proxmox node name."
  type        = string
  default     = "pve"

  validation {
    condition     = trimspace(var.proxmox_node_name) != ""
    error_message = "proxmox_node_name cannot be empty."
  }
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

  validation {
    condition     = var.proxmox_network_vlan_id == null || (var.proxmox_network_vlan_id >= 1 && var.proxmox_network_vlan_id <= 4094)
    error_message = "proxmox_network_vlan_id must be null or between 1 and 4094."
  }
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

  validation {
    condition     = var.proxmox_ssh_agent || (var.proxmox_ssh_private_key_path != null && trimspace(var.proxmox_ssh_private_key_path) != "")
    error_message = "Set proxmox_ssh_private_key_path when proxmox_ssh_agent is false."
  }
}

variable "proxmox_ssh_username" {
  description = "SSH username for Proxmox node operations."
  type        = string
  default     = "root"

  validation {
    condition     = trimspace(var.proxmox_ssh_username) != ""
    error_message = "proxmox_ssh_username cannot be empty."
  }
}

variable "proxmox_ssh_node_address" {
  description = "SSH address of the Proxmox node."
  type        = string
  default     = "pve"

  validation {
    condition     = trimspace(var.proxmox_ssh_node_address) != ""
    error_message = "proxmox_ssh_node_address cannot be empty."
  }
}

variable "proxmox_ssh_node_port" {
  description = "SSH port of the Proxmox node."
  type        = number
  default     = 22

  validation {
    condition     = var.proxmox_ssh_node_port >= 1 && var.proxmox_ssh_node_port <= 65535
    error_message = "proxmox_ssh_node_port must be between 1 and 65535."
  }
}

variable "talos_version" {
  description = "Talos version tag to download."
  type        = string
  default     = "v1.12.4"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+([-.][0-9A-Za-z.]+)?$", var.talos_version))
    error_message = "talos_version must be a tag like v1.12.4."
  }
}

variable "talos_arch" {
  description = "Talos image architecture."
  type        = string
  default     = "amd64"

  validation {
    condition     = contains(["amd64", "arm64"], var.talos_arch)
    error_message = "talos_arch must be 'amd64' or 'arm64'."
  }
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

  validation {
    condition     = var.talos_template_vmid >= 100 && var.talos_template_vmid <= 999999999
    error_message = "talos_template_vmid must be between 100 and 999999999."
  }
}

variable "talos_template_cpu_cores" {
  description = "CPU cores assigned to the Talos template."
  type        = number
  default     = 2

  validation {
    condition     = var.talos_template_cpu_cores >= 1
    error_message = "talos_template_cpu_cores must be >= 1."
  }
}

variable "talos_template_memory_mb" {
  description = "Memory assigned to the Talos template (MB)."
  type        = number
  default     = 4096

  validation {
    condition     = var.talos_template_memory_mb >= 1024
    error_message = "talos_template_memory_mb must be >= 1024."
  }
}

variable "talos_template_disk_size_gb" {
  description = "Disk size assigned to the Talos template (GB)."
  type        = number
  default     = 20

  validation {
    condition     = var.talos_template_disk_size_gb >= 10
    error_message = "talos_template_disk_size_gb must be >= 10."
  }
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
    condition     = alltrue([for name in keys(var.k8s_nodes) : can(regex("^[a-z0-9-]+$", name))])
    error_message = "Each k8s_nodes key must match ^[a-z0-9-]+$."
  }

  validation {
    condition     = alltrue([for node in values(var.k8s_nodes) : can(cidrhost("${node.ip}/32", 0))])
    error_message = "Each k8s_nodes.ip must be a valid IPv4 address."
  }

  validation {
    condition     = alltrue([for node in values(var.k8s_nodes) : node.vm_id >= 100 && node.vm_id <= 999999999])
    error_message = "Each k8s_nodes.vm_id must be between 100 and 999999999."
  }

  validation {
    condition     = length(distinct([for node in values(var.k8s_nodes) : node.vm_id])) == length(var.k8s_nodes)
    error_message = "Each k8s_nodes.vm_id must be unique."
  }

  validation {
    condition     = length(distinct([for node in values(var.k8s_nodes) : node.ip])) == length(var.k8s_nodes)
    error_message = "Each k8s_nodes.ip must be unique."
  }

  validation {
    condition     = alltrue([for node in values(var.k8s_nodes) : can(regex("^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$", node.mac_address))])
    error_message = "Each k8s_nodes.mac_address must be a valid MAC address (format XX:XX:XX:XX:XX:XX)."
  }

  validation {
    condition     = length(distinct([for node in values(var.k8s_nodes) : lower(node.mac_address)])) == length(var.k8s_nodes)
    error_message = "Each k8s_nodes.mac_address must be unique."
  }
}

variable "k8s_control_plane_cpu_cores" {
  description = "CPU cores for control plane nodes."
  type        = number
  default     = 2

  validation {
    condition     = var.k8s_control_plane_cpu_cores >= 1
    error_message = "k8s_control_plane_cpu_cores must be >= 1."
  }
}

variable "k8s_control_plane_memory_mb" {
  description = "Memory (MB) for control plane nodes."
  type        = number
  default     = 6144

  validation {
    condition     = var.k8s_control_plane_memory_mb >= 2048
    error_message = "k8s_control_plane_memory_mb must be >= 2048."
  }
}

variable "k8s_worker_cpu_cores" {
  description = "CPU cores for worker nodes."
  type        = number
  default     = 4

  validation {
    condition     = var.k8s_worker_cpu_cores >= 1
    error_message = "k8s_worker_cpu_cores must be >= 1."
  }
}

variable "k8s_worker_memory_mb" {
  description = "Memory (MB) for worker nodes."
  type        = number
  default     = 16384

  validation {
    condition     = var.k8s_worker_memory_mb >= 2048
    error_message = "k8s_worker_memory_mb must be >= 2048."
  }
}

variable "k8s_cluster_name" {
  description = "Talos/Kubernetes cluster name."
  type        = string
  default     = "homelab-k8s"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.k8s_cluster_name))
    error_message = "k8s_cluster_name must match ^[a-z0-9-]+$."
  }
}

variable "k8s_cluster_endpoint" {
  description = "Talos/Kubernetes API endpoint IP or VIP."
  type        = string
  default     = "192.168.1.201"

  validation {
    condition = (
      can(cidrhost("${var.k8s_cluster_endpoint}/32", 0)) ||
      can(regex("^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$", var.k8s_cluster_endpoint))
    )
    error_message = "k8s_cluster_endpoint must be a valid IPv4 address or DNS hostname."
  }
}

variable "k8s_gateway_ipv4" {
  description = "Planned IPv4 gateway for Kubernetes nodes."
  type        = string
  default     = "192.168.1.254"

  validation {
    condition     = can(cidrhost("${var.k8s_gateway_ipv4}/32", 0))
    error_message = "k8s_gateway_ipv4 must be a valid IPv4 address."
  }
}

variable "k8s_dns_servers" {
  description = "Planned DNS servers for Kubernetes nodes."
  type        = list(string)
  default     = ["8.8.8.8"]

  validation {
    condition     = length(var.k8s_dns_servers) > 0
    error_message = "k8s_dns_servers cannot be empty."
  }

  validation {
    condition     = alltrue([for dns in var.k8s_dns_servers : can(cidrhost("${dns}/32", 0))])
    error_message = "Each entry in k8s_dns_servers must be a valid IPv4 address."
  }
}
