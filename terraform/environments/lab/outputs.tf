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
  value       = [for name in local.k8s_control_plane_nodes : var.k8s_nodes[name].ip]
}

output "k8s_worker_planned_ips" {
  description = "Planned IP addresses for worker nodes."
  value       = [for name in local.k8s_worker_nodes : var.k8s_nodes[name].ip]
}

output "k8s_network_plan" {
  description = "Planned base network settings for Talos node bootstrap."
  value = {
    gateway_ipv4 = var.k8s_gateway_ipv4
    dns_servers  = var.k8s_dns_servers
  }
}

output "talos_cluster_config" {
  description = "Talos bootstrap configuration derived from Terraform (single source of truth)."
  value = {
    cluster_name        = var.k8s_cluster_name
    cluster_endpoint    = var.k8s_cluster_endpoint
    gateway_ipv4        = var.k8s_gateway_ipv4
    dns_servers         = var.k8s_dns_servers
    control_plane_nodes = local.k8s_control_plane_nodes
    worker_nodes        = local.k8s_worker_nodes
    node_target_ip      = { for name, node in var.k8s_nodes : name => node.ip }
  }
}

output "talos_cluster_env" {
  description = "Shell snippet generated from Terraform for Talos bootstrap input."
  value = join("\n", concat(
    [
      "#!/usr/bin/env bash",
      "# Generated from Terraform output 'talos_cluster_env'. Do not edit manually.",
      format("CLUSTER_NAME=%s", jsonencode(var.k8s_cluster_name)),
      format("CLUSTER_ENDPOINT=%s", jsonencode(var.k8s_cluster_endpoint)),
      format("GATEWAY_IPV4=%s", jsonencode(var.k8s_gateway_ipv4)),
      format("DNS_SERVERS=(%s)", join(" ", [for dns in var.k8s_dns_servers : jsonencode(dns)])),
      format("CONTROL_PLANE_NODES=(%s)", join(" ", [for name in local.k8s_control_plane_nodes : jsonencode(name)])),
      format("WORKER_NODES=(%s)", join(" ", [for name in local.k8s_worker_nodes : jsonencode(name)])),
      "declare -A NODE_TARGET_IP=(",
    ],
    [
      for name in sort(keys(var.k8s_nodes)) :
      format("  [%s]=%s", name, jsonencode(var.k8s_nodes[name].ip))
    ],
    [
      ")",
    ]
  ))
}
