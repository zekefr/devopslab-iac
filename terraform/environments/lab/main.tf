module "talos_proxmox_cluster" {
  source = "../../modules/talos-proxmox-cluster"

  proxmox_node_name            = var.proxmox_node_name
  proxmox_image_datastore_id   = var.proxmox_image_datastore_id
  proxmox_vm_disk_datastore_id = var.proxmox_vm_disk_datastore_id
  proxmox_network_bridge       = var.proxmox_network_bridge
  proxmox_network_vlan_id      = var.proxmox_network_vlan_id

  talos_version               = var.talos_version
  talos_arch                  = var.talos_arch
  talos_image_content_type    = var.talos_image_content_type
  talos_template_name         = var.talos_template_name
  talos_template_vmid         = var.talos_template_vmid
  talos_template_cpu_cores    = var.talos_template_cpu_cores
  talos_template_memory_mb    = var.talos_template_memory_mb
  talos_template_disk_size_gb = var.talos_template_disk_size_gb
  talos_template_tags         = var.talos_template_tags

  k8s_nodes                   = var.k8s_nodes
  k8s_control_plane_cpu_cores = var.k8s_control_plane_cpu_cores
  k8s_control_plane_memory_mb = var.k8s_control_plane_memory_mb
  k8s_worker_cpu_cores        = var.k8s_worker_cpu_cores
  k8s_worker_memory_mb        = var.k8s_worker_memory_mb
  k8s_cluster_name            = var.k8s_cluster_name
  k8s_cluster_endpoint        = var.k8s_cluster_endpoint
  k8s_gateway_ipv4            = var.k8s_gateway_ipv4
  k8s_dns_servers             = var.k8s_dns_servers
}
