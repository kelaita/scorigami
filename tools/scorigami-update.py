#!/usr/bin/env python3
"""
scorigami-update.py -- keep /var/www/html/pomace/scores.html current without
scraping pro-football-reference.

The served scores.html is the source of truth: we parse it, apply the finished
games from ESPN's public scoreboard API, and write it back in the same markup
the Scorigami SwiftUI app already parses.

First run:   ./scorigami-update.py --seed      (records what's already counted)
Every run:   ./scorigami-update.py             (applies new finals)
Safe check:  ./scorigami-update.py --dry-run

Python 3.9+, standard library only.
"""

import argparse
import datetime as dt
import json
import os
import re
import shutil
import sys
import tempfile
import urllib.request
from zoneinfo import ZoneInfo

SCORES_HTML = "/var/www/html/pomace/scores.html"
STATE_DIR = os.path.expanduser("~/scorigami")
STATE_FILE = os.path.join(STATE_DIR, "applied.json")
BACKUP_DIR = os.path.join(STATE_DIR, "backups")
KEEP_BACKUPS = 10

ESPN = ("https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard"
        "?dates={season}&seasontype={stype}&week={week}")
ESPN_NOW = "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard"
EASTERN = ZoneInfo("America/New_York")

# ESPN abbreviation -> Pro-Football-Reference boxscore code (used in the href
# the app shows; PFR keys the URL on the HOME team).
PFR_CODE = {
    "ARI": "crd", "ATL": "atl", "BAL": "rav", "BUF": "buf", "CAR": "car",
    "CHI": "chi", "CIN": "cin", "CLE": "cle", "DAL": "dal", "DEN": "den",
    "DET": "det", "GB": "gnb", "HOU": "htx", "IND": "clt", "JAX": "jax",
    "KC": "kan", "LAC": "sdg", "LAR": "ram", "LV": "rai", "MIA": "mia",
    "MIN": "min", "NE": "nwe", "NO": "nor", "NYG": "nyg", "NYJ": "nyj",
    "PHI": "phi", "PIT": "pit", "SF": "sfo", "SEA": "sea", "TB": "tam",
    "TEN": "oti", "WSH": "was",
}

ROW_RE = re.compile(r"<tr[ >].*?</tr>", re.S)
CELL_RE = {
    "pts_win":  re.compile(r'data-stat="pts_win"[^>]*>\s*(\d+)\s*<'),
    "pts_lose": re.compile(r'data-stat="pts_lose"[^>]*>\s*(\d+)\s*<'),
    "counter":  re.compile(r'data-stat="counter"[^>]*>\s*(\d+)\s*<'),
}
LAST_RE = re.compile(
    r'data-stat="last_game"[^>]*?csk="([0-9-]+)"[^>]*>\s*<a href="([^"]+)">(.*?)</a>', re.S)


# ---------------------------------------------------------------- read

def load_html(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def parse_scores(html):
    """-> {(win, lose): {"count": int, "date": "YYYY-MM-DD",
                         "href": str, "text": str}}"""
    body = html
    m = re.search(r"<tbody\b.*?(?:</tbody>|</table>)", html, re.S)
    if m:
        body = m.group(0)
    table = {}
    for row in ROW_RE.findall(body):
        try:
            w = int(CELL_RE["pts_win"].search(row).group(1))
            l = int(CELL_RE["pts_lose"].search(row).group(1))
            c = int(CELL_RE["counter"].search(row).group(1))
        except AttributeError:
            continue
        lg = LAST_RE.search(row)
        table[(w, l)] = {
            "count": c,
            "date": lg.group(1) if lg else "",
            "href": lg.group(2) if lg else "",
            "text": lg.group(3).strip() if lg else "",
        }
    return table


# ---------------------------------------------------------------- fetch

def fetch(url):
    req = urllib.request.Request(url, headers={
        "User-Agent": "scorigami-update/1.0 (+https://pomace.net)",
        "Accept": "application/json",
    })
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def current_week():
    d = fetch(ESPN_NOW)
    season = d.get("season", {})
    return (int(season.get("year")), int(season.get("type", 2)),
            int(d.get("week", {}).get("number", 1)))


def finished_games(season, stype, week):
    """-> list of dicts for games that are actually final."""
    out = []
    for ev in fetch(ESPN.format(season=season, stype=stype, week=week)).get("events", []):
        status = ev.get("status", {}).get("type", {})
        if not status.get("completed") or status.get("state") != "post":
            continue
        comp = ev["competitions"][0]
        sides = {}
        for c in comp["competitors"]:
            sides[c["homeAway"]] = {
                "abbr": c["team"]["abbreviation"],
                "name": c["team"]["displayName"],
                "score": int(c["score"]),
            }
        if "home" not in sides or "away" not in sides:
            continue
        kick = dt.datetime.fromisoformat(ev["date"].replace("Z", "+00:00"))
        out.append({
            "id": str(ev["id"]),
            "date": kick.astimezone(EASTERN).date(),
            "home": sides["home"],
            "away": sides["away"],
        })
    return out


# ---------------------------------------------------------------- apply

def describe(game):
    """PFR renders the winner first: 'Winner vs. Loser, Month D, YYYY'.
    A tie keeps away-then-home order, which is what PFR does too."""
    h, a = game["home"], game["away"]
    first, second = (a, h) if a["score"] >= h["score"] else (h, a)
    when = game["date"].strftime("%B %-d, %Y")
    return f'{first["name"]} vs. {second["name"]}, {when}'


def boxscore_href(game):
    code = PFR_CODE.get(game["home"]["abbr"], game["home"]["abbr"].lower())
    return f'/boxscores/{game["date"].strftime("%Y%m%d")}0{code}.htm'


def apply_game(table, game):
    """-> ('new'|'bump', (w, l))"""
    w = max(game["home"]["score"], game["away"]["score"])
    l = min(game["home"]["score"], game["away"]["score"])
    key = (w, l)
    entry = table.get(key)
    iso = game["date"].isoformat()
    kind = "bump"
    if entry is None:
        entry = {"count": 0, "date": "", "href": "", "text": ""}
        table[key] = entry
        kind = "new"
    entry["count"] += 1
    if iso >= entry["date"]:                      # keep the most recent
        entry["date"] = iso
        entry["href"] = boxscore_href(game)
        entry["text"] = describe(game)
    return kind, key


# ---------------------------------------------------------------- write

def render(table):
    rows = sorted(table.items(), key=lambda kv: (-kv[1]["count"], -kv[0][0], -kv[0][1]))
    total = sum(v["count"] for v in table.values())
    out = []
    out.append("<!DOCTYPE html>")
    out.append('<html lang="en">')
    out.append("<head>")
    out.append('<meta charset="utf-8">')
    out.append("<title>All Game Scores in Pro Football History</title>")
    out.append(f"<!-- generated {dt.datetime.now().isoformat(timespec='seconds')} "
               "by scorigami-update.py -->")
    out.append("</head>")
    out.append("<body>")
    out.append('<table class="sortable stats_table" id="games">')
    out.append(f"<caption>{total:,} Games Table</caption>")
    out.append("<thead>")
    out.append("<tr>")
    for label, stat in (("Rk", "ranker"), ("Score", "game_score"), ("PtsW", "pts_win"),
                        ("PtsL", "pts_lose"), ("PtTot", "points_total"),
                        ("PD", "points_diff"), ("Count", "counter"),
                        (" ", "all_games"), ("Last Game", "last_game")):
        out.append(f'<th scope="col" data-stat="{stat}">{label}</th>')
    out.append("</tr>")
    out.append("</thead>")
    out.append("<tbody>")
    for rank, ((w, l), v) in enumerate(rows, start=1):
        out.append("<tr >")
        out.append(f'<th scope="row" class="right " data-stat="ranker" >{rank}</th>')
        out.append(f'<td class="right " data-stat="game_score" >{w}-{l}</td>')
        out.append(f'<td class="right " data-stat="pts_win" >{w}</td>')
        out.append(f'<td class="right " data-stat="pts_lose" >{l}</td>')
        out.append(f'<td class="right " data-stat="points_total" >{w + l}</td>')
        out.append(f'<td class="right " data-stat="points_diff" >{w - l}</td>')
        out.append(f'<td class="right " data-stat="counter" >{v["count"]}</td>')
        out.append('<td class="center " data-stat="all_games" >'
                   f'<a href="/boxscores/game_scores_find.cgi?pts_win={w}&amp;'
                   f'pts_lose={l}">all games</a></td>')
        out.append(f'<td class="right " data-stat="last_game" csk="{v["date"]}" >'
                   f'<a href="{v["href"]}">{v["text"]}</a></td>')
        out.append("</tr>")
    out.append("</tbody>")
    out.append("</table>")
    out.append("</body>")
    out.append("</html>")
    return "\n".join(out) + "\n"


def write_atomic(path, text):
    d = os.path.dirname(path) or "."
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".scores-", suffix=".html")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)          # same filesystem -> atomic, keeps serving
    except Exception:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def backup(path):
    os.makedirs(BACKUP_DIR, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    shutil.copy2(path, os.path.join(BACKUP_DIR, f"scores-{stamp}.html"))
    old = sorted(os.listdir(BACKUP_DIR))[:-KEEP_BACKUPS]
    for f in old:
        os.unlink(os.path.join(BACKUP_DIR, f))


def load_state():
    try:
        with open(STATE_FILE, encoding="utf-8") as fh:
            return set(json.load(fh).get("applied", []))
    except FileNotFoundError:
        return None


def save_state(ids):
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(STATE_FILE, "w", encoding="utf-8") as fh:
        json.dump({"updated": dt.datetime.now().isoformat(timespec="seconds"),
                   "applied": sorted(ids)}, fh, indent=1)


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--file", default=SCORES_HTML)
    ap.add_argument("--season", type=int)
    ap.add_argument("--seasontype", type=int, choices=(1, 2, 3))
    ap.add_argument("--week", type=int)
    ap.add_argument("--weeks-back", type=int, default=1,
                    help="also re-check this many prior weeks for late finals")
    ap.add_argument("--seed", action="store_true",
                    help="record current finals as already counted; changes no counts")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if args.season and args.week:
        season, stype, week = args.season, args.seasontype or 2, args.week
    else:
        season, stype, week = current_week()

    weeks = [w for w in range(week - args.weeks_back, week + 1) if w >= 1]
    games = []
    for w in weeks:
        try:
            games.extend(finished_games(season, stype, w))
        except Exception as e:
            print(f"warn: week {w} fetch failed: {e}", file=sys.stderr)
    games.sort(key=lambda g: g["date"])
    print(f"{season} seasontype {stype} weeks {weeks}: {len(games)} completed game(s)")

    applied = load_state()
    if applied is None:
        if not args.seed:
            sys.exit(f"no state file at {STATE_FILE}.\n"
                     "Run once with --seed first so already-counted games aren't "
                     "double counted.")
        applied = set()

    if args.seed:
        save_state(applied | {g["id"] for g in games})
        print(f"seeded {len(games)} game id(s); scores.html untouched")
        return

    fresh = [g for g in games if g["id"] not in applied]
    if not fresh:
        print("nothing new")
        return

    table = parse_scores(load_html(args.file))
    print(f"loaded {len(table)} distinct scores, {sum(v['count'] for v in table.values()):,} games")

    gami = []
    for g in fresh:
        kind, key = apply_game(table, g)
        tag = "SCORIGAMI" if kind == "new" else "         "
        print(f"  {tag}  {key[0]}-{key[1]}  {describe(g)}")
        if kind == "new":
            gami.append(key)

    if args.dry_run:
        print(f"dry run: {len(fresh)} game(s) not written")
        return

    backup(args.file)
    write_atomic(args.file, render(table))
    save_state(applied | {g["id"] for g in fresh})
    print(f"wrote {args.file}: {len(table)} distinct scores, "
          f"{sum(v['count'] for v in table.values()):,} games, "
          f"{len(gami)} new scorigami")


if __name__ == "__main__":
    main()
