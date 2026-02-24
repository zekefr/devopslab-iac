locals {
  talos_version_trimmed = trimprefix(var.talos_version, "v")
  talos_image_url       = "https://github.com/siderolabs/talos/releases/download/${var.talos_version}/metal-${var.talos_arch}.raw.zst"
  talos_image_file_name = "talos-${local.talos_version_trimmed}-${var.talos_arch}.img"
  k8s_control_plane_nodes = sort([
    for name, node in var.k8s_nodes : name if node.role == "control-plane"
  ])
  k8s_worker_nodes = sort([
    for name, node in var.k8s_nodes : name if node.role == "worker"
  ])
}

resource "proxmox_virtual_environment_download_file" "talos_image" {
  node_name               = var.proxmox_node_name
  datastore_id            = var.proxmox_image_datastore_id
  content_type            = var.talos_image_content_type
  file_name               = local.talos_image_file_name
  url                     = local.talos_image_url
  decompression_algorithm = "zst"
  overwrite               = false
  verify                  = true
}

resource "proxmox_virtual_environment_vm" "talos_template" {
  node_name = var.proxmox_node_name
  vm_id     = var.talos_template_vmid
  name      = var.talos_template_name

  description = "Talos ${var.talos_version} base template (managed by Terraform)"
  tags        = var.talos_template_tags
  template    = true
  started     = false
  on_boot     = false

  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0"]

  cpu {
    cores = var.talos_template_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.talos_template_memory_mb
    floating  = var.talos_template_memory_mb
  }

  network_device {
    bridge  = var.proxmox_network_bridge
    model   = "virtio"
    vlan_id = var.proxmox_network_vlan_id
  }

  disk {
    interface    = "scsi0"
    datastore_id = var.proxmox_vm_disk_datastore_id
    file_id      = proxmox_virtual_environment_download_file.talos_image.id
    size         = var.talos_template_disk_size_gb
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  operating_system {
    type = "l26"
  }
}

resource "proxmox_virtual_environment_vm" "k8s_node" {
  for_each = var.k8s_nodes

  node_name = var.proxmox_node_name
  vm_id     = each.value.vm_id
  name      = each.key

  description = "Talos ${each.value.role} node (planned IP: ${each.value.ip})"
  tags        = ["lab", "talos", "k8s", each.value.role]
  template    = false
  started     = true
  on_boot     = true

  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0"]

  clone {
    vm_id        = proxmox_virtual_environment_vm.talos_template.vm_id
    node_name    = var.proxmox_node_name
    datastore_id = var.proxmox_vm_disk_datastore_id
    full         = true
  }

  cpu {
    cores = each.value.role == "control-plane" ? var.k8s_control_plane_cpu_cores : var.k8s_worker_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = each.value.role == "control-plane" ? var.k8s_control_plane_memory_mb : var.k8s_worker_memory_mb
    floating  = each.value.role == "control-plane" ? var.k8s_control_plane_memory_mb : var.k8s_worker_memory_mb
  }

  network_device {
    bridge      = var.proxmox_network_bridge
    model       = "virtio"
    vlan_id     = var.proxmox_network_vlan_id
    mac_address = each.value.mac_address
  }
}
