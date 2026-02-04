import json
import os
import socket
import subprocess
from pathlib import Path

from dotenv import load_dotenv
from flask import Flask, jsonify, redirect, render_template, request, session, url_for
from werkzeug.security import check_password_hash, generate_password_hash


def load_env():
    load_dotenv(os.environ.get("SHELFCAST_ENV_FILE", "../config/.env"))
    return {
        "secret_key": os.environ.get("SHELFCAST_SECRET_KEY", "change-me"),
        "data_path": os.environ.get("SHELFCAST_DATA_PATH", "../data/sample_data.json"),
        "settings_path": os.environ.get("SHELFCAST_SETTINGS_PATH", "../config/settings.json"),
        "settings_example_path": os.environ.get(
            "SHELFCAST_SETTINGS_EXAMPLE_PATH", "../config/settings.example.json"
        ),
        "system_changes_path": os.environ.get(
            "SHELFCAST_SYSTEM_CHANGES_PATH", "../config/system_changes.json"
        ),
        "port": int(os.environ.get("SHELFCAST_PORT", "8080")),
    }


def ensure_settings(settings_path, example_path):
    settings_file = Path(settings_path)
    if settings_file.exists():
        return
    example_file = Path(example_path)
    if not example_file.exists():
        settings_file.parent.mkdir(parents=True, exist_ok=True)
        settings_file.write_text("{}", encoding="utf-8")
        return
    settings_file.parent.mkdir(parents=True, exist_ok=True)
    settings_file.write_text(example_file.read_text(encoding="utf-8"), encoding="utf-8")


def read_json(path, fallback):
    file_path = Path(path)
    if not file_path.exists():
        return fallback
    return json.loads(file_path.read_text(encoding="utf-8"))


def write_json(path, payload):
    file_path = Path(path)
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


DEFAULT_SETTINGS = {
    "auth": {
        "admin_user": "admin",
        "admin_password": "change-me",
        "require_login_for_display": False,
    },
    "data": {"data_path": "../data/sample_data.json"},
    "display": {
        "show_weather": True,
        "show_news": True,
        "show_todos": True,
        "show_calendar": True,
        "show_packages": True,
    },
    "news": {"predefined_sources": ["https://example.com/rss"], "custom_sources": []},
    "calendar": {
        "google": {
            "enabled": False,
            "client_id": "",
            "client_secret": "",
            "device_code": "",
            "refresh_token": "",
        }
    },
    "system": {
        "static_ip": {"enabled": False, "iface": "eth0", "address": "", "router": "", "dns": ""}
    },
}


def merge_settings(defaults, override):
    if not isinstance(defaults, dict) or not isinstance(override, dict):
        return override if override is not None else defaults
    merged = {}
    for key, value in defaults.items():
        if key in override:
            merged[key] = merge_settings(value, override[key])
        else:
            merged[key] = value
    for key, value in override.items():
        if key not in merged:
            merged[key] = value
    return merged


def read_data(data_path):
    return read_json(
        data_path,
        {
            "weather": {},
            "news": [],
            "todos": [],
            "calendar": [],
            "packages": [],
        },
    )


def get_ip_address():
    ip_address = ""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.connect(("8.8.8.8", 80))
            ip_address = sock.getsockname()[0]
    except OSError:
        pass

    if not ip_address:
        try:
            output = subprocess.check_output(["hostname", "-I"], text=True).strip()
            ip_address = output.split()[0] if output else ""
        except (OSError, subprocess.CalledProcessError):
            ip_address = ""

    return ip_address or "unknown"


env = load_env()
ensure_settings(env["settings_path"], env["settings_example_path"])
app = Flask(__name__)
app.secret_key = env["secret_key"]


def load_settings():
    raw = read_json(env["settings_path"], {})
    return merge_settings(DEFAULT_SETTINGS, raw)


def save_settings(settings):
    write_json(env["settings_path"], settings)


def is_logged_in(settings):
    return session.get("user") == settings.get("auth", {}).get("admin_user")

def requires_display_login(settings):
    return bool(settings.get("auth", {}).get("require_login_for_display", False))


@app.route("/")
def index():
    settings = load_settings()
    if requires_display_login(settings) and not is_logged_in(settings):
        return redirect(url_for("login"))
    data = read_data(settings.get("data", {}).get("data_path", env["data_path"]))
    display = settings.get("display", {})
    return render_template(
        "index.html", data=data, display=display, ip_address=get_ip_address()
    )


@app.route("/api/data")
def api_data():
    settings = load_settings()
    if requires_display_login(settings) and not is_logged_in(settings):
        return jsonify({"error": "unauthorized"}), 401
    return jsonify(read_data(settings.get("data", {}).get("data_path", env["data_path"])))


@app.route("/login", methods=["GET", "POST"])
def login():
    settings = load_settings()
    auth = settings.get("auth", {})
    if request.method == "POST":
        username = request.form.get("username", "")
        password = request.form.get("password", "")
        password_hash = auth.get("admin_password_hash", "")
        plaintext_password = auth.get("admin_password", "")
        password_ok = False
        if password_hash:
            password_ok = check_password_hash(password_hash, password)
        elif plaintext_password:
            password_ok = plaintext_password == password
        if username == auth.get("admin_user") and password_ok:
            session["user"] = username
            return redirect(url_for("index"))
        return render_template(
            "login.html", error="Invalid credentials", ip_address=get_ip_address()
        )
    return render_template("login.html", ip_address=get_ip_address())


@app.route("/onboarding")
def onboarding():
    return render_template("onboarding.html", ip_address=get_ip_address())


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


@app.route("/settings", methods=["GET", "POST"])
def settings():
    current = load_settings()
    if not is_logged_in(current):
        return redirect(url_for("login"))

    if request.method == "POST":
        auth = current.setdefault("auth", {})
        admin_user = request.form.get("admin_user", auth.get("admin_user", "admin")).strip()
        auth["admin_user"] = admin_user or auth.get("admin_user", "admin")

        new_password = request.form.get("admin_password", "")
        if new_password:
            auth["admin_password_hash"] = generate_password_hash(new_password)
            auth.pop("admin_password", None)

        data = current.setdefault("data", {})
        data_path = request.form.get("data_path", data.get("data_path", env["data_path"]))
        data["data_path"] = data_path.strip() or env["data_path"]

        display = current.setdefault("display", {})
        display["show_weather"] = bool(request.form.get("show_weather"))
        display["show_news"] = bool(request.form.get("show_news"))
        display["show_todos"] = bool(request.form.get("show_todos"))
        display["show_calendar"] = bool(request.form.get("show_calendar"))
        display["show_packages"] = bool(request.form.get("show_packages"))

        news = current.setdefault("news", {})
        predefined_raw = request.form.get("news_predefined_sources", "")
        predefined_sources = [
            line.strip() for line in predefined_raw.splitlines() if line.strip()
        ]
        custom_raw = request.form.get("news_custom_sources", "")
        custom_sources = [line.strip() for line in custom_raw.splitlines() if line.strip()]
        news["predefined_sources"] = predefined_sources
        news["custom_sources"] = custom_sources

        calendar = current.setdefault("calendar", {})
        google = calendar.setdefault("google", {})
        google["enabled"] = bool(request.form.get("google_enabled"))
        google["client_id"] = request.form.get("google_client_id", "").strip()
        google["client_secret"] = request.form.get("google_client_secret", "").strip()
        google["device_code"] = request.form.get("google_device_code", "").strip()
        google["refresh_token"] = request.form.get("google_refresh_token", "").strip()

        system = current.setdefault("system", {})
        static_ip = system.setdefault("static_ip", {})
        static_ip["enabled"] = bool(request.form.get("static_ip_enabled"))
        static_ip["address"] = request.form.get("static_ip_address", "").strip()
        static_ip["router"] = request.form.get("static_ip_router", "").strip()
        static_ip["dns"] = request.form.get("static_ip_dns", "").strip()
        static_ip["iface"] = request.form.get("static_ip_iface", "").strip() or "eth0"

        save_settings(current)
        write_json(env["system_changes_path"], {"static_ip": static_ip})

        return redirect(url_for("settings"))

    return render_template("settings.html", settings=current)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=env["port"], debug=False)
