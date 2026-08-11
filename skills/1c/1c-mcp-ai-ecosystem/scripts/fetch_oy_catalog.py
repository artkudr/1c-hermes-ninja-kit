#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Скрейп полного каталога OpenYellow через его API.

Сайт openyellow.org — static SPA; данные отдаёт API openyellow.openintegrations.dev.
Ограничение API: pageSize <= 100. Полный дамп = 36 страниц (~3587 репозиториев).

Использование:
    python fetch_oy_catalog.py [выходной_файл]
    # по умолчанию: oy_all_repos.json рядом со скриптом/в текущем каталоге

Поля карточки: name, url, author, stars, license, description, tags, ai_summary,
updated, isFork, createddate.
"""
import json
import sys
import time
import urllib.request

BASE = "https://openyellow.openintegrations.dev/api/repos?filter=top&pageSize=100&page={}"


def fetch_page(page: int) -> list:
    url = BASE.format(page)
    req = urllib.request.Request(url, headers={"User-Agent": "hermes-oy-catalog/1.0"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = json.load(resp)
    if isinstance(data, dict):
        for key in ("items", "repos", "data"):
            if isinstance(data.get(key), list):
                return data[key]
        raise RuntimeError(f"Неожиданная форма ответа: {list(data.keys())}")
    return data


def main() -> None:
    out = sys.argv[1] if len(sys.argv) > 1 else "oy_all.json"
    all_repos = []
    page = 1
    while True:
        items = fetch_page(page)
        if not items:
            break
        all_repos.extend(items)
        print(f"стр. {page}: +{len(items)} (всего {len(all_repos)})", file=sys.stderr)
        if len(items) < 100:
            break
        page += 1
        time.sleep(0.2)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(all_repos, f, ensure_ascii=False, indent=1)
    print(f"Сохранено {len(all_repos)} репозиториев -> {out}", file=sys.stderr)


if __name__ == "__main__":
    main()