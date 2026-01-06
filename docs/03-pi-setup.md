# Raspberry Pi setup

## OS install

1. Install Raspberry Pi OS Lite on the microSD.
2. Enable SSH in the imager or add an empty `ssh` file to the boot partition.
3. Boot the Pi and SSH in.

## System packages

Run from the Pi:

```bash
sudo apt update
sudo apt install -y git python3 python3-venv python3-pip chromium-browser xserver-xorg x11-xserver-utils xinit
```

## Headless automation (recommended)

Two options are provided:

- One-time provisioning script you run over SSH after first boot.
- First-boot service that runs automatically if the repo is already on the Pi.

### Option A: SSH provisioning script

From your laptop:

```bash
ssh pi@<pi-ip>
curl -fsSL <your-raw-repo-url>/scripts/pi-provision.sh -o /tmp/pi-provision.sh
chmod +x /tmp/pi-provision.sh
/tmp/pi-provision.sh <your-git-repo-url>
```

### Option B: First-boot service

If you are building a custom image, place the repo at `/home/pi/ShelfCast`, then:

```bash
sudo cp /home/pi/ShelfCast/raspberry-pi/first-boot.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable first-boot.service
```

Place a file at `/boot/shelfcast_repo_url.txt` with your git repo URL before first boot.

## Clone and configure

```bash
git clone <your-github-url> ShelfCast
cd ShelfCast
git submodule update --init --recursive
cp config/env.example config/.env
cp config/settings.example.json config/settings.json
```

Ensure the Pi has GitHub SSH keys configured for the `script-helpers` submodule.

Edit `config/.env` for credentials and data locations.

## Install the web app

```bash
cd web-app
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Run the web app

```bash
./scripts/run-web.sh
```

## Onboarding (recommended)

After provisioning, run the guided CLI:

```bash
./scripts/onboarding-cli.sh
```

The kiosk launches the local onboarding page at `http://localhost:8080/onboarding`,
which also shows the Pi IP address for remote setup.

### Android USB provisioning (optional)

If you want to auto-install APKs or open the dashboard on an Android 4+ device:

```bash
./scripts/android-provision.sh
```

Place APKs to auto-install in `config/android/apks/` before running the script.

## Kiosk mode

See `raspberry-pi/kiosk.service` and `raspberry-pi/kiosk.sh` for auto-start. Enable with systemd.
