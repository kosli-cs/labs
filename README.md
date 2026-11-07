# Kosli Learning Labs

This repository contains hands-on learning labs to help DevOps engineers, Platform engineers, and software developers get familiar with [Kosli](https://kosli.com) - a compliance automation and change observability platform. Think of it as a flight recorder for your software delivery lifecycle (SDLC).

## About These Labs

These labs provide a progressive, practical introduction to Kosli's core features. You'll learn how to track your software delivery process from build through deployment, define compliance requirements, and record and enforce the controls in your software delivery.

Each lab builds on the previous one, taking you from initial setup through runtime compliance enforcement.

## Prerequisites

- A GitHub account
- Basic familiarity with Git, CI/CD concepts, and command line
- No prior Kosli experience required

## Lab Structure

### [Lab 1: Get Ready](lab-01-get-ready.md)

Log in to Kosli and verify the sample application pipeline.

**You'll learn:**

- Logging in to Kosli
- Creating a copy of the sample repository
- Understanding the existing CI/CD pipeline

### [Lab 2: Flows and Trails](lab-02-flows-and-trails.md)

Install the Kosli CLI and start tracking your delivery process.

**You'll learn:**

- Installing and configuring the Kosli CLI
- Creating Flows to represent your CI/CD pipeline
- Beginning Trails to track individual executions
- Integrating Kosli into your GitHub Actions workflow

### [Lab 3: Build Controls and Attestations](lab-03-build-controls.md)

Record evidence about your artifacts and build process.

**You'll learn:**

- Attesting artifacts (binaries and Docker images)
- Attaching JUnit test results
- Attesting vulnerability scan results
- Understanding binary provenance and the Evidence Vault

### [Lab 4: Release Controls and Compliance](lab-04-release-controls.md)

Record evidence about your release process and enforce deployment gates.

**You'll learn:**

- How to use Flow Templates and how they define compliance requirements
- How to update an existing Flow to enforce specific attestations
- The difference between compliant and non-compliant Trails
- How to use `kosli assert artifact` to gate deployments based on compliance status

### [Lab 5: Runtime Controls](lab-05-runtime-controls.md)

Track what's running in production and enforce Environment Policies.

**You'll learn:**

- Creating Kosli Environments
- Snapshotting Docker environments
- Defining Environment Policies
- Enforcing policy requirements
- Viewing compliance status

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
