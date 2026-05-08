# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# `tfe` is used only for read-only lookups (registry module, project).
provider "tfe" {
  hostname = var.hostname
}

# `restapi` is used to call the no-code provisioning API, which the tfe
# provider does not yet expose as a resource.
# https://developer.hashicorp.com/terraform/cloud-docs/api-docs/no-code-provisioning
provider "restapi" {
  uri                  = "https://${var.hostname}"
  write_returns_object = true
  headers = {
    Authorization = "Bearer ${local.hcp_terraform_token}"
    Content-Type  = "application/vnd.api+json"
  }
}
