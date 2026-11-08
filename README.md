# Kosli Learning Labs

This repository contains hands-on learning labs to help DevOps engineers, Platform engineers, and software developers get familiar with [Kosli](https://kosli.com) - a compliance automation and change observability platform. Think of it as a flight recorder for your software delivery lifecycle (SDLC).

## About These Labs

These labs provide a progressive, practical introduction to Kosli's core features. You'll learn how to track your software delivery process from build through deployment, define compliance requirements, and record and enforce the controls in your software delivery.

Each lab builds on the previous one, taking you from initial setup through controls, runtime compliance enforcement and administration as code.

## Prerequisites

- A GitHub account
- Basic familiarity with Git, CI/CD concepts, and command line
- No prior Kosli experience required
- The Admin role in your Kosli Organization, with the Controls feature (beta) enabled (Labs 4, 7 and 8)
- [Terraform](https://developer.hashicorp.com/terraform/install) 1.10 or later (Lab 8)

## Lab Structure

The lab titles follow [How Kosli works](https://docs.kosli.com/understand_kosli/how_kosli_works), so you can read the matching section of the docs before each lab.

### [Lab 1: Get Ready](lab-01-get-ready.md)

Log in to Kosli and verify the sample application pipeline.

**You'll learn:**

- Logging in to Kosli
- Creating a copy of the sample repository
- Understanding the existing CI/CD pipeline

### [Lab 2: Modeling your process: Flows and Trails](lab-02-flows-and-trails.md)

Install the Kosli CLI and start tracking your delivery process.

**You'll learn:**

- Installing and configuring the Kosli CLI
- Creating Flows to represent your CI/CD pipeline
- Beginning Trails to track individual executions
- Integrating Kosli into your GitHub Actions workflow

### [Lab 3: Recording evidence: Artifacts and Attestations](lab-03-artifacts-and-attestations.md)

Record evidence about your artifacts and build process.

**You'll learn:**

- Attesting artifacts (binaries and Docker images)
- Attaching JUnit test results
- Attesting vulnerability scan results
- Understanding binary provenance and the Evidence Vault

### [Lab 4: Implementing controls: Controls and Decisions](lab-04-controls-and-decisions.md)

Turn the evidence you record into decisions against named controls.

**You'll learn:**

- What a control is, and how your evidence maps to controls
- Creating controls in Kosli
- Testing and publishing a policy written with Ergo
- Recording decisions against controls from your pipeline

### [Lab 5: Defining compliance: Flow Templates and Deployment Gates](lab-05-flow-templates-and-gates.md)

Define what a compliant Trail must contain, and gate your deployment on it.

**You'll learn:**

- How Flow Templates define compliance requirements, including control decisions
- How to update an existing Flow to enforce specific attestations
- The difference between compliant and non-compliant Trails
- How to use `kosli assert artifact` to gate deployments based on compliance status

### [Lab 6: Monitoring runtime: Environments, Snapshots, and Policies](lab-06-environments-and-policies.md)

Track what's running in production and require your controls in an Environment Policy.

**You'll learn:**

- Creating Kosli Environments
- Snapshotting Docker environments
- Defining Environment Policies that require controls
- Gating deployments on an Environment
- Viewing compliance state

### [Lab 7: Writing policies: Ergo](lab-07-writing-policies-with-ergo.md)

Write your own Ergo policy for a new control.

**You'll learn:**

- Reading the input a policy receives
- Writing Ergo subjects, requirements, checks and params
- Reading an Ergo report and its violations
- Publishing and pinning policy versions

### [Lab 8: Kosli administration: Terraform](lab-08-terraform-administration.md)

Manage your Kosli setup as code with the Kosli Terraform provider.

**You'll learn:**

- Configuring the Kosli Terraform provider
- Creating a service account and API key for CI
- Importing existing Kosli resources into Terraform
- Moving resource management out of your pipeline

## Getting Started

Start with [Lab 1: Get Ready](lab-01-get-ready.md) and work through the labs sequentially. Each lab includes:

- Clear learning objectives
- Step-by-step instructions
- Verification checklists
- Links to relevant Kosli documentation

## Resources

- [Kosli Documentation](https://docs.kosli.com/)
- [What is Kosli?](https://docs.kosli.com/understand_kosli/what_is_kosli)
- [How Kosli works](https://docs.kosli.com/understand_kosli/how_kosli_works)
- [Kosli Glossary](https://docs.kosli.com/understand_kosli/glossary)
- [Kosli CLI Reference](https://docs.kosli.com/client_reference/overview)
- [Kosli Website](https://kosli.com)

## Support

If you encounter issues or have questions:

- Check the [Kosli Documentation](https://docs.kosli.com/)
- Review the verification checklist in each lab
- Contact [Kosli Support](https://www.kosli.com/contact/)

## License

See [LICENSE](LICENSE) file for details.
