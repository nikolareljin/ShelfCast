# Scripts and CI

## script-helpers

All bash scripts rely on the `script-helpers` library. Initialize the submodule:

```bash
git submodule update --init --recursive
```

The submodule uses the SSH URL (`git@github.com:nikolareljin/script-helpers.git`), so ensure your GitHub SSH keys are set up on the target machine.

If you need a different location, set `SCRIPT_HELPERS_DIR` before running a script.

## ci-helpers

GitHub Actions are wired to `ci-helpers` reusable workflows. See `.github/workflows/ci.yml`.

If you want to change the workflow or pin a different tag, update the `uses:` line in that file (e.g. `git@github.com:nikolareljin/ci-helpers.git` at the desired ref).
