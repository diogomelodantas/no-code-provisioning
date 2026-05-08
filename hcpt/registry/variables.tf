# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "hostname" {
  description = "HCP Terraform / Terraform Enterprise hostname."
  type        = string
  default     = "app.terraform.io"
}

variable "organization" {
  description = "HCP Terraform organization that will own the registry module."
  type        = string
}

variable "github_installation_name" {
  description = "Name of the GitHub App installation already connected to the HCP Terraform organization (typically your GitHub username or org)."
  type        = string
  default     = "diogomelodantas"
}

variable "vcs_repo_identifier" {
  description = "VCS repository identifier (`<owner>/<repo>`) hosting the module source."
  type        = string
  default     = "diogomelodantas/no-code-provisioning"
}

variable "module_name" {
  description = "Name of the module as it will appear in the private registry."
  type        = string
  default     = "no-code-aws-rds"
}

variable "module_provider" {
  description = "Provider namespace for the registry module (e.g. `aws`, `azurerm`)."
  type        = string
  default     = "aws"
}

variable "module_branch" {
  description = "Git branch to publish as the no-code module source."
  type        = string
  default     = "main"
}

variable "module_source_directory" {
  description = "Path within the VCS repository where the module source lives (monorepo support)."
  type        = string
  default     = "modules/no-code-aws-rds"
}

variable "version_pin" {
  description = "Optional semver version to pin the no-code module to (e.g. `1.2.3`). Leave null to always use the latest published version from the branch."
  type        = string
  default     = null
}

variable "no_code_enabled" {
  description = "Whether no-code provisioning is enabled for the module."
  type        = bool
  default     = true
}
