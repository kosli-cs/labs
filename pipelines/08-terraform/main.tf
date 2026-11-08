# Reference solution for Lab 8. Your own version lives in terraform/main.tf.

terraform {
  required_version = ">= 1.10"
  required_providers {
    kosli = {
      source = "kosli-dev/kosli"
    }
  }
}

# Authenticates with the KOSLI_API_TOKEN and KOSLI_ORG environment variables
provider "kosli" {}

# --- Service account for the CI pipeline ---------------------------------------

resource "kosli_service_account" "ci" {
  name        = "labs-ci"
  description = "GitHub Actions pipeline for the labs repository"
  privilege   = "member"
}

resource "kosli_service_account_api_key" "ci" {
  service_account_name = kosli_service_account.ci.name
  description          = "GitHub Actions secret KOSLI_API_TOKEN"
}

output "ci_api_key" {
  value     = kosli_service_account_api_key.ci.key
  sensitive = true
}

# --- Resources created in earlier labs, adopted with import blocks -------------

import {
  to = kosli_flow.labs
  id = "labs-pipeline"
}

resource "kosli_flow" "labs" {
  name        = "labs-pipeline"
  description = "CI/CD pipeline for labs application"
  template    = file("${path.module}/../flow-template.yaml")
}

import {
  to = kosli_environment.labs_prod
  id = "labs-prod"
}

resource "kosli_environment" "labs_prod" {
  name        = "labs-prod"
  type        = "docker"
  description = "Production environment for labs application"
}

import {
  to = kosli_policy.labs_prod_requirements
  id = "labs-prod-requirements"
}

resource "kosli_policy" "labs_prod_requirements" {
  name    = "labs-prod-requirements"
  content = file("${path.module}/../.kosli-policy.yml")
}

import {
  to = kosli_policy_attachment.labs_prod
  id = "labs-prod/labs-prod-requirements"
}

resource "kosli_policy_attachment" "labs_prod" {
  environment_name = kosli_environment.labs_prod.name
  policy_name      = kosli_policy.labs_prod_requirements.name
}

# --- Controls from Lab 4 and Lab 7 ---------------------------------------------

import {
  to = kosli_control.quality_assurance
  id = "LAB-001"
}

resource "kosli_control" "quality_assurance" {
  identifier  = "LAB-001"
  name        = "Quality assurance"
  description = "Every deployable artifact is built from code that passed its unit tests"
}

import {
  to = kosli_control.vulnerability_scanning
  id = "LAB-002"
}

resource "kosli_control" "vulnerability_scanning" {
  identifier  = "LAB-002"
  name        = "Vulnerability scanning"
  description = "Every deployable container image has been scanned for vulnerabilities"
}

import {
  to = kosli_control.binary_provenance
  id = "LAB-003"
}

resource "kosli_control" "binary_provenance" {
  identifier  = "LAB-003"
  name        = "Binary provenance"
  description = "Every deployable artifact can be traced to the CI build and commit that produced it"
}
