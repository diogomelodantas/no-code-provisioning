# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Resolve the GitHub App installation already connected to the org so that
# HCP Terraform can pull the module source from the VCS repository.
data "tfe_github_app_installation" "this" {
  name = var.github_installation_name
}

# Publish the module from the configured branch into the organization's
# private registry as a branch-based (non-tagged) module.
resource "tfe_registry_module" "no_code_aws_rds" {
  organization = var.organization

  # `name` and `module_provider` must be set explicitly when using
  # `source_directory`, since the API cannot infer them from a monorepo path.
  name            = var.module_name
  module_provider = var.module_provider

  vcs_repo {
    display_identifier         = var.vcs_repo_identifier
    identifier                 = var.vcs_repo_identifier
    branch                     = var.module_branch
    source_directory           = var.module_source_directory
    github_app_installation_id = data.tfe_github_app_installation.this.id
    tags                       = false
  }
}

# Enable no-code provisioning for the module, pinned to the configured branch.
resource "tfe_no_code_module" "no_code_aws_rds" {
  organization    = var.organization
  registry_module = tfe_registry_module.no_code_aws_rds.id
  version_pin     = var.module_branch
  enabled         = var.no_code_enabled
}
