# ShelfCast

ShelfCast turns a Nook Simple Touch or an old Android tablet/phone into a touch-enabled display for a Raspberry Pi 3. It runs a small dashboard web app for weather, news, todos, calendar, and package status, and supports remote updates through a web login or an SSH dialog-style CLI.

## Quick start

- Read `docs/README.md` for the full guide.
- Pick your access path:
  - Web app with login (recommended)
  - SSH + dialog CLI (alternate)
- For headless automation, see `docs/03-pi-setup.md`.
- Update dashboard settings at `/settings` after login.

## Repo layout

- `docs/` step-by-step setup and operating instructions
- `raspberry-pi/` Pi configuration, display/kiosk setup, and services
- `web-app/` dashboard web app
- `ubuntu-test/` local testing on Ubuntu
- `macos-test/` local testing on macOS
- `scripts/` install and helper scripts
- `config/` example env files
- `vendor/script-helpers/` git submodule required for bash scripts

## Status

This repo is a scaffold to get you to a working end-to-end setup quickly. Each module has TODOs and placeholders you can fill in for your APIs and data sources.

## CI

GitHub Actions use the `ci-helpers` reusable workflow in `.github/workflows/ci.yml`.
