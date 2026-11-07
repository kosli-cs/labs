# Lab 4: Release Controls and Trail Compliance

## Learning Goals

- Understand Flow Templates and how they define compliance requirements
- Update an existing Flow to enforce specific attestations
- Understand the difference between compliant and non-compliant Trails
- Use `kosli assert artifact` to gate deployments based on compliance status

## Introduction

In the previous labs, you've been recording evidence (Attestations) for your builds. Recording evidence is only part of the picture.

**Release controls** validate that software is ready for production, so you also need to ensure that the *required* evidence is actually present before allowing a deployment to proceed. See [Controls](https://docs.kosli.com/understand_kosli/controls) for more on release controls.

A **Flow Template** defines what artifacts and attestations a trail must have to be compliant. 

It lists:

- Which artifacts are expected in the Trail
- Which attestations are required for each artifact
- Which attestations are required for the Trail itself

Kosli runs a **Trail Evaluation** to check each Trail against its Flow Template, and determines whether it is **Compliant** or **Non-compliant**.

By adding `kosli assert artifact` to your pipeline as a **deployment gate**, you can automatically block deployments that don't meet your compliance requirements.

## Prerequisites

- Completed [Lab 3: Build Controls and Attestations](lab-03-build-controls.md)
- CI/CD pipeline successfully sending attestations to Kosli

## Exercise

### Overview

In this lab, you will:

- Define a Flow Template that requires unit tests and a vulnerability scan
- Update your existing Flow with these requirements
- Verify that your current pipeline is compliant
- Add a deployment gate step to your pipeline using `kosli assert artifact`
- (Optional) Test what happens when requirements are not met

### Step-by-step instructions

#### 1. Define Compliance Requirements

We can tell Kosli what a compliant Trail looks like.

We do this by defining a template YAML file.

Create a file named `flow-template.yaml` in the root of your repository:

```yaml
# yaml-language-server: $schema=https://docs.kosli.com/schemas/flow-template/v1.json
version: 1
trail:
  artifacts:
    - name: application
      attestations:
        - name: unit-tests
          type: junit
    - name: docker-image
      attestations:
        - name: security-scan
          type: generic
```

This template matches the structure of the attestations we set up in Lab 3:

1. An `application` artifact which must have `unit-tests`.
2. A `docker-image` artifact which must have a `security-scan`.

> :bulb: If you also attested the SBOM in the optional part of Lab 3, you can require it too by adding `- name: sbom` with `type: sbom` under the `docker-image` attestations. If you didn't, leave it out: it is used in the optional non-compliance test below.

#### 2. Update the Flow

Now, let's update your existing Flow to use this template. We'll add a step to your workflow to ensure the Flow definition is always up to date with your code.

Open `.github/workflows/full-pipeline.yaml` and find the `Create/Update Flow` step (added in Lab 2). Update it to use the template file:

```yaml
      - name: Create/Update Flow
        run: |
          kosli create flow ${APP_NAME}-pipeline \
            --description "CI/CD pipeline for ${APP_NAME} application" \
            --template-file flow-template.yaml
```

> :bulb: We removed `--use-empty-template` and replaced it with `--template-file flow-template.yaml`.

#### 3. Add a deployment gate

Now that we have rules, let's enforce them! We will add a step before deployment that asserts that the artifact is compliant.

In `.github/workflows/full-pipeline.yaml`, find the `Deploy` job. Add the assertion step **before** the "Deploy to production" step:

```yaml
    - name: Setup Kosli CLI
      uses: kosli-dev/setup-cli-action@v5
      with:
        version:
          2.54.0
    - name: Assert Compliance
      run: |
        IMAGE_NAME="ghcr.io/${IMAGE}:latest"
        kosli assert artifact ${IMAGE_NAME} \
          --artifact-type oci \
          --flow ${APP_NAME}-pipeline
```

This command asks Kosli: *"Is this artifact (and its Trail) compliant?"* Because neither `--environment` nor `--policy` is given, Kosli asserts against the **Flow Template** of the Flows the artifact appears in, and `--flow` narrows the lookup to your Flow.

- **Compliant**: all artifacts and attestations in the template are present, **and** none of the attestations made to the Trail are non-compliant.
  - The command exits with 0, and the pipeline continues to deploy.
- **Non-compliant**: one or more artifacts or attestations in the template are missing, **or** one of the attestations made to the Trail is non-compliant.
  - The command exits with 1, failing the pipeline and preventing deployment.

See [kosli assert artifact](https://docs.kosli.com/client_reference/kosli_assert_artifact/) and [Enforce policies](https://docs.kosli.com/getting_started/enforce_policies) for more details.

#### 4. Test the deployment gate

1. Commit the `flow-template.yaml` and the changes to `.github/workflows/full-pipeline.yaml`:

```bash
git add flow-template.yaml .github/workflows/full-pipeline.yaml
git commit -m "Add Flow Template and deployment gate"
git push origin main
```

2. Watch the GitHub Actions workflow run.
3. The `Create/Update Flow` step will update your Flow definition.
4. The build and attestations will proceed as normal.
5. The `Assert Compliance` step in the `Deploy` job will check the status.
6. Since you are providing all required attestations, the gate should pass.

#### 5. Verify in Kosli

1. Go to [app.kosli.com](https://app.kosli.com).
2. Navigate to your Flow (`labs-pipeline`).
3. Click on the latest Trail.
4. The Trail's compliance status should be **Compliant**.
5. You can see the Flow Template requirements listed and checked off.

#### 6. (Optional) Test Non-Compliance

To see the gate in action, you can simulate a failure.

1. Edit `flow-template.yaml` to require the SBOM from the optional part of Lab 3, which your pipeline doesn't attest:

```yaml
# ... existing content ...
    - name: docker-image
      attestations:
        - name: security-scan
          type: generic
        - name: sbom  # Not attested by the pipeline!
          type: sbom
```

> :bulb: If you did attest the SBOM in Lab 3, require an attestation you haven't made instead, e.g. `- name: performance-test` with `type: generic`.

2. Commit and push.
3. Watch the pipeline.
4. The `Assert Compliance` step should **fail**, preventing the `Deploy to production` step from running.
5. In the Kosli app, the Trail will be marked **Non-compliant**.

> :bulb: Don't forget to revert this change to make your pipeline green again!

### Verification Checklist

Before moving to the next lab, ensure you have:

- ✅ Created `flow-template.yaml`
- ✅ Updated the workflow to apply the template
- ✅ Added `kosli assert artifact` to the Deploy job
- ✅ Verified that a fully attested build passes the gate
- ✅ Verified that the Trail shows as **Compliant** in the Kosli app

If anything did not go according to plan, you can reference our solution pipeline in [pipelines/04-complete.yaml](pipelines/04-complete.yaml) and the Flow Template in [pipelines/04-flow-template.yaml](pipelines/04-flow-template.yaml).

### Clean up

If you did the optional non-compliance test, make sure to revert `flow-template.yaml` to its working state.

## Next Steps

In [Lab 5: Runtime Controls](lab-05-runtime-controls.md), you'll learn how to create environments, snapshot what's running in production, and enforce Environment Policies.

## Resources

- [Kosli Flows Documentation](https://docs.kosli.com/getting_started/flows/)
- [Flow Templates](https://docs.kosli.com/getting_started/flows#flow-template)
- [Flow Template reference](https://docs.kosli.com/template-reference/flow_template)
- [Enforce policies](https://docs.kosli.com/getting_started/enforce_policies)
- [kosli assert artifact CLI Reference](https://docs.kosli.com/client_reference/kosli_assert_artifact/)
