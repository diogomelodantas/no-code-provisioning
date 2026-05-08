# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "registry_module_id" {
  description = "ID of the published private registry module."
  value       = tfe_registry_module.no_code_aws_rds.id
}

output "registry_module_name" {
  description = "Fully-qualified name of the registry module (organization/name/provider)."
  value       = "${var.organization}/${tfe_registry_module.no_code_aws_rds.name}/${tfe_registry_module.no_code_aws_rds.module_provider}"
}

output "no_code_module_id" {
  description = "ID of the no-code module configuration."
  value       = tfe_no_code_module.no_code_aws_rds.id
}

output "no_code_module_version_pin" {
  description = "Branch (or version) the no-code module is pinned to."
  value       = tfe_no_code_module.no_code_aws_rds.version_pin
}
