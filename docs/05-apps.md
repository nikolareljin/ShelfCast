# Dashboard apps

The web dashboard reads a JSON data file and renders modules:

- Weather forecast
- News
- Todo list
- Calendar events
- Package arrivals

## Data sources

For now, data is loaded from `data/sample_data.json`. Replace this with API fetchers in `web-app/data_sources/`.

## Settings

Edit settings in the web UI at `/settings`. This writes to `config/settings.json` and stores placeholders for integrations.

Integration notes:

- Google Calendar uses OAuth device flow placeholders (device code + refresh token stored).
- News sources allow predefined RSS feeds and custom RSS feeds.

TODOs:

- Weather API integration
- News feed integration
- Todo integration (CalDAV, Todoist, or local)
- Calendar integration
- Package tracking provider
