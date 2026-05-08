# HCP Terraform Workspace — No-Code Module Consumer

This Terraform configuration creates a workspace **bound to a no-code
module** by calling the [No-Code Provisioning API](https://developer.hashicorp.com/terraform/cloud-docs/api-docs/no-code-provisioning#create-a-no-code-module-workspace).

> **Why an API call instead of `tfe_workspace`?**
> The `tfe` provider's `tfe_workspace` resource creates an empty
> workspace with no configuration source — HCP Terraform shows
> *"Waiting for configuration"* because nothing tells it which no-code
> module to fetch. The only way to attach the no-code module source to
> a workspace today is via `POST /no-code-modules/:id/workspaces`. We
> use the [`Mastercard/restapi`](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs)
> provider to make that call from Terraform.

## Layout

```
hcpt/workspace/
├── README.md
├── versions.tf              # Terraform & provider version constraints
├── providers.tf             # tfe + restapi provider configuration
├── variables.tf             # Input variables
├── main.tf                  # No-code workspace via REST API
├── outputs.tf               # Workspace ID, name, URL
└── terraform.tfvars.example # Sample variable values
```

## Prerequisites

1. **`hcpt/registry` already applied** — note the `no_code_module_id`
   output (`nocode-XXXX...`); you'll pass it as `no_code_module_id` here.
2. **HCP Terraform CLI login** (`terraform login`). The token is read
   automatically from `~/.terraform.d/credentials.tfrc.json`. You can
   override it by setting `TF_VAR_hcp_terraform_token` or
   `hcp_terraform_token` in tfvars.
   > The no-code endpoint **does not accept organization tokens** — use
   > a user or team token.
3. **AWS IAM role configured for OIDC trust** with HCP Terraform. Pass
   the role ARN as `aws_run_role_arn`. See
   [Dynamic Credentials with the AWS Provider](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/aws-configuration).

## Usage

```sh
cd hcpt/workspace

cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: set `organization`, `no_code_module_id`,
# `workspace_name`, `db_name`, `db_username`, `aws_run_role_arn`.

terraform init
terraform plan
terraform apply
```

After `apply`, open the printed `workspace_url`. The workspace will
already have the no-code module configuration attached and will queue a
plan automatically.

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `hostname` | HCP Terraform / TFE hostname | `string` | `app.terraform.io` |
| `organization` | HCP Terraform organization | `string` | _(required)_ |
| `hcp_terraform_token` | API token (user/team). Falls back to `terraform login` credentials. | `string` | `null` |
| `no_code_module_id` | ID of the no-code module (`nocode-XXXX`). Auto-discovered from `hcpt/registry` state when null. | `string` | `null` |
| `registry_state_file` | Path to the `hcpt/registry` state file (used to auto-discover the module ID) | `string` | `../registry/terraform.tfstate` |
| `workspace_name` | Workspace name | `string` | _(required)_ |
| `workspace_description` | Workspace description | `string` | _(default text)_ |
| `project_name` | Project to place the workspace in | `string` | `null` |
| `execution_mode` | `remote` or `agent` | `string` | `remote` |
| `agent_pool_id` | Required when `execution_mode = agent` | `string` | `null` |
| `auto_apply` | Auto-apply successful plans | `bool` | `false` |
| `terraform_version` | Pinned Terraform version | `string` | `null` (latest) |
| `region` | AWS region for the RDS instance | `string` | `us-east-2` |
| `db_name` | Unique name for the RDS instance | `string` | _(required)_ |
| `db_username` | RDS root username | `string` | _(required)_ |
| `aws_run_role_arn` | IAM role ARN assumed via OIDC for plan + apply | `string` | _(required)_ |
| `aws_plan_role_arn` | Override IAM role for the plan phase | `string` | `null` |
| `aws_apply_role_arn` | Override IAM role for the apply phase | `string` | `null` |
| `aws_workload_identity_audience` | Custom OIDC audience | `string` | `null` |

## Outputs

| Name | Description |
|---|---|
| `workspace_id` | ID of the created workspace |
| `workspace_name` | Workspace name |
| `workspace_url` | Direct link to the workspace in HCP Terraform |
| `no_code_module_id` | The no-code module backing this workspace |

## Notes & limitations

- **State drift:** the `restapi_object` resource only knows what it
  POSTed. If you change variable values via the HCP Terraform UI later,
  Terraform will overwrite them on the next apply. Pick one source of
  truth.
- **Updates:** changing `name`, `execution_mode`, or other attributes
  triggers a `PATCH /workspaces/:id`; changing `no_code_module_id`
  forces replacement (the workspace is destroyed and recreated).
- **Variable updates:** because variables are nested in the create
  payload, updating them with `restapi_object` re-PATCHes the workspace
  variables. For finer control, you can switch to managing variables
  with the no-code workspace upgrade endpoint.
- **AWS auth:** uses HCP Terraform dynamic credentials (OIDC). No
  long-lived AWS keys are stored on the workspace.
