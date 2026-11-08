# Lab 6: Monitoring runtime: Environments, Snapshots, and Policies

## Learning Goals

- Understand Kosli Environments and how they track runtime state
- Create a Kosli Environment to represent your deployment target
- Snapshot a Docker environment from CI to report what's running
- Understand Environment Snapshots and change tracking
- Create and configure Environment Policies that require controls
- Gate a deployment on an Environment
- Attach Policies to Environments for enforcement
- Integrate environment snapshotting into your CI/CD pipeline

## Introduction

**Kosli Environments** record the artifacts running in your runtime environments (dev, staging, production, etc.) and how they change. Every time you report an **Environment Snapshot** that differs from the previous one, Kosli creates an immutable record of:

- What artifacts are running, identified by their SHA256 fingerprint
- When they started and stopped
- Whether they're compliant with your policies
- The complete change history over time

**Environment Policies** define compliance requirements for what may run in an Environment. They specify rules like:

- All artifacts must have provenance (be part of a Flow)
- All artifacts must have passed specific tests
- All artifacts must have security scans
- Specific attestations must be present

Because each running artifact is identified by its fingerprint, Kosli traces it back to the Flows and Trails that assiciated with it. Together, Environments and Environment Policies link what you built to what is running, and flag anything that doesn't meet your requirements.

### Understanding Environment Types

Kosli supports several environment types:

- **docker**: Tracks Docker containers on a host
- **K8S**: Tracks Kubernetes pods in namespaces
- **ECS**: Tracks AWS ECS tasks
- **lambda**: Tracks AWS Lambda functions
- **S3**: Tracks files in S3 buckets
- **azure-apps**: Tracks Azure Web Apps and Function Apps
- **cloud-run**: Tracks Google Cloud Run services and jobs
- **server**: Tracks files on a server filesystem, effectively making it possible to track any type of application runtime.

You can also group several Environments into a **logical** Environment, and let Kosli report snapshots for you with [Cloud Capture](https://docs.kosli.com/administration/cloud_capture/overview).

See [Environments documentation](https://docs.kosli.com/getting_started/environments/) for more details.

## Prerequisites

- Completed [Lab 5: Defining compliance: Flow Templates and Deployment Gates](lab-05-flow-templates-and-gates.md)
- Kosli CLI installed and configured
- Artifacts and attestations flowing through your pipeline
- Understanding of your deployment process

## Exercise

### Overview

In this lab, you will:

- Create a Kosli Environment representing your deployment target
- Snapshot a Docker environment from your CI pipeline
- Understand how Kosli tracks environment changes
- Create an Environment Policy with requirements
- Attach the Policy to your Environment
- Integrate automated snapshotting into your workflow
- View environment snapshots and compliance status in Kosli

### Step-by-step instructions

#### Create an Environment

Your application deploys as a Docker container, so you'll create a `docker` type environment:

```bash
# Create a Docker environment
kosli create environment labs-prod \
  --type docker \
  --description "Production environment for labs application"

# Verify it was created
kosli get environment labs-prod
```

Visit [app.kosli.com](https://app.kosli.com), navigate to Environments, and you should see `labs-prod` listed (currently with no snapshots).

See [kosli create environment](https://docs.kosli.com/client_reference/kosli_create_environment/) for more details.

#### Explore an existing Environment

Since we cannot assume everyone has Docker installed locally, let's look at a real-world example of an environment in Kosli.

Navigate to the [Cyber-Dojo AWS Beta environment](https://app.kosli.com/cyber-dojo/environments/aws-beta/snapshots/).

Here you can see a history of snapshots taken from an AWS environment. Each snapshot shows exactly what was running at that point in time.

In the Kosli app you can see

  - **Running artifacts**: The container image(s) currently running.
  - **Compliance status**: Whether they meet policy requirements (if any)
  - **Events**: What started or stopped since the last snapshot
  - **Duration**: When this application started running on the environment.

Each snapshot is immutable. If you take another snapshot and nothing changed, Kosli won't create a new one. New snapshots are only created when there are actual changes.

> :bulb: Regular snapshotting creates a complete audit trail of your production environment, showing exactly what was running at any point in time. In production you would report snapshots automatically on a schedule (e.g. a cron job or a scheduled CI job), not only after a deployment.

#### Snapshot the environment in CI

Let's integrate automated snapshotting into your workflow by adding a step to the `Deploy` job in `.github/workflows/full-pipeline.yaml`.

Add this step after the "Deploy to production" step:

```yaml
    - name: Kosli snapshot environment
      run: kosli snapshot docker labs-prod 
```

> :bulb: In your workflow, this runs after the application is deployed. It captures what's running immediately after deployment.
>
> The GitHub Actions runner simulates a production host here: it is thrown away after each run, and the next step stops the container again. On a real host the application would keep running, and you would snapshot it on a schedule as well.

#### Create an Environment Policy

Environment Policies define what's required for artifacts running in an Environment to be compliant. Let's create one:

**Create `.kosli-policy.yml`:**

```yaml
_schema: https://docs.kosli.com/schemas/policy/v1

artifacts:
  provenance:
    required: true  # All artifacts must be part of a Flow

  trail-compliance:
    required: true  # All artifacts must come from a Compliant Trail

  attestations:
    - type: decision
      for_control: LAB-001  # Quality assurance
    - type: decision
      for_control: LAB-002  # Vulnerability scanning
```

This policy requires:

1. All running artifacts must have been attested to Kosli (provenance)
2. All artifacts must come from a **Compliant** Trail, i.e. one that satisfies the Flow Template from Lab 5 (`trail-compliance`)
3. All artifacts must have a passing decision for the controls `LAB-001` and `LAB-002`

Notice what the policy does *not* say: nothing about JUnit, Trivy or attestation names. It says "control `LAB-001` has been satisfied". How that is judged lives in the policy that decides the control, from Lab 4. If you switch test framework or scanner tomorrow, this Environment Policy stays the same.

> :bulb: A policy that refers to a control that doesn't exist is rejected, so create the controls (Lab 4) before the policy. See [Requiring controls in environment policies](https://docs.kosli.com/tutorials/working_with_controls#requiring-controls-in-environment-policies).

Create the policy in Kosli:

```bash
kosli create policy labs-prod-requirements .kosli-policy.yml

# View the policy
kosli get policy labs-prod-requirements
```

See [kosli create policy](https://docs.kosli.com/client_reference/kosli_create_policy/) and [Policy documentation](https://docs.kosli.com/getting_started/policies/) for more details.

#### Attach the Policy to your Environment

Now attach the policy to the environment to activate it:

```bash
kosli attach-policy labs-prod-requirements --environment labs-prod

# Verify attachment
kosli get environment labs-prod
```

> :bulb: Attaching a policy automatically triggers an evaluation of the latest environment snapshot, and creates a new snapshot with an updated compliance state.

See [kosli attach policy](https://docs.kosli.com/client_reference/kosli_attach-policy/) for more details.

#### View compliance status

Return to the Kosli app:

1. Navigate to Environments → labs-prod
2. Look at the latest snapshot
3. Check the compliance state:
   - **Compliant**: all artifacts in the snapshot satisfy the attached policies
   - **Non-compliant**: one or more artifacts violate the attached policies
   - **Unknown**: no policies are attached, so there are no requirements to evaluate against
4. Click on artifacts to see which attestations are present

<details>
<summary>:bulb: If your artifact is non-compliant, it might be because:</summary>

- A decision for `LAB-001` or `LAB-002` is missing, or was denied
- The Trail is not compliant with the Flow Template
- The artifact wasn't properly attested in the first place

</details>

> :bulb: Environment Policies are evaluated on every snapshot, which tells you about non-compliance *after* the fact. To block a non-compliant artifact *before* it is deployed, use a policy enforcement gate with `kosli assert artifact`, which you'll set up below.

#### Manage policy in CI

Let's automate policy updates by adding a step to your workflow. Policies are immutable: running `kosli create policy` with changed content creates a new version of the policy, so the history of your requirements is kept. You can add this to the `Deploy` job, before the deployment happens.

Add this step before the "Assert Compliance" step:

```yaml
    - name: Update Kosli policy
      run: kosli create policy labs-prod-requirements .kosli-policy.yml
    - name: Attach policy to environment
      run: kosli attach-policy labs-prod-requirements --environment labs-prod
```

#### Gate the deployment on the Environment

In Lab 5, your deployment gate asserted against the Flow Template. Now that the Environment has a policy, assert against the Environment instead. Change the `Assert Compliance` step in the `Deploy` job:

```yaml
    - name: Assert Compliance
      run: |
        IMAGE_NAME="ghcr.io/${IMAGE}:latest"
        kosli assert artifact ${IMAGE_NAME} \
          --artifact-type oci \
          --environment labs-prod
```

`--environment` checks the artifact against every policy attached to `labs-prod`. Because the policy requires `trail-compliance`, the Flow Template from Lab 5 is still enforced, and on top of it the controls. This step is the Policy Enforcement Point: the decisions are recorded in the `Controls` job, and enforced here.

`kosli assert artifact` supports three assertion scopes: `--environment` (all policies attached to the environment), `--policy` (specific named policies), or neither (the Flow Template, as in Lab 5). `--environment` and `--policy` are mutually exclusive.

See [Enforce policies](https://docs.kosli.com/getting_started/enforce_policies) and [kosli assert artifact](https://docs.kosli.com/client_reference/kosli_assert_artifact/) for more details.

#### Verify workflow integration

Ensure your `.github/workflows/full-pipeline.yaml` now includes the policy update, the Environment assertion and the snapshot steps in the `Deploy` job.

#### Test the complete integration

1. Commit the changes:

```bash
# Commit policy and workflow
git add .kosli-policy.yml .github/workflows/full-pipeline.yaml
git commit -m "Add Kosli environment and policy management"
git push origin main
```

2. Watch the workflow execute
3. Verify the "Update Kosli policy" and "Kosli snapshot environment" steps succeed
4. In the Kosli app:
   - Check your environment has a new snapshot
   - Verify the running artifact's compliance status
   - Review which attestations are present

> :bulb: Your artifact should now be compliant, since your pipeline records the evidence (Lab 3) and the decisions (Lab 4) on every run.

#### Optional: Assert against a specific policy

You can also assert against named policies, regardless of which environment they are attached to. This is useful as a promotion gate between stages:

```bash
kosli assert artifact ghcr.io/${IMAGE}:latest \
  --artifact-type oci \
  --policy labs-prod-requirements
```

If the artifact is non-compliant, this command exits with a non-zero status.

#### Understanding policy expressions

Environment Policies support conditional logic using expressions. For example:

```yaml
artifacts:
  attestations:
    # Only require Snyk scans for production flow
    - if: ${{ flow.name == "production" }}
      name: snyk-scan
      type: snyk
    
    # Exceptions: don't require tests for specific artifacts
    - name: unit-tests
      type: junit
      exceptions:
        - if: ${{ artifact.name == "legacy-component" }}
```

> :bulb: Policy expressions allow sophisticated compliance rules based on flow tags, artifact names, and other metadata.

See [Policy expressions](https://docs.kosli.com/policy-reference/environment_policy#policy-expressions) for more details.

### Verification Checklist

Before completing this lab, ensure you have:

- ✅ Created a `labs-prod` environment of type `docker`
- ✅ Explored the Cyber-Dojo environment in Kosli
- ✅ Created a `.kosli-policy.yml` file with compliance requirements
- ✅ Created the policy in Kosli and attached it to your environment
- ✅ Updated workflow with policy update and snapshot steps
- ✅ Changed the deployment gate to assert against the `labs-prod` Environment
- ✅ Workflow runs successfully with policy updates and snapshotting
- ✅ Can see environment snapshots in the Kosli app
- ✅ Can see the compliance state (Compliant / Non-compliant / Unknown) for running artifacts
- ✅ Understand how policies enforce requirements

If anything did not go according to plan, you can reference our solution pipeline in [pipelines/06-complete.yaml](pipelines/06-complete.yaml) and the policy in [pipelines/06-kosli-policy.yml](pipelines/06-kosli-policy.yml).

### Clean up

No cleanup is required. Environments, snapshots, and policies remain for audit and historical tracking.

## Next Steps

In [Lab 7: Writing policies: Ergo](lab-07-writing-policies-with-ergo.md), you'll write your own Ergo policy for a third control, binary provenance, and require it in this Environment Policy.

## Resources

- [Kosli Environments Documentation](https://docs.kosli.com/getting_started/environments/)
- [Kosli Policies Documentation](https://docs.kosli.com/getting_started/policies/)
- [kosli create environment CLI Reference](https://docs.kosli.com/client_reference/kosli_create_environment/)
- [kosli snapshot docker CLI Reference](https://docs.kosli.com/client_reference/kosli_snapshot_docker/)
- [kosli create policy CLI Reference](https://docs.kosli.com/client_reference/kosli_create_policy/)
- [kosli attach-policy CLI Reference](https://docs.kosli.com/client_reference/kosli_attach-policy/)
- [kosli assert artifact CLI Reference](https://docs.kosli.com/client_reference/kosli_assert_artifact/)
- [Environment Policy reference](https://docs.kosli.com/policy-reference/environment_policy)
- [Enforce policies](https://docs.kosli.com/getting_started/enforce_policies)
