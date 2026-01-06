# Remote access

## Web app (recommended)

- Browse to `http://<pi-ip>:8080`
- Login with the credentials from `config/settings.json`
- Update data sources and settings

### System changes via web UI

The web UI writes pending system changes to `config/system_changes.json`. Apply them on the Pi:

```bash
sudo /home/pi/ShelfCast/raspberry-pi/apply-system-changes.sh
```

This updates `/etc/dhcpcd.conf` and requires a reboot to take effect. Default interface is `eth0`, but you can switch to `wlan0` for a Nook-based setup.

## SSH dialog app (alternate)

A simple terminal UI can be used over SSH. It writes to the same config files.

- TODO: implement `ubuntu-test/dialog-cli/` and `raspberry-pi/dialog-cli/`
