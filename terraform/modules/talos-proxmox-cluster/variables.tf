variable "proxmox_node_name" {
  description = "Target Proxmox node name."
  type        = string
}

variable "proxmox_image_datastore_id" {
  description = "Datastore used to store the downloaded Talos image file."
  type        = string
}

variable "proxmox_vm_disk_datastore_id" {
  description = "Datastore used for template and cloned VM disks."
  type        = string
}

variable "proxmox_network_bridge" {
  description = "Proxmox bridge used by VM network interfaces."
  type        = string
}

variable "proxmox_network_vlan_id" {
  description = "Optional VLAN ID for VM network interfaces."
  type        = number
  default     = null
}

variable "talos_version" {
  description = "Talos version tag to download."
  type        = string
}

variable "talos_arch" {
  description = "Talos image architecture."
  type        = string
}

variable "talos_image_content_type" {
  description = "Proxmox content type used for the downloaded Talos image."
  type        = string
}

variable "talos_template_name" {
  description = "Proxmox VM template name."
  type        = string
}

variable "talos_template_vmid" {
  description = "Reserved VMID for the Talos template."
  type        = number
}

variable "talos_template_cpu_cores" {
  description = "CPU cores assigned to the Talos template."
  type        = number
}

variable "talos_template_memory_mb" {
  description = "Memory assigned to the Talos template (MB)."
  type        = number
}

variable "talos_template_disk_size_gb" {
  description = "Disk size assigned to the Talos template (GB)."
  type        = number
}

variable "talos_template_tags" {
  description = "Tags applied to the Talos template VM."
  type        = list(string)
}

variable "k8s_nodes" {
  description = "Kubernetes node definitions keyed by VM name."
  type = map(object({
    role        = string
    ip          = string
    vm_id       = number
    mac_address = string
  }))
}

variable "k8s_control_plane_cpu_cores" {
  description = "CPU cores for control plane nodes."
  type        = number
}

variable "k8s_control_plane_memory_mb" {
  description = "Memory (MB) for control plane nodes."
  type        = number
}

variable "k8s_worker_cpu_cores" {
  description = "CPU cores for worker nodes."
  type        = number
}

variable "k8s_worker_memory_mb" {
  description = "Memory (MB) for worker nodes."
  type        = number
}

variable "k8s_cluster_name" {
  description = "Talos/Kubernetes cluster name."
  type        = string
}

variable "k8s_cluster_endpoint" {
  description = "Talos/Kubernetes API endpoint IP or VIP."
  type        = string
}

variable "k8s_gateway_ipv4" {
  description = "Planned IPv4 gateway for Kubernetes nodes."
  type        = string
}

variable "k8s_dns_servers" {
  description = "Planned DNS servers for Kubernetes nodes."
  type        = list(string)
}
