output "talos_image_url" {
  description = "Talos raw image URL used for template provisioning."
  value       = module.talos_proxmox_cluster.talos_image_url
}

output "talos_image_file_id" {
  description = "File ID of the downloaded Talos image in Proxmox."
  value       = module.talos_proxmox_cluster.talos_image_file_id
}

output "talos_template_name" {
  description = "Name of the Talos template VM."
  value       = module.talos_proxmox_cluster.talos_template_name
}

output "talos_template_vmid" {
  description = "VMID of the Talos template VM."
  value       = module.talos_proxmox_cluster.talos_template_vmid
}

output "k8s_nodes" {
  description = "Provisioned Kubernetes nodes with role and planned IP."
  value       = module.talos_proxmox_cluster.k8s_nodes
}

output "k8s_control_plane_planned_ips" {
  description = "Planned IP addresses for control plane nodes."
  value       = module.talos_proxmox_cluster.k8s_control_plane_planned_ips
}

output "k8s_worker_planned_ips" {
  description = "Planned IP addresses for worker nodes."
  value       = module.talos_proxmox_cluster.k8s_worker_planned_ips
}

output "k8s_network_plan" {
  description = "Planned base network settings for Talos node bootstrap."
  value       = module.talos_proxmox_cluster.k8s_network_plan
}

output "talos_cluster_config" {
  description = "Talos bootstrap configuration derived from Terraform (single source of truth)."
  value       = module.talos_proxmox_cluster.talos_cluster_config
}

output "talos_cluster_env" {
  description = "Shell snippet generated from Terraform for Talos bootstrap input."
  value       = module.talos_proxmox_cluster.talos_cluster_env
}
