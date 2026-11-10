# Lab 7: Writing policies: Ergo

## Learning Goals

- Read the input a policy receives from Kosli
- Write your own Ergo policy: subjects, requirements, checks and params
- Read an Ergo report and its violations to understand a denial
- Publish a new control with its own policy, and require it in your Environment Policy
- Understand policy versions, and how to pin one

## Introduction

In Lab 4 you used a ready-made policy to decide two controls. In this lab you write a policy yourself, for the third control from Lab 4's table: **artifact binary provenance**.

Binary provenance means that every artifact can be traced back to where it came from: the CI build that produced it and the git commit it was built from. Kosli records this when you attest an artifact with `--build-url` and `--commit-url`, as you did in Lab 3.

[Ergo](https://ergo.kosli.com) lets you write a policy's requirements as plain sentences in YAML:

- **Subjects** are the things a policy checks, and where they come from in the input (`from`). A subject can be filtered with `whose`, picked from an object with `named by $params.x`, or made from a list of keys with `named by each of $params.x`.
- **Requirements** each name a subject and list its **checks**. Each check has a `description` and an `assert`: one sentence, such as `origin_url is a non-empty string`.
- **Params** are values passed with each evaluation, read as `$params.x`. Ergo has no defaults, so a missing param fails the check.
- The **report** has one row per subject and check, with the value read, whether it passed, and a `cause` for failures (`absent`, `null`, `value` or `unusable`). **Violations** are the failed rows.

See the [Ergo reference](https://ergo.kosli.com/docs/reference/) for every sentence form, such as `is one of`, `matches`, `is at least`, `contains` and `is before`.

## Prerequisites

- Completed [Lab 6: Monitoring runtime: Environments, Snapshots, and Policies](lab-06-environments-and-policies.md)
- The Ergo library downloaded to `policies/lib/ergo.rego` (see Lab 4)
- `jq` installed (it is included in the devbox environment)

## Exercise

### Overview

In this lab, you will:

- Look at the Trail data your policy will receive
- Write an Ergo policy for binary provenance
- Test it against your Trail, and make it fail on purpose
- Create the control `LAB-003` and publish the policy
- Record a decision for `LAB-003` in CI and require it in your Environment Policy
- Publish a new version of a policy and pin a version

### Step-by-step instructions

#### Look at the input

A policy published with `--input-schema trail` receives one **trail moment**: the state of a Trail at one instant, as `input.trail`. Fetch the latest moment of your Trail to see what your policy can read:

```bash
curl -s -H "Authorization: Bearer $KOSLI_API_TOKEN" \
  "https://app.kosli.com/api/v2/trails/$KOSLI_ORG/labs-pipeline/$(git rev-parse HEAD)/moments/latest" \
  | jq '.compliance_status.artifacts_statuses | to_entries[] | {name: .key, origin_url: .value.origin_url, created_at: .value.created_at, git_commit_info: .value.git_commit_info}'
```

> :information_source: If your Organization is hosted in the US, replace `https://app.kosli.com` with `https://app.us.kosli.com`.

Each artifact under `compliance_status.artifacts_statuses` carries its provenance: `origin_url` (the build URL), `created_at` and `git_commit_info`. These are the fields your policy will check.

> :bulb: Drop the `jq` filter after `jq` to see the whole trail moment, including each artifact's `attestations_statuses`, which the Lab 4 policy reads.

See [Trail moment](https://docs.kosli.com/policy-reference/rego_policy#trail-moment) for a description of every field.

#### Write the policy

Create the directory `policies/binary-provenance/` with two files.

First, the requirements in `policies/binary-provenance/policy.ergo.yaml`. Kosli loads `*.ergo.yaml` files into `data`, where the policy can read them. Start from this skeleton and fill in the checks:

```yaml
ergo_spec: v0.5
description: Every deployable artifact in the trail has binary provenance
subjects:
  artifact:
    description: Each artifact named in the artifacts param
    from: trail.compliance_status.artifacts_statuses named by each of $params.artifacts
requirements:
  binary_provenance:
    description: The artifact was reported to Kosli with its build origin and source commit
    subject: artifact
    checks:
      built_in_ci:
        description: The artifact links to the CI build that produced it
        assert: # TODO: origin_url must be a non-empty string
      # TODO: add a check that git_commit_info is an object
      # TODO: add a check that created_at exists
```

`named by each of $params.artifacts` makes each artifact name in the `artifacts` param a subject of its own. With `{"artifacts": ["application", "docker-image"]}`, both artifacts must pass every check.

<details>
<summary>:bulb: Hint: the checks</summary>

```yaml
    checks:
      built_in_ci:
        description: The artifact links to the CI build that produced it
        assert: origin_url is a non-empty string
      from_commit:
        description: The artifact is linked to the git commit it was built from
        assert: git_commit_info is an object
      reported:
        description: The artifact has a creation time
        assert: created_at exists
```

</details>

Then hand the requirements to Ergo. Copy the wrapper from Lab 4, which works for any Ergo policy:

```bash
cp policies/attestation-compliant/policy.rego policies/binary-provenance/policy.rego
```

It reads `ergo_spec`, `subjects` and `requirements` from `data`, calls `ergo.report`, and declares `allow` (Ergo's overall answer) and `violations` (the failed checks) for Kosli.

#### Test the policy

Evaluate your local files against your latest Trail. Nothing is recorded:

```bash
kosli evaluate policy \
  --context trail=labs-pipeline/$(git rev-parse HEAD) \
  --path policies/binary-provenance/ \
  --path policies/lib/ergo.rego \
  --params '{"artifacts": ["application", "docker-image"]}'
```

You should see `RESULT: ALLOWED`.

Now make it fail on purpose, to see what a denial looks like. Ask for an artifact your pipeline doesn't produce:

```bash
kosli evaluate policy \
  --context trail=labs-pipeline/$(git rev-parse HEAD) \
  --path policies/binary-provenance/ \
  --path policies/lib/ergo.rego \
  --params '{"artifacts": ["application", "docker-image", "frontend"]}'
```

The result is `RESULT: DENIED`. Each violation names the requirement, the check, the subject (`frontend`), and the `cause`, here `absent`.

Try one more: remove the `--params` flag completely. Ergo has no defaults, so a policy run without its params is denied rather than silently passing.

> :bulb: Add `--output json` to see the full Ergo report under `outputs.report`, including every check that *passed*. This is what makes an Ergo decision easy to explain to an auditor.

#### Create the control and publish the policy

Create the control:

```bash
kosli create control LAB-003 \
  --name "Binary provenance" \
  --description "Every deployable artifact can be traced to the CI build and commit that produced it"
```

Then publish the policy:

```bash
kosli publish rego-policy binary-provenance \
  --path policies/binary-provenance/ \
  --path policies/lib/ergo.rego \
  --input-schema trail \
  --name "Binary provenance" \
  --comment "Initial version"
```

#### Record the decision in CI

Add a third decision step to the end of the `Controls` job in `.github/workflows/full-pipeline.yaml`:

```yaml
    - name: Decide LAB-003 Binary provenance
      run: |
        kosli evaluate policy \
          --context trail=${APP_NAME}-pipeline/${GIT_COMMIT} \
          --identifier binary-provenance \
          --params '{"artifacts": ["application", "docker-image"]}' \
          --control LAB-003 \
          --flow ${APP_NAME}-pipeline \
          --trail ${GIT_COMMIT} \
          --fingerprint ${FINGERPRINT}
```

#### Require the control in your Environment Policy

Add `LAB-003` to `.kosli-policy.yml`:

```yaml
  attestations:
    - type: decision
      for_control: LAB-001  # Quality assurance
    - type: decision
      for_control: LAB-002  # Vulnerability scanning
    - type: decision
      for_control: LAB-003  # Binary provenance
```

Commit and push:

```bash
git add policies/binary-provenance/ .kosli-policy.yml .github/workflows/full-pipeline.yaml
git commit -m "Add binary provenance control"
git push origin main
```

Watch the workflow. The `Controls` job records three decisions, the `Update Kosli policy` step publishes a new version of the Environment Policy, and the deployment gate checks all three controls.

> :warning: The order matters. If you add `LAB-003` to the Environment Policy before the control exists, Kosli rejects the policy. If you deploy before the decision is recorded, the gate fails.

#### Policy versions

Each publish stores a new version of a policy, and evaluations run the newest valid version. That is convenient, but it also means a new version changes what every later decision runs.

1. Change a description in `policies/binary-provenance/policy.ergo.yaml` and publish again, with a comment:

```bash
kosli publish rego-policy binary-provenance \
  --path policies/binary-provenance/ \
  --path policies/lib/ergo.rego \
  --input-schema trail \
  --comment "Clarify check descriptions"
```

2. The command reports version 2. In the Kosli app, open **Controls** → `LAB-003` and look at a decision: it cites the policy version that ran.

3. To keep your pipeline on a version you have reviewed, pin it by appending `@v<n>` to the identifier in the `Controls` job:

```yaml
          --identifier binary-provenance@v1 \
```

Move the pin when you're ready to adopt a newer version.

See [Pinning a policy version](https://docs.kosli.com/tutorials/working_with_controls#pinning-a-policy-version) for more details.

### Verification Checklist

Before moving to the next lab, ensure you have:

- ✅ Looked at the trail moment your policy receives
- ✅ Written `policies/binary-provenance/policy.ergo.yaml` and `policy.rego`
- ✅ Seen the policy allow your Trail, and deny it with a missing artifact
- ✅ Created the control `LAB-003` and published the `binary-provenance` policy
- ✅ Added the `LAB-003` decision step to the `Controls` job
- ✅ Required `LAB-003` in `.kosli-policy.yml`, and the deployment gate passes
- ✅ Published a second version of the policy, and understand how to pin a version

If anything did not go according to plan, you can reference our solutions in [pipelines/07-complete.yaml](pipelines/07-complete.yaml), [pipelines/07-binary-provenance/](pipelines/07-binary-provenance/) and [pipelines/07-kosli-policy.yml](pipelines/07-kosli-policy.yml).

## Next Steps

In [Lab 8: Kosli administration: Terraform](lab-08-terraform-administration.md), you'll manage your Flow, Environment, Environment Policy and controls as code with the Kosli Terraform provider.

## Resources

- [Ergo: Getting started](https://ergo.kosli.com/docs/getting-started/)
- [Ergo reference](https://ergo.kosli.com/docs/reference/)
- [Ergo playground](https://ergo.kosli.com/playground/)
- [Rego Policy reference](https://docs.kosli.com/policy-reference/rego_policy)
- [Working with controls](https://docs.kosli.com/tutorials/working_with_controls)
- [kosli publish rego-policy CLI Reference](https://docs.kosli.com/client_reference/kosli_publish_rego-policy/)
- [kosli evaluate policy CLI Reference](https://docs.kosli.com/client_reference/kosli_evaluate_policy/)
