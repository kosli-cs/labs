# Lab 2: Modeling your process: Flows and Trails

## Learning Goals

- Install and configure the Kosli CLI on your local machine or GitHub Codespace
- Create and configure an API key for Kosli authentication
- Understand the concepts of Flows and Trails in Kosli
- Create your first Flow using the Kosli CLI
- Begin a Trail manually to track a process execution
- Integrate Flow and Trail creation into your CI/CD workflow

## Introduction

Now is the time to dig into the world of Kosli.

Kosli uses **Flows** and **Trails** to organize and track your software delivery processes:

- A **Flow** models a repeatable business or software process (like your CI/CD pipeline). It is the container for everything that happens within that process.
- A **Trail** represents a single execution of that Flow, such as one CI build or one pull request. You begin a Trail each time the process runs, and you choose its identifier (a git commit SHA, a PR number, a release ticket ID) so that Trails map to concepts your team already works with.

Think of a Flow as the container for your process, and Trails as the individual executions where you record what actually happened. What a *compliant* Trail must contain is defined by a **Flow Template**, which you'll add in Lab 5.

## Prerequisites

- Completed [Lab 1: Get Ready](lab-01-get-ready.md)
- A Kosli account
- Your copy of the labs repository
- Command line access (local terminal or GitHub Codespace)

## Exercise

### Overview

In this lab, you will:

- Install the Kosli CLI tool
- Generate an API key for authentication
- Create a Kosli Flow to represent your CI/CD pipeline
- Begin a Trail manually using a git commit as the identifier
- Add Flow and Trail steps to your GitHub Actions workflow
- Verify the Flow and Trail appear in the Kosli app

### Step-by-step instructions

#### Install the Kosli CLI

You can download the correct Kosli CLI for your platform, given that you can run shell scripts on it, by invoking this one-line script:

```bash
curl -fL https://raw.githubusercontent.com/kosli-dev/cli/refs/heads/main/install-cli.sh | sh

# Verify installation
kosli version
```

> :bulb: If this installation method fails, see [Install Kosli CLI](https://docs.kosli.com/getting_started/install) for alternative installation options.

#### Create a Kosli API Key

- In the Kosli app, open **Profile** from the user menu in the top-right corner ([https://app.kosli.com/settings/profile](https://app.kosli.com/settings/profile))
- In the **API keys** section, click **Add API key**
- Choose a Time-To-Live (TTL) that covers the duration of the labs, and add a descriptive label (e.g., "Kosli labs")
- Click **Add** and copy the key immediately. Kosli only stores a hash of it, so it is shown once and cannot be retrieved later
- Paste it somewhere you can find it again during these labs, you might need it several times.

> :information_source: This is a **personal API key**, which authenticates as you. For real CI/CD pipelines, use a [service account](https://docs.kosli.com/administration/authentication/service_accounts) API key instead: it is scoped to a single Organization and has an explicit role. For now, a personal API key is fine: in Lab 8 you'll replace it with a service account API key.

**Configure the API key for CLI use:**

```bash
# Set environment variables
export KOSLI_API_TOKEN="your-api-key-here"
export KOSLI_ORG="your-gh-username"
```

See [Authenticating to Kosli](https://docs.kosli.com/getting_started/authenticating_to_kosli) and [Assigning flags via environment variables](https://docs.kosli.com/getting_started/install#assigning-flags-via-environment-variables) for more details.

#### Create a Flow manually

First, let's create a Flow manually to understand the concept:

```bash
# Create a Flow with an empty template
kosli create flow labs-pipeline \
  --description "CI/CD pipeline for labs application" \
  --use-empty-template

# Verify the Flow was created
kosli get flow labs-pipeline
```

You should see something like the following returned:

```bash
Name:                labs-pipeline
Description:         CI/CD pipeline for labs application
Visibility:          private
Template:            
                     version: 1
Last Deployment At:  N/A
Tags:                None
```

> :bulb: The `--use-empty-template` flag creates a Flow without compliance requirements. In Lab 5, you'll learn how to add a Flow Template with specific attestation requirements.

Visit [app.kosli.com](https://app.kosli.com) and navigate to Flows to see your newly created Flow.

See [kosli create flow](https://docs.kosli.com/client_reference/kosli_create_flow/) for more details.

#### Begin a Trail manually

A Trail represents one execution of your process. Let's create a Trail using your latest git commit:

```bash
# Begin a Trail using the current git commit SHA
kosli begin trail $(git rev-parse HEAD) \
  --flow labs-pipeline \
  --description "Manual trail for testing"

# Verify the Trail was created
kosli get trail $(git rev-parse HEAD) \
  --flow labs-pipeline
```
> :warning: Make sure to run this in your copy of the labs repository!

The Trail name is the git commit SHA, which uniquely identifies this execution. This allows Kosli to connect all activities (builds, tests, deployments) that happen for this specific commit.

> :bulb: You can use any naming scheme for Trails (commit SHA, PR number, Jira ticket, etc.). Git commits are common because they're unique and tied to your source code.

- Go to the Kosli app to see your new Trail under your Flow called "labs-pipeline"

![first trail](img/first-trail.png)

See [kosli begin trail](https://docs.kosli.com/client_reference/kosli_begin_trail/) for more details and [Flows documentation](https://docs.kosli.com/getting_started/flows/) and [Trails documentation](https://docs.kosli.com/getting_started/trails/) for conceptual understanding.

#### Immutable Trails

Kosli stores each record as an immutable entry. You can update a Trail, but every update is appended as a new event, so the history is never overwritten.
This is important in a compliance setting, where the ability to change data is equal to the risk of tampering with it.

To explore this, let's begin the same Trail once more with a slightly different description.

```bash
kosli begin trail $(git rev-parse HEAD) \
  --flow labs-pipeline \
  --description "Manual trail for testing."
```

If this had been a mutable Trail, the description would have been updated with a dot at the end, and no record of the change would have been kept. Now get the Trail once more:

```bash
kosli get trail $(git rev-parse HEAD) \
  --flow labs-pipeline
```

The result should look like the following:

```bash
Name:              df029fec81ae14bd9dc98ce365c4d2d92d5c32ac
Description:       Manual trail for testing.
Compliance:        COMPLIANT
Last modified at:  Wed, 26 Nov 2025 21:14:33 CET • 44 seconds ago
Events:

     TIME                           DESCRIPTION    GIT-COMMIT  COMPLIANCE
     Wed, 26 Nov 2025 21:13:09 CET  trail started
     Wed, 26 Nov 2025 21:14:33 CET  trail updated
```

Notice that the **Events** section shows both the original `trail started` event and a new `trail updated` event. Every change to a Trail is appended as an event, so the history is preserved for auditability.

#### Integrate Kosli into your CI/CD pipeline

Now let's integrate Flow and Trail creation into your CI/CD pipeline.

**Add API key as a GitHub Secret:**

1. Go to your copy of the labs repository on GitHub
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Name: `KOSLI_API_TOKEN`
5. Value: Your Kosli API key
6. Click "Variables"
7. Click "New repository variable"
8. Name it `KOSLI_ORG` and set the value to your Organization name (the same value you exported as `KOSLI_ORG` earlier)

> :bulb: Never commit API keys to your repository via Git. Always use environment variables or secrets management.

#### Update GitHub Actions workflow

We will update the workflow file `.github/workflows/full-pipeline.yaml` to include Kosli commands directly.

**1. Add global environment variables**

To avoid repeating the Kosli credentials in every step, add them as global environment variables at the top of your workflow file:

```yaml
env:
  KOSLI_API_TOKEN: ${{ secrets.KOSLI_API_TOKEN }}
  KOSLI_ORG: ${{ vars.KOSLI_ORG }}
  # ... other existing env vars ...
```

**2. Add Kosli steps**

Add the following steps to your workflow. Place them just after checking out the code.

```yaml
      - name: Clone down repository
        uses: actions/checkout@v7
      
  #Your new additions

      - name: Setup Kosli CLI
        uses: kosli-dev/setup-cli-action@v5
        with:
          version:
            2.54.0

      - name: Create/Update Flow
        run: |
          kosli create flow ${APP_NAME}-pipeline \
            --description "CI/CD pipeline for ${APP_NAME} application" \
            --use-empty-template

      - name: Begin Trail
        run: |
          kosli begin trail ${GIT_COMMIT} \
            --flow ${APP_NAME}-pipeline \
            --description "Build ${BUILD_NUMBER}: ${GIT_BRANCH}"
```

> :bulb: We use the `kosli-dev/setup-cli-action` to install the CLI. The `env` variables we set earlier ensure the CLI is authenticated.

#### Test the integration

1. Commit the changes to your workflow file:

```bash
git add .github/workflows/full-pipeline.yaml
git commit -m "Add Kosli Flow and Trail steps"
git push origin main
```

2. Go to GitHub Actions and watch the workflow run
3. Verify the "Setup Kosli CLI", "Create/Update Flow" and "Begin Trail" steps complete successfully
4. Check the logs to see the Kosli CLI output
5. Visit [app.kosli.com](https://app.kosli.com) and navigate to your Flow
6. You should see a new Trail corresponding to your commit

> :bulb: Each push to your repository will now create a new Trail, allowing you to track the complete history of your pipeline executions.

### Verification Checklist

Before moving to the next lab, ensure you have:

- ✅ Kosli CLI installed and can run `kosli version`
- ✅ API key created and configured as environment variables
- ✅ API key and Organization name added as GitHub Secrets and variables
- ✅ Successfully created a Flow manually using the CLI
- ✅ Successfully created a Trail manually using a git commit SHA
- ✅ Updated workflow with Kosli steps
- ✅ Workflow runs successfully with Flow and Trail creation
- ✅ Can see the Flow and Trails in the Kosli app

If anything did not go according to plan, you can reference our solution pipeline in [pipelines/02-complete.yaml](pipelines/02-complete.yaml)

## Next Steps

In [Lab 3: Recording evidence: Artifacts and Attestations](lab-03-artifacts-and-attestations.md), you'll learn how to attest artifacts and attach evidence like test results, SBOMs, and security scans to your Trails.

## Resources

- [Kosli Flows Documentation](https://docs.kosli.com/getting_started/flows/)
- [Kosli Trails Documentation](https://docs.kosli.com/getting_started/trails/)
- [kosli create flow CLI Reference](https://docs.kosli.com/client_reference/kosli_create_flow/)
- [kosli begin trail CLI Reference](https://docs.kosli.com/client_reference/kosli_begin_trail/)
- [Kosli CLI Installation](https://docs.kosli.com/getting_started/install)
- [Authenticating to Kosli](https://docs.kosli.com/getting_started/authenticating_to_kosli)
