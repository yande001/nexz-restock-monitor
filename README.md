# NEXZ Hair Clip Restock Monitor

Watches the [JYP Japan Online Store](https://jypj-store.com) and **emails you the moment a
sold-out NEXZ『LIVE TOUR 2026』hair clip comes back in stock.**

It polls 7 clips (YUTiE, PPOMOYA, HYUROMI, SEIDEE, GEONSKY, HARUBEAR, JELLY-YU) every 10
seconds. FOX2Y is excluded because it was already in stock — edit the script to change the list.

[中文說明見 README.zh.md](./README.zh.md)

## How it works

The store is built on **Shopify**, which exposes a hidden JSON endpoint for every product:

```
https://jypj-store.com/products/<handle>.js  ->  { ... "available": true/false ... }
```

That `available` boolean is the same flag the store's own "Add to Cart" button uses — far more
reliable than scraping the "Sold Out" text off the HTML page (which breaks on wording/translation
changes). The monitor just polls those tiny JSON endpoints and emails you when one flips to `true`.

See [restock_monitor_explained.md](./restock_monitor_explained.md) for the full design write-up.

## Requirements

- `bash`, `curl`, and `python3` (3.6+) — all standard. **No `pip install` needed** (uses only the
  Python standard library).
- A **Gmail account** to send the alert from, with 2-Step Verification enabled.

## Setup

1. **Clone:**
   ```bash
   git clone https://github.com/yande001/nexz-restock-monitor.git
   cd nexz-restock-monitor
   ```

2. **Create a Gmail App Password** at <https://myaccount.google.com/apppasswords>
   (requires 2-Step Verification). You'll get a 16-character password like `abcd efgh ijkl mnop`.

3. **Configure credentials:**
   ```bash
   cp mail.cfg.example mail.cfg
   ```
   Edit `mail.cfg`:
   ```
   GMAIL_USER=your_address@gmail.com
   GMAIL_APP_PW=abcdefghijklmnop      # 16 chars, spaces removed
   MAIL_TO=where_to_notify@example.com
   ```
   `mail.cfg` is gitignored, so it never gets committed.

4. **Send a test email** to confirm it works:
   ```bash
   python3 send_mail.py "Test" "If you got this, email alerts work."
   ```
   You should see `sent ok` and receive the email (check spam too).

## Run

Foreground (Ctrl-C to stop):
```bash
bash restock_monitor.sh
```

Background, surviving terminal close:
```bash
nohup bash restock_monitor.sh > /dev/null 2>&1 &
```

Progress is appended to `restock.log`:
```bash
tail -f restock.log
```

The script exits as soon as a restock is found (after emailing you), or after a ~12-hour safety
cap (`MAX_ITERS=4320`). Re-run it to keep watching.

### Run persistently (optional)

**cron** — restart on every reboot:
```cron
@reboot cd /path/to/nexz-restock-monitor && nohup bash restock_monitor.sh >> restock.log 2>&1 &
```

**systemd user service** — `~/.config/systemd/user/nexz-restock.service`:
```ini
[Unit]
Description=NEXZ restock monitor

[Service]
WorkingDirectory=/path/to/nexz-restock-monitor
ExecStart=/usr/bin/bash restock_monitor.sh
Restart=on-success   # restock found -> exit 0 -> restart to keep watching others

[Install]
WantedBy=default.target
```
```bash
systemctl --user daemon-reload && systemctl --user enable --now nexz-restock
```

## Customizing the watched products

Edit the `NAMES` map in `restock_monitor.sh`. Each entry is a Shopify product **handle** (the
slug in the product URL `/products/<handle>`) mapped to a display name. To find a handle, open a
product page and copy the last path segment, or check `https://jypj-store.com/products/<handle>.js`.

## Limitations

- **Not event-driven.** 10s polling means up to a 10s delay; Shopify has no public buyer webhook.
- **Runs only while the process is up.** Use the cron/systemd options above for reboot resilience.
- **Fail-safe by design.** If the store rate-limits or errors, a cycle reads as "sold out" and
  retries — you may miss a check, but you'll never get a false-alarm email.

## Security

Your Gmail App Password lives only in your local `mail.cfg` (gitignored). If it ever leaks, revoke
it at <https://myaccount.google.com/apppasswords>. App Passwords can be revoked individually
without changing your main Google password.

## License

[MIT](./LICENSE)
