---
name: scan-issues
description: Scan the Flutter app for bugs and architecture drift — runs the static passes (flutter analyze + tool/scan.dart), then dispatches the flutter-bug-hunter and flutter-arch-auditor agents, and merges everything into one ranked report. Use when asked to scan, audit, or review the project for issues, bugs, leaks, or convention violations.
---

# Scan the app for issues

Three passes, cheapest first. Each one catches what the previous cannot.

| Pass | Catches | Cost |
|---|---|---|
| `flutter analyze` | Dart-level lints and errors | seconds |
| `dart run tool/scan.dart` | This project's conventions: layering, DI, platform files, disposal | seconds |
| Agents | Semantic bugs: races, wrong-tree reads, state bugs | minutes |

## Arguments

- *(none)* — full scan of `lib/`, all three passes.
- `--quick` — static passes only, no agents.
- `--diff` — scope the agents to files changed against `master`.
- `--arch` / `--bugs` — run only that one agent.

## 1. Static passes

```
flutter analyze --no-pub
dart run tool/scan.dart --json
```

`tool/scan.dart` is the project-aware scanner; read its header comment for the
rule list. It exits 1 when any high-severity finding is present, so run it
without `&&` chaining. Groups are `arch`, `platform`, `lifecycle`, `runtime`,
`hygiene` — narrow with `--only=arch,platform`.

Also run `flutter test`. **Known baseline:** `test/widget_test.dart` is the
stale `flutter create` counter test and fails on a clean tree. Report it as a
standing issue, not as a regression, unless it has been fixed since.

Stop here for `--quick`. Otherwise carry the static findings forward — the
agents are told not to repeat them.

## 2. Agent passes

Spawn both in parallel, in the background, in a single message:

- `flutter-bug-hunter` — runtime bugs.
- `flutter-arch-auditor` — architecture and convention drift.

Give each agent, in its prompt:

- The scope: `lib/` in full, or the exact changed-file list for `--diff`
  (`git diff --name-only master...HEAD -- 'lib/**/*.dart'`).
- The static findings already reported, so it does not duplicate them.
- Any focus the user asked for.

Do not run these agents unprompted outside this skill — spawning them is what
the user asked for by invoking it.

## 3. Merge and report

Combine all three passes into one list. Then:

- **Drop duplicates.** Same file, same line, same underlying cause — keep the
  version with the better explanation, usually the agent's.
- **Demote what is already known.** `CLAUDE.md` documents deliberate scope
  cuts: recursive folder copy is unsupported by design, Firebase is web-only
  by necessity, VLC CPU cost is a tracked open risk. These are not findings.
- **Rank by consequence, not by pass.** A wrong-tree write found by an agent
  outranks every analyzer lint.

Write the full report to `docs/scan-report.md` (create `docs/` if needed) and
give the user a short summary in the terminal: the counts by severity, the
three or four findings actually worth acting on, and the path to the report.
Do not paste the whole report into the terminal.

Do not fix anything unless the user asks. The output of this skill is a report.

## Extending the scanner

When a bug class shows up twice, it belongs in `tool/scan.dart` rather than in
an agent prompt — deterministic, free, and it cannot regress. Add a rule to the
matching `check*` function, give it a `group/rule-name` id and a `hint` that
explains the consequence, and verify it against a deliberately broken fixture
file under `lib/` before trusting it.
