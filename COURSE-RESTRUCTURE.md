# Course restructure: from 5 to 8 labs

Overview for the meeting about restructuring the Kosli learning labs. It describes the new structure, what the new labs cover, what changed in the existing labs, the decisions behind it, and what still has to be checked before the course is used.

## Why

- **Controls are now a first-class concept in Kosli** (beta): you create a control, a policy decides it, and the decision is recorded and enforced. The labs didn't cover this.
- **The old titles clashed with that concept.** Labs 3–5 were called "Build/Release/Runtime Controls" but never created a control. With a controls lab in the course, the word "control" should first appear there.
- **The titles now follow the docs.** Labs 2–6 are named after the sections of [How Kosli works](https://docs.kosli.com/understand_kosli/how_kosli_works), so learners can read the matching section before each lab.
- **Two more advanced topics**: writing your own policies with Ergo, and administering Kosli as code with Terraform.

## New structure

| # | Title | Status | File |
|---|---|---|---|
| 1 | Get Ready | unchanged | `lab-01-get-ready.md` |
| 2 | Modeling your process: Flows and Trails | renamed | `lab-02-flows-and-trails.md` |
| 3 | Recording evidence: Artifacts and Attestations | renamed (was "Build Controls and Attestations") | `lab-03-artifacts-and-attestations.md` |
| **4** | **Implementing controls: Controls and Decisions** | **new** | `lab-04-controls-and-decisions.md` |
| 5 | Defining compliance: Flow Templates and Deployment Gates | was Lab 4 "Release Controls" | `lab-05-flow-templates-and-gates.md` |
| 6 | Monitoring runtime: Environments, Snapshots, and Policies | was Lab 5 "Runtime Controls" | `lab-06-environments-and-policies.md` |
| **7** | **Writing policies: Ergo** | **new** | `lab-07-writing-policies-with-ergo.md` |
| **8** | **Kosli administration: Terraform** | **new** | `lab-08-terraform-administration.md` |

The story across the labs:

1. **Labs 2–3** record *evidence*: Flows, Trails, Artifacts and Attestations.
2. **Lab 4** turns evidence into *decisions* against named controls.
3. **Labs 5–6** *enforce*: first the Flow Template, then an Environment Policy that requires the controls.
4. **Lab 7** goes deeper on how decisions are made, by writing an Ergo policy from scratch.
5. **Lab 8** moves the *administration* of everything above into Terraform.

## Decisions taken

These were open questions before the restructure, and are now settled:

| Question | Decision |
|---|---|
| Are the Controls (beta) enabled for the training Organizations? | Yes |
| Can learners publish policies and run Terraform (both need the Admin role)? | Yes, learners are admin in their own Organization |
| Which Ergo version should the labs pin? | v0.5 (`ergo_spec: v0.5`, release `rego-v0.5.0`) |
| Should Lab 6's Environment Policy *replace* the attestation rules with control requirements (`for_control`), or keep both? | Replace. The policy now requires provenance, trail compliance and the controls, and names no tools |
| Should Terraform in Lab 8 *take over* resource management from the pipeline, or be a standalone exercise? | Take over. The pipeline stops creating the Flow and the Environment Policy |
| Should Lab 3 be called "Build Controls" or "Binary Provenance"? | Neither. "Recording evidence: Artifacts and Attestations", matching the docs. Binary provenance is explained inside Lab 3 and becomes its own control in Lab 7 |

## The new labs

### Lab 4 – Implementing controls: Controls and Decisions

Ergo is only touched lightly: learners use a ready-made policy.

- **Opening**: maps the docs' [Controls](https://docs.kosli.com/understand_kosli/controls) page onto Lab 3's evidence. JUnit is evidence for *quality assurance*, Trivy for *vulnerability scanning*, and the fingerprinted artifacts for *binary provenance*.
- **Concepts**: control, policy and decision, and why recording a decision is kept separate from enforcing it.
- **Create controls**: `LAB-001` Quality assurance and `LAB-002` Vulnerability scanning, with `kosli create control`.
- **Ready-made policy**: `policies/attestation-compliant/` checks that an attestation on an artifact is recorded and compliant. One policy decides both controls, through params (`{"artifact": …, "attestation": …}`).
- **Test**: `kosli evaluate policy --path` against the learner's own Trail, showing both an allowed and a denied result.
- **Publish**: `kosli publish rego-policy attestation-compliant`.
- **CI**: a new `Controls` job fingerprints the Docker image and records both decisions with `kosli evaluate policy --control … --fingerprint …`. The `Deploy` job now needs `Controls`.

### Lab 7 – Writing policies: Ergo

- **Read the input**: fetch the trail moment from the API to see which fields a policy can read.
- **Write a policy**: for a third control, `LAB-003` Binary provenance. Each artifact must have a build URL (`origin_url`), git commit info and a creation time. Learners fill in a skeleton, with a hint containing the solution.
- **Ergo concepts**: subjects, `named by each of $params.x`, requirements, checks, params, the report and violations.
- **Make it fail on purpose**: an artifact that doesn't exist, and a run without params.
- **Publish and enforce**: create the control and publish the policy, add a decision step to the `Controls` job, and require `LAB-003` in the Environment Policy.
- **Policy versions**: publish version 2, see that decisions cite the version that ran, and pin `@v1`.

### Lab 8 – Kosli administration: Terraform

- **Provider setup**: the Kosli provider in `terraform/main.tf`, authenticated with the existing environment variables.
- **Service account**: `labs-ci` with the `member` role and an API key. The GitHub secret `KOSLI_API_TOKEN` switches from the personal key used since Lab 2 to this key. This picks up the "use a service account for CI" note in Lab 2.
- **Import**: `import` blocks adopt the Flow (with `template = file(...)`), the `labs-prod` Environment, the Environment Policy, the policy attachment and the three controls.
- **No changes**: plan until there are no changes, then apply.
- **Pipeline takeover**: remove `Create/Update Flow`, `Update Kosli policy` and `Attach policy to environment` from the pipeline.
- **Change through code**: add tags to the Flow with Terraform.
- **Limitation**: Rego/Ergo policies have no Terraform resource, so they are still published with the CLI. This is said explicitly in the lab.
- **Course ending**: the Conclusion section moved here from the old Lab 5.

## Changes to existing labs

| Lab | Changes |
|---|---|
| README | New lab list and "You'll learn" bullets. New prerequisites: the Admin role with Controls enabled, and Terraform 1.10 or later. Links to *How Kosli works* |
| 1 | Link to Lab 2 uses the new title |
| 2 | New title. References to the Flow Template now point to Lab 5. The personal API key note points forward to Lab 8 |
| 3 | New title. The "this lab is about build controls" opening is replaced by a pointer to Lab 4. Next Steps leads to Lab 4 |
| 5 (old 4) | New title. The "Release controls" paragraph is removed. The Flow Template now also requires `LAB-001-decision` and `LAB-002-decision` (type `decision`) on `docker-image`. New explanation that a denied decision blocks the gate. Lab numbers and solution file names updated |
| 6 (old 5) | New title, and the "runtime controls" line is removed. **The Environment Policy is rewritten**: `provenance`, `trail-compliance` and `for_control: LAB-001/LAB-002`, with a paragraph on why it names no tools. **The deployment gate moves from the Flow Template to `--environment labs-prod`** (Policy Enforcement Point). The old optional gate section becomes "assert against a specific policy". The Conclusion moved to Lab 8 |

## Repository changes

**Renamed**
- `lab-03-build-controls.md` → `lab-03-artifacts-and-attestations.md`
- `lab-04-release-controls.md` → `lab-05-flow-templates-and-gates.md`
- `lab-05-runtime-controls.md` → `lab-06-environments-and-policies.md`
- `pipelines/04-complete.yaml` → `05-complete.yaml`, and `05-complete.yaml` → `06-complete.yaml`
- `pipelines/04-flow-template.yaml` → `05-flow-template.yaml`, and `05-kosli-policy.yml` → `06-kosli-policy.yml`

**New**
- `lab-04-controls-and-decisions.md`, `lab-07-writing-policies-with-ergo.md`, `lab-08-terraform-administration.md`
- `policies/attestation-compliant/`: the ready-made Ergo policy for Lab 4
- `pipelines/04-complete.yaml`: Lab 3 plus the `Controls` job
- `pipelines/07-complete.yaml`, `pipelines/07-kosli-policy.yml`, `pipelines/07-binary-provenance/`: Lab 7 solutions
- `pipelines/08-complete.yaml` and `pipelines/08-terraform/main.tf`: Lab 8 solutions

**Updated**
- `pipelines/05-complete.yaml` and `06-complete.yaml` include the `Controls` job. `06` asserts with `--environment`
- `pipelines/05-flow-template.yaml` and `06-kosli-policy.yml` match the new lab content
- `.gitignore` ignores Terraform state (it holds the CI API key) and the downloaded `policies/lib/ergo.rego`

**Unchanged**
- `.github/workflows/full-pipeline.yaml`, the learners' starting point

## To verify before the course is used

None of the new material has been run against a real Kosli Organization yet. Check these in a test run:

1. **Ergo grammar.** I couldn't run OPA locally, so the policies were written from the v0.5 docs. Check two forms in particular: the child subject `from: artifact.attestations_statuses named by $params.attestation` (Lab 4), and `named by each of $params.artifacts` (Lab 7).
2. **Artifact names without a template.** In Lab 4 the Flow still has an empty template. Check that `compliance_status.artifacts_statuses` is keyed by the `--name` used when attesting (`application`, `docker-image`) even then.
3. **Where decisions land.** Check that decisions recorded with `--fingerprint` show up as `LAB-00x-decision` on the `docker-image` artifact, so the Flow Template in Lab 5 matches them.
4. **Service account permissions.** Check that a `member` service account can record decisions with `kosli evaluate policy --control` (Lab 8).
5. **Terraform import.** Check that the plan after import has no changes. The provider docs warn that YAML formatting differences in `template` can show up as no-op changes.
6. **Ordering in Lab 7.** `LAB-003` must exist before the Environment Policy refers to it, and the decision must be recorded before the gate. The lab warns about this; check that the order of steps works in practice.

## Open points for discussion

- **Terraform in the dev environment**: Terraform is not in `devbox.json` or the devcontainer yet. The nixpkgs `terraform` package is unfree, so it needs `allowUnfree` and a regenerated `devbox.lock`. The alternative is to let learners install it themselves (what Lab 8 says now).
- **docs.kosli.com/labs**: the published copy still has the old 5-lab structure and titles. Should it be synced, or replaced with a link to this repository?
- **Docs on Ergo versions**: the docs' [Working with controls](https://docs.kosli.com/tutorials/working_with_controls) tutorial and [Rego Policy](https://docs.kosli.com/policy-reference/rego_policy) reference still use Ergo v0.2. They should be updated to v0.5 to match the labs (feedback for the docs team).
- **Controls are beta**: CLI flags and the policy YAML for controls may still change. Who keeps Labs 4 and 7 up to date?
- **Lab length**: Labs 4, 7 and 8 have more terminal work than the earlier labs. Do they fit in the training schedule, or should Lab 7 or 8 be optional or advanced?
- **File names**: the labs were renamed to match their new titles, which breaks old links to `lab-03-build-controls.md` and the other old names, e.g. in slides or bookmarks.
