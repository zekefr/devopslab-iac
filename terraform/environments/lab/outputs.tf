output "talos_image_url" {
  description = "Talos raw image URL used for template provisioning."
  value       = local.talos_image_url
}

output "talos_image_file_id" {
  description = "File ID of the downloaded Talos image in Proxmox."
  value       = proxmox_virtual_environment_download_file.talos_image.id
}

output "talos_template_name" {
  description = "Name of the Talos template VM."
  value       = proxmox_virtual_environment_vm.talos_template.name
}

output "talos_template_vmid" {
  description = "VMID of the Talos template VM."
  value       = proxmox_virtual_environment_vm.talos_template.vm_id
}

output "k8s_nodes" {
  description = "Provisioned Kubernetes nodes with role and planned IP."
  value = {
    for name, vm in proxmox_virtual_environment_vm.k8s_node : name => {
      vm_id        = vm.vm_id
      role         = var.k8s_nodes[name].role
      planned_ip   = var.k8s_nodes[name].ip
      proxmox_node = vm.node_name
    }
  }
}

output "k8s_control_plane_planned_ips" {
  description = "Planned IP addresses for control plane nodes."
  value       = [for name, node in var.k8s_nodes : node.ip if node.role == "control-plane"]
}

output "k8s_worker_planned_ips" {
  description = "Planned IP addresses for worker nodes."
  value       = [for name, node in var.k8s_nodes : node.ip if node.role == "worker"]
}

output "k8s_network_plan" {
  description = "Planned base network settings for Talos node bootstrap."
  value = {
    gateway_ipv4 = var.k8s_gateway_ipv4
    dns_servers  = var.k8s_dns_servers
  }
}
