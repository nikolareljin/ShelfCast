# Repository Guidelines

## Project Structure & Module Organization
- `web-app/` Flask dashboard app (`app.py`), HTML templates, and static assets.
- `raspberry-pi/` kiosk and systemd service scripts for Pi setup.
- `scripts/` automation helpers (provisioning, local run).
- `docs/` step-by-step setup and operating guides.
- `config/` example configuration files (`env.example`, `settings.example.json`).
- `ubuntu-test/` local, non-Pi test harness for the web app.

## Build, Test, and Development Commands
- `git submodule update --init --recursive` initializes `vendor/script-helpers` required by scripts.
- `./scripts/run-web.sh` creates a venv, installs Python deps, seeds `config/settings.json`, and starts the web app.
- `cd ubuntu-test && ./setup.sh` prepares a local Ubuntu test environment.
- `cd ubuntu-test && ./run.sh` runs the web app against the Ubuntu test setup.

## Coding Style & Naming Conventions
- Python code lives in `web-app/`. Follow standard PEP 8 style: 4-space indentation, snake_case for variables/functions, and CapWords for classes.
- HTML templates live in `web-app/templates/`; keep template names short and descriptive (e.g., `index.html`, `settings.html`).
- Static assets live in `web-app/static/`; keep filenames kebab-case (e.g., `theme-dark.css`).

## Testing Guidelines
- There is no automated test suite in this repo.
- Use `ubuntu-test/` to validate changes without Pi hardware.
- When adding tests, document the command in `docs/07-ubuntu-test.md`.

## Commit & Pull Request Guidelines
- No Git history is present in this workspace, so there is no established commit convention.
- Use clear, scoped commit messages (e.g., `web-app: add calendar card`).
- PRs should describe user-facing changes, include setup/config notes, and link relevant issues.

## Configuration & Security Tips
- Copy `config/env.example` to `config/.env` and `config/settings.example.json` to `config/settings.json`.
- Avoid committing real API keys; keep secrets in local `.env` files.
