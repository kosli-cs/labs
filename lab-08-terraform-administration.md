# Lab 8: Kosli administration: Terraform

## Learning Goals

- Configure the Kosli Terraform provider
- Create a service account and API key for your CI pipeline
- Adopt resources created in earlier labs into Terraform with import blocks
- Manage your Flow, Environment, Environment Policy and controls as code
- Remove the resource management steps from your pipeline, now that Terraform owns them

## Introduction

So far you have created Kosli resources in two ways: by hand with the CLI (the Environment and the controls) and from your pipeline (the Flow and the Environment Policy). That works, but it spreads the definition of your setup across terminals, workflow steps and people's memory.

The [Kosli Terraform provider](https://docs.kosli.com/terraform-reference) lets you manage Kosli resources as Infrastructure-as-Code: reviewed in pull requests, versioned in git, and applied the same way every time. In this lab you hand over the *administration* of your Kosli setup to Terraform:

| Resource | Created in | Managed from now on by |
|---|---|---|
| Flow `labs-pipeline` and its Flow Template | Lab 2 / Lab 5, by the pipeline | Terraform (`kosli_flow`) |
| Environment `labs-prod` | Lab 6, by hand | Terraform (`kosli_environment`) |
| Environment Policy `labs-prod-requirements` and its attachment | Lab 6, by the pipeline | Terraform (`kosli_policy`, `kosli_policy_attachment`) |
| Controls `LAB-001`, `LAB-002`, `LAB-003` | Lab 4 / Lab 7, by hand | Terraform (`kosli_control`) |
| Service account for CI | new | Terraform (`kosli_service_account`, `kosli_service_account_api_key`) |

What stays in the pipeline is what *records* facts: beginning Trails, attestations, decisions, assertions and snapshots.

> :information_source: The Rego and Ergo policies you published in Lab 4 and Lab 7 have no Terraform resource. Keep publishing them with `kosli publish rego-policy`.

## Prerequisites

- Completed [Lab 7: Writing policies: Ergo](lab-07-writing-policies-with-ergo.md)
- [Terraform](https://developer.hashicorp.com/terraform/install) 1.10 or later installed (`terraform version`)
- Your personal API key with the Admin role exported as `KOSLI_API_TOKEN`, and `KOSLI_ORG` set

## Exercise

### Overview

In this lab, you will:

- Configure the Kosli provider
- Create a service account for your pipeline and switch the GitHub secret to its API key
- Import the Flow, Environment, Environment Policy, attachment and controls into Terraform
- Run `terraform plan` until it shows no changes
- Remove the `Create/Update Flow`, `Update Kosli policy` and `Attach policy to environment` steps from your pipeline
- Make a change through Terraform

### Step-by-step instructions

#### Configure the provider

Create `terraform/main.tf` in your repository:

```hcl
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
```

Initialize the working directory. This downloads the provider:

```bash
cd terraform
terraform init
```

> :bulb: If your Organization is in the US region, set `api_url = "https://app.us.kosli.com"` in the provider block.

#### Create a service account for CI

Since Lab 2, your pipeline has used your *personal* API key. A personal key authenticates as you, with your permissions in every Organization you belong to. For automation, the Kosli docs recommend a **service account**: an identity scoped to one Organization with an explicit role.

Add to `terraform/main.tf`:

```hcl
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
```

The `member` role can do everything the pipeline does from now on: begin Trails, attest, record decisions, assert and snapshot. It can't publish policies or change the Organization.

Apply it:

```bash
terraform apply
```

Review the plan and type `yes`. Then print the new key and put it in your GitHub repository under **Settings → Secrets and variables → Actions**, replacing the value of the `KOSLI_API_TOKEN` secret:

```bash
terraform output -raw ci_api_key
```

> :warning: The raw key is only returned once, at creation, and Terraform keeps it in its state file `terraform.tfstate`. The state file is listed in `.gitignore`: never commit it. In a real setup, keep the state in a remote backend with access control.

> :bulb: Kosli caps every API key at 365 days. Rotate the key before it expires by changing its `description` or `expires_at`, which replaces it with a new key.

See [kosli_service_account](https://docs.kosli.com/terraform-reference/resources/service_account) and [kosli_service_account_api_key](https://docs.kosli.com/terraform-reference/resources/service_account_api_key) for more details.

#### Import the resources from earlier labs

Your Flow, Environment, Environment Policy and controls already exist in Kosli. Instead of recreating them, you **import** them, so Terraform takes over the existing resources with their history intact. An `import` block says which existing resource a Terraform resource corresponds to.

Add to `terraform/main.tf`:

```hcl
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
```

Notice that the Flow Template and the Environment Policy are still read from `flow-template.yaml` and `.kosli-policy.yml` with `file()`. The YAML files stay the single source of truth; Terraform applies them.

Now add a `kosli_control` resource with an `import` block for each control. Here is the first one:

```hcl
import {
  to = kosli_control.quality_assurance
  id = "LAB-001"
}

resource "kosli_control" "quality_assurance" {
  identifier  = "LAB-001"
  name        = "Quality assurance"
  description = "Every deployable artifact is built from code that passed its unit tests"
}
```

Add `LAB-002` and `LAB-003` the same way, with the names and descriptions you used in Lab 4 and Lab 7.

#### Plan until there are no changes

```bash
terraform plan
```

The plan lists the resources to import. If it also shows changes, your configuration doesn't match what exists in Kosli yet: compare the attributes in the plan with your configuration, e.g. a description that is worded differently, and adjust the configuration. Repeat until the plan only shows imports, then apply:

```bash
terraform apply
```

> :bulb: Once the import is applied, the `import` blocks have done their job. You can delete them, or leave them in as documentation.

See [Import](https://developer.hashicorp.com/terraform/language/import) in the Terraform docs for more on import blocks.

#### Remove resource management from the pipeline

Terraform now owns the Flow and the Environment Policy, so the pipeline should stop changing them. Otherwise two tools manage the same resource, and whichever runs last wins.

In `.github/workflows/full-pipeline.yaml`:

1. In the `Build` job, remove the `Create/Update Flow` step
2. In the `Deploy` job, remove the `Update Kosli policy` and `Attach policy to environment` steps

Commit and push everything except the Terraform state:

```bash
cd ..
git add terraform/main.tf terraform/.terraform.lock.hcl .github/workflows/full-pipeline.yaml
git commit -m "Manage Kosli resources with Terraform"
git push origin main
```

Watch the workflow. It now runs with the service account's API key: the Trail, attestations, decisions, deployment gate and snapshot all work as before.

> :bulb: Everything the pipeline records from now on is recorded by the `labs-ci` service account instead of by you. Service accounts give a cleaner audit trail, because automation and people are no longer mixed up.

#### Make a change through Terraform

Your Kosli setup is now changed through code. Try it:

1. Add tags to the Flow in `terraform/main.tf`:

```hcl
resource "kosli_flow" "labs" {
  name        = "labs-pipeline"
  description = "CI/CD pipeline for labs application"
  template    = file("${path.module}/../flow-template.yaml")
  tags = {
    team    = "labs"
    managed = "terraform"
  }
}
```

2. Run `terraform plan`. It shows exactly one change: the tags on the Flow
3. Run `terraform apply` and see the tags on the Flow in the Kosli app

The same goes for the Flow Template and the Environment Policy: change `flow-template.yaml` or `.kosli-policy.yml`, then `terraform plan` shows the change and `terraform apply` makes it.

> :bulb: In a team, you would run `terraform plan` on every pull request and `terraform apply` on merge, for example from a separate workflow using an admin service account. Then every change to your compliance setup is reviewed and recorded in git.

### Verification Checklist

Before completing this lab, ensure you have:

- ✅ Configured the Kosli provider in `terraform/main.tf` and run `terraform init`
- ✅ Created the `labs-ci` service account and API key, and updated the `KOSLI_API_TOKEN` GitHub secret
- ✅ Imported the Flow, Environment, Environment Policy, attachment and the three controls
- ✅ `terraform plan` shows no changes
- ✅ Removed the `Create/Update Flow`, `Update Kosli policy` and `Attach policy to environment` steps from the workflow
- ✅ Workflow runs successfully with the service account
- ✅ Made a change to the Flow through Terraform
- ✅ Not committed `terraform.tfstate`

If anything did not go according to plan, you can reference our solutions in [pipelines/08-complete.yaml](pipelines/08-complete.yaml) and [pipelines/08-terraform/main.tf](pipelines/08-terraform/main.tf).

## Conclusion

Congratulations! You've completed the Kosli learning labs. You now know how to:

1. Model your delivery process with Flows and Trails
2. Record evidence with Artifacts and Attestations
3. Implement controls, decided by policies you can write yourself with Ergo
4. Define compliance with Flow Templates and enforce it with deployment gates
5. Monitor what's running with Environments, Snapshots and Environment Policies
6. Administer your Kosli setup as code with Terraform

You have implemented build, release and runtime controls, with an immutable record that links every running artifact back to the commit, Trail, evidence and decisions that produced it.

## Next Steps

- Explore [custom attestation types](https://docs.kosli.com/getting_started/attestations/#attestation-types) for your specific tools
- Set up [Kubernetes environment reporting](https://docs.kosli.com/tutorials/report_k8s_envs) if you use K8s
- Let Kosli report your cloud environments with [Cloud Capture](https://docs.kosli.com/administration/cloud_capture/overview)
- Explore the [Kosli API](https://docs.kosli.com/api-reference/overview) for custom integrations

## Resources

- [Kosli Terraform provider](https://docs.kosli.com/terraform-reference)
- [Service accounts](https://docs.kosli.com/administration/authentication/service_accounts)
- [kosli_flow](https://docs.kosli.com/terraform-reference/resources/flow)
- [kosli_environment](https://docs.kosli.com/terraform-reference/resources/environment)
- [kosli_policy](https://docs.kosli.com/terraform-reference/resources/policy)
- [kosli_policy_attachment](https://docs.kosli.com/terraform-reference/resources/policy_attachment)
- [kosli_control](https://docs.kosli.com/terraform-reference/resources/control)
- [Terraform Registry: kosli-dev/kosli](https://registry.terraform.io/providers/kosli-dev/kosli/latest/docs)
