# Scripts and CI

## script-helpers

All bash scripts rely on the `script-helpers` library. Initialize the submodule:

```bash
git submodule update --init --recursive
```

The submodule uses the HTTPS URL (`https://github.com/nikolareljin/script-helpers.git`), so no SSH deploy key is needed on the target machine.

> **Existing clones (post SSH → HTTPS migration):** if you initialized the submodule before this change, the old SSH URL may be cached in `.git/config`. Run `git submodule sync --recursive` once before the update command to pick up the new URL.

If you need a different location, set `SCRIPT_HELPERS_DIR` before running a script.

## ci-helpers

GitHub Actions are wired to `ci-helpers` reusable workflows. See `.github/workflows/ci.yml`.

If you want to change the workflow or pin a different tag, update the `uses:` line in that file (e.g. `nikolareljin/ci-helpers/.github/workflows/python.yml@production`).
