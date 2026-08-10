# 1c-hermes-ninja-kit

**Самоустанавливающийся плейбук ИИ-экосистемы разработки 1С.**

Ставит окружение (oscript последней версии, opm-пакеты,
живой мост 1c-mcp-toolkit :6003), создаёт 1С-базы по единой конвенции и даёт
агентам (Hermes и другим) понятный контур работы: `src/cf` — типовая (read-only
контекст), `src/cfe/*` — расширения.

## Быстрый старт (чистая машина с Hermes + Docker)

1. Hermes читает ссылку на этот репозиторий, спрашивает корневую папку проектов
   (например `C:/hermes`) и клонирует себя туда.
2. `bash install/install.sh "C:/hermes"` — идемпотентная установка:
   - oscript (последняя стабильная версия, самодостаточный zip в `tools/engine`,
     без UAC — winget-каталог отстаёт, не используем);
   - opm-пакеты (`sql`, `autumn`, `autumn-mcp`); `yaxunit` — отдельно из git;
   - статический контур mcp-1c (lekot): oscript-сервер поиска по выгрузке +
     справки SQLite (5 инструментов, без живой сессии 1С) — `install/install-mcp1c.sh`;
   - создаётся `C:/hermes/tools/` (всё не-докерное: `.env`, `projects.json`, движки).
3. Повторный запуск безопасен — скрипт идемпотентный.

## Живой мост в 1С (1c-mcp-toolkit, порт 6003)

Мост даёт агентам доступ к живой dev-базе: `execute_query`, `get_metadata`,
`get_event_log`, `get_bsl_syntax_help`, права, ссылки — read-only (опасные
операции — только с подтверждением `ALLOW_DANGEROUS_WITH_APPROVAL=true`).

```bash
# 1) поднять прокси (Docker, идемпотентно):
docker run -d --name 1c-mcp-toolkit-proxy -p 6003:6003 \
  -e ALLOW_DANGEROUS_WITH_APPROVAL=true --restart unless-stopped \
  roctup/1c-mcp-toolkit-proxy

# 2) подключить к Hermes (12 инструментов):
hermes mcp add 1c-toolkit --url http://127.0.0.1:6003/mcp   # ответы: n, y

# 3) сессия 1С с обработкой (dev-база, пользователь вводит пароль сам):
"/c/Program Files (x86)/1cv8/8.3.27.2130/bin/1cv8.exe" ENTERPRISE \
  /F "C:\1C\bases\<база>" \
  /Execute "C:\hermes\tools\run\1c-mcp-toolkit\build\MCP_Toolkit_x86.epf" \
  /C "startup;mode=proxy;url=http://localhost:6003;channel=default"
```

Проверка: `curl http://localhost:6003/health` → `active_sessions_count ≥ 1`;
`curl -X POST http://localhost:6003/api/get_metadata -H "Content-Type: application/json" -d '{}'`.
Подробности (переменные, каналы, анонимизация) — в `docs/INSTALL.md` §12 и
`docs/DECISIONS.md`.

## Статический контур (lekot/mcp-1c) — поиск по выгрузке без живой сессии

oscript-сервер поверх выгрузки конфигурации: работает всегда, не требует базы,
пароля и Docker. Даёт агенту 5 инструментов Hermes (`mcp__mcp1c__*`):

| Инструмент | Что делает |
|---|---|
| `bsl_search` | поиск текста/регэкспа по BSL-модулям выгрузки (src/cf, src/cfe/...) |
| `read_module` | чтение одного модуля (или список методов) |
| `xml_search` | поиск по XML-метаданным выгрузки |
| `config_list` | обход структуры конфигурации |
| `syntax_help_search` | справка синтакс-помощника 1С из SQLite (6 МБ в репо сервера) |

```bash
bash install/install-mcp1c.sh "C:/hermes"   # идемпотентно; --force — переустановка
hermes mcp test mcp-1c                       # ✓ Connected, ✓ Tools discovered: 5
```

Сервер живёт в `tools/mcp-1c` (build из репозитория lekot/mcp-1c: `main.os` +
`src/` + `shcntx_help.db`). После установки — **переоткрыть Hermes** (инструменты
появляются в новой сессии). Подробности и грабли — `docs/INSTALL.md` §13.

## Работа с базами

```bash
bash scripts/ninja.sh new <имя> --ext <ExtA> [--ext <ExtB> …]  # создать базу
bash scripts/ninja.sh list        # реестр баз (tools/projects.json)
bash scripts/ninja.sh scan        # базы на диске + кто не в реестре
```

Статический анализ кода — контур mcp-1c (`bsl_search`, `read_module`, …)
и живой мост 1c-mcp-toolkit.

Структура каждой базы:

```bash
<имя>/
  src/cf/            # выгрузка типовой — read-only, в git не хранится
  src/cfe/<Расширение>/  # расширения (единственное, что линтуем)
  notes/registry.md  # реестр: версия типовой одной строкой
  reports/           # отчёты анализа
  AGENTS.md  .gitignore
```

После создания базы ОБЯЗАТЕЛЬНО привязать к ней desktop-проект Hermes
(`project_create`: имя базы, path = папка базы; проверка `pwd` = корень базы
после переключения). Переключение между базами — `project_switch`, не `cd`.
Полные правила — в `docs/CONVENTIONS.md` и `templates/AGENTS.md.tpl`.

## Документация

- `docs/INSTALL.md` — пошаговое руководство, **каждый пункт проверен исполнением**;
- `docs/CONVENTIONS.md` — конвенции структуры и git;
- `docs/DECISIONS.md` — почему именно так (zip-oscript, локальный образ и т.п.).

## Лицензия

MIT. Публикация на GitHub — по решению владельца (по умолчанию private).
Секретов и личных путей в репозитории нет: токены — в `.env` (вне git),
ориентиры — в `.env.example`.