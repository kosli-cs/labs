# Lab 3: Build Controls and Attestations

## Learning Goals

- Understand what attestations are and why they matter for compliance
- Attest artifacts to Kosli
- Attach test results (JUnit) as attestations
- Attach Software Bill of Materials (SBOM) as attestations
- Integrate attestation commands into your CI/CD pipeline

## Introduction

**Attestations** are how you record facts about your software supply chain in Kosli.

They are immutable pieces of evidence that prove certain activities occurred - like tests passing, security scans completing, or artifacts being built.

Kosli has different attestation types:
A few examples:

- Commons like: `artifact`,`generic`
- Tool specific: `junit`,`snyk`
- Custom: Types that you define yourself.

Each attestation is linked to a Trail and optionally to a specific artifact. This creates an auditable chain of evidence showing what happened during your software delivery process.

### Understanding artifact fingerprints

Kosli identifies artifacts by their SHA256 fingerprint (hash). This fingerprint uniquely identifies the artifact regardless of where it's stored or what it's named. The Kosli CLI can automatically calculate fingerprints for:

- **Files**: JAR files, binaries, etc. (`--artifact-type file`)
- **Directories**: Source code, build outputs (`--artifact-type dir`)
- **Docker images**: From local Docker daemon (`--artifact-type docker`)
- **OCI images**: From container registries (`--artifact-type oci`)

> :bulb: Using fingerprints ensures you're tracking the exact artifact, not just its name or tag.

See [Artifacts documentation](https://docs.kosli.com/getting_started/artifacts/) for more details.

## Prerequisites

- Completed [Lab 2: Flows and Trails](lab-02-flows-and-trails.md)
- Kosli CLI installed and configured
- Your copy of the labs repository with Flow and Trail creation working
- Understanding of your application's build process

## Exercise

### Overview

In this lab, you will:

- Attest the Java application artifact (JAR file) to Kosli
- Attest the Docker container image to Kosli
- Attach JUnit test results as attestations
- Generate and attest an SBOM (Software Bill of Materials)
- Create shell scripts to integrate attestations into your workflow
- View all attestations in the Kosli web interface

### Step-by-step instructions

#### Attest the application artifact

Your build process creates a JAR file in `app/build/libs/`. Let's attest it by adding a step to the `Build` job in `.github/workflows/full-pipeline.yaml`.

Add this step after the "Build application" step:

```yaml
      - name: Attest application artifact
        run: |
          JAR_FILE=$(ls app/build/libs/app-*.jar)
          kosli attest artifact ${JAR_FILE} \
            --artifact-type file \
            --flow ${APP_NAME}-pipeline \
            --trail ${GIT_COMMIT} \
            --name application \
            --build-url ${BUILD_URL} \
            --commit-url ${COMMIT_URL}
```

The `--name application` parameter gives this artifact a logical name in your Flow. This name will be used to attach other attestations (like tests) to this specific artifact.

See [kosli attest artifact](https://docs.kosli.com/client_reference/kosli_attest_artifact/) for more details.

#### Attest JUnit test results

Your pipeline runs tests that produce JUnit XML results. Let's attest them by adding a step to the `Build` job in `.github/workflows/full-pipeline.yaml`.

Add this step after the "Test" step:

```yaml
      - name: Attest JUnit test results
        run: |
          kosli attest junit \
            --flow ${APP_NAME}-pipeline \
            --trail ${GIT_COMMIT} \
            --name application.unit-tests \
            --results-dir app/build/test-results/test/
```

The `--name application.unit-tests` links this attestation to the `application` artifact we attested earlier. Kosli automatically analyzes the JUnit XML to determine if tests passed or failed.

> :bulb: The dot notation (artifact.attestation) tells Kosli this attestation belongs to a specific artifact. Attestations without dots belong to the Trail itself.

See [kosli attest junit](https://docs.kosli.com/client_reference/kosli_attest_junit/) for more details.

#### Attest the Docker image

After building the Docker image, attest it to Kosli by adding steps to the `Docker-image` job in `.github/workflows/full-pipeline.yaml`.

Add these steps after the "push docker" step:

```yaml
    - name: Setup Kosli CLI
      uses: kosli-dev/setup-cli-action@v5
      with:
        version:
          2.54.0
    - name: Attest Docker image
      run: |
        IMAGE_NAME="ghcr.io/${IMAGE}:latest"
        kosli attest artifact ${IMAGE_NAME} \
          --artifact-type oci \
          --flow ${APP_NAME}-pipeline \
          --trail ${GIT_COMMIT} \
          --name docker-image \
          --build-url ${BUILD_URL} \
          --commit-url ${COMMIT_URL} \
          --registry-username ${{ github.actor }} \
          --registry-password ${{ secrets.GITHUB_TOKEN }}
```

Using `--artifact-type oci` tells Kosli to fetch the image manifest directly from the container registry without needing Docker locally. This is more reliable in CI environments.

> :bulb: You can attest both the JAR and Docker image, or just the Docker image. Both approaches are valid - it depends on what you consider your deployable artifact.

#### Generate and attest SBOM

Your workflow already generates an SBOM using Anchore. Let's attest it by adding steps to the `Docker-image` job in `.github/workflows/full-pipeline.yaml`.

Add these steps after the "Generate SBOM for the docker image" step:

```yaml
    - name: Attest SBOM
      run: |
        IMAGE_NAME="ghcr.io/${IMAGE}:latest"
        kosli attest generic \
          --flow ${APP_NAME}-pipeline \
          --trail ${GIT_COMMIT} \
          --name docker-image.sbom \
          --artifact-type oci ${IMAGE_NAME} \
          --attachments sbom.spdx.json \
          --registry-username ${{ github.actor }} \
          --registry-password ${{ secrets.GITHUB_TOKEN }}

```

> :bulb: Generic attestations allow you to record any fact.

The SBOM attestation is linked to the `docker-image` artifact. Kosli stores the SBOM in its Evidence Vault for future reference.

> :bulb: An SBOM (Software Bill of Materials) lists all components and dependencies in your software. It's crucial for tracking vulnerabilities and license compliance.

See [kosli attest sbom](https://docs.kosli.com/client_reference/kosli_attest_sbom/) for more details and [Attestations documentation](https://docs.kosli.com/getting_started/attestations/) for conceptual understanding.

#### Verify the workflow integration

Ensure your `.github/workflows/full-pipeline.yaml` now includes the new Kosli steps in the `Build` and `Docker-image` jobs.

#### Test the attestations

1. Commit the changes to your workflow file:

```bash
git add .github/workflows/full-pipeline.yaml
git commit -m "Add Kosli attestation steps"
git push origin main
```

2. Watch the GitHub Actions workflow run
3. Verify each attestation step completes successfully
4. Check the logs for Kosli CLI output showing fingerprints and attestation confirmations

#### View attestations in Kosli

1. Log in to [app.kosli.com](https://app.kosli.com)
2. Navigate to your Flow (labs-pipeline)
3. Click on the latest Trail (your commit SHA)
4. You should see:
   - **Artifacts**: The JAR file and Docker image with their fingerprints
   - **Attestations**: Unit tests, SBOM attached to artifacts
   - **Timeline**: When each attestation was recorded
5. Click on individual attestations to view details:
   - JUnit results showing test counts and any failures
   - SBOM showing dependencies and components
   - Links to build URLs and commit URLs

> :bulb: The Trail view provides a complete audit trail of everything that happened for this commit, with immutable evidence stored in Kosli.

#### Optional: Attest vulnerability scans

Your workflow already runs Trivy security scans. While not creating an attestation yet, you could extend this lab by attesting the scan results:

```bash
# Example for future enhancement
# Replace gh_user with your GitHub username
export DOCKER_IMAGE="<gh_user>/labs"

kosli attest generic \
  --flow labs-pipeline \
  --trail $(git rev-parse HEAD) \
  --name docker-image.security-scan \
  --artifact-type oci ghcr.io/${DOCKER_IMAGE}:latest \
  --compliant=true \
  --description "Trivy scan completed"
```

> :bulb: Generic attestations allow you to record any fact. In production, you'd parse the Trivy results and set `--compliant` based on severity thresholds.

### Verification Checklist

Before moving to the next lab, ensure you have:

- ✅ Updated workflow with attestation steps
- ✅ Workflow runs successfully with all attestation steps passing
- ✅ Can see artifacts in the Kosli Trail view with their fingerprints
- ✅ Can see JUnit test results attached to the application artifact
- ✅ Can see SBOM attached to the Docker image artifact
- ✅ Understand how attestations create an audit trail

If anything did not go according to plan, you can reference our solution pipeline in [pipelines/03-complete.yaml](pipelines\03-complete.yaml)

## Next Steps

lab-04-release-controls.md
In [Lab 4: Release Controls](lab-04-release-controls.md), you'll learn how to check your artifact for compliance, just before deploying it to production.

## Resources

- [Kosli Attestations Documentation](https://docs.kosli.com/getting_started/attestations/)
- [Kosli Artifacts Documentation](https://docs.kosli.com/getting_started/artifacts/)
- [kosli attest artifact CLI Reference](https://docs.kosli.com/client_reference/kosli_attest_artifact/)
- [kosli attest junit CLI Reference](https://docs.kosli.com/client_reference/kosli_attest_junit/)
- [kosli attest sbom CLI Reference](https://docs.kosli.com/client_reference/kosli_attest_sbom/)
- [Attestation Types](https://docs.kosli.com/getting_started/attestations/#attestation-types)
