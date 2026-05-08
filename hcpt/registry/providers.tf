# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

# Credentials and hostname are sourced from the local HCP Terraform CLI
# login (`terraform login`). No token configuration is required here.
provider "tfe" {
  hostname = var.hostname
}
