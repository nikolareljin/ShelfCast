# Repository Guidelines

## Project Structure & Module Organization
- `web-app/` Flask dashboard app (`app.py`), HTML templates, and static assets.
- `nook-app/` Android application for Nook Simple Touch (API 7, Java).
- `raspberry-pi/` kiosk, systemd services, and Pi setup scripts.
- `scripts/` automation helpers (provisioning, deployment, local run).
- `dev-setup/` Ubuntu development environment setup scripts.
- `docs/` step-by-step setup and operating guides.
- `config/` example configuration files (`env.example`, `settings.example.json`).
- `ubuntu-test/` local, non-Pi test harness for the web app.
- `macos-test/` local macOS test harness.

## Build, Test, and Development Commands

### Initial Setup (Ubuntu)
- `./dev-setup/install-prerequisites.sh` installs system packages (Python, Java, ADB).
- `./dev-setup/install-android-sdk.sh` installs Android SDK with API 7 for Nook.
- `git submodule update --init --recursive` initializes `vendor/script-helpers` required by scripts.

### Web App (Server)
- `./scripts/run-web.sh` creates venv, installs Python deps, seeds config, and starts the web app.
- `cd ubuntu-test && ./setup.sh && ./run.sh` runs the web app locally on Ubuntu.

### Nook App (Android APK)
- `cd nook-app && ./gradlew assembleRelease` builds release APK for Nook Simple Touch.
- `cd nook-app && ./gradlew assembleDebug` builds debug APK.
- APK output: `nook-app/app/build/outputs/apk/release/app-release.apk`

### Deployment to Raspberry Pi
- `./scripts/deploy-to-pi.sh` syncs code to Pi via SSH.
- `./scripts/deploy-to-pi.sh --restart` syncs and restarts the service.
- `./scripts/deploy-apk-to-pi.sh` builds APK, copies to Pi, installs on Nook.
- `./scripts/pi-shell.sh` opens SSH session to Pi.
- `./scripts/pi-shell.sh "command"` runs a command on Pi.

## Coding Style & Naming Conventions
- Python code lives in `web-app/`. Follow standard PEP 8 style: 4-space indentation, snake_case for variables/functions, and CapWords for classes.
- Java code lives in `nook-app/`. Follow Android conventions: 4-space indentation, camelCase for methods/variables, PascalCase for classes.
- HTML templates live in `web-app/templates/`; keep template names short and descriptive (e.g., `index.html`, `settings.html`).
- Static assets live in `web-app/static/`; keep filenames kebab-case (e.g., `theme-dark.css`).
- Shell scripts use `bash` with `set -euo pipefail` for safety.

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
