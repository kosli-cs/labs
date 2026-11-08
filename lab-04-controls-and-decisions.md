# Lab 4: Implementing controls: Controls and Decisions

## Learning Goals

- Understand what a control is, and how the evidence you already record maps to controls
- Create controls in Kosli
- Publish a policy that decides a control, written with Ergo
- Test a policy against your own Trail before publishing it
- Record decisions against controls from your CI/CD pipeline

## Introduction

In Lab 3 you recorded evidence: unit test results, a vulnerability scan and fingerprinted artifacts. Each of those is evidence that a **control** ran.

A **control** is a repeatable, verifiable activity that mitigates one or more risks in your software delivery. The [Controls](https://docs.kosli.com/understand_kosli/controls) page in the Kosli docs groups controls by the phase where they apply: build, release, runtime and lifecycle. Look at what you already have:

| Control | Phase | Risk mitigated | Evidence from Lab 3 |
|---|---|---|---|
| Quality assurance | Release | Vulnerable software in production | The `unit-tests` attestation on the `application` artifact |
| Vulnerability scanning | Release | Vulnerable software in production, supply chain compromise | The `security-scan` attestation on the `docker-image` artifact |
| Artifact binary provenance | Build | Supply chain compromise | The fingerprinted `application` and `docker-image` artifacts |

So far these are only attestations with tool-specific names. In this lab you make the controls themselves first-class in Kosli:

- A **control** is the named requirement your organization enforces, with a stable identifier like `LAB-001`. It is what auditors and compliance teams ask about.
- A **policy** is the rule that judges whether the evidence satisfies a control. You write it with [Ergo](https://ergo.kosli.com), an open source library maintained by Kosli that lets you write a policy's requirements as YAML sentences, or in plain Rego.
- A **decision** is the recorded outcome of evaluating a published policy against a Trail. Kosli runs the evaluation itself and records the decision as an attestation, with the policy version, the params and the result as evidence.

Recording a decision is kept separate from enforcing it. In this lab your pipeline *records* decisions. In Lab 5 and Lab 6 you *enforce* them before deployment.

> :information_source: Controls are a beta feature in Kosli and must be enabled for your Organization. Publishing a policy requires the Admin role in your Organization.

## Prerequisites

- Completed [Lab 3: Recording evidence: Artifacts and Attestations](lab-03-artifacts-and-attestations.md)
- Kosli CLI installed and configured with `KOSLI_API_TOKEN` and `KOSLI_ORG`
- At least one pipeline run where the `unit-tests` and `security-scan` attestations were recorded
- The Admin role in your Kosli Organization

## Exercise

### Overview

In this lab, you will:

- Create two controls: `LAB-001` Quality assurance and `LAB-002` Vulnerability scanning
- Look at the ready-made Ergo policy that ships with this repository
- Test the policy against your latest Trail
- Publish the policy to Kosli
- Add a `Controls` job to your workflow that records a decision for each control
- View the decisions in the Kosli app

### Step-by-step instructions

#### Create the controls

Create one control per requirement. The identifier is what decisions and Environment Policies refer to, so it should never change. The name and description can be changed later.

```bash
kosli create control LAB-001 \
  --name "Quality assurance" \
  --description "Every deployable artifact is built from code that passed its unit tests"

kosli create control LAB-002 \
  --name "Vulnerability scanning" \
  --description "Every deployable container image has been scanned for vulnerabilities"

# Verify they were created
kosli list controls
```

In the Kosli app, open **Controls** to see your new controls. They have no decisions yet.

See [kosli create control](https://docs.kosli.com/client_reference/kosli_create_control/) for more details.

#### Look at the policy

A decision comes from a policy. This repository already contains one in `policies/attestation-compliant/`. It answers a single question: *does this artifact in the Trail carry a recorded, compliant attestation with this name?*

The requirements are written as Ergo sentences in `policies/attestation-compliant/policy.ergo.yaml`:

```yaml
ergo_spec: v0.5
description: An attestation on an artifact in the trail is recorded and compliant
subjects:
  artifact:
    description: The artifact named by the artifact param
    from: trail.compliance_status.artifacts_statuses named by $params.artifact
  attestation:
    description: The attestation named by the attestation param, on that artifact
    from: artifact.attestations_statuses named by $params.attestation
requirements:
  attestation_compliant:
    description: The artifact carries a recorded, compliant attestation
    subject: attestation
    checks:
      recorded:
        description: The attestation is recorded on the artifact
        assert: status is "COMPLETE"
      compliant:
        description: The attestation is compliant
        assert: is_compliant is true
```

- **Subjects** are the things the policy checks. Here: the artifact named by the `artifact` param, and on that artifact, the attestation named by the `attestation` param.
- **Requirements** list the **checks** each subject must pass. Each check is one sentence, such as `is_compliant is true`.
- **Params** (`$params.artifact`, `$params.attestation`) are passed with every evaluation. That is why one policy can decide both controls: `LAB-001` checks `unit-tests` on `application`, and `LAB-002` checks `security-scan` on `docker-image`.

`policies/attestation-compliant/policy.rego` hands the requirements to Ergo and declares `allow`, which is Kosli's answer: allowed or denied. You don't need to change it. You'll write your own Ergo policy in Lab 7.

The policy also needs the Ergo library itself. Download a pinned release, so a new Ergo version can't change your policy unexpectedly:

```bash
curl -L --create-dirs -o policies/lib/ergo.rego \
  https://github.com/kosli-dev/ergo/releases/download/rego-v0.5.0/ergo.rego
```

> :bulb: The `ergo_spec` in the YAML must match the Ergo release: `rego-v0.5.0` reads `ergo_spec: v0.5`.

#### Test the policy against your Trail

Before publishing, evaluate the local files against your latest Trail. `--path` sends the files with the evaluation. Kosli runs them exactly as it will run the published policy, and records nothing:

```bash
kosli evaluate policy \
  --context trail=labs-pipeline/$(git rev-parse HEAD) \
  --path policies/attestation-compliant/ \
  --path policies/lib/ergo.rego \
  --params '{"artifact": "application", "attestation": "unit-tests"}'
```

> :warning: Use the commit SHA of a pipeline run that completed Lab 3, e.g. after `git pull`. The Trail must contain the attestations.

The command prints `RESULT: ALLOWED`. Now try an attestation that doesn't exist:

```bash
kosli evaluate policy \
  --context trail=labs-pipeline/$(git rev-parse HEAD) \
  --path policies/attestation-compliant/ \
  --path policies/lib/ergo.rego \
  --params '{"artifact": "application", "attestation": "integration-tests"}'
```

This time the result is `RESULT: DENIED`, with the violations explaining which check failed and why.

See [Test the policy](https://docs.kosli.com/tutorials/working_with_controls#test-the-policy) for more details.

#### Publish the policy

Only a published policy can record a decision. Publish it under the identifier `attestation-compliant`. `--input-schema trail` means the policy reads a single Trail:

```bash
kosli publish rego-policy attestation-compliant \
  --path policies/attestation-compliant/ \
  --path policies/lib/ergo.rego \
  --input-schema trail \
  --name "Attestation is compliant" \
  --comment "Initial version"
```

Kosli validates the policy and the command prints `valid`. Each publish stores a new version, and evaluations run the newest valid one.

> :bulb: Only Organization admins can publish policies. This keeps the judgment out of the hands of the team being judged: Kosli runs the evaluation and records the decision itself, so a pipeline cannot swap in its own policy or change the result on its way into Kosli.

See [kosli publish rego-policy](https://docs.kosli.com/client_reference/kosli_publish_rego-policy/) for more details.

#### Record decisions in CI

Now let your pipeline record a decision for each control on every run. The decision is about the artifact you deploy, so it is recorded with the fingerprint of the Docker image.

Add a new `Controls` job to `.github/workflows/full-pipeline.yaml`, for example just before the `Deploy` job. It runs after the `Build` and `Security-scan` jobs, so both attestations are recorded before the policy is evaluated:

```yaml
  Controls:
    runs-on: ubuntu-latest
    needs: [Build, Security-scan]
    steps:
    - name: Setup Kosli CLI
      uses: kosli-dev/setup-cli-action@v5
      with:
        version:
          2.54.0
    - name: Fingerprint Docker image
      run: |
        FINGERPRINT=$(kosli fingerprint ghcr.io/${IMAGE}:latest \
          --artifact-type oci \
          --registry-username ${{ github.actor }} \
          --registry-password ${{ secrets.GITHUB_TOKEN }})
        echo "FINGERPRINT=${FINGERPRINT}" >> $GITHUB_ENV
    - name: Decide LAB-001 Quality assurance
      run: |
        kosli evaluate policy \
          --context trail=${APP_NAME}-pipeline/${GIT_COMMIT} \
          --identifier attestation-compliant \
          --params '{"artifact": "application", "attestation": "unit-tests"}' \
          --control LAB-001 \
          --flow ${APP_NAME}-pipeline \
          --trail ${GIT_COMMIT} \
          --fingerprint ${FINGERPRINT}
    - name: Decide LAB-002 Vulnerability scanning
      run: |
        kosli evaluate policy \
          --context trail=${APP_NAME}-pipeline/${GIT_COMMIT} \
          --identifier attestation-compliant \
          --params '{"artifact": "docker-image", "attestation": "security-scan"}' \
          --control LAB-002 \
          --flow ${APP_NAME}-pipeline \
          --trail ${GIT_COMMIT} \
          --fingerprint ${FINGERPRINT}
```

Then add `Controls` to the `needs` of the `Deploy` job, so the decisions are recorded before deployment:

```yaml
  Deploy:
    runs-on: ubuntu-latest
    needs: [Docker-image, Security-scan, Component-test, Performance-test, Controls]
```

What the flags do:

- `--context` is the Trail to evaluate.
- `--identifier` is the published policy to run, and `--params` are the values it reads.
- `--control` records the outcome as a decision against that control, in the Trail given by `--flow` and `--trail`.
- `--fingerprint` says which artifact the decision is about. This is what lets an Environment Policy check, in Lab 6, that the artifact you deploy has a passing decision.

The decision is recorded as an attestation named `LAB-001-decision` and `LAB-002-decision` on the `docker-image` artifact.

> :bulb: The steps don't fail when a policy denies. Their job is to *record* the decision, whatever it is. Blocking a deployment is the job of `kosli assert artifact`, which you'll add in Lab 5. Add `--assert` if you want a denial to fail the step right away.

See [kosli evaluate policy](https://docs.kosli.com/client_reference/kosli_evaluate_policy/) and [Recording a decision against a control](https://docs.kosli.com/tutorials/working_with_controls#recording-a-decision-against-a-control) for more details.

#### Test the integration

1. Commit the changes to your workflow file:

```bash
git add .github/workflows/full-pipeline.yaml
git commit -m "Record decisions against controls"
git push origin main
```

2. Watch the GitHub Actions workflow run
3. Verify the `Controls` job completes, and that each decision step prints `RESULT: ALLOWED`

#### View the decisions in Kosli

1. In the Kosli app, open your Flow (`labs-pipeline`) and the latest Trail
2. On the `docker-image` artifact, you should see the `LAB-001-decision` and `LAB-002-decision` attestations
3. Click a decision to see its evidence: the control, the policy version that ran, the params and the result
4. Open **Controls** and select `LAB-001`. The **Decisions** tab lists every decision recorded against the control, across all your Trails

> :bulb: A control and its policy are versioned separately. The control states the requirement and rarely changes. The policy implements the check and changes whenever you refine it. Each decision cites both versions.

### Verification Checklist

Before moving to the next lab, ensure you have:

- ✅ Created the controls `LAB-001` and `LAB-002`
- ✅ Tested the policy against your Trail, and seen both an allowed and a denied result
- ✅ Published the `attestation-compliant` policy
- ✅ Added the `Controls` job to the workflow, and added it to the `needs` of the `Deploy` job
- ✅ Workflow runs successfully and records two decisions on the `docker-image` artifact
- ✅ Can see the decisions under **Controls** in the Kosli app

If anything did not go according to plan, you can reference our solution pipeline in [pipelines/04-complete.yaml](pipelines/04-complete.yaml).

## Next Steps

In [Lab 5: Defining compliance: Flow Templates and Deployment Gates](lab-05-flow-templates-and-gates.md), you'll define what a compliant Trail must contain, including your control decisions, and gate your deployment on it.

## Resources

- [Controls](https://docs.kosli.com/understand_kosli/controls)
- [Working with controls](https://docs.kosli.com/tutorials/working_with_controls)
- [Rego Policy reference](https://docs.kosli.com/policy-reference/rego_policy)
- [Ergo documentation](https://ergo.kosli.com/docs/getting-started/)
- [kosli create control CLI Reference](https://docs.kosli.com/client_reference/kosli_create_control/)
- [kosli publish rego-policy CLI Reference](https://docs.kosli.com/client_reference/kosli_publish_rego-policy/)
- [kosli evaluate policy CLI Reference](https://docs.kosli.com/client_reference/kosli_evaluate_policy/)
