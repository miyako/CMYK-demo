# Working in this repository

This is a **consumer** of the `miyako/CMYK` component (a demo/integration
project), not the component itself. Component logic lives upstream; if a bug is
in conversion rather than in how this demo calls it, fix it in
[miyako/CMYK](https://github.com/miyako/CMYK).

Conventions come from the `miyako/skills` submodule in `.agents/`. Read the
relevant skill before editing its area: `4dform` (form JSON), `4dcss` (styles),
`4dproject` (project structure), `4dcli` (tool4d runs), `4dstartup` (window
start-up), `4dlsp`/`4dform` (validation).

## Ground rules

* Keep the component pinned by tag in `Project/Sources/dependencies.json`. Do not
  vendor or patch it here.
* Never commit `Components/`, `tools/`, `LabOutput/`, `DerivedData/` or `Libraries/`;
  they are generated (see `.gitignore`).
* The scenario matrix is the contract with the component: every row's `expect`
  is a claim about behaviour. When the component's behaviour changes, change the
  row and the note **together**, and say so in the commit message.
* Do not present the CMYK preview as colour proof. It is a display approximation;
  keep that wording in UI text and docs.
* Numbers that live in the UI (window 1240×946, quality range 1…100) must stay
  consistent with the form JSON, the class validation and the README.

## Before committing

```sh
scripts/verify.sh     # schema + geometry + bindings + project JSON
scripts/accept.sh     # needs tool4d; 11/11 scenarios plus the interactive path
```

Both must pass. `scripts/accept.sh` writes a JSON report to `/tmp` by default and
exits with the failure count.

## How the pieces connect

`On Startup` → `Start` → `DIALOG("Lab"; cs.CMYKLab.new())`. The form declares
`"formClass": "CMYKLab"`, so every `Form.<name>` in the form JSON is a property of
`Project/Sources/Classes/CMYKLab.4dm`. Object methods are one-liners that call
class functions; keep logic in the class so it stays testable headlessly.

`Acceptance` is the only place allowed to call `QUIT 4D`; it exits with the
number of failed scenarios so CI can use the status code.

## Adding a scenario

1. Add the case in `_loadScenarios` (name, kind, source, profile, options,
   `expect`, `note`).
2. Make sure the expectation is the component's *documented* behaviour; run
   `scripts/accept.sh` to confirm.
3. If it needs a new asset, add it to `scripts/generate_assets.py` (deterministic
   numpy/Pillow) rather than committing a hand-made binary.
4. Update `README.md`/`NOTES.md` if the case documents a new error code.
