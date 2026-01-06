# Overview

ShelfCast is a small, self-hosted dashboard meant to run on a Raspberry Pi 3 and display on a Nook Simple Touch or an old Android tablet/phone. The display acts as a touchscreen client. The Pi hosts the web app and optional SSH dialog app.

## Goals

- Touch input works on the Nook
- Nook behaves like a standard display for the Pi
- Dashboard shows weather, news, todos, calendar, and package arrivals
- Remote access for updates and settings
- Simple, reproducible install

## High-level architecture

- Raspberry Pi 3 runs Raspberry Pi OS Lite + a kiosk browser
- Dashboard web app is served locally on the Pi
- Optional SSH dialog app for quick edits without a browser
- Data sources are stubbed via JSON initially and can be swapped with APIs
