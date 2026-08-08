# Labs

Standalone Markdown labs under `labs/day-N/`. Each lab pairs with a section
(`SNN`) and is meant to be copy-pasteable. Emulator labs need LocalStack
(`task lab:up`); mock-provider labs do not.

Interactive picker (optional [`gum`](https://github.com/charmbracelet/gum)):

```bash
task lab    # setup/lab.sh — pick a lab and run common tofu steps
```

Source of truth on GitHub:
[labs/](https://github.com/PlatformRelay/OpenTofu-Workshop/tree/main/labs).

## Day 1 — Author

| Lab | Topic |
| --- | --- |
| [00-setup](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-1/00-setup.md) | Setup and first resource |
| [01-iac-fork](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-1/01-iac-fork.md) | Infrastructure as Code |
| [02-hcl-blocks](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-1/02-hcl-blocks.md) | HCL building blocks |
| [03-core-workflow](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-1/03-core-workflow.md) | Plan / apply / destroy |
| [04-state](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-1/04-state.md) | State |
| [05-state-encryption](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-1/05-state-encryption.md) | State encryption |
| [06-variables](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-1/06-variables.md) | Variables & types |
| [15-conditions-checks](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-1/15-conditions-checks.md) | Preconditions & checks |
| [07-modules](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-1/07-modules.md) | Modules |
| [08-naming-labels](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-1/08-naming-labels.md) | Naming & labelling |
| [09-best-practices](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-1/09-best-practices.md) | Best practices *(recommended)* |
| [10-differentiators](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-1/10-differentiators.md) | OpenTofu differentiators *(recommended)* |
| [11-taco-landscape](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-1/11-taco-landscape.md) | TACO landscape *(optional, paper)* |

## Day 2 — Test

| Lab | Topic |
| --- | --- |
| [12-testing-pyramid](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-2/12-testing-pyramid.md) | Testing pyramid |
| [13-static-analysis](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-2/13-static-analysis.md) | Static analysis |
| [14-security-scanners](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-2/14-security-scanners.md) | Security & policy scanners |
| [16-tofu-test](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-2/16-tofu-test.md) | Native `tofu test` |
| [17-mocking](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-2/17-mocking.md) | Mocking providers |
| [18-terratest-cost](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-2/18-terratest-cost.md) | Terratest & cost *(optional)* |
| [19-testing-cicd](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-2/19-testing-cicd.md) | Testing in CI/CD |

## Day 3 — Scale

| Lab | Topic |
| --- | --- |
| [20-why-terramate](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-3/20-why-terramate.md) | Why Terramate |
| [21-stacks](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-3/21-stacks.md) | Stacks |
| [22-codegen](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-3/22-codegen.md) | Code generation |
| [23-orchestration](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-3/23-orchestration.md) | Orchestration |
| [24-change-detection](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-3/24-change-detection.md) | Change detection |
| [25-terramate-ci-cloud](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-3/25-terramate-ci-cloud.md) | Terramate CI + Cloud *(optional)* |
| [26-capstone](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-3/26-capstone.md) | Capstone & wrap-up |
| [27-terragrunt-comparison](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-3/27-terragrunt-comparison.md) | Terragrunt vs Terramate *(optional appendix)* |
| [28-ecosystem-tooling](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/labs/day-3/28-ecosystem-tooling.md) | Ecosystem tooling *(optional appendix)* |

Workdirs for runnable OpenTofu (init/plan/apply) often sit beside the lab
Markdown as `labs/day-N/NN-topic/` directories — follow each lab’s paths.

## Environment reminders

```bash
task setup       # toolchain
task lab:up      # LocalStack on :4566
task lab:down    # wipe emulator (clean slate)
```

See [setup.md](setup.md) and
[setup/localstack.md](https://github.com/PlatformRelay/OpenTofu-Workshop/blob/main/setup/localstack.md).
