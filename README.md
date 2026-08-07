# sg-e2e-terraform-fixtures

Terraform code backing the StackGuardian **WF Runs** automated test suite.

Each folder is a fixture: a workflow points at this repo with its `Working Dir` set to one of
them. **Nothing here is meant to run outside the test org** — the resources exist to be planned,
applied and destroyed by tests, not to serve anything.

```
wfr-tf-baseline/   applies clean · 3 buckets + a utility resource   ← the workhorse
wfr-in-flight/     holds mid-run so a running run can be read       ← unblocks all of cancel
wfr-plan-fail/     fails during plan, before any facts are written
wfr-apply-fail/    plan succeeds, apply collides on a taken name
wfr-tf-many/       40 resources with long addresses
wfr-no-op/         a plan that finds nothing to do, every time
wfr-init-fail/     dies during init, before any step exists
wfr-with-inputs/   six inputs of five types, for the +N more affordance
wfr-no-inputs/     none at all — the counterpart
wfr-logs-large/    50k lines, past any inline threshold
wfr-logs-debug/    carries a debug-only line
wfr-step-error-exit0/  prints an error banner and SUCCEEDS
```

⚠️ **The folder name IS the fixture id from the test-case plan** — the same `[wfr-...]` each case
carries in its `Preconditions`. They are deliberately not renamed to something more readable: a
failing test has to name the exact state the case asked for, findable without a mapping table.

---

## Where these are seeded

The code here is half of a fixture; the other half is a workflow on the platform pointing at it.

```
org     demo-org                     ⚠️ NOT autotesting-org — see below
group   e2e-wfruns-fixtures          16 workflows, one per fixture
repo    this one, branch main, Working Dir = the folder name
```

⚠️ **The organization is not interchangeable, and this cost a full day to find.** The same fixture
— same repo, same folder, same payload — behaves differently per org:

```
demo-org         run facts land at wfs/{ParentKSUID}/wfruns/{ResourceKSUID}/…   → readable ✅
autotesting-org  run facts land at wfs/{ParentKSUID}/wfruns/{run_id}/…          → 400 ❌
```

Core reads the KSUID path either way, so in `autotesting-org` every run reports
`"Workflow Run Facts does not exist"` even though the file was written correctly. Any case that
asserts on plan, cost, policy or resources is unrunnable there. Seeded in `demo-org` for that
reason alone.

### The template fixtures are not in this repo

Three fixtures use a **marketplace template** rather than a custom source, because the cases they
serve assert on template, revision and patch — fields a `customSource` workflow does not have:

```
sg-e2e-fixture:1   Latest=False   → wfr-no-op/        wfr-header-variants-old · wfr-revision-changed
sg-e2e-fixture:2   Latest=True    → wfr-with-inputs/  wfr-header-variants-new
```

⚠️ **So these folders have a second consumer.** Changing `wfr-no-op/` or `wfr-with-inputs/` also
changes what those template revisions serve. The template itself lives on the platform, created
via `POST /templates/` — it is not versioned here.

`wfr-revision-changed` additionally has its workflow moved to `:2` **after** its run executed on
`:1`, so the run and the workflow deliberately disagree. That divergence IS the fixture.

---

## Why folders and not branches

A workflow reads code from a repo, so fixtures that need *different code* need different
sources. Three ways to do that; this repo uses the third:

| | |
|---|---|
| six repos | unmaintainable |
| one repo, six branches | every fixture invisible from every other; branches drift apart silently |
| **one repo, one branch, folders** | all fixture code in one view, one commit changes what it must, reviewable in a normal PR |

The failure mode branches invite is real and we already hit it: a fixture whose definition
drifted from what its name promises. Two of the four seeded fixtures no longer do what they are
called.

⚠️ **One case still wants a branch.** `TC-197` needs a workflow whose *template revision changed
after a run*. That is naturally a second commit or branch — but it is one fixture, not six.

---

## The fixtures

### `wfr-tf-baseline/` — the workhorse

Referenced by more cases than any other fixture. Every element earns its place:

| | Why |
|---|---|
| `for_each` over three keys | a resource must be named by its **address**, not by its position. A singleton cannot exercise this |
| `random_id` | a `random_*` address renders `Service` as a dash while `aws_*` reads "AWS" — both sides of that assertion in one run |
| `aws_s3_bucket` | seconds to create and destroy, free while empty, and the `aws_` prefix feeds the `Service` column |
| `force_destroy` | without it a destroy fails once anything lands in the bucket, leaving the fixture dirty |
| random suffix | S3 bucket names are unique **across all of AWS** — a fixed name collides and the apply fails in a way that reads as a product bug |
| `tags` | the surface to drift: change one in the console, the next refresh should notice |
| two `output`s | one list, one scalar |

#### ⚠️ It has two stages, and applying them in order is what makes it useful

The plan has to carry **create, update, destroy, replace and untouched at the same time** — the
test cases name every one of those operations. A fixture that has only ever created resources can
never render a `~`, a `-` or a `-/+`, because **Terraform can only update or delete what is already
in state.**

So the fixture is a pair of applies, switched by `var.stage`:

```
stage = "seed"    alpha · beta · gamma · replaced-a          plants the pre-state
stage = "mixed"   alpha · beta        · replaced-b · added   THE fixture run
```

What the mixed plan carries, and where each operation comes from:

| Operation | Comes from |
|---|---|
| `-` destroy | `gamma` leaves the `for_each` set |
| `~` update in place | the `Revision` tag flips `v1` → `v2` on every surviving bucket |
| `-/+` replace | `replaced` carries `replace_token` in its **bucket name**, which is force-new |
| `+` create | `added` exists only in the mixed stage |
| untouched | `random_id.suffix` — unchanged, and still listed |

⇒ **Seed first, apply, then switch to mixed and apply again.** The mixed *run* is the fixture; the
state it leaves behind is incidental. Re-applying `mixed` afterwards is a no-op — to rebuild the
fixture, go back to `seed` and repeat.

⚠️ **The mixed plan shape cannot be verified locally.** `terraform validate` passes and the
formatting is clean, but a plan needs real AWS credentials, so what the run actually renders is
confirmed on the platform, not here.

### `wfr-in-flight/` — slow on purpose

A `time_sleep` before the bucket, so the run stalls **during** plan and apply rather than after
everything already exists. `hold_seconds` defaults to `600s` and is a variable.

Everything about a running run — the live badge, streaming logs, the cancel control and every
state cancel can be triggered from — needs a run that is still going when the test looks at it.
Without a deliberate hold it is a race the test either wins or reports as a flake, and neither
outcome says anything about the product.

**Referenced by more cases than anything except the baseline**, and it gates the whole cancel
block.

#### 🔴 `time_sleep` sleeps when it is CREATED — measured

Without a trigger the resource lands in state on the first apply and every apply after that plans
it as a **no-op**, so the hold silently stops happening:

```
apply on empty state       152s total · 109s inside apply-terraform-plan   ← the hold ran
apply on populated state    70s total ·  17s inside apply-terraform-plan   ← it did not
```

⇒ `triggers = { run = timestamp() }` differs on every plan, so the hold is recreated — and always
runs — on every apply. ⚠️ The cost is that this fixture's plan **always carries a replacement**.
Deliberate here; do not copy it into a fixture whose plan shape is what a case asserts on.

#### Why 600s

One UI observation costs ~17s measured end to end, of which ~16s is a `networkidle` wait that can
never settle because the dashboard polls continuously. At a 90s hold, one run served ~3 tests; the
in-flight block is 27 cases. A 10-minute hold is what lets **one run serve the whole block**
instead of paying for a run per handful of tests.

### `wfr-plan-fail/` — fails before writing anything

References a variable that is never declared, so Terraform rejects the configuration while
evaluating it: no resource list, no cost estimate, no policy evaluation.

⚠️ **The route matters, not only the outcome.** The fixture this replaces failed through poisoned
*inputs* — also an error at plan, but a different path. *"No facts"* is the actual assertion of
the cases that use it, so it has to fail before anything is written.

### `wfr-apply-fail/` — the plan survives, the apply does not

A bucket name fixed on purpose, with no random suffix. Terraform cannot know the name is taken
until it asks AWS, so the plan produces a complete valid set of facts and only the apply fails
with `BucketAlreadyExists`.

⚠️ **Requires `sg-e2e-taken-do-not-delete` to exist beforehand, and to NOT be in this fixture's
own state.** Both halves matter, and the second one is the trap:

```
first apply on a clean state  →  the fixture CREATES the bucket and adopts it
every apply after that        →  no collision, run COMPLETES, fixture is silently useless
a destroy                     →  takes the bucket with it
```

Measured on 2026-08-07: two consecutive applies both returned COMPLETED for exactly this reason.
The recovery sequence is `destroy` → recreate the bucket by hand → `apply`, which then fails as
intended.

⇒ **Never run `apply` on this fixture from an empty state**, and never run `destroy` on it at all.
The bucket lives outside Terraform on purpose; it is tagged `Purpose=wfr-apply-fail-collision-target`.

### `wfr-no-op/` — nothing to do, every time

No resources and **no outputs**, so the plan is empty on the first run and on every run after it.

⚠️ **The missing outputs are deliberate, and measured.** An output is itself a planned change:
with one declared, the first plan reports `Changes to Outputs` and the fixture is only a no-op
from the second run onwards. Declaring nothing is what makes it empty from the start.

The alternative — applying the baseline and planning it again — only reads as a no-op while
nothing drifts, and stops being one the moment anything changes outside Terraform.

### `wfr-tf-many/` — pagination and truncation

40 security groups with deliberately long names.

⚠️ **Security groups rather than buckets on purpose.** The default S3 quota is 100 buckets per
account and `wfr-tf-baseline/` already spends some; 40 more would push a shared account near the ceiling
and the fixture would fail for a reason unrelated to what it tests.

### `wfr-init-fail/` — dies before any step exists

Requires a provider that is not in the registry, so `init` fails while resolving it. Nothing
after init starts: no plan, no step output, no facts.

⚠️ **That is the distinction the cases rest on.** A failed *step* still produced a step and its
output; an init failure means the run died before the first step existed, so the surfaces that
read "which step failed" have nothing to read.

### `wfr-with-inputs/` and `wfr-no-inputs/`

Six inputs across five types — string, number, bool, list, map — against a configuration that
declares none.

⚠️ **The types differ on purpose.** The cases assert values keep their Terraform shape: strings
quoted, numbers and booleans bare, structures as raw objects. Six strings would let a page that
quotes everything pass.

### `wfr-logs-large/` — past any inline threshold

50 000 padded lines.

⚠️ **The threshold is a backend property and is not measured.** The count is deliberately far
past any plausible cutoff rather than tuned to it — a fixture sitting near the boundary would
flip between inline and pointer as the log format changes, and a test that passes for the wrong
reason is worse than one that fails.

### `wfr-logs-debug/` — one debug-only line

⚠️ **The marker literal is a guess at the shape, not field-truth.** Which token the platform
treats as debug-only lives in the runner (`sg-run-controller`), not here — the same gap that
blocks `TC-225`. Confirm the real one before writing the assertion, or the test matches a string
we invented.

### `wfr-step-error-exit0/` — looks failed, succeeded

Prints `--- ERROR ---` and exits 0. **The run succeeds**, so any surface deciding "failed" by
scanning the log for error-looking text gets it wrong. The exit code is the truth.

The plan names an existing instance (`simple-ec2-g8qe`, step `preprepre`), but that lives in a
personal workflow group — the churn this repo replaces.

---

## Not here, and why

**`wfr-minimal-config`** — a workflow with no source config, no mini steps, no runner constraints and
no approvers. That is **workflow configuration**, not code.

**Anything CUSTOM** — `wfStepInputData.command` is ignored; a step's command comes from its step
template. CUSTOM fixtures are built from step templates, not from this repo.

---

## Conventions

- Everything is tagged `ManagedBy = "platform-qa"` and `Fixture = "<folder>"`, so anything left
  behind is identifiable and safe to sweep.
- `region` defaults to `eu-central-1` and is a variable everywhere.
- No backend block: the platform manages the state.
- No secrets, no data sources reaching outside the account.
