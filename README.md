# sg-e2e-terraform-fixtures

Terraform code backing the StackGuardian **WF Runs** automated test suite.

Each folder is a fixture: a workflow points at this repo with its `Working Dir` set to one of
them. **Nothing here is meant to run outside the test org** — the resources exist to be planned,
applied and destroyed by tests, not to serve anything.

```
baseline/     applies clean · 3 buckets + a utility resource   ← the workhorse
in-flight/    holds mid-run so a running run can be read       ← unblocks all of cancel
plan-fail/    fails during plan, before any facts are written
apply-fail/   plan succeeds, apply collides on a taken name
many/         40 resources with long addresses
```

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

### `baseline/` — the workhorse

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

**Applying this is the single highest-return action in the whole fixture backlog.** Nothing in
the test group has ever applied, and without state there is no destroy, no refresh, no drift and
no resources.

### `in-flight/` — slow on purpose

A `time_sleep` before the bucket, so the run stalls **during** plan and apply rather than after
everything already exists. `hold_seconds` defaults to `90s` and is a variable.

Everything about a running run — the live badge, streaming logs, the cancel control and every
state cancel can be triggered from — needs a run that is still going when the test looks at it.
Without a deliberate hold it is a race the test either wins or reports as a flake, and neither
outcome says anything about the product.

**Referenced by more cases than anything except the baseline**, and it gates the whole cancel
block.

### `plan-fail/` — fails before writing anything

References a variable that is never declared, so Terraform rejects the configuration while
evaluating it: no resource list, no cost estimate, no policy evaluation.

⚠️ **The route matters, not only the outcome.** The fixture this replaces failed through poisoned
*inputs* — also an error at plan, but a different path. *"No facts"* is the actual assertion of
the cases that use it, so it has to fail before anything is written.

### `apply-fail/` — the plan survives, the apply does not

A bucket name fixed on purpose, with no random suffix. Terraform cannot know the name is taken
until it asks AWS, so the plan produces a complete valid set of facts and only the apply fails
with `BucketAlreadyExists`.

⚠️ **Requires `sg-e2e-taken-do-not-delete` to exist beforehand.** Create it once, by hand, and
never delete it — if it disappears the apply starts succeeding and this stops being a fixture.

### `many/` — pagination and truncation

40 security groups with deliberately long names.

⚠️ **Security groups rather than buckets on purpose.** The default S3 quota is 100 buckets per
account and `baseline/` already spends some; 40 more would push a shared account near the ceiling
and the fixture would fail for a reason unrelated to what it tests.

---

## Not here, and why

**`no-op`** — a no-op is *"apply, then plan again"*. The baseline once applied **is** the no-op,
so it needs no code of its own. It needs a second workflow only if a no-op must coexist with a
baseline that still has pending changes.

**`minimal-config`** — a workflow with no source config, no mini steps, no runner constraints and
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
