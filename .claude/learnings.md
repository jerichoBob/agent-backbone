# Learnings

Corrections and lessons captured during development. Each entry records what went wrong and the rule going forward.

---

## Deploy Pipeline is Fully Automated — No Manual Smoke Gates

**Rule:** The deploy pipeline runs `tests/run-all.sh` automatically — no manual ctrl+c smoke test gate. `uat-deploy-app.sh` starts the app in detached mode, waits for `/health`, runs the full suite, tears down local, then proceeds to ECR/ECS. A test failure aborts the deploy.

**Why:** A manual "test then ctrl+c" gate requires a human in the loop and is inconsistent. The test suite is the verification — it should run automatically and gate the deploy on pass/fail.

**How to apply:** Never add manual pause points to the deploy script. Any new verification belongs in `tests/run-all.sh`, not as an interactive step.

---

## Tests at Every Deploy Layer

**Rule:** The SOP must include `tests/run-all.sh` after both local deploy and UAT deploy — not just before committing. Defense in depth for a multi-tenant app means testing at every layer of the stack on every deploy.

**Why:** Multitenant isolation bugs can appear at the DB layer, HTTP layer, job layer, or search layer independently. Running tests only once (pre-commit) misses regressions introduced by infra changes, migration drift, or environment differences.

**How to apply:** When documenting or updating the deploy SOP, always include `bash tests/run-all.sh` as a step after local deploy and after UAT deploy. When adding new spec ACs, add the corresponding test suite to `tests/run-all.sh` before shipping.

---

## Debugging requires systematic hypothesis testing

**Rule:** When debugging, follow a strict chain: form hypothesis → design tests → run tests → validate or eliminate → repeat. Never say "only remaining explanation" after testing one hypothesis. Always enumerate all possible causes before claiming elimination.

**Why:** Lazy thinking leads to wrong conclusions and wasted time. A proper debug process catches edge cases and avoids confirmation bias.

**How to apply:**

1. State the hypothesis explicitly
2. Design the minimum tests needed to validate or eliminate it
3. Run all tests before concluding
4. If eliminated, enumerate ALL remaining hypotheses — not just one
5. Repeat until root cause is confirmed

---

## Always include required parameters in tool calls

**Rule:** `write` requires both `path` AND `content`. `edit` requires both `path` AND `edits`. Never call either with only `path`.

**Why:** The tools will silently fail with a validation error every time, causing repeated identical failures.

**How to apply:** Before invoking `write` or `edit`, confirm both required params are present in the call.

---

## Always build Docker images for linux/amd64 when targeting AWS Fargate

**Rule:** Any Docker image built on Apple Silicon (arm64) that will run on AWS Fargate must be built with `--platform linux/amd64`. This applies to all images: api, web, migrate, seed, and any future one-off task images.

**Why:** Fargate runs on x86_64. An arm64 image pushed to ECR will fail at task start with `CannotPullContainerError: image Manifest does not contain descriptor matching platform 'linux/amd64'` — a non-obvious error that wastes a full Fargate task cycle to discover.

**How to apply:** Always use `docker build --platform linux/amd64 ...` for any image destined for ECR/Fargate. Add `--platform linux/amd64` to any new Dockerfile build commands in deploy scripts.

---

## "Local deploy" means scripts/local-docker-run.sh — full Docker image pipeline

**Rule:**

- "local deploy" (or "deploy locally") = `bash scripts/local-docker-run.sh` — builds all 4 production images (api, web, migrate, seed), runs migrate, runs seed, then starts services via `docker-compose.local.yml`. This is UAT-DEV: a full environment mirror with the validation baseline dataset.
- "UAT deploy" (or "deploy to UAT") = `bash scripts/uat-deploy-app.sh` — builds images, validates locally, pushes to ECR, runs migrate + seed on Fargate, redeploys ECS.
- `pnpm dev` is for raw code editing only — not a "deploy".

**Why:** Local deploy must mirror UAT exactly: same images, same migrate+seed pipeline, same baseline dataset. Without seed, tests have no data. Without Docker images, you're not testing what ships.

**How to apply:** When the user says "deploy locally" or "local deploy" → run `bash scripts/local-docker-run.sh`. Never substitute `pnpm dev` for a local deploy.

---

## Docker Image Inventory and Deploy Pipeline Wiring

**Rule:** There are 4 Docker images in this project. All 4 must be built and run in **both** local-docker and UAT deploy pipelines. Seed is not optional — it establishes the validation baseline dataset without which tests cannot run meaningfully.

| Image   | Dockerfile                    | local-docker-run.sh             | uat-deploy-app.sh                      |
| ------- | ----------------------------- | ------------------------------- | -------------------------------------- |
| API     | `apps/api/Dockerfile`         | ✅ build + run                  | ✅ build + push + ECS service          |
| Web     | `apps/web/Dockerfile`         | ✅ build + run                  | ✅ build + push + ECS service          |
| Migrate | `apps/api/Dockerfile.migrate` | ✅ build + run against local DB | ✅ build + push + Fargate one-off task |
| Seed    | `apps/api/Dockerfile.seed`    | ⚠️ must run after migrate       | ⚠️ must run after migrate on Fargate   |

**Why:** The seed populates the validation baseline dataset. Without it, UAT has no data and tests cannot pass. Local Docker (UAT-DEV) is a full environment mirror — it must also seed. Migrate without seed = empty DB = broken tests.

**How to apply:**

- `local-docker-run.sh`: after migrate, build `grostak/seed:local` and `docker run` it against local DB before starting services.
- `uat-deploy-app.sh`: after migrate Fargate task completes, run seed as a second Fargate one-off task using `grostak/seed:latest` from ECR.
- Never describe `Dockerfile.seed` as "UAT only" — it belongs in both pipelines.
- Seed image must also use `--platform linux/amd64`.

---

## write tool requires BOTH path AND content — never call with path alone

**What went wrong:** Called `write` with only `path`, no `content`. The tool validated and failed every single retry with `content: must have required properties content`. Kept retrying with the same bad invocation.

**Bad invocation:**

```json
{ "path": "specs/spec-v22-admin-tenant-impersonation.md" }
```

**Good invocation:**

```json
{
  "path": "specs/spec-v22-admin-tenant-impersonation.md",
  "content": "---\nversion: 22\n..."
}
```

**Rule:** The `write` tool requires both `path` AND `content` — always. Before calling `write`, confirm both parameters are present in the call. `content` cannot be omitted even for new empty files. If the content is long, compose it fully first, then pass it in a single `write` call.

---

## write tool: generation loop — switch to bash heredoc immediately

**What went wrong:** When generating a `write` call with large TypeScript file content, the model emitted the tool call with only `path`, silently omitting `content`. Every retry reproduced the same broken generation pattern — the error message in context included a `write` call template which the model pattern-matched against, re-generating the same empty-content call. 20+ identical failures in a row wasted significant session budget.

**Root cause:** Model generation failure during large `write` invocations — `content` was never emitted. Not a tool bug. The retry loop made it worse by feeding the same broken template back into context.

**Rule:** If `write` fails with "content was empty" even once — **immediately switch to `bash` heredoc**. Never retry `write` in a loop.

```bash
cat > 'path/to/file.ts' << 'HEREDOC'
<full file content>
HEREDOC
```

For large files (>50 lines), always prefer `bash` heredoc over `write`. It's more reliable for multi-line content.

**How to detect:** The error says `content was empty for path "..."`. First occurrence = switch to bash. Do not retry `write`.

---

## Self-Correct Immediately

**Rule:** After every mistake — whether the user points it out or I catch it myself — immediately record it here. Don't wait to be told.

**Why:** Corrections that aren't recorded are forgotten. The expectation is: each correction makes the next session smarter. Waiting for the user to say "remember this" is the wrong behavior.

**How to apply:** As soon as I recognize a mistake or receive a correction, before moving on, add an entry to this file and commit it with the relevant change.

---

## Dockerfile must declare ARG for every NEXT*PUBLIC*\* build-time variable

**Rule:** Every `--build-arg NEXT_PUBLIC_*` passed to `docker build` must have a matching `ARG` + `ENV` declaration in the Dockerfile **in the build stage that runs `next build`**. Missing `ARG` means the variable is silently ignored by Docker — Next.js never sees it during the build.

**Why:** Without `ARG NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY` declared, Clerk can't initialize during `next build`. With `output: "standalone"`, Next.js statically traces routes at build time — any route handler that imports `@clerk/nextjs/server` and can't initialize gets dropped from the standalone output entirely. The route exists in source, works in `pnpm dev` (which reads `.env.local`), but returns 404 in the built Docker image because it was never included in `.next/standalone`.

**How to apply:** When adding a new `NEXT_PUBLIC_*` env var, add both to:

1. `apps/web/Dockerfile` in the builder stage: `ARG NEXT_PUBLIC_FOO` + `ENV NEXT_PUBLIC_FOO=$NEXT_PUBLIC_FOO`
2. The build script (`uat-build-push.sh` etc): `--build-arg NEXT_PUBLIC_FOO="$VALUE"`

Never assume a `--build-arg` is visible to the build without a matching `ARG` declaration.
