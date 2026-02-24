# iCloud Calendar Sync (CalDAV) with vdirsyncer + khal

This repo includes a minimal iCloud calendar workflow based on:

- `vdirsyncer` for CalDAV sync
- `khal` for local calendar CLI access
- `scripts/icloud-calendar-sync` as the glue command

The setup uses iCloud **CalDAV** (`https://caldav.icloud.com/`), not WebDAV.

## 1) Configure credentials locally (untracked)

Use one of these local files:

- `~/.config/icloud-calendar.env`
- `./.env.icloud-calendar` (repo-local, gitignored)

Example:

```sh
ICLOUD_CALDAV_USERNAME="you@example.com"
ICLOUD_CALDAV_APP_PASSWORD="abcd-efgh-ijkl-mnop"
# optional overrides
# ICLOUD_CALDAV_URL="https://caldav.icloud.com/"
# ICLOUD_CALENDAR_TIMEZONE="America/New_York"
```

Notes:

- Create an Apple app-specific password in your Apple ID security settings.
- Never commit credentials to this repo.

## 2) Sync calendars

```sh
just calendar-sync
```

On first run, the helper performs `discover` and then `sync`.

Local data path:

- `${XDG_DATA_HOME:-~/.local/share}/calendars/icloud/vdirs`

Status path:

- `${XDG_STATE_HOME:-~/.local/state}/icloud-calendar/vdirsyncer`

## 3) Optional normalized cache for automation

```sh
just calendar-sync-cache
```

This also writes JSON cache output to:

- `${XDG_CACHE_HOME:-~/.cache}/icloud-calendar/events.json`

You can override cache path:

```sh
scripts/icloud-calendar-sync --cache-file /tmp/my-events.json
```

## 4) khal config defaults

If `~/.config/khal/config` does not exist, the helper creates one with:

- discovered calendars under the synced vdir path
- `local_timezone` and `default_timezone` set from `ICLOUD_CALENDAR_TIMEZONE` (default: `UTC`)

If you already manage your own khal config, the helper leaves it unchanged.

## All-day event guidance

iCloud all-day entries are date-based events. To avoid date shifts:

- Set `ICLOUD_CALENDAR_TIMEZONE` to your real IANA timezone (for example `America/Los_Angeles`).
- Keep khal `local_timezone` and `default_timezone` aligned to that same timezone.
- Avoid mixing floating-date and explicit-time events when scripting automation logic; inspect `start_type`/`end_type` in cache JSON.
