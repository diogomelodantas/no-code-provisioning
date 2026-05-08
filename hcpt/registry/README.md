# HCP Terraform Registry — No-Code Module Publisher

This Terraform configuration publishes the
[`modules/no-code-aws-rds`](../../modules/no-code-aws-rds) module to an
**HCP Terraform** organization's **private registry** and enables it for
**no-code provisioning**, pinned to a Git branch (default: `main`).

## Layout

```
hcpt/registry/
├── README.md
├── versions.tf              # Terraform & provider version constraints
├── providers.tf             # tfe provider configuration
├── variables.tf             # Input variables
├── main.tf                  # Registry module + no-code module resources
├── outputs.tf               # Useful outputs
└── terraform.tfvars.example # Sample variable values
```

## Prerequisites

1. **HCP Terraform CLI login** — credentials are read from your local
   `~/.terraform.d/credentials.tfrc.json`:
   ```sh
   terraform login
   ```
2. **GitHub App VCS connection** already configured in the target HCP
   Terraform organization (Settings → Version Control → GitHub App). The
   installation name (typically your GitHub username or org) is passed via
   `github_installation_name`.
3. The repository (`diogomelodantas/no-code-provisioning` by default) must
   be accessible to that GitHub App installation.

## Usage

```sh
cd hcpt/registry

cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars and set `organization` to your HCP Terraform org

terraform init
terraform plan
terraform apply
```

## Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `hostname` | HCP Terraform / TFE hostname | `string` | `app.terraform.io` |
| `organization` | HCP Terraform organization | `string` | _(required)_ |
| `github_installation_name` | GitHub App installation name connected to the org | `string` | `diogomelodantas` |
| `vcs_repo_identifier` | VCS repo (`<owner>/<repo>`) holding the module source | `string` | `diogomelodantas/no-code-provisioning` |
| `module_name` | Registry module name | `string` | `no-code-aws-rds` |
| `module_provider` | Module provider namespace | `string` | `aws` |
| `module_branch` | Branch published as the module source | `string` | `main` |
| `module_source_directory` | Path within the repo where the module lives (monorepo) | `string` | `modules/no-code-aws-rds` |
| `version_pin` | Semver version to pin the no-code module to. Leave `null` to track latest. | `string` | `null` |
| `no_code_enabled` | Enable no-code provisioning | `bool` | `true` |

## Outputs

| Name | Description |
|---|---|
| `registry_module_id` | ID of the published private registry module |
| `registry_module_name` | Fully-qualified `org/name/provider` identifier |
| `no_code_module_id` | ID of the no-code module configuration |
| `no_code_module_version_pin` | Branch the no-code module is pinned to |

## Notes

- This configuration uses a **branch-based** registry module
  (`tags = false`), so commits to `main` automatically become the latest
  module source — no Git tags required.
- The module source lives in a **subdirectory** (`modules/no-code-aws-rds`)
  rather than the repo root. This is supported via the `source_directory`
  argument on `vcs_repo` (currently a **beta** feature in HCP Terraform).
  When using `source_directory`, both `name` and `module_provider` must be
  set explicitly — the API cannot infer them from a monorepo path.
- To publish a different module from this repo, change `module_name`,
  `module_provider`, and `module_source_directory` accordingly.
- To disable no-code provisioning without destroying the registry module,
  set `no_code_enabled = false` and re-apply.
