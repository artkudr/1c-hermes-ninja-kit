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
   - opm-пакеты (`sql`, `autumn`, `autumn-mcp`); `yaxunit` — опция (снят с плана);
   - статический контур mcp-1c-autumn: oscript-сервер поиска по выгрузке +
     справки SQLite (5 инструментов, без живой сессии 1С; порт lekot/mcp-1c
     на autumn-mcp) — `install/install-mcp1c-autumn.sh`;
   - LLM-ядро 1c-buddy :6002 (1С:Напарник): MCP, 8 экспертных инструментов
     (порт только 127.0.0.1; токен code.1c.ai — в `tools/.env`);
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

## Статический контур (mcp-1c-autumn) — поиск по выгрузке без живой сессии

oscript-сервер поверх выгрузки конфигурации: работает всегда, не требует базы,
пароля и Docker. Даёт агенту 5 инструментов Hermes (`mcp__mcp_1c_autumn__*`):

| Инструмент | Что делает |
|---|---|
| `bsl_search` | поиск текста/регэкспа по BSL-модулям выгрузки (src/cf, src/cfe/...) |
| `read_module` | чтение одного модуля (или список методов) |
| `xml_search` | поиск по XML-метаданным выгрузки |
| `config_list` | обход структуры конфигурации |
| `syntax_help_search` | справка синтакс-помощника 1С из SQLite (6 МБ в репо сервера) |

```bash
bash install/install-mcp1c-autumn.sh "C:/hermes"  # идемпотентно; --force — переустановка
hermes mcp test mcp-1c-autumn                     # ✓ Connected, ✓ Tools discovered: 5
```

Сервер живёт в `tools/mcp-1c-autumn` — порт оригинального lekot/mcp-1c на фреймворк
autumn-mcp (JSON-RPC-слой заменён библиотечным, контракты инструментов без изменений;
origin и лицензия GPL-3.0 — в README сервера). Прежний lekot-сервер отключён, история
и исходники — в `tools/archive/mcp-1c-lekot/`. После установки — **переоткрыть Hermes**
(инструменты появляются в новой сессии). Подробности и грабли — `docs/INSTALL.md` §13.

## LLM-ядро: 1c-buddy (1С:Напарник), порт 6002

Шлюз к сервису 1С:Напарник (code.1c.ai): 8 экспертных инструментов для агентов —
ответы по платформе, база знаний ИТС, ревью/правка BSL. Подключается **только
как MCP** (решение владельца: мозг Hermes не меняем, OpenAI `/v1` не включаем).

```bash
bash install/install-buddy.sh "C:/hermes"   # идемпотентно; --force — пересоздать контейнер
hermes mcp test 1c-buddy                     # ✓ Connected, ✓ Tools discovered: 8
```

| Инструмент | Что делает |
|---|---|
| `ask_1c_ai` | общий вопрос по платформе, объяснение, практическая рекомендация |
| `search_1c_documentation` / `search_its` | поиск по документации платформы / базе знаний ИТС |
| `fetch_its` | чтение документа ИТС по id (id отдаёт `search_its`) |
| `check_1c_code` / `modify_1c_code` | проверка (синтаксис/ревью) и правка BSL по заданию |
| `explain_1c_syntax` / `diff_1c_documentation_versions` | объяснение синтаксиса / сравнение документации версий |

Токен `ONEC_AI_TOKEN` — бесплатно на [code.1c.ai](https://code.1c.ai), кладётся в
`tools/.env` (install.sh создаёт файл и просит заполнить). Контейнер
`roctup/1c-buddy` публикует порт **только на `127.0.0.1`** — в `/mcp` и веб-чате
аутентификации нет, наружу выставлять нельзя.

> ⚠ ТоС: API code.1c.ai по пользовательскому соглашению предназначено для
> 1С:EDT; сторонний вызов — на свой страх и риск (в ответах может появляться
> приписка «API предназначено для 1С:EDT», в худшем случае — блокировка токена).
> Согласовано с владельцем 2026-08-10. Подробности — `docs/INSTALL.md` §14.

## Работа с базами

```bash
bash scripts/ninja.sh new <имя> --ext <ExtA> [--ext <ExtB> …]  # создать базу
bash scripts/ninja.sh list        # реестр баз (tools/projects.json)
bash scripts/ninja.sh scan        # базы на диске + кто не в реестре
```

Анализ кода — статический контур mcp-1c-autumn (`bsl_search`, `read_module`, …),
живой мост 1c-mcp-toolkit и LLM-ядро 1c-buddy (Напарник).

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

## Скиллы кита (skills.external_dirs)

1С-скиллы живут в ките (`skills/<категория>/<скилл>/SKILL.md`) и подключаются
к Hermes как внешний каталог (одна копия, правки — коммитом в кит):

```bash
hermes config set --force skills.external_dirs "C:/hermes/1c-hermes-ninja-kit/skills"
# проверка: hermes skills list | grep 1c
```

Список скиллов и грабли — `docs/INSTALL.md` §15.

## Документация

- `docs/INSTALL.md` — пошаговое руководство, **каждый пункт проверен исполнением**;
- `docs/CONVENTIONS.md` — конвенции структуры и git;
- `docs/DECISIONS.md` — почему именно так (zip-oscript, локальный образ и т.п.).

## Лицензия

MIT. Публикация на GitHub — по решению владельца (по умолчанию private).
Секретов и личных путей в репозитории нет: токены — в `.env` (вне git),
ориентиры — в `.env.example`.