# .tflint.hcl — basic linting ruleset for the workshop's OpenTofu code.
# Run: tflint --recursive   (or via pre-commit). Docs: https://github.com/terraform-linters/tflint

config {
  # Lint modules called by the configuration too.
  call_module_type = "all"
  force            = false
}

# Core ruleset: naming conventions, unused declarations, deprecated syntax, etc.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# --- Individual rules (explicit so learners can see what's enforced) ---------

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}
