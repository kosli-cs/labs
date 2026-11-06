# Lab 4: Release Controls and Compliance

## Learning Goals

- Understand Flow Templates and how they define compliance requirements
- Update an existing Flow to enforce specific attestations
- Understand the difference between compliant and non-compliant Trails
- Use `kosli assert artifact` to gate deployments based on compliance status

## Introduction

In the previous labs, you've been recording evidence (attestations) for your builds. However, recording evidence is only half the battle. You also need to ensure that the *required* evidence is actually present before allowing a release to proceed.

**Flow Templates** define the "shape" of a compliant release. They specify:

- Which artifacts are expected
- Which attestations are required for each artifact
- Which attestations are required for the Trail itself

When a Trail is evaluated against its Flow Template, Kosli determines if it is **Compliant** or **Non-Compliant**.

By using the `kosli assert artifact` command in your pipeline, you can automatically block deployments that don't meet your compliance standards.

## Prerequisites

- Completed [Lab 3: Build Controls and Attestations](lab-03-build-controls.md)
- CI/CD pipeline successfully sending attestations to Kosli

## Exercise

### Overview

In this lab, you will:

- Define a Flow Template that requires Unit Tests and an SBOM
- Update your existing Flow with these requirements
- Verify that your current pipeline is compliant
- Add a "Release Gate" step to your pipeline using `kosli assert artifact`
- (Optional) Test what happens when requirements are not met

### Step-by-step instructions

#### 1. Define Compliance Requirements

We can tell Kosli what attestations a "good" release looks like.

We do this by defining a template YAML file.

Create a file named `flow-template.yaml` in the root of your repository:

```yaml
version: 1
trail:
  artifacts:
    - name: application
      attestations:
        - name: unit-tests
          type: junit
    - name: docker-image
      attestations:
        - name: sbom
          type: generic
```

This template matches the structure of the attestations we set up in Lab 3:

1. An `application` artifact which must have `unit-tests`.
2. A `docker-image` artifact which must have an `sbom`.

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

#### 3. Gate the Release

Now that we have rules, let's enforce them! We will add a step before deployment that checks if the artifacts are compliant.

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

This command asks Kosli: *"Is this artifact (and its trail) compliant?"*

- **Yes**: means that all attestations and artifacts in the template is pressent **and** none of the attestations made to the trail are non-compliant.
  - The command exits with 0, and the pipeline continues to deploy.
- **No**: means that either one or more attestations and artifacts in the template is not pressent **or** one of the attestations made to the trail are non-compliant.
  - The command exits with 1, failing the pipeline and preventing deployment.

See [kosli assert artifact](https://docs.kosli.com/client_reference/kosli_assert_artifact/) for more details.

#### 4. Test the Release Gate

1. Commit the `flow-template.yaml` and the changes to `.github/workflows/full-pipeline.yaml`:

```bash
git add flow-template.yaml .github/workflows/full-pipeline.yaml
git commit -m "Add Flow Template and Release Gate"
git push origin main
```

2. Watch the GitHub Actions workflow run.
3. The `Create/Update Flow` step will update your Flow definition.
4. The build and attestations will proceed as normal.
5. The `Assert Compliance` step in the `Deploy` job will check the status.
6. Since you are providing all required attestations, the gate should pass (Green).

#### 5. Verify in Kosli

1. Go to [app.kosli.com](https://app.kosli.com).
2. Navigate to your Flow (`labs-pipeline`).
3. Click on the latest Trail.
4. You should see the **Compliance** status is **COMPLIANT** (Green).
5. You can see the template requirements listed and checked off.

#### 6. (Optional) Test Non-Compliance

To see the gate in action, you can simulate a failure.

1. Edit `flow-template.yaml` to require a non-existent attestation:

```yaml
# ... existing content ...
    - name: docker-image
      attestations:
        - name: sbom
          type: generic
        - name: performance-test  # We haven't implemented this yet!
          type: generic
```

2. Commit and push.
3. Watch the pipeline.
4. The `Assert Compliance` step should **fail**, preventing the `Deploy to production` step from running.
5. In the Kosli UI, the Trail will be marked **NON-COMPLIANT**.

> :bulb: Don't forget to revert this change to make your pipeline green again!

### Verification Checklist

Before moving to the next lab, ensure you have:

- ✅ Created `flow-template.yaml`
- ✅ Updated the workflow to apply the template
- ✅ Added `kosli assert artifact` to the Deploy job
- ✅ Verified that a fully attested build passes the gate
- ✅ Verified that the Trail shows as "COMPLIANT" in the Kosli UI

### Clean up

If you did the optional non-compliance test, make sure to revert `flow-template.yaml` to its working state.

## Next Steps

In [Lab 5: Runtime Controls](lab-05-runtime-controls.md), you'll learn how to create environments, snapshot what's running in production, and enforce compliance policies.

## Resources

- [Kosli Flows Documentation](https://docs.kosli.com/getting_started/flows/)
- [Flow Templates](https://docs.kosli.com/getting_started/flows/#templates)
- [kosli assert artifact CLI Reference](https://docs.kosli.com/client_reference/kosli_assert_artifact/)
