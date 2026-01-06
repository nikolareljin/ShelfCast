# Nook Simple Touch setup

The Nook Simple Touch runs Android 2, so keep the dashboard compatible with older WebView/browsers when building UI changes.

## Display driver

You will need a community driver to use the Nook Simple Touch as a display. Common options are based on the Linux fbdev/USB gadget tooling. The exact steps vary with kernel version.

Keep the driver instructions here once confirmed:

- TODO: link to the chosen driver and exact install steps
- TODO: confirm touch input mapping

## Touch validation

After the driver is installed:

1. Plug in the Nook.
2. Run `xinput` and confirm a new touch device appears.
3. Use `xinput test <id>` to confirm events.

## Android tablet or phone alternative

If you use an old Android tablet or phone instead of the Nook (Android 4+):

1. Connect it to the same network as the Pi.
2. Open the browser and navigate to `http://<pi-ip>:8080`.
3. Enable any kiosk/pinned mode your launcher supports.
4. Optional: connect by USB and run `./scripts/android-provision.sh` on the Pi.

### Older Android kiosk tips (Android 4+)

- Prefer a lightweight browser (e.g., the stock browser or Firefox) and disable animations if available.
- Enable “stay awake”/screen-on while charging, or use a keep-awake app to avoid screen sleep.
- Add a home screen shortcut to the dashboard URL for quick launch.
- If supported, use a kiosk or pinned-mode app to lock the device to the dashboard.
