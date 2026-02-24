check "k8s_control_plane_present" {
  assert {
    condition     = length(local.k8s_control_plane_nodes) > 0
    error_message = "k8s_nodes must include at least one control-plane node."
  }
}

check "k8s_worker_present" {
  assert {
    condition     = length(local.k8s_worker_nodes) > 0
    error_message = "k8s_nodes must include at least one worker node."
  }
}

check "k8s_control_plane_quorum_shape" {
  assert {
    condition     = length(local.k8s_control_plane_nodes) == 1 || length(local.k8s_control_plane_nodes) % 2 == 1
    error_message = "Use an odd number of control-plane nodes when running more than one, to preserve etcd quorum behavior."
  }
}

check "k8s_cluster_endpoint_not_worker_ip" {
  assert {
    condition     = !contains([for name in local.k8s_worker_nodes : var.k8s_nodes[name].ip], var.k8s_cluster_endpoint)
    error_message = "k8s_cluster_endpoint cannot use a worker node IP. Use a control-plane IP or a dedicated VIP/LB."
  }
}

check "talos_template_vmid_not_reused" {
  assert {
    condition     = !contains([for node in values(var.k8s_nodes) : node.vm_id], var.talos_template_vmid)
    error_message = "talos_template_vmid must not be reused by k8s_nodes VM IDs."
  }
}
