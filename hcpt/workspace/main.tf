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

  # Variables managed post-create by tfe_variable resources (keyed by
  # "<category>.<key>") so updates propagate via /workspaces/:id/vars.
  workspace_managed_vars = {
    for v in concat(local.workspace_terraform_vars, local.workspace_env_vars) :
    "${v.category}.${v.key}" => v
  }

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

  # HCP Terraform key-value tags applied to the workspace via the
  # `tag-bindings` relationship on create. Updates are managed by
  # `tfe_workspace_settings.this` below.
  workspace_tags = merge(var.default_tags, var.tags)

  workspace_tag_bindings = [
    for k, v in local.workspace_tags : {
      type = "tag-bindings"
      attributes = {
        key   = k
        value = v
      }
    }
  ]

  workspace_payload = jsonencode({
    data = {
      type       = "workspaces"
      attributes = local.workspace_attributes
      relationships = merge(
        local.project_id == null ? {} : {
          project = { data = { type = "project", id = local.project_id } }
        },
        length(local.workspace_tag_bindings) == 0 ? {} : {
          "tag-bindings" = { data = local.workspace_tag_bindings }
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
#
# Endpoint paths differ per lifecycle stage:
#   create  -> POST   /api/v2/no-code-modules/:nocode-id/workspaces
#   read    -> GET    /api/v2/workspaces/:ws-id
#   update  -> PATCH  /api/v2/workspaces/:ws-id
#   destroy -> POST   /api/v2/workspaces/:ws-id/actions/safe-delete
#
# Using `safe-delete` (instead of plain DELETE) asks HCP Terraform to
# unbind the workspace from its no-code module before removing it,
# avoiding the phantom-reference bug that blocks subsequent module
# deletion.
resource "restapi_object" "workspace" {
  path           = "/api/v2/no-code-modules/${local.effective_no_code_module_id}/workspaces"
  read_path      = "/api/v2/workspaces/{id}"
  update_path    = "/api/v2/workspaces/{id}"
  destroy_path   = "/api/v2/workspaces/{id}/actions/safe-delete"
  destroy_method = "POST"
  update_method  = "PATCH"
  id_attribute   = "data/id"
  data           = local.workspace_payload
}

# Manage workspace variables via the dedicated /workspaces/:id/vars endpoint
# so that updates to inputs propagate on subsequent applies. The initial POST
# above creates the workspace without vars; HCP Terraform will queue runs
# until these variables land.
resource "tfe_variable" "this" {
  for_each = local.workspace_managed_vars

  workspace_id = restapi_object.workspace.id
  key          = each.value.key
  value        = each.value.value
  category     = each.value.category
  sensitive    = each.value.sensitive
  description  = "Managed by hcpt/workspace Terraform configuration."
}

# HCP Terraform auto-queues a run the moment the workspace is created, but
# that first run fires *before* `tfe_variable.this` has written the inputs,
# so it errors with "No value for required variable". This resource queues
# a follow-up run after the vars land (apply phase), and queues a destroy
# run on teardown so the `safe-delete` endpoint can succeed.
resource "tfe_workspace_run" "this" {
  count        = var.queue_runs ? 1 : 0
  workspace_id = restapi_object.workspace.id

  apply {
    manual_confirm    = false
    wait_for_run      = true
    retry_attempts    = 3
    retry_backoff_min = 5
  }

  destroy {
    manual_confirm    = false
    wait_for_run      = true
    retry_attempts    = 3
    retry_backoff_min = 5
  }

  depends_on = [tfe_variable.this]
}
