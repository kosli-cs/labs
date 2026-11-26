# Lab 1: Get Ready with Kosli

## Learning Goals

- Log in to Kosli
- Create a copy of the sample application repository
- Verify that the CI/CD pipeline runs successfully
- Understand the basic structure of the application and its deployment process

## Introduction

Welcome to the first lab!

Before diving into Kosli's features, you need to log in to Kosli and verify that your sample application builds and deploys correctly.

This lab uses a simple [Java application](app) with a complete CI/CD pipeline already configured in GitHub Actions. The pipeline builds the application, creates a Docker image, runs tests, and deploys it.

In subsequent labs, you'll integrate Kosli to track all these activities.

## Prerequisites

- A GitHub account
- Basic familiarity with Git and GitHub
- Understanding of CI/CD concepts
- A web browser

## Exercise

### Overview

In this lab, you will:

- Log in to Kosli with your account
- Create a copy of the labs repository to your GitHub account
- Enable GitHub Actions on your copied repository
- Verify that the pipeline runs successfully and produces artifacts
- Observe the application deployment process

### Step-by-step instructions

#### Log in to Kosli

- Log in to the Kosli app with your account at [https://app.kosli.com](https://app.kosli.com) (or [https://app.us.kosli.com](https://app.us.kosli.com) if your Organization is hosted in the US)
- Depending on how your Organization is set up, you sign in with single sign-on, Magic Link or GitHub

> :information_source: If you need help accessing your account, ask your training instructor.

So far so good :tada:. We will go a lot more in detail with Kosli in the next sections, but for now we need the scaffolding set up.

#### Make a copy of the repository

- Navigate to the labs repository's main page (the repository you're currently viewing)
- Click the "Use this template" button in the top-right corner of the page
- Select "Create a new repository"
- Select your personal GitHub account as the "Owner" and name the repository `labs`
- Optionally add a description, and choose to make the repository public or private
- Click "Create repository from template"
- Wait for GitHub to complete the copy process
- You should now have a copy at `https://github.com/YOUR-GITHUB-USERNAME/labs`

> :bulb: From now on the term "your repository" will mean your copy of the labs repository.

#### Enable GitHub Actions

1. Go to your repository on GitHub
2. Click on the "Actions" tab
3. If prompted, click "I understand my workflows, go ahead and enable them"
4. The workflow should start automatically, if not, you can trigger it manually:
   - Click on "Main workflow" in the left sidebar
   - Click "Run workflow" button on the right
   - Select the branch (usually `main`) and click "Run workflow"

#### Verify the pipeline execution

- In the "Actions" tab, click on the most recent workflow run
- Observe the workflow jobs:
  - **Build**: Compiles the Java application using Gradle
  - **Linting**: Checks code quality (may show warnings)
  - **Docker-image**: Builds and pushes a Docker container image
  - **Security-scan**: Scans the Docker image for vulnerabilities
  - **Component-test**: Runs integration tests
  - **Performance-test**: Runs basic performance checks
  - **Deploy**: Starts and stops the application container
- Wait for all jobs to complete (green checkmarks)

![Pipeline](img/pipeline.png)

- If any jobs fail, review the logs to understand what went wrong

> :bulb: The pipeline might take 3-6 minutes to complete on the first run. GitHub Actions provides free minutes for public repositories.

<details>
<summary>:bulb: Common issues</summary>

- **Docker-image job fails with permission error**: Make sure your repository has package write permissions enabled
- **Linting shows warnings**: This is expected and won't fail the build (DISABLE_ERRORS is set to true)

</details>

#### Explore the GitHub Actions workflow

1. In your repository, navigate to `.github/workflows/full-pipeline.yaml`
2. Review the workflow structure:
   - Notice how it's triggered on every push
   - Observe the environment variables set at the top
   - See how artifacts are shared between jobs using `upload-artifact` and `download-artifact`
   - Note the dependencies between jobs (e.g., Docker-image needs Build)
3. In later labs, you'll add Kosli integration to this pipeline

#### View the Docker image

1. Go to your GitHub profile page
2. Click on "Packages" tab in the left sidebar
3. You should see the `labs` package
4. Click on it to view details about the Docker image
5. Note the image tag (usually `latest`) and the SHA digest

> :bulb: The Docker image is automatically published to GitHub Container Registry (ghcr.io) by the pipeline.

### Verification Checklist

Before moving to the next lab, ensure you have:

- ✅ Logged in to the Kosli app with access to your Organization
- ✅ A copy of the labs repository under your GitHub account
- ✅ GitHub Actions successfully completed all jobs in the workflow
- ✅ A Docker image published to your GitHub Container Registry
- ✅ Understanding of the basic pipeline structure

### Clean up

No cleanup is required for this lab. The deployed container is automatically stopped by the pipeline's Deploy job.

## Next Steps

In [Lab 2: Modeling your process: Flows and Trails](lab-02-flows-and-trails.md), you'll learn how to install the Kosli CLI, create Flows and Trails, and start integrating Kosli into your CI/CD pipeline.

## Resources

- [Kosli Documentation](https://docs.kosli.com/)
- [What is Kosli?](https://docs.kosli.com/understand_kosli/what_is_kosli)
- [How Kosli works](https://docs.kosli.com/understand_kosli/how_kosli_works)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
