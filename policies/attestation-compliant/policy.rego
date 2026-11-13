package policy

import data.ergo
import rego.v1

# Read the Ergo requirements that Kosli loads from policy.ergo.yaml into data
default ergo_spec := null

ergo_spec := data.ergo_spec

default subjects := {}

subjects := data.subjects

default requirements := {}

requirements := data.requirements

# METADATA
# entrypoint: true
report := ergo.report(input, {"ergo_spec": ergo_spec, "subjects": subjects, "requirements": requirements}, data.params)

# Kosli's policy contract: a boolean allow with a safe default
default allow := false

allow if report.compliant

# METADATA
# entrypoint: true
violations := ergo.violations(report)
