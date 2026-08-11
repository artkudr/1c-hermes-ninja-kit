#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Полный пагинированный фетч каталога OpenYellow (openyellow.org).
Сайт — статический SPA, данные отдаёт JSON API openyellow.openintegrations.dev/api.
pageSize капается до 100 → обязательно идём страницами до пустой страницы.

Использование:
    python fetch_openyellow.py [output.json]
По умолчанию пишет oy_all_repos.json в текущей директории.
"""
import json
import sys
import time
import urllib.request

API = "https://openyellow.openintegrations.dev/api"
PAGE_SIZE = 100
OUT = sys.argv[1] if len(sys.argv) > 1 else "oy_all_repos.json"

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (research)"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))

def main():
    all_repos = []
    page = 1
    while True:
        url = f"{API}/repos?filter=top&pageSize={PAGE_SIZE}&page={page}"
        batch = fetch(url)
        if not batch:
            break
        all_repos.extend(batch)
        print(f"page {page}: +{len(batch)} (total {len(all_repos)})")
        if len(batch) < PAGE_SIZE:
            break
        page += 1
        time.sleep(0.3)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(all_repos, f, ensure_ascii=False, indent=1)
    print(f"done: {len(all_repos)} repos -> {OUT}")

if __name__ == "__main__":
    main()