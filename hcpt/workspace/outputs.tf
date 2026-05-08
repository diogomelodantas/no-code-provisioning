# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "workspace_id" {
  description = "ID of the no-code workspace."
  value       = restapi_object.workspace.id
}

output "workspace_name" {
  description = "Workspace name."
  value       = var.workspace_name
}

output "workspace_url" {
  description = "URL to the workspace in HCP Terraform."
  value       = "https://${var.hostname}/app/${var.organization}/workspaces/${var.workspace_name}"
}

output "no_code_module_id" {
  description = "ID of the no-code module backing this workspace."
  value       = local.effective_no_code_module_id
}
