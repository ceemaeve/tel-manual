#!/usr/bin/env python3
"""
feed.py - fill manual.json for the TEL-Manual overlays from the Discord calendar, without the VPS.

Runs on GitHub Actions in the tel-manual repo (.github/workflows/feed.yml) every 15 minutes, and by hand.
It is the same reading of the Discord scheduled events the website app does for /api/public/feed
(server/app/lib/discord.ts + guests.ts in tel-sites), in Python standard library only:
  * events with status 1 or 2, the next 8 days, a show kept until 30 minutes after it ends
  * weekly and daily repeats expanded per occurrence
  * name upper-cased, desc = first line, guests from the "Guests:" line (corps in brackets dropped,
    placeholders and "one more TBA" skipped), endAt when the event has an end time
Writes {"updated", "source": "discord", "nextShows": [...]} to manual.json; the overlays read nextShows.

Hold: if manual.json has "hold": true (the editor's Hold switch), it is left exactly as it is, so a
hand-written list survives the next refresh. Take the hold off to go back to automatic.

  DISCORD_BOT_TOKEN=... DISCORD_GUILD_ID=... python3 feed.py manual.json
  python3 feed.py manual.json --events events.json      (a saved API reply; no token needed)
Exit 0 and "unchanged" when the shows are the same as the file already has.
"""
import datetime as dt, json, os, re, sys, time, urllib.error, urllib.request

HORIZON_DAYS = 8
DEFAULT_SHOW_MS = 3 * 3600_000
AFTER_SHOW_MS = 30 * 60_000
DAY_MS = 86_400_000
PLACEHOLDER = re.compile(r"^(guest|guests|special guest|none|n/a|\?+)$", re.I)


def log(msg):
    print(time.strftime("%Y-%m-%d %H:%M:%S ") + msg, flush=True)


def fetch_events(token, guild):
    req = urllib.request.Request(
        f"https://discord.com/api/v10/guilds/{guild}/scheduled-events",
        headers={"Authorization": "Bot " + token, "User-Agent": "DiscordBot (https://thisevelife.space, 1.0)"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", "replace")[:300]
            if e.code != 429 or attempt == 3:
                sys.exit(f"Discord said {e.code}: {body}")
            try:
                wait = float(json.loads(body).get("retry_after", 0))
            except Exception:
                wait = 0
            wait = max(wait, 5 * (attempt + 1))
            if wait > 120:
                sys.exit(f"Discord rate limit: try again in {int(wait)} s")
            log(f"Discord rate limit, waiting {wait:.0f} s")
            time.sleep(wait)


def first_line(text, limit=140):
    line = ((text or "").split("\n")[0] or "").strip()
    if not line:
        return None
    if len(line) <= limit:
        return line
    cut = line[:limit]
    at_word = cut[:max(0, cut.rfind(" "))]
    return (at_word or cut) + " …"


def parse_guests(desc):
    out = []
    for raw in (desc or "").split("\n"):
        line = re.sub(r"[*_`]", "", raw).strip()
        g = re.match(r"^guests?\s*:\s*(.+)$", line, re.I)
        if not g:
            continue
        lst = re.sub(r"\([^)]*\)", "", g.group(1))
        for part in re.split(r",|;|\s+&\s+|\s+and\s+", lst, flags=re.I):
            part = re.sub(r"^\s*\+\s*", "", part).strip()
            part = re.sub(r"\s{2,}", " ", part)
            if not part or PLACEHOLDER.match(part):
                continue
            if re.search(r"\b(tba|tbc|tbd|more)\b", part, re.I):
                continue
            if len(part) > 40:
                continue
            out.append(part)
    return out


def parse_ms(s):
    try:
        return int(dt.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp() * 1000)
    except Exception:
        return None


def occurrences(ev, now_ms, horizon_ms, keep_ms):
    start = parse_ms(ev.get("scheduled_start_time") or "")
    if start is None:
        return []
    rr = ev.get("recurrence_rule")
    in_window = lambda t: t + keep_ms + AFTER_SHOW_MS > now_ms and t < now_ms + horizon_ms
    if not rr or rr.get("frequency") not in (2, 3):
        return [start] if in_window(start) else []
    base = parse_ms(rr.get("start") or "") or start
    bd = dt.datetime.fromtimestamp(base / 1000, dt.timezone.utc)
    end = parse_ms(rr["end"]) if rr.get("end") else None
    days = (rr.get("by_weekday") or [bd.weekday()]) if rr["frequency"] == 2 else None  # Discord: 0 = Monday
    today = dt.datetime.fromtimestamp(now_ms / 1000, dt.timezone.utc)
    today_utc = int(dt.datetime(today.year, today.month, today.day, tzinfo=dt.timezone.utc).timestamp() * 1000)
    out = []
    for i in range(-1, int(horizon_ms // DAY_MS) + 2):
        day_start = today_utc + i * DAY_MS
        t = day_start + bd.hour * 3_600_000 + bd.minute * 60_000
        if not in_window(t) or t < base or (end is not None and t > end):
            continue
        if days is not None and dt.datetime.fromtimestamp(t / 1000, dt.timezone.utc).weekday() not in days:
            continue
        out.append(t)
    return out


def iso(ms):
    return dt.datetime.fromtimestamp(ms / 1000, dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")


def project(events, now_ms, horizon_days=HORIZON_DAYS):
    horizon_ms = horizon_days * DAY_MS
    shows = []
    for ev in events:
        if ev.get("status") not in (1, 2):
            continue
        s, e = parse_ms(ev.get("scheduled_start_time") or ""), parse_ms(ev.get("scheduled_end_time") or "")
        length = e - s if (s is not None and e is not None and e > s) else DEFAULT_SHOW_MS
        duration = length if (e is not None and not ev.get("recurrence_rule")) else None
        guests = parse_guests(ev.get("description"))
        for at in occurrences(ev, now_ms, horizon_ms, length):
            show = {"name": (ev.get("name") or "").upper(), "desc": first_line(ev.get("description")),
                    "at": iso(at), "endAt": iso(at + duration) if duration else None, "guests": guests}
            shows.append(show)
    shows.sort(key=lambda x: x["at"])
    return shows


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit(__doc__)
    path = args[0]
    try:
        current = json.load(open(path, encoding="utf-8"))
    except (FileNotFoundError, ValueError):
        current = {}
    if current.get("hold") is True:
        log("hold is on in manual.json: left as it is")
        return 0
    if "--events" in args:
        events = json.load(open(args[args.index("--events") + 1], encoding="utf-8"))
    else:
        token, guild = os.environ.get("DISCORD_BOT_TOKEN", ""), os.environ.get("DISCORD_GUILD_ID", "")
        if not token or not guild:
            sys.exit("DISCORD_BOT_TOKEN and DISCORD_GUILD_ID must be set")
        events = fetch_events(token, guild)
    shows = project(events, int(time.time() * 1000))
    if current.get("source") == "discord" and current.get("nextShows") == shows:
        log(f"unchanged: {len(shows)} show(s)")
        return 0
    doc = {"updated": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"), "source": "discord", "nextShows": shows}
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, path)
    log(f"wrote {len(shows)} show(s): " + "; ".join(s["name"][:50] for s in shows[:4]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
