# Host test setup (Ubuntu/Debian/macOS/WSL)

Use this to validate the web app without the Pi hardware from a controller host.

Supported hosts:
- Ubuntu/Debian-based Linux (including WSL)
- macOS

```bash
git submodule update --init --recursive
```

## Ubuntu/Debian/WSL

```bash
cd ubuntu-test
./setup.sh
./run.sh
```

## macOS

Ensure Python 3 is installed (for example, `brew install python`), then:

```bash
cd macos-test
./setup.sh
./run.sh
```
