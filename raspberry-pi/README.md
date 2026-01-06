# Raspberry Pi files

- `kiosk.sh`: launches Chromium in kiosk mode
- `kiosk.service`: systemd unit for auto-start

## Enable kiosk

```bash
sudo cp raspberry-pi/kiosk.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable kiosk.service
sudo systemctl start kiosk.service
```

Update `ExecStart` in `kiosk.service` to match your user and repo path.

## Headless automation

- `scripts/pi-provision.sh` installs packages, clones the repo, and enables kiosk.
- `first-boot.service` can run provisioning automatically on first boot if the repo is preloaded.
