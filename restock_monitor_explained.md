# NEXZ Hair Clip Restock Monitor — How It Works

## The core insight: bypass the scraping problem

The search page (`/en/search?q=...`) renders "Sold Out" as HTML text. Scraping that is
fragile — wording changes, translations, lazy-loaded markup. But it's a **Shopify** store,
and Shopify exposes a hidden JSON endpoint for every product:

```
https://jypj-store.com/products/<handle>.js  ->  {... "available": true/false ...}
```

That `available` boolean is the same flag the store's own "Add to Cart" button uses. It was
verified against a known in-stock item (FOX2Y -> true) and a sold-out item (-> false) before
trusting it. So instead of parsing a webpage, the monitor polls 7 tiny JSON endpoints — fast,
unambiguous, language-independent.

### Clip -> handle map

| Clip     | Handle        |
|----------|---------------|
| YUTiE    | nx26-lt0-0037 |
| PPOMOYA  | nx26-lt0-0031 |
| HYUROMI  | nx26-lt0-0036 |
| SEIDEE   | nx26-lt0-0035 |
| GEONSKY  | nx26-lt0-0034 |
| HARUBEAR | nx26-lt0-0033 |
| JELLY-YU | nx26-lt0-0032 |

(FOX2Y / `nx26-lt0-0038` is deliberately excluded.)

## Why not the WebFetch tool?

The original URL went through the `WebFetch` tool, which caches each URL for 15 minutes. A
10-second poll against a 15-minute cache would just return stale data. So the monitor uses raw
`curl`, which hits the live server every cycle.

## Architecture — 3 pieces

1. **`restock_monitor.sh`** — the watcher loop:
   ```
   every 10s:
       for each of the 7 handles:
           curl the .js endpoint, grep "available":true/false
       if any is true:
           log it, SEND EMAIL, exit 0
       else:
           log "still sold out", sleep 10
   safety cap: 4320 iterations (~12h)
   ```

2. **`send_mail.py`** — Gmail SMTP sender. Connects to `smtp.gmail.com:465` over SSL, logs in
   with the app password, sends a plaintext `EmailMessage`. Takes subject + body as arguments
   so the same script serves both the test email and the real alert.

3. **`mail.cfg`** — credentials (`chmod 600`), read by `send_mail.py`. Kept separate from code
   so secrets aren't hardcoded.

## Two layers of notification (defense in depth)

- **Primary — autonomous email:** the bash script calls `send_mail.py` itself the instant it
  detects stock. This fires even if Claude is idle or the session is asleep. Not dependent on
  the assistant.
- **Backup — in-chat:** the script runs as a background task. The harness re-invokes Claude
  when a background process exits — and the script only exits on a restock (or the 12h cap).
  So a restock also wakes Claude to message you in chat.

A hit triggers both paths; an email failure doesn't kill the chat alert and vice-versa.

## Key reliability decisions

- `--max-time 8` on every curl — a hung request can't stall the loop.
- Fail-safe direction: if the store rate-limits or errors, the grep finds no `"available":true`,
  so it reads as "still sold out." Worst case is a missed check, never a false-alarm email.
- Append-only log (`restock.log`) — lets the status be answered from recent lines + a counter.
- Restart discipline: when email was added, the old process was stopped and relaunched, so
  there's never two monitors double-sending.

## Honest limitations

- It lives only as long as the session/machine stays up — not reboot-proof. A cron job or
  systemd service would fix that.
- The app password sits in plaintext in `mail.cfg` in the scratchpad. Revoke it at
  https://myaccount.google.com/apppasswords when done.
- 10s polling is a fixed interval, not event-driven — up to 10s lag between a real restock and
  the alert. Shopify has no public push/webhook for buyers.

## Files

| File                       | Role                                  |
|----------------------------|---------------------------------------|
| `restock_monitor.sh`       | Polling loop, triggers the alert      |
| `send_mail.py`             | Gmail SMTP sender                     |
| `mail.cfg`                 | Credentials (chmod 600)               |
| `restock.log`              | Append-only check history             |
