# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

locals {
  credentials_file = pathexpand("~/.terraform.d/credentials.tfrc.json")

  # Resolve the API token: explicit var > terraform-login credentials file.
  hcp_terraform_token = coalesce(
    var.hcp_terraform_token,
    try(
      jsondecode(file(local.credentials_file)).credentials[var.hostname].token,
      null,
    ),
  )

  # Optional project lookup.
  project_id = var.project_name == null ? null : data.tfe_project.this[0].id

  # Build the JSON:API payload for the no-code workspace creation endpoint.
  # https://developer.hashicorp.com/terraform/cloud-docs/api-docs/no-code-provisioning#create-a-no-code-module-workspace
  workspace_terraform_vars = [
    {
      key       = "region"
      value     = var.region
      category  = "terraform"
      sensitive = false
    },
    {
      key       = "db_name"
      value     = var.db_name
      category  = "terraform"
      sensitive = false
    },
    {
      key       = "db_username"
      value     = var.db_username
      category  = "terraform"
      sensitive = false
    },
  ]

  workspace_env_vars = concat(
    [
      {
        key       = "TFC_AWS_PROVIDER_AUTH"
        value     = "true"
        category  = "env"
        sensitive = false
      },
      {
        key       = "TFC_AWS_RUN_ROLE_ARN"
        value     = var.aws_run_role_arn
        category  = "env"
        sensitive = false
      },
    ],
    var.aws_plan_role_arn == null ? [] : [{
      key       = "TFC_AWS_PLAN_ROLE_ARN"
      value     = var.aws_plan_role_arn
      category  = "env"
      sensitive = false
    }],
    var.aws_apply_role_arn == null ? [] : [{
      key       = "TFC_AWS_APPLY_ROLE_ARN"
      value     = var.aws_apply_role_arn
      category  = "env"
      sensitive = false
    }],
    var.aws_workload_identity_audience == null ? [] : [{
      key       = "TFC_AWS_WORKLOAD_IDENTITY_AUDIENCE"
      value     = var.aws_workload_identity_audience
      category  = "env"
      sensitive = false
    }],
  )

  workspace_vars = [
    for v in concat(local.workspace_terraform_vars, local.workspace_env_vars) : {
      type       = "vars"
      attributes = v
    }
  ]

  workspace_attributes = merge(
    {
      name             = var.workspace_name
      description      = var.workspace_description
      "auto-apply"     = var.auto_apply
      "execution-mode" = var.execution_mode
    },
    var.terraform_version == null ? {} : { "terraform-version" = var.terraform_version },
    var.execution_mode == "agent" && var.agent_pool_id != null ? { "agent-pool-id" = var.agent_pool_id } : {},
  )

  workspace_payload = jsonencode({
    data = {
      type       = "workspaces"
      attributes = local.workspace_attributes
      relationships = merge(
        local.project_id == null ? {} : {
          project = { data = { type = "project", id = local.project_id } }
        },
        {
          vars = { data = local.workspace_vars }
        },
      )
    }
  })
}

# Optional project lookup.
data "tfe_project" "this" {
  count        = var.project_name == null ? 0 : 1
  organization = var.organization
  name         = var.project_name
}

# Read the sibling `hcpt/registry` state to discover the no-code module ID
# automatically when `no_code_module_id` is not provided explicitly.
data "terraform_remote_state" "registry" {
  count   = var.no_code_module_id == null ? 1 : 0
  backend = "local"

  config = {
    path = var.registry_state_file
  }
}

locals {
  effective_no_code_module_id = coalesce(
    var.no_code_module_id,
    try(data.terraform_remote_state.registry[0].outputs.no_code_module_id, null),
  )
}

# Create the no-code workspace via the provisioning API. This is the only
# way to bind a workspace to a no-code module so HCP Terraform fetches the
# module configuration automatically.
resource "restapi_object" "workspace" {
  path         = "/api/v2/no-code-modules/${local.effective_no_code_module_id}/workspaces"
  destroy_path = "/api/v2/workspaces/{id}"
  id_attribute = "data/id"
  data         = local.workspace_payload
}
