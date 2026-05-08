# No-Code Provisioning on HCP Terraform

End-to-end demo of HCP Terraform's [No-Code Provisioning](https://developer.hashicorp.com/terraform/cloud-docs/no-code-provisioning) workflow, fully managed as code:

1. Author a Terraform module under [modules/](modules/).
2. Publish it to the organization's private registry as a **branch-based no-code module** ([hcpt/registry/](hcpt/registry/)).
3. Provision a workspace from that no-code module ([hcpt/workspace/](hcpt/workspace/)) — including project placement, dynamic AWS credentials (OIDC), and managed workspace variables.

## Repository layout

```
.
├── modules/
│   └── no-code-aws-rds/         # Terraform module published to the registry
├── hcpt/
│   ├── registry/                # Publishes the module + enables no-code
│   └── workspace/               # Creates a no-code workspace from the module
└── README.md
```

| Path | Purpose |
| --- | --- |
| [modules/no-code-aws-rds](modules/no-code-aws-rds/) | Example AWS RDS module exposed as a no-code module. |
| [hcpt/registry](hcpt/registry/) | `tfe_registry_module` (branch-based, monorepo `source_directory`) + `tfe_no_code_module`. |
| [hcpt/workspace](hcpt/workspace/) | Creates the no-code workspace via the HCP Terraform REST API and manages variables. |

## How the two configurations fit together

**Concert Mocking Workflows with Terraform**
```
┌──────────────────────────┐        ┌───────────────────────────┐
│  hcpt/registry           │        │  hcpt/workspace           │
│                          │        │                           │
│  tfe_registry_module     │        │  restapi_object.workspace │
│      │ enables           │  reads │      (POST /no-code-      │
│      ▼                   │ output │       modules/:id/        │
│  tfe_no_code_module ─────┼────────┼──►   workspaces)          │
│      (nocode-XXXX)       │  via   │                           │
│                          │ remote │  tfe_variable.this        │
│                          │ state  │      (PATCH /workspaces/  │
│                          │        │       :id/vars)           │
└──────────────────────────┘        └───────────────────────────┘
```

`hcpt/workspace` reads `no_code_module_id` automatically from `../registry/terraform.tfstate` via a `terraform_remote_state` data source, so you don't have to copy/paste the ID.

## Prerequisites

- HCP Terraform organization with the GitHub App installed and access to this repo.
- `terraform login` for `app.terraform.io` (writes a **user** token to `~/.terraform.d/credentials.tfrc.json` — required by the no-code provisioning endpoint; org tokens are rejected).
- AWS account configured with the [HCP Terraform OIDC trust](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/aws-configuration) and an IAM role the workspace can assume.
- Local CLI: `terraform >= 1.5`, `jq` (for the helper one-liners).

## Quick start

```sh
# 1) Publish the module to the registry and enable no-code provisioning
cd hcpt/registry
cp terraform.tfvars.example terraform.tfvars   # edit values
terraform init
terraform apply

# 2) Provision a no-code workspace from that module
cd ../workspace
cp terraform.tfvars.example terraform.tfvars   # edit values
terraform init
terraform apply
```

After the second apply, HCP Terraform queues a run on the new workspace using dynamic AWS credentials.

## Key design decisions

- **Branch-based publishing.** `tfe_registry_module` uses `vcs_repo.branch` + `tags = false` so the registry tracks `main` instead of git tags.
- **Monorepo support.** `vcs_repo.source_directory = "modules/no-code-aws-rds"` (currently in beta on the `tfe` provider) lets a single repo host the module alongside the publishing config.
- **No `version_pin`.** For branch-based modules the no-code module always points at the latest auto-generated version, so `version_pin` is left null.
- **REST API for workspace creation.** The `tfe` provider has no resource that binds a workspace to a no-code module, so [hcpt/workspace](hcpt/workspace/) uses [`Mastercard/restapi`](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs) to call `POST /api/v2/no-code-modules/:id/workspaces`. Lifecycle paths are split: `read` / `update` / `destroy` target `/api/v2/workspaces/:id`.
- **Variables managed separately.** The create payload omits `vars`; workspace variables are managed by `tfe_variable` resources so updates propagate via `/workspaces/:id/vars` (PATCH on `/workspaces/:id` does **not** accept variable changes).
- **AWS via OIDC.** The workspace sets the `TFC_AWS_*` env vars so the AWS provider in the no-code module assumes an IAM role at run time. No long-lived AWS credentials are stored.

## Cleanup notes & gotchas

- **Destroy order matters.** Always destroy `hcpt/workspace` *before* `hcpt/registry` — the no-code module can't be deleted while it has workspaces attached.
- **Phantom no-code references.** If a workspace gets out of sync with state (e.g. an apply fails mid-flight), HCP Terraform may keep an internal reference that blocks deletion of the registry module with `Cannot delete registry module because it is being used by one or more no-code workspaces`. The corresponding no-code module DELETE returns `500`. In that case open a HashiCorp support ticket with the org name and module IDs, or `terraform state rm` the orphans and use a fresh `module_name` next time.
- **User token required.** Org tokens cannot call the no-code provisioning endpoint. Re-run `terraform login` if you see `404 Not Found` or `403 forbidden` when creating the workspace.
- **First DB run.** RDS rejects master usernames containing hyphens/underscores. Use plain alphanumerics (e.g. `demoadmin`) for `db_username`.

## License

Mozilla Public License 2.0 — see [modules/no-code-aws-rds/LICENSE](modules/no-code-aws-rds/LICENSE).
