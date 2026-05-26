# Scripts and CI

## script-helpers

All bash scripts rely on the `script-helpers` library. Initialize the submodule:

```bash
git submodule sync --recursive
git submodule update --init --recursive
```

The submodule uses the HTTPS URL (`https://github.com/nikolareljin/script-helpers.git`), so no SSH deploy key is needed on the target machine.

> **Existing clones:** if you initialized the submodule before the SSH → HTTPS migration, run `git submodule sync --recursive` first so Git picks up the new URL from `.gitmodules` instead of the cached SSH URL in `.git/config`.

If you need a different location, set `SCRIPT_HELPERS_DIR` before running a script.

## ci-helpers

GitHub Actions are wired to `ci-helpers` reusable workflows. See `.github/workflows/ci.yml`.

If you want to change the workflow or pin a different tag, update the `uses:` line in that file (e.g. `nikolareljin/ci-helpers/.github/workflows/python.yml@production`).
