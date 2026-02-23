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
