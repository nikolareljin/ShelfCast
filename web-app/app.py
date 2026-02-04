import json
import os
import socket
import subprocess
import time
import threading
import ipaddress
from datetime import datetime
from email.parser import BytesParser
from email.policy import default as email_default_policy
from urllib.parse import urlparse
from defusedxml import ElementTree as DefusedET
from defusedxml.common import DefusedXmlException
from email.utils import parsedate_to_datetime
from pathlib import Path

import feedparser
import imaplib
import requests
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
        "email_password": os.environ.get("SHELFCAST_EMAIL_PASSWORD", ""),
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
        "require_login_for_display": True,
    },
    "data": {"data_path": "../data/sample_data.json"},
    "display": {
        "show_weather": True,
        "show_news": True,
        "show_todos": True,
        "show_calendar": True,
        "show_packages": True,
    },
    "news": {
        "predefined_sources": ["https://example.com/rss"],
        "custom_sources": [],
        "refresh_minutes": 5,
        "latest_limit": 5,
        "newsapi_key": "",
    },
    "email": {
        "host": "",
        "port": 993,
        "user": "",
        "password": "",
        "folder": "INBOX",
        "ssl": True,
        "require_login_for_display": True,
        "refresh_minutes": 1,
    },
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
            "emails": [],
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


def is_legacy_client():
    ua = (request.headers.get("User-Agent") or "").lower()
    legacy_tokens = ("android 2.1", "eclair", "nook", "bntv", "bntv250", "bnrv")
    return any(token in ua for token in legacy_tokens)


class ThreadSafeCache:
    def __init__(self, initial):
        self._lock = threading.RLock()
        self._data = dict(initial)

    def get(self, key, default=None):
        with self._lock:
            return self._data.get(key, default)

    def set(self, key, value):
        with self._lock:
            self._data[key] = value

    def snapshot(self):
        with self._lock:
            return dict(self._data)


NEWS_CACHE = ThreadSafeCache({"items": [], "last_fetch": 0.0})
EMAIL_CACHE = ThreadSafeCache({"items": [], "last_fetch": 0.0})
WEATHER_CACHE = ThreadSafeCache({"payload": {}, "last_fetch": 0.0})
LOCATION_CACHE = ThreadSafeCache({"payload": {}, "last_fetch": 0.0})
_WEATHER_THREAD_STARTED = False
_WEATHER_STOP_EVENT = threading.Event()
_WEATHER_THREAD_LOCK = threading.Lock()
_WEATHER_REFRESH_LOCK = threading.Lock()
_LOCATION_LOCK = threading.Lock()
_NEWS_REFRESH_LOCK = threading.Lock()
_EMAIL_REFRESH_LOCK = threading.Lock()


def _clamp(value, minimum, maximum):
    return max(minimum, min(maximum, value))


def _normalize_news_item(title, source, link, published, source_type):
    return {
        "title": title.strip() if title else "Untitled",
        "source": source.strip() if source else "Unknown",
        "link": link or "",
        "published": published or "",
        "source_type": source_type,
    }


def _is_safe_url(url):
    try:
        parsed = urlparse(url)
    except Exception:
        return False
    if parsed.scheme not in ("http", "https"):
        return False
    if not parsed.hostname:
        return False
    try:
        infos = socket.getaddrinfo(parsed.hostname, None)
    except socket.gaierror:
        return False
    for info in infos:
        ip = info[4][0]
        try:
            addr = ipaddress.ip_address(ip)
        except ValueError:
            return False
        if (
            addr.is_private
            or addr.is_loopback
            or addr.is_link_local
            or addr.is_reserved
            or addr.is_multicast
        ):
            return False
    return True


def _safe_get(url, timeout=8):
    # Best-effort SSRF protection: validate before request and block redirects.
    if not _is_safe_url(url):
        return None
    try:
        resp = requests.get(url, timeout=timeout, allow_redirects=False)
    except Exception:
        return None
    if getattr(resp, "is_redirect", False) or getattr(resp, "is_permanent_redirect", False):
        return None
    if resp.url != url:
        return None
    if not _is_safe_url(resp.url):
        return None
    return resp


def _fetch_rss_items(url):
    items = []
    try:
        resp = _safe_get(url, timeout=8)
        if not resp or not resp.ok:
            return items
        feed = feedparser.parse(resp.text)
    except Exception:
        return items
    source_title = feed.feed.get("title") if hasattr(feed, "feed") else None
    for entry in feed.entries[:20]:
        title = entry.get("title", "")
        link = entry.get("link", "")
        published = entry.get("published", "") or entry.get("updated", "")
        items.append(
            _normalize_news_item(
                title, source_title or urlparse(url).netloc, link, published, "rss"
            )
        )
    return items


def _normalize_source_url(url):
    if "github.com/" in url and "/blob/" in url:
        return url.replace("github.com/", "raw.githubusercontent.com/").replace("/blob/", "/")
    return url


def _extract_opml_sources(content):
    sources = []
    try:
        root = DefusedET.fromstring(content)
    except (DefusedET.ParseError, DefusedXmlException):
        return sources
    for outline in root.iter("outline"):
        xml_url = outline.attrib.get("xmlUrl") or outline.attrib.get("url")
        if xml_url:
            sources.append(xml_url)
    return sources


def _expand_sources(sources):
    expanded = []
    for source in sources:
        normalized = _normalize_source_url(source)
        if not _is_safe_url(normalized):
            continue
        if normalized.lower().endswith(".opml"):
            try:
                resp = _safe_get(normalized, timeout=8)
                if resp and resp.ok:
                    opml_sources = _extract_opml_sources(resp.text)
                    for opml_source in opml_sources:
                        opml_normalized = _normalize_source_url(opml_source)
                        if _is_safe_url(opml_normalized):
                            expanded.append(opml_normalized)
                    continue
            except Exception:
                # If fetching/parsing OPML fails, fall back to treating as a feed URL.
                pass
        expanded.append(normalized)
    return expanded


def _get_location_cached():
    with _LOCATION_LOCK:
        cached = LOCATION_CACHE.snapshot()
        now = time.time()
        if cached.get("payload") and now - cached.get("last_fetch", 0.0) < 6 * 60 * 60:
            return cached.get("payload")
        try:
            resp = requests.get("https://ipapi.co/json/", timeout=5)
            if resp.ok:
                payload = resp.json()
                LOCATION_CACHE.set("payload", payload)
                LOCATION_CACHE.set("last_fetch", now)
                return payload
        except Exception:
            # If geo lookup fails, return cached data.
            return cached.get("payload", {})
        return cached.get("payload", {})


def _get_location_country_code():
    data = _get_location_cached()
    return data.get("country_code")


def _get_location():
    data = _get_location_cached()
    return {
        "city": data.get("city") or "",
        "region": data.get("region") or "",
        "country": data.get("country_name") or "",
        "latitude": data.get("latitude"),
        "longitude": data.get("longitude"),
    }


def _weather_icon_key(code):
    if code in (0,):
        return "clear"
    if code in (1, 2):
        return "partly"
    if code in (3,):
        return "cloudy"
    if code in (45, 48):
        return "fog"
    if code in (51, 53, 55, 56, 57):
        return "drizzle"
    if code in (61, 63, 65, 66, 67, 80, 81, 82):
        return "rain"
    if code in (71, 73, 75, 77, 85, 86):
        return "snow"
    if code in (95, 96, 99):
        return "thunder"
    return "cloudy"


def _fetch_weather():
    location = _get_location()
    lat = location.get("latitude")
    lon = location.get("longitude")
    if lat is None or lon is None:
        return {}
    params = {
        "latitude": lat,
        "longitude": lon,
        "current_weather": "true",
        "daily": "weathercode,temperature_2m_max,temperature_2m_min",
        "timezone": "auto",
    }
    try:
        resp = requests.get("https://api.open-meteo.com/v1/forecast", params=params, timeout=8)
        if not resp.ok:
            return {}
        payload = resp.json()
    except Exception:
        return {}

    current = payload.get("current_weather", {}) or {}
    daily = payload.get("daily", {}) or {}
    dates = daily.get("time", []) or []
    maxes = daily.get("temperature_2m_max", []) or []
    mins = daily.get("temperature_2m_min", []) or []
    codes = daily.get("weathercode", []) or []
    forecast = []
    for idx in range(min(3, len(dates))):
        code = codes[idx] if idx < len(codes) else None
        forecast.append(
            {
                "date": dates[idx],
                "high_c": maxes[idx] if idx < len(maxes) else None,
                "low_c": mins[idx] if idx < len(mins) else None,
                "code": code,
                "icon": _weather_icon_key(code),
            }
        )

    return {
        "location": ", ".join([p for p in [location.get("city"), location.get("region")] if p]),
        "current_temp_c": current.get("temperature"),
        "current_windspeed": current.get("windspeed"),
        "current_code": current.get("weathercode"),
        "current_icon": _weather_icon_key(current.get("weathercode")),
        "forecast": forecast,
    }


def _refresh_weather():
    now = time.time()
    cached = WEATHER_CACHE.snapshot()
    if cached.get("payload") and now - cached.get("last_fetch", 0.0) < 15 * 60:
        return cached.get("payload")
    with _WEATHER_REFRESH_LOCK:
        cached = WEATHER_CACHE.snapshot()
        if cached.get("payload") and now - cached.get("last_fetch", 0.0) < 15 * 60:
            return cached.get("payload")
        payload = _fetch_weather()
        if payload:
            WEATHER_CACHE.set("payload", payload)
            WEATHER_CACHE.set("last_fetch", now)
            return payload
        # Keep last known good payload to avoid empty display
        return cached.get("payload", {})


def _weather_background_loop(stop_event=None):
    if stop_event is None:
        stop_event = _WEATHER_STOP_EVENT
    while not stop_event.is_set():
        try:
            _refresh_weather()
        except Exception as exc:
            try:
                app.logger.exception("Weather refresh failed")
            except Exception:
                print(f"Weather refresh failed: {exc}", flush=True)
        stop_event.wait(900)


def _start_weather_background():
    global _WEATHER_THREAD_STARTED
    with _WEATHER_THREAD_LOCK:
        if _WEATHER_THREAD_STARTED:
            return
        if os.environ.get("WERKZEUG_RUN_MAIN") == "true" or not app.debug:
            _WEATHER_STOP_EVENT.clear()
            thread = threading.Thread(
                target=_weather_background_loop, args=(_WEATHER_STOP_EVENT,), daemon=True
            )
            thread.start()
            _WEATHER_THREAD_STARTED = True
 

@app.before_first_request
def _init_weather_background():
    _start_weather_background()


def _fetch_newsapi_items(api_key, limit):
    if not api_key:
        return []
    country = _get_location_country_code() or "us"
    params = {
        "apiKey": api_key,
        "country": country.lower(),
        "pageSize": limit,
    }
    try:
        resp = requests.get("https://newsapi.org/v2/top-headlines", params=params, timeout=8)
        if not resp.ok:
            return []
        payload = resp.json()
    except Exception:
        return []
    items = []
    for article in payload.get("articles", [])[:limit]:
        title = article.get("title", "")
        source = (article.get("source") or {}).get("name", "NewsAPI")
        link = article.get("url", "")
        published = article.get("publishedAt", "")
        items.append(_normalize_news_item(title, source, link, published, "newsapi"))
    return items


def _dedupe_news(items):
    seen = set()
    output = []
    for item in items:
        key = (item.get("title", "").strip().lower(), item.get("source", "").strip().lower())
        if key in seen:
            continue
        seen.add(key)
        output.append(item)
    return output


def _published_timestamp(value):
    if not value:
        return 0.0
    try:
        return parsedate_to_datetime(value).timestamp()
    except Exception:
        # Unsupported date format; try ISO fallback.
        pass
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
    except Exception:
        return 0.0


def _refresh_news(settings):
    news_settings = settings.get("news", {})
    try:
        refresh_minutes = int(news_settings.get("refresh_minutes", 5) or 5)
    except (TypeError, ValueError):
        refresh_minutes = 5
    refresh_minutes = _clamp(refresh_minutes, 1, 15)
    now = time.time()
    cached = NEWS_CACHE.snapshot()
    if cached.get("items") and now - cached.get("last_fetch", 0.0) < refresh_minutes * 60:
        return cached.get("items")
    with _NEWS_REFRESH_LOCK:
        cached = NEWS_CACHE.snapshot()
        if cached.get("items") and now - cached.get("last_fetch", 0.0) < refresh_minutes * 60:
            return cached.get("items")

        sources = []
        sources.extend(news_settings.get("predefined_sources", []))
        sources.extend(news_settings.get("custom_sources", []))
        sources = [s.strip() for s in sources if s.strip()]

        items = []
        for source in _expand_sources(sources):
            items.extend(_fetch_rss_items(source))

        try:
            latest_limit = int(news_settings.get("latest_limit", 5) or 5)
        except (TypeError, ValueError):
            latest_limit = 5
        latest_limit = _clamp(latest_limit, 5, 10)
        items.extend(_fetch_newsapi_items(news_settings.get("newsapi_key", ""), latest_limit))

        items = _dedupe_news(items)
        items.sort(key=lambda item: _published_timestamp(item.get("published")), reverse=True)
        if latest_limit > 1:
            has_newsapi = any(item.get("source_type") == "newsapi" for item in items)
            if has_newsapi:
                newsapi_items = [item for item in items if item.get("source_type") == "newsapi"]
                rss_items = [item for item in items if item.get("source_type") != "newsapi"]
                items = rss_items[: max(latest_limit - 1, 0)]
                items.extend(newsapi_items[:1])
                items.sort(
                    key=lambda item: _published_timestamp(item.get("published")),
                    reverse=True,
                )
                items = items[:latest_limit]
            else:
                items = items[:latest_limit]
        else:
            items = items[:latest_limit]
        NEWS_CACHE.set("items", items)
        NEWS_CACHE.set("last_fetch", now)
        return items


def _fetch_emails(settings):
    email_settings = settings.get("email", {})
    host = email_settings.get("host")
    user = email_settings.get("user")
    password = env.get("email_password") or email_settings.get("password")
    if not host or not user or not password:
        return []
    port = int(email_settings.get("port", 993) or 993)
    folder = email_settings.get("folder", "INBOX")
    use_ssl = bool(email_settings.get("ssl", True))
    client = None
    try:
        if use_ssl:
            client = imaplib.IMAP4_SSL(host, port)
        else:
            client = imaplib.IMAP4(host, port)
        client.login(user, password)
        client.select(folder, readonly=True)
        status, data = client.search(None, "ALL")
        if status != "OK":
            return []
        ids = data[0].split()
        latest_ids = ids[-5:] if len(ids) > 5 else ids
        emails = []
        parser = BytesParser(policy=email_default_policy)
        for msg_id in reversed(latest_ids):
            status, msg_data = client.fetch(msg_id, "(BODY.PEEK[HEADER])")
            if status != "OK":
                continue
            raw_bytes = msg_data[0][1]
            message = parser.parsebytes(raw_bytes)
            subject = message.get("subject", "")
            sender = message.get("from", "")
            date_str = message.get("date", "")
            emails.append(
                {"subject": subject or "(no subject)", "from": sender, "date": date_str}
            )
        return emails
    except Exception:
        return []
    finally:
        if client is not None:
            try:
                client.logout()
            except Exception:
                pass


def _refresh_emails(settings):
    email_settings = settings.get("email", {})
    try:
        refresh_minutes = int(email_settings.get("refresh_minutes", 1) or 1)
    except (TypeError, ValueError):
        refresh_minutes = 1
    refresh_minutes = _clamp(refresh_minutes, 1, 15)
    now = time.time()
    cached = EMAIL_CACHE.snapshot()
    if cached.get("items") and now - cached.get("last_fetch", 0.0) < refresh_minutes * 60:
        return cached.get("items")
    with _EMAIL_REFRESH_LOCK:
        cached = EMAIL_CACHE.snapshot()
        if cached.get("items") and now - cached.get("last_fetch", 0.0) < refresh_minutes * 60:
            return cached.get("items")
        items = _fetch_emails(settings)
        EMAIL_CACHE.set("items", items)
        EMAIL_CACHE.set("last_fetch", now)
        return items


def _should_include_emails(settings):
    email_settings = settings.get("email", {})
    if bool(email_settings.get("require_login_for_display", True)):
        return is_logged_in(settings)
    return True

@app.route("/")
def index():
    settings = load_settings()
    if requires_display_login(settings) and not is_logged_in(settings):
        return redirect(url_for("login"))
    data = read_data(settings.get("data", {}).get("data_path", env["data_path"]))
    data["weather"] = _refresh_weather() or data.get("weather", {})
    data["news"] = _refresh_news(settings)
    data["emails"] = _refresh_emails(settings) if _should_include_emails(settings) else []
    display = settings.get("display", {})
    template_name = "index_legacy.html" if is_legacy_client() else "index.html"
    return render_template(
        template_name,
        data=data,
        display=display,
        ip_address=get_ip_address(),
        news_refresh_minutes=settings.get("news", {}).get("refresh_minutes", 5),
        email_refresh_minutes=settings.get("email", {}).get("refresh_minutes", 1),
    )


@app.route("/api/data")
def api_data():
    settings = load_settings()
    if requires_display_login(settings) and not is_logged_in(settings):
        return jsonify({"error": "unauthorized"}), 401
    data = read_data(settings.get("data", {}).get("data_path", env["data_path"]))
    data["weather"] = _refresh_weather() or data.get("weather", {})
    data["news"] = _refresh_news(settings)
    data["emails"] = _refresh_emails(settings) if _should_include_emails(settings) else []
    return jsonify(data)


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
        auth["require_login_for_display"] = bool(request.form.get("require_login_for_display"))

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
        news_refresh_raw = (request.form.get("news_refresh_minutes", "5") or "5").strip()
        try:
            news_refresh = int(news_refresh_raw)
        except ValueError:
            news_refresh = 5
        news["refresh_minutes"] = _clamp(news_refresh, 1, 15)
        news_limit_raw = (request.form.get("news_latest_limit", "5") or "5").strip()
        try:
            news_limit = int(news_limit_raw)
        except ValueError:
            news_limit = 5
        news["latest_limit"] = _clamp(news_limit, 5, 10)
        newsapi_key = request.form.get("newsapi_key", "").strip()
        if request.form.get("newsapi_key_clear"):
            news["newsapi_key"] = ""
        elif newsapi_key != "":
            news["newsapi_key"] = newsapi_key

        email = current.setdefault("email", {})
        email["host"] = request.form.get("email_host", "").strip()
        email_port = request.form.get("email_port", "993").strip()
        email["port"] = int(email_port) if email_port.isdigit() else 993
        email["user"] = request.form.get("email_user", "").strip()
        email_password = request.form.get("email_password", "").strip()
        if request.form.get("email_password_clear"):
            email["password"] = ""
        elif email_password != "":
            email["password"] = email_password
        email["folder"] = request.form.get("email_folder", "INBOX").strip() or "INBOX"
        email["ssl"] = bool(request.form.get("email_ssl"))
        email["require_login_for_display"] = bool(
            request.form.get("email_require_login_for_display")
        )
        email_refresh_raw = (request.form.get("email_refresh_minutes", "1") or "1").strip()
        try:
            email_refresh = int(email_refresh_raw)
        except (TypeError, ValueError):
            email_refresh = 1
        email["refresh_minutes"] = _clamp(email_refresh, 1, 15)

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
        NEWS_CACHE.set("items", [])
        NEWS_CACHE.set("last_fetch", 0.0)
        EMAIL_CACHE.set("items", [])
        EMAIL_CACHE.set("last_fetch", 0.0)

        return redirect(url_for("settings"))

    return render_template("settings.html", settings=current)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=env["port"], debug=False)
