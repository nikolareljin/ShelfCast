# ShelfCast Platform — Integration Blueprint

> **Audience:** Developers extending ShelfCast. This document describes the full system
> architecture from the simplest single-Pi deployment to a fully orchestrated multi-device
> platform with AI-powered event intelligence.
>
> **Status:** Living reference — updated as implementation advances.
> See [§10](#10-relation-to-implementation-tasks) for task-to-phase mapping.

---

## 1. Purpose of this document

ShelfCast started as a Pi-centric information dashboard for a single eInk display. The
platform vision extends it into a general-purpose display-orchestration hub that can drive
any number of heterogeneous devices — from Nook eReaders connected over USB to ESP32-based
smart displays subscribed over MQTT — while integrating with VigilantCore for real-time
AI-scored event intelligence.

This document defines:

- The **three-tier deployment model** (Minimal → Standard → Full)
- The **three-plane architecture** (Observation / Intelligence / Presentation)
- Supported **device types** and their connection protocols
- The **MQTT topic namespace**
- The **VigilantCore integration contract**
- The 14 **render job screen types**
- The **device lifecycle** (Provisioning → Managed → Locked)

It does **not** replace the per-tier setup guides in `docs/01-08`. Those guides remain the
authoritative how-to reference for each component. This document is the system-design
reference those guides derive from.

---

## 2. Deployment Tiers

ShelfCast supports three deployment tiers. Each tier is a strict superset of the one before
it; upgrading from Tier 1 to Tier 2 does not require throwing away any existing work.

### Tier 1: Minimal

> Current state of the codebase. No changes required to existing code.

| Component | Description |
|-----------|-------------|
| Raspberry Pi | Runs Flask app on port 8080 |
| Nook Simple Touch | Connects over USB/ADB; WebView loads `http://pi.local:8080` |
| Android tablet/phone | Wi-Fi; browser kiosk at `http://pi.local:8080` |
| Pi Chromium kiosk | Local fullscreen browser at `localhost:8080` |

Data sources are pulled directly by the Flask app:

- Weather via OpenWeatherMap (or compatible) REST API
- News via RSS feeds and NewsAPI
- Email via IMAP
- Calendar via Google Calendar OAuth2

No MQTT broker is required. No external services beyond the data APIs above. Authentication
is session-based with CSRF validation and brute-force throttling.

### Tier 2: Standard

> Add MQTT broker + ShelfCast orchestration hub + new device types.

Introduces Mosquitto (or equivalent MQTT broker) co-located on the Pi or a dedicated host.
ShelfCast becomes the **orchestration hub**: it consumes raw sensor and status messages,
composes render jobs, and fans them out to all registered display devices.

New capabilities at this tier:

- **Device registry** — each display device is registered with an ID, type, and capability
  profile; ShelfCast tracks heartbeats and connectivity state.
- **Render job composition** — ShelfCast assembles screen-type payloads (weather card,
  news headline, system status, etc.) and publishes them to `display/<device-id>/render/current`.
- **GeekMagic SmallTV-Ultra** and **CYD/Cheap Yellow Display** subscribe via MQTT and render
  server-pushed templates — no polling required.
- **Sensor ingestion** — local sensors (temperature, humidity, soil moisture, door contacts)
  publish to `raw/sensor/#`; ShelfCast normalises and stores these values.
- **Scheduler** — per-device or per-group refresh intervals, quiet hours, and priority overrides.

HTTP-connected devices (Nook, Android, Pi kiosk) continue to work unchanged.

### Tier 3: Full

> Add VigilantCore for AI-powered extreme-event monitoring.

VigilantCore (see [§7](#7-vigilantcore-integration)) runs as a separate process (local or
remote). It discovers, normalises, deduplicates, and AI-scores events from dozens of news,
RSS, emergency, and search providers.

New capabilities at this tier:

- **Normalised event stream** — VigilantCore publishes scored events to
  `intel/events/normalized` and `intel/events/high_priority`.
- **Alert cards** — ShelfCast composes `alert_card` and `headline_card` render jobs from
  high-priority events and delivers them to all connected displays.
- **Emergency bypass** (opt-in) — events with `impact_score >= 9` can pre-empt the normal
  render schedule.
- **Cross-device event acknowledgement** — a user acknowledgement on any one device clears
  the alert from all others via `intel/events/ack/<event-id>`.

---

## 3. System Architecture

### Three-plane model

```
┌─────────────────────────────────────────────────────────────────────┐
│  OBSERVATION PLANE                                                  │
│                                                                     │
│  VigilantCore ──► intel/events/*    Sensors ──► raw/sensor/#       │
│  Weather APIs ──► ingestion svc     News RSS ──► ingestion svc     │
│  Email (IMAP) ──► ingestion svc     Calendar ──► ingestion svc     │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ MQTT + internal
┌──────────────────────────────▼──────────────────────────────────────┐
│  INTELLIGENCE / COMPOSITION PLANE  (ShelfCast core)                 │
│                                                                     │
│  State Store  →  Composer  →  Priority Queue  →  Publisher          │
│  Device Registry    Profile Manager    Scheduler    Admin UI        │
└───────┬─────────────────────────────────┬───────────────────────────┘
        │ HTTP (Tier 1/2)                 │ MQTT (Tier 2/3)
┌───────▼───────────────┐   ┌────────────▼───────────────────────────┐
│  PRESENTATION PLANE   │   │  PRESENTATION PLANE (new devices)      │
│  (legacy HTTP)        │   │                                        │
│                       │   │  GeekMagic SmallTV-Ultra               │
│  Nook Simple Touch    │   │    (MQTT subscriber, Wi-Fi)            │
│    USB/ADB + WebView  │   │                                        │
│                       │   │  CYD / Cheap Yellow Display            │
│  Android tablet       │   │    (MQTT subscriber, Wi-Fi)            │
│    browser kiosk      │   │                                        │
│                       │   │  Generic browser client                │
│  Pi Chromium kiosk    │   │    (HTTP poll or WebSocket)            │
│    local browser      │   │                                        │
└───────────────────────┘   └────────────────────────────────────────┘
```

### Component roles and boundaries

| Component | Tier | Responsibility | Does NOT own |
|-----------|------|---------------|--------------|
| Flask app | 1+ | HTTP render, auth, data fetch, settings UI | MQTT, device registry |
| MQTT broker | 2+ | Message routing, topic ACLs | Business logic |
| Ingestion service | 2+ | Poll data sources, normalise, store state | Rendering |
| Composer | 2+ | Build render job payloads from state | Delivery |
| Publisher | 2+ | Fan-out render jobs to device topics | Composition |
| Device registry | 2+ | Register, profile, health-check devices | Rendering |
| VigilantCore | 3 | Discover and score extreme events | Display logic |
| Admin UI | 2+ | Device mgmt, profile editor, dashboard | Data ingest |

---

## 4. Supported Device Types

| Device | Protocol | Rendering engine | Connection | Tier | Status |
|--------|----------|-----------------|------------|------|--------|
| Nook Simple Touch | HTTP | WebView (Android 2.1) | USB/ADB to Pi | 1 | Existing |
| Android tablet/phone | HTTP | Browser kiosk | Wi-Fi | 1 | Existing |
| Raspberry Pi kiosk | HTTP | Chromium fullscreen | Local | 1 | Existing |
| GeekMagic SmallTV-Ultra | MQTT | Template renderer (ESP8266/ESP32) | Wi-Fi | 2 | Planned |
| CYD / Cheap Yellow Display | MQTT | Template renderer (ESP32) | Wi-Fi | 2 | Planned |
| Generic browser client | HTTP / WS | Browser | Wi-Fi / LAN | 2 | Planned |

### Nook Simple Touch

The existing WebView kiosk running on Android 2.1. The `EinkRefreshHelper` in the Nook app
drives partial/full refresh cycles on the eInk panel. Connection is ADB over USB to the Pi;
the Pi hosts the dashboard at `http://localhost:8080` and bridges via ADB port-forward.

Constraints: no TLS client support, no WebSockets, Android 2.1 WebKit only. Render jobs are
delivered as server-rendered HTML pages, not JSON payloads.

### GeekMagic SmallTV-Ultra

An ESP8266/ESP32-based colour LCD smart display. It connects over Wi-Fi, subscribes to its
assigned MQTT topic `display/<device-id>/render/current`, and renders a pre-defined template
using the JSON payload from ShelfCast. The device firmware is maintained separately in
`firmware/` (planned — see SC-051 through SC-060).

### CYD / Cheap Yellow Display

An ESP32 development board with a built-in 320×240 ILI9341 TFT and resistive touchscreen.
Subscribes to MQTT. Renders a subset of screen types that fit the physical display
constraints. Touch events publish to `display/<device-id>/event/touch`.

### Generic browser client

Any device with a modern browser. Can poll the ShelfCast HTTP API for render jobs, or
connect via WebSocket for server-push. Useful for development testing and for large-format
displays (TV, monitor) that don't need dedicated firmware.

---

## 5. Data Sources

| Source | Pull mechanism | MQTT topic (normalised) | Tier |
|--------|---------------|------------------------|------|
| Weather (OpenWeatherMap) | HTTP REST poll | `intel/weather/current` | 1+ |
| News / RSS feeds | feedparser poll | `intel/news/latest` | 1+ |
| Email (IMAP) | IMAP IDLE | `intel/email/unread` | 1+ |
| Google Calendar | OAuth2 REST poll | `intel/calendar/upcoming` | 1+ |
| VigilantCore events | MQTT subscribe | `intel/events/normalized` | 3 |
| Local sensors | MQTT subscribe | `raw/sensor/#` | 2+ |
| Server / service health | internal | `intel/health/services` | 2+ |

Data sources are polled by the **ingestion service** (Tier 2+) or directly by the Flask app
(Tier 1). Normalised state is stored in a lightweight SQLite cache. The composer reads from
this cache to build render jobs — it never calls external APIs directly.

---

## 6. MQTT Topic Namespace

All MQTT topics use a flat hierarchy with `/` separators. The top-level prefix indicates
the plane and direction of data flow.

```
raw/
  sensor/<device-id>/<sensor-type>    # raw device-published readings
  status/<device-id>                  # device heartbeat / connection state

intel/
  weather/current                     # normalised current conditions
  weather/forecast/<hours>            # normalised N-hour forecast
  news/latest                         # normalised top headlines
  news/feed/<feed-id>                 # per-feed normalised items
  email/unread                        # unread email summary
  calendar/upcoming                   # next N calendar events
  events/normalized                   # VigilantCore normalised events (Tier 3)
  events/high_priority                # impact_score >= 7 (Tier 3)
  events/ack/<event-id>               # acknowledgement broadcast
  health/services                     # service health status

display/
  <device-id>/render/current          # active render job (retained)
  <device-id>/render/queue            # queued render jobs
  <device-id>/config                  # device config push (retained)
  <device-id>/heartbeat               # device heartbeat → ShelfCast
  <device-id>/event/touch             # touch/button events from device

display-group/
  <group-id>/render/current           # group-level render job (retained)
  <group-id>/config                   # group config push
```

**Topic conventions:**

- Retained topics (`render/current`, `config`) are marked `retain=true` so a device
  recovers its last state on reconnect without waiting for the next publish cycle.
- QoS 1 is used for render jobs and config pushes; QoS 0 for heartbeats and raw sensor data.
- `<device-id>` is a UUID-based stable identifier assigned at provisioning time.
- `<group-id>` is an admin-assigned label (e.g., `living-room`, `all-displays`).

---

## 7. VigilantCore Integration

VigilantCore (`/projects/Projects/_NIK_PROGRAMS/vigilant-core`) is an AI-powered event
intelligence platform. It discovers, normalises, deduplicates, and scores events from 30+
providers (RSS feeds, NewsAPI, Google CSE, Bing, DuckDuckGo, emergency search providers).
Local AI scoring uses Ollama (qwen2.5:7b default, auto-fallback to 3b on 8 GB RAM).

### Role in Tier 3

VigilantCore acts as a **read-only event publisher** from ShelfCast's perspective. It:

1. Runs its own event-gathering loop independently.
2. Normalises events into a standard schema (see below).
3. Publishes to `intel/events/normalized` and `intel/events/high_priority`.
4. Does **not** subscribe to any ShelfCast topics.

ShelfCast subscribes to both topics and feeds the events into the composer.

### Schema contract

The normalised event payload published by VigilantCore conforms to
`schemas/intel_vc_event.json` (to be added — see SC-031). Key fields:

```json
{
  "event_id":      "string (UUID)",
  "title":         "string",
  "summary":       "string",
  "severity":      "info | low | medium | high | critical",
  "impact_score":  "integer 1–10",
  "confidence":    "float 0–1",
  "timestamp_utc": "ISO-8601",
  "location":      { "city": "…", "region": "…", "country": "…", "lat": 0.0, "lon": 0.0 },
  "source_url":    "string",
  "source_name":   "string",
  "tags":          ["string"]
}
```

### Priority paths

| `impact_score` | Topic | ShelfCast action |
|---------------|-------|-----------------|
| 1–6 | `intel/events/normalized` | Queued for next scheduled slot |
| 7–8 | `intel/events/high_priority` | Pre-empts normal schedule |
| 9–10 | `intel/events/high_priority` | Emergency bypass (opt-in, config flag) |

### Emergency bypass

When `features.emergency_bypass: true` in `config/settings.json` and
`impact_score >= 9`, ShelfCast immediately pushes an `alert_card` render job to
**all** connected displays, overriding whatever they were showing. The current render job
is saved and restored after the alert is acknowledged.

Opt-in is per-installation (disabled by default).

---

## 8. Render Job Screen Types

A **render job** is a JSON payload published to `display/<device-id>/render/current`.
It contains a `screen_type` discriminator and a `payload` object specific to that type.
The full JSON schema lives in `schemas/render_job.json` (to be added — see SC-032).

| # | Screen type | Description | Primary content |
|---|-------------|-------------|----------------|
| 1 | `clock_date` | Full-screen clock with date | Time, date, optional weather icon |
| 2 | `weather_now` | Current conditions card | Temp, conditions, humidity, wind |
| 3 | `weather_forecast` | Multi-hour/day forecast | Icon + temp per period |
| 4 | `news_headline` | Single large headline | Title, source, timestamp |
| 5 | `news_ticker` | Rotating short headlines | 3–5 items cycling |
| 6 | `calendar_today` | Today's agenda | Event list with times |
| 7 | `calendar_next` | Next single event countdown | Event name + time-until |
| 8 | `email_summary` | Unread email digest | Count + sender/subject previews |
| 9 | `sensor_readout` | Single sensor reading | Value, unit, trend arrow |
| 10 | `sensor_grid` | Multi-sensor dashboard | 2–6 readings in grid layout |
| 11 | `alert_card` | High-priority event alert | Title, summary, severity badge, source |
| 12 | `system_status` | Service health overview | Per-service up/down indicators |
| 13 | `custom_image` | Static or animated image | URL or base64 image data |
| 14 | `blank` | Display off / blank screen | No content — used for quiet hours |

Device capability profiles declare which screen types a device can render. The composer
skips unsupported types and falls back to the device's declared fallback type.

---

## 9. Device Lifecycle Modes

Every device in the device registry progresses through three lifecycle modes:

```
  PROVISIONING  ──►  MANAGED  ──►  LOCKED
       │                │               │
  First contact    Normal ops      Config frozen
  Auto-assign ID   Receive jobs    Read-only
  Push default     Heartbeat       OTA only
  config           tracking
```

### Provisioning

A device enters this mode the first time it connects. ShelfCast assigns a stable UUID,
records the device type and reported capabilities, and pushes a default config to
`display/<device-id>/config` (retained). The device is added to the registry with
`status: provisioning`.

Provisioning completes when the device publishes its first heartbeat with `status: ready`.

### Managed

Normal operating mode. ShelfCast tracks heartbeats (expected interval in device config),
delivers render jobs on schedule, accepts touch/button events, and updates the device's
last-seen timestamp. An admin can edit the device's profile, group memberships, and
capability overrides.

A device transitions back to Provisioning if it is wiped or its firmware is re-flashed
(new client ID on MQTT connect).

### Locked

Config is frozen. ShelfCast will not push config changes. Render jobs are still delivered.
Used for production deployments where accidental reconfiguration must be prevented. Requires
explicit admin unlock to exit.

---

## 10. Relation to Implementation Tasks

The GitHub issues created from `TODO.txt` are grouped into phases that map directly to the
tiers above.

| Phase | Issues | Tier delivered | Key capabilities |
|-------|--------|---------------|-----------------|
| 0 | SC-001–SC-010 | Foundation | Repo restructure, MQTT broker setup, config schema |
| 1 | SC-011–SC-025 | Tier 2 (core) | Device registry, ingestion service, composer, publisher |
| 2 | SC-026–SC-040 | Tier 2 (displays) | SmallTV-Ultra firmware, CYD firmware, render job schemas |
| 3 | SC-041–SC-055 | Tier 3 (VC) | VigilantCore MQTT bridge, intel schema, alert card type |
| 4 | SC-056–SC-071 | Tier 3 (full) | Emergency bypass, group addressing, admin UI, OTA |
| — | VC-009–VC-013 | VigilantCore | Freshness ranking, provider orchestration, MQTT publisher |

Tasks in Phase 0 are prerequisites for all other phases. Tasks within a phase can be
parallelised after Phase 0 is complete.

---

## 11. How to Extend

### Adding a new device type

1. Add a row to the device-type enum in `schemas/render_job.json`.
2. Define a capability profile in `config/device_profiles/<type>.json` listing supported
   screen types and fallback type.
3. Implement the firmware or client subscriber (see `firmware/` for ESP32 examples).
4. Register the device via the admin UI or directly via `POST /api/v1/devices`.

### Adding a new data source

1. Add an ingestion handler in `backend/ingestion/<source_name>.py` that polls or
   subscribes to the source and returns a normalised dict matching the relevant
   `intel/<topic>` schema.
2. Register the handler in `backend/ingestion/__init__.py`.
3. Add any required credentials to `config/env.example`.
4. The composer will automatically pick up the new state key if a screen type references it.

### Adding a new screen type

1. Add the type to the `screen_type` enum in `schemas/render_job.json`.
2. Define the `payload` sub-schema for that type.
3. Add a composer strategy in `backend/composer/strategies/<type>.py`.
4. Add renderer implementations for each device type that should support it (HTML template
   for HTTP devices, JSON template for MQTT devices).
5. Update capability profiles to opt devices into the new type.

---

## Related documents

| Document | Purpose |
|----------|---------|
| `docs/01-overview.md` | System overview and feature list |
| `docs/02-hardware.md` | Pi + Nook hardware setup |
| `docs/03-pi-setup.md` | Raspberry Pi software setup |
| `docs/04-nook-setup.md` | Nook Android app setup |
| `docs/05-apps.md` | Companion app installation |
| `docs/06-remote-access.md` | Remote access configuration |
| `docs/07-ubuntu-test.md` | Ubuntu development environment |
| `docs/08-scripts-ci.md` | Scripts and CI/CD reference |
| `docs/deployment.md` | Deployment guide |
| `docs/dev-prerequisites.md` | Developer prerequisites |
| `schemas/render_job.json` | Render job schema (planned — SC-032) |
| `schemas/intel_vc_event.json` | VigilantCore event schema (planned — SC-031) |
