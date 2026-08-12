# ArtVault — Phase Workflow (branch-per-phase + CodeRabbit)

Every GSD phase ships through a feature branch and a PR to `main`, so the
CodeRabbit GitHub app (installed on `kaishavery1977/artvault`) auto-reviews
each phase's diff before it lands. `main` stays reviewable and green.

## The flow (per phase)

1. **Branch** — cut the phase branch from the latest `main`:
   ```bash
   git checkout main && git pull
   git checkout -b feat/<phase-slug>
   ```
   Phase slugs mirror the planning dir, e.g. `feat/launch-experience-v2`.

2. **Plan + execute** — write the phase `PLAN.md` in `.planning/phases/`, then
   implement wave-by-wave with atomic commits (GSD conventions: descriptive
   messages, one logical change per commit).

3. **Verify before pushing** — every wave must be green before it leaves the
   machine:
   ```bash
   flutter analyze && flutter test
   ```

4. **Push + PR**:
   ```bash
   git push -u origin feat/<phase-slug>
   gh pr create --base main --head feat/<phase-slug> \
     --title "feat(<phase>): <summary>" \
     --body "Implements Phase <n> from .planning. CodeRabbit will review."
   ```

5. **CodeRabbit review** — the app posts findings on the PR automatically.
   - Fix **Critical** and **Warning** findings (push updates the PR; CodeRabbit
     re-reviews incrementally).
   - **Info** findings: fix if cheap, otherwise note and move on.

6. **Merge to `main`** (squash keeps history clean), then sync planning docs:
   ```bash
   gh pr merge --squash --delete-branch
   git checkout main && git pull
   ```

7. **Close the loop** — update `.planning/STATE.md` and `ROADMAP.md` on `main`
   with the phase outcome and merge commit.

## Exceptions

- **Planning docs only** (`.planning/*` edits with no `lib/`/`test/`
  changes): may go straight to `main` — CodeRabbit doesn't need to review
  markdown.
- **Emergency hotfixes**: direct-to-`main` allowed, but open the PR first and
  let the review post before merging when practical.
