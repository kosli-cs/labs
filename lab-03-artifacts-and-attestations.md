# Lab 3: Recording evidence: Artifacts and Attestations

## Learning Goals

- Understand what attestations are and why they matter for compliance
- Attest artifacts to Kosli
- Attach test results (JUnit) as attestations
- Attach vulnerability scan results as attestations
- Integrate attestation commands into your CI/CD pipeline

## Introduction

In this lab you record evidence about your software: the artifacts you build, and facts about them such as test results and vulnerability scans. In Lab 4 you'll turn this evidence into decisions against **controls**.

An **Attestation** records that a specific control was executed and captures its result. Attestations are how you record the facts you care about in your software supply chain: immutable evidence that certain activities occurred, like tests passing, security scans completing, or artifacts being built.

Kosli supports two kinds of attestation types:

- **Built-in types** for common controls, such as JUnit, Snyk, SonarCloud, pull requests and Jira. Use the `generic` type for controls that do not require automated evaluation.
- **Custom types** that you define yourself with [`kosli create attestation-type`](https://docs.kosli.com/client_reference/kosli_create_attestation-type/), evaluated with jq rules.

Each Attestation is linked to a Trail and optionally to a specific Artifact. This creates an auditable chain of evidence showing what happened during your software delivery process.

### Artifact fingerprints and binary provenance

Kosli identifies Artifacts by their SHA256 fingerprint. Names and tags can change (a `latest` tag can point to different images over time), while a fingerprint cannot. This is what gives each artifact its **binary provenance**: a tamper-proof link from the Trail where it was built to the Environments where it later runs. The Kosli CLI can automatically calculate fingerprints for:

- **Files**: JAR files, binaries, etc. (`--artifact-type file`)
- **Directories**: Source code, build outputs (`--artifact-type dir`)
- **Docker images**: From local Docker daemon (`--artifact-type docker`)
- **OCI images**: From container registries (`--artifact-type oci`)

> :bulb: Using fingerprints ensures you're tracking the exact artifact, not just its name or tag.

See [Artifacts documentation](https://docs.kosli.com/getting_started/artifacts/) for more details.

## Prerequisites

- Completed [Lab 2: Modeling your process: Flows and Trails](lab-02-flows-and-trails.md)
- Kosli CLI installed and configured
- Your copy of the labs repository with Flow and Trail creation working
- Understanding of your application's build process

## Exercise

### Overview

In this lab, you will:

- Attest the Java application artifact (JAR file) to Kosli
- Attest the Docker container image to Kosli
- Attach JUnit test results as attestations
- Attest the results of a vulnerability scan
- Add attestation steps to your GitHub Actions workflow
- View all attestations in the Kosli app

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

The `--name application` parameter is the artifact's `name`, which the Flow Template will reference in Lab 5. The same name is used to attach other attestations (like tests) to this specific artifact.

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

#### Attest the vulnerability scan

Your workflow already scans the Docker image for vulnerabilities with Trivy, in the `Security-scan` job. Right now the results only end up in the job log. Let's save them to a file and attest them to Kosli as evidence that the scan was performed, linked to the `docker-image` artifact.

In the `Security-scan` job of `.github/workflows/full-pipeline.yaml`, change the "Run Trivy vulnerability scanner" step so it writes its results to a JSON file:

```yaml
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@ed142fd0673e97e23eac54620cfb913e5ce36c25 # v0.36.0
      with:
        image-ref: 'ghcr.io/${{ env.IMAGE }}:latest'
        format: 'json'
        output: 'trivy-results.json'
        #exit-code: '1' #Defaults to 0 meaning that the action will not fail the build if vulnerabilities are found
        ignore-unfixed: true
        vuln-type: 'os,library'
        severity: 'CRITICAL,HIGH'
```

> :bulb: We changed `format` from `table` to `json` and added `output`, so the results end up in a file we can attach to the attestation.

Then add these steps after it:

```yaml
    - name: Setup Kosli CLI
      uses: kosli-dev/setup-cli-action@v5
      with:
        version:
          2.54.0
    - name: Attest vulnerability scan
      run: |
        IMAGE_NAME="ghcr.io/${IMAGE}:latest"
        kosli attest generic \
          --flow ${APP_NAME}-pipeline \
          --trail ${GIT_COMMIT} \
          --name docker-image.security-scan \
          --artifact-type oci ${IMAGE_NAME} \
          --compliant=true \
          --description "Trivy vulnerability scan" \
          --attachments trivy-results.json \
          --annotate scan_tool=trivy \
          --registry-username ${{ github.actor }} \
          --registry-password ${{ secrets.GITHUB_TOKEN }}
```

The `--name docker-image.security-scan` links this attestation to the `docker-image` artifact. Kosli stores `trivy-results.json` in its Evidence Vault, and the `scan_tool` annotation shows which scanner produced it.

> :bulb: Generic attestations allow you to record any fact. Here, `--compliant=true` records that the scan was performed, and the full results are available as evidence.

See [kosli attest generic](https://docs.kosli.com/client_reference/kosli_attest_generic/) for more details and [Attestations documentation](https://docs.kosli.com/getting_started/attestations/) for conceptual understanding.

#### Verify the workflow integration

Ensure your `.github/workflows/full-pipeline.yaml` now includes the new Kosli steps in the `Build`, `Docker-image` and `Security-scan` jobs.

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
   - **Attestations**: Unit tests and the vulnerability scan attached to artifacts
   - **Timeline**: When each attestation was recorded
5. Click on individual attestations to view details:
   - JUnit results showing test counts and any failures
   - The vulnerability scan with its annotations and the attached `trivy-results.json`
   - Links to build URLs and commit URLs

> :bulb: The Trail view provides a complete audit trail of everything that happened for this commit, with immutable evidence stored in Kosli.

#### Optional: Attest the SBOM

Your workflow also generates an SBOM (Software Bill of Materials) of the Docker image with Anchore, in the "Generate SBOM for the docker image" step of the `Docker-image` job. SBOM is a built-in attestation type in Kosli, so you can extend this lab by attesting it with `kosli attest sbom`. Add this step after the "Generate SBOM for the docker image" step:

```yaml
    - name: Attest SBOM
      run: |
        IMAGE_NAME="ghcr.io/${IMAGE}:latest"
        kosli attest sbom ${IMAGE_NAME} \
          --artifact-type oci \
          --flow ${APP_NAME}-pipeline \
          --trail ${GIT_COMMIT} \
          --name docker-image.sbom \
          --sbom-file sbom.spdx.json \
          --registry-username ${{ github.actor }} \
          --registry-password ${{ secrets.GITHUB_TOKEN }}
```

Kosli reads the SBOM's format, creation time, the tools that produced it, the subject it describes and how many packages it lists, and stores the file in its Evidence Vault. Nothing in the SBOM is checked against the artifact: the attestation records what the SBOM claims.

> :bulb: An SBOM lists all components and dependencies in your software. It's crucial for tracking vulnerabilities and license compliance.

See [kosli attest sbom](https://docs.kosli.com/client_reference/kosli_attest_sbom/) for more details.

### Verification Checklist

Before moving to the next lab, ensure you have:

- ✅ Updated workflow with attestation steps
- ✅ Workflow runs successfully with all attestation steps passing
- ✅ Can see artifacts in the Kosli Trail view with their fingerprints
- ✅ Can see JUnit test results attached to the application artifact
- ✅ Can see the vulnerability scan attached to the Docker image artifact
- ✅ Understand how Attestations and binary provenance create an audit trail

If anything did not go according to plan, you can reference our solution pipeline in [pipelines/03-complete.yaml](pipelines/03-complete.yaml)

## Next Steps

In [Lab 4: Implementing controls: Controls and Decisions](lab-04-controls-and-decisions.md), you'll turn the evidence you just recorded into decisions against controls.

## Resources

- [Kosli Attestations Documentation](https://docs.kosli.com/getting_started/attestations/)
- [Kosli Artifacts Documentation](https://docs.kosli.com/getting_started/artifacts/)
- [kosli attest artifact CLI Reference](https://docs.kosli.com/client_reference/kosli_attest_artifact/)
- [kosli attest junit CLI Reference](https://docs.kosli.com/client_reference/kosli_attest_junit/)
- [kosli attest generic CLI Reference](https://docs.kosli.com/client_reference/kosli_attest_generic/)
- [Attestation Types](https://docs.kosli.com/getting_started/attestations/#attestation-types)
- [Controls](https://docs.kosli.com/understand_kosli/controls)
- [kosli attest sbom CLI Reference](https://docs.kosli.com/client_reference/kosli_attest_sbom/)