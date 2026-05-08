# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "hostname" {
  description = "HCP Terraform / Terraform Enterprise hostname."
  type        = string
  default     = "app.terraform.io"
}

variable "organization" {
  description = "HCP Terraform organization that owns the no-code module."
  type        = string
}

variable "hcp_terraform_token" {
  description = "HCP Terraform user/team API token. If null, the token is read from `~/.terraform.d/credentials.tfrc.json` (i.e. `terraform login`). Org tokens are NOT accepted by the no-code endpoint."
  type        = string
  default     = null
  sensitive   = true
}

variable "no_code_module_id" {
  description = "ID of the no-code-enabled module (e.g. `nocode-XXXXXXXX`). If null, it is read from the sibling `hcpt/registry` Terraform state."
  type        = string
  default     = null
}

variable "registry_state_file" {
  description = "Path to the `hcpt/registry` Terraform state file. Used as a fallback to discover `no_code_module_id` when the variable is null."
  type        = string
  default     = "../registry/terraform.tfstate"
}

variable "project_name" {
  description = "Project to place the workspace in. If null, the default project is used."
  type        = string
  default     = null
}

variable "workspace_name" {
  description = "Name of the no-code workspace to create."
  type        = string
}

variable "workspace_description" {
  description = "Description for the workspace."
  type        = string
  default     = "No-code provisioned workspace for the no-code-aws-rds module."
}

variable "execution_mode" {
  description = "Workspace execution mode. No-code requires `remote` (or `agent`)."
  type        = string
  default     = "remote"

  validation {
    condition     = contains(["remote", "agent"], var.execution_mode)
    error_message = "execution_mode must be `remote` or `agent` for no-code workspaces."
  }
}

variable "agent_pool_id" {
  description = "Agent pool ID. Required when `execution_mode = \"agent\"`."
  type        = string
  default     = null
}

variable "auto_apply" {
  description = "Whether the workspace auto-applies successful plans."
  type        = bool
  default     = false
}

variable "terraform_version" {
  description = "Terraform version for the workspace. Null = latest."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Module input variables (forwarded as Terraform variables on the workspace)
# ---------------------------------------------------------------------------

variable "region" {
  description = "AWS region for the RDS instance."
  type        = string
  default     = "us-east-2"
}

variable "db_name" {
  description = "Unique name to assign to the RDS instance."
  type        = string
}

variable "db_username" {
  description = "RDS root username."
  type        = string
}

# ---------------------------------------------------------------------------
# AWS authentication via HCP Terraform dynamic credentials (OIDC)
# ---------------------------------------------------------------------------

variable "aws_run_role_arn" {
  description = "ARN of the IAM role HCP Terraform assumes via OIDC for both plan and apply phases."
  type        = string
}

variable "aws_plan_role_arn" {
  description = "Optional IAM role ARN for the plan phase. Falls back to `aws_run_role_arn`."
  type        = string
  default     = null
}

variable "aws_apply_role_arn" {
  description = "Optional IAM role ARN for the apply phase. Falls back to `aws_run_role_arn`."
  type        = string
  default     = null
}

variable "aws_workload_identity_audience" {
  description = "Optional custom OIDC audience. Defaults to `aws.workload.identity` when null."
  type        = string
  default     = null
}
