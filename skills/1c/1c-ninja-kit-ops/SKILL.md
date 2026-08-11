---
name: 1c-ninja-kit-ops
description: "Use when verifying/committing the 1C Hermes Ninja Kit."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [windows]
metadata:
  hermes:
    tags: [1c, ninja-kit, git, github, templates, mcp]
---

# 1C Hermes Ninja Kit — сопровождение (ops)

## When to Use

- Пользователь просит «перепроверь кит», «закоммить кит», «запушь», «сделай репозиторий публичным».
- После разворачивания нового стенда (qbikdev и т.п.) — сверка «опыт стенда → изменения в ките».
- Правка шаблонов/установщиков/доков кита, миграция контура (переименование сервера/инструмента).

## Факты окружения (актуально 2026-08)

- Кит: `C:\hermes\1c-hermes-ninja-kit` (git, ветка `main`, origin = `https://github.com/artkudr/1c-hermes-ninja-kit.git`).
- Эталон базы: `templates/project/`. `ninja new` штампует базу: копирует `AGENTS.md.tpl` из `templates/` как `<base>/AGENTS.md` (строка ~72 `scripts/ninja.sh`) + копирует каркас `templates/project/*`.
- Контуры в ките: статический **mcp-1c-autumn** (порт lekot/mcp-1c на autumn-mcp), живой **1c-mcp-toolkit :6003**, LLM-ядро **1c-buddy :6002**, мост **pi-bridge** (служба NSSM). **bslc — изъят** («БЕЗ НАДОБНОСТИ», архив `C:\hermes\bsl-server-fail`).
- Публикация: токен в `~/.git-credentials` (HTTPS), gh/SSH нет; репо создаётся/меняется через `api.github.com` (POST `/user/repos`, PATCH `/repos/<owner>/<repo>`).

## Рабочий процесс (проверка → коммит → пуш → публикация)

1. `git status -sb` + `git log --oneline -15` + `git log origin/main..main` (пусто = всё запушено).
2. Сверка «опыт стенда → кит»: найти сессию стенда (`session_search`), выписать, какие артефакты должны быть в ките, проверить наличие install-скриптов, шаблонов, секций INSTALL/DECISIONS.
3. **Свеп старых имён при миграциях** (см. Пифолл #1): grep по ВСЕМ файлам, ожидать 0 совпадений.
4. Правки → коммит Conventional Commits (русский язык сообщений: `docs(шаблоны): ...`, `feat(mcp): ...`). Коммиты — только по явной команде владельца.
5. Пуш: `git push origin main`. github.com может разово таймаутить — ретраи с паузой. api.github.com может быть недоступен, пока github.com жив (пуш идёт на github.com — не путать).
6. Публикация/видимость: PATCH `https://api.github.com/repos/artkudr/1c-hermes-ninja-kit` `{"private": false}` — **требует одобрения** (см. Пифолл #3), планировать на присутствие пользователя.

## Пифоллы

1. **Миграцию контура нельзя заканчивать на docs/.** Коммит `894d572` перевёл сервер mcp-1c → mcp-1c-autumn и обновил INSTALL/README/DECISIONS, но шаблоны баз (`templates/AGENTS.md.tpl`, `templates/project/*`) остались на старом имени контура и префиксе инструментов (`mcp__mcp1c__*`). Недовнесённая правка всплыла только при сверке со стендом (коммит `dad1b6b`). Правило: после любого переименования свепить старое имя по ВСЕМ файлам кита (`docs + templates + scripts`), ожидая 0 совпадений.
2. **search_files (ripgrep) на этой Windows-машине может падать** с `rg: /c/<path>: IO error (os error 2/3)` — путь конвертируется в MSYS-форму, которую нативный rg не открывает. Обход: `terminal` grep (bash понимает `/c/...`).
3. **Гейт одобрений Hermes**: команды, читающие токен из `~/.git-credentials` (curl/PATCH к api.github.com), и bash-скрипты с `rm -rf` (ad-hoc верификаторы в Temp) триггерят промпт одобрения; если владелец не у экрана — «BLOCKED: Command timed out without user response». Повторять запрещено. Стратегия: read-only верификацию — через terminal grep/read_file (без одобрения); API-мутации и скрипты с `rm` — отдельным шагом с явным согласием (clarify → «буду одобрять промпт»), либо версия скрипта без `rm`.
4. **Если сквозной тест заблокирован** (например `ninja new` в верификаторе): подтвердить механизм доставки по коду — строка штамповки `cp` в `ninja.sh` — и проверить контент шаблона напрямую; этого достаточно как ad-hoc-доказательство.
5. Верификаторы — ad-hoc: `%TEMP%\hermes-verify-<топик>.sh`, прогнать, удалить. Это не «suite green»: у кита нет канонического тест-раннера (bash-скрипты/доки).

## Ссылки

- `references/qbikdev-experience.md` — что дал стенд qbikdev: какие правки кита из него вышли и итоговая сверка 2026-08-11.