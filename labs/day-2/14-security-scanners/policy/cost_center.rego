package main

import future.keywords.contains
import future.keywords.if

# Org policy: every aws_security_group must carry a cost_center tag.
# Generic scanners do not encode this rule — Conftest/OPA does.
deny contains msg if {
	some name
	resource := input.resource.aws_security_group[name][_]
	not resource.tags.cost_center
	msg := sprintf("aws_security_group.%s missing required tag cost_center", [name])
}
