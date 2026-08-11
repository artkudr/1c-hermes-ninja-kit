# Статический контур: lekot/mcp-1c — развёрнут (2026-08-10)

Статус: ✅ развёрнут → Hermes MCP `mcp-1c` (5/5 инструментов, enabled). Сквозной тест зелёный. Сестра `references/live-bridge-deploy.md` (живой мост :6003).

## Главный вывод

План (гайд 06) предполагал «порт lekot/mcp-1c → autumn-mcp», но **порт НЕ понадобился**: репо самодостаточно — папка `build/` это готовый stdio-сервер на чистом oscript 2.x (никакого autumn). Экономия ~0.5 дня.

## Репо (проверено 2026-08-10)

- Ветка `main`, последний пуш 2026-03. Скачивание: `curl -sSL -o mcp-1c.zip https://github.com/lekot/mcp-1c/archive/refs/heads/main.zip` (заметка: `-o /tmp/...` в git-bash падает exit 23 — писать в $HOME/рабочий каталог).
- `build/` = 29 файлов: `main.os` (entrypoint), `src/{Dispatcher,adapters,common,domain,handlers,usecases}`, **`src/data/shcntx_help.db` (6 МБ — SQLite-справка синтакс-помощника УЖЕ В РЕПО**, экспорт из 1С не нужен), `opm pack/1c-mcp-0.2.0.ospx`, `rules/1c-mcp-metadata.mdc`, `skills/git-status-short/`.
- Лицензия/принадлежность: lekot (автор), README содержит правило-промпт `1c-mcp-metadata.mdc` для Cursor.

## Инструменты и параметры (важно!)

| Tool | Параметры (required выделены) |
|---|---|
| bsl_search | **path** (корень с BSL), **query** (строка или regex), useRegex (bool, default false) |
| xml_search | **path**, **query** |
| config_list | **path**, maxDepth (int) |
| read_module | **path** (файл `*.bsl` ИЛИ каталог → рекурсивный поиск, каталог возвращает список модулей и просит полный путь файла) |
| syntax_help_search | **query**, db_path (необязателен) |

Пифолл: параметр **`query`, не `pattern`** (первая попытка с `pattern` → `Argument 'query' is required`). `useRegex`, а не `regex`.

## Путь БД справки (syntax_help_search) — cwd-баг и env-фикс

main.os вычисляет каталог скрипта и пишет рядом `shcntx_help_db_path.txt`; поиск БД: env `SHCNTX_HELP_DB` → файл-указатель → `src/data/shcntx_help.db` относительно main.os.

**Грабли (поймано вживую):** oscript НЕ отдаёт путь скрипта в `АргументыКоманднойСтроки` — `ПутьСкрипта` остаётся `"main.os"`, `Файл(...).ПолноеИмя` резолвится от cwd. Ручной smoke-тест из каталога сервера это маскировал (потому первоначальная запись «env не нужен» — НЕВЕРНА), но Hermes стартует stdio-сервер из ДОМАШНЕЙ папки → справка падает: `База справки не найдена: C:/Users/<user>/src/data/shcntx_help.db`. **Фикс — env в конфиге сервера** (handler читает окружение первым):

```bash
hermes config set "mcp_servers.mcp-1c.env.SHCNTX_HELP_DB" "C:\hermes\tools\mcp-1c\src\data\shcntx_help.db"
```

Вступает только в НОВОЙ сессии Hermes (переоткрыть). Побочный эффект: при каждом старте сервер пишет `shcntx_help_db_path.txt` в cwd процесса — `hermes mcp test` из репо/кита насорит в него (gitignore + `rm -f` в скриптах).

## Развёртывание (факт, 2026-08-10)

- Путь: **`C:\hermes\tools\mcp-1c\`** — владелец явно попросил «не в корень клади mcp-1c, а куда-нибудь в тулзы». Путь без кириллицы (требование oscript/Cursor).
- oscript 2.1.0 — портируемый кит `C:\hermes\tools\engine\oscript-2.1.0\bin\oscript.exe`, уже в PATH. lib содержит opm, sql, autumn, autumn-mcp — ставить ничего не пришлось.
- Регистрация в Hermes:
  ```bash
  printf 'Y\n' | hermes mcp add mcp-1c --command oscript --args "C:\hermes\tools\mcp-1c\main.os"
  hermes config set mcp_servers.mcp-1c.connect_timeout 60
  ```
  (детали и пифоллы CLI — в SKILL.md, раздел «Развёртывание stdio MCP-сервера в Hermes»).
- **env-фикс справки обязателен** (см. выше раздел про cwd-баг): `hermes config set "mcp_servers.mcp-1c.env.SHCNTX_HELP_DB" "C:\hermes\tools\mcp-1c\src\data\shcntx_help.db"` — без него `syntax_help_search` в сессии Hermes падает.
- **Канонический повторный развёрт — установщик кита** `1c-hermes-ninja-kit/install/install-mcp1c.sh "C:/hermes"` (идемпотентный; `--force` — переустановка): сам качает/распаковывает в `tools/mcp-1c`, регистрирует `mcp-1c` (--args последним + `printf 'Y\n'`), ставит env, гоняет `hermes mcp test`, чистит txt-мусор. Вызывается и из `install.sh` (шаг 6). Вручную уже не развёртывать.
- Проверено повторным прогоном установщика + ad-hoc верификацией: 13/13 PASS (синтаксис, наличие БД, регистрация, env, идемпотентность, отсутствие мусора, `hermes mcp test` → Tools discovered; коммиты кита запушены).
- Проверки: `hermes mcp test mcp-1c` → ✓ Connected (515ms), Tools discovered: 5; smoke-тест через mcp SDK: bsl_search по `src/cfe/Компас_Кьюбик` (кириллические пути работают), read_module (список модулей), syntax_help_search «Запрос» — всё зелёное.

## oscript/opm факты

- `opm` в ките: `bin/opm.bat`; из bash — `oscript -encoding=utf-8 lib/opm/src/cmd/opm.os <cmd>` (без `-encoding=utf-8` консоль OEM-866 → кракозябры и падение в cli-хелпере). В cmd.exe: `opm.bat`.
- `opm list` пуст — кит развернул пакеты в lib вручную (реестр opm не ведётся). Норма; наличие пакета проверять по `lib/<имя>`.
- Для MCP-регистрации opm не нужен — command = oscript напрямую.

## Очередь этапа 2 (не сделано)

- `bsl-check.sh` — обёртка `docker run --rm -v <проект>:/ws ghcr.io/1c-syntax/bsl-language-server analyze --srcDir /ws/src/cfe/<Расширение> --reporter json|sarif --outputDir /ws/reports` + карта проектов (`C:\hermes\tools\projects.json` уже существует).
- yaxunit-тесты.
- Docker `mcp-lsp-qbik-dev` (bslc MCP bridge) висит unhealthy — не чинить как канал: основной канал bslc для Hermes = CLI, не MCP (гайд 05; MCP-режим bslc экспериментальный).