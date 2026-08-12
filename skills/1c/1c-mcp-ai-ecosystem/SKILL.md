---
name: 1c-mcp-ai-ecosystem
description: Use when researching 1С MCP/AI open-source catalogs.
---

# 1C MCP/AI open-source ecosystem

Как искать, классифицировать, оценивать и портировать open-source MCP-серверы и ИИ-инструменты для 1С:Предприятие. Контекст пользователя: Windows, 1С 8.3.20+ (файловые/серверные dev-базы), XML-выгрузки, установлен OneScript (oscript), работа через Cursor / Claude Code / Codex, мост 1c-mcp-toolkit (ROCTUP) на `:6003` (`/mcp` Streamable HTTP + `/api` REST). Общение — по-русски. Пользователь предпочитает «анализ → гайд → руками», без спешки.

## Свежий каталог OpenYellow (главный источник)

- Сайт openyellow.org — **static SPA**: данные отдаёт API `https://openyellow.openintegrations.dev/api` (найдено в `js/main.js` сайта).
- Эндпоинты: `GET /api/repos/stats`, `GET /api/repos/filters`, `GET /api/repos?filter=top&pageSize=N&page=P`.
- **Ограничение: pageSize ≤ 100** → полный дамп = 36 страниц (~3587 репо). `filter=top` отдаёт весь каталог.
- Поля карточки: `name`, `description`, `tags`, `ai_summary`, `author`, `stars`, `license`, `url`, `updated`, `isFork`, `createddate`.
- **Скрейп**: `python scripts/fetch_oy_catalog.py` (urllib, пагинация, сохраняет `oy_all_repos.json`). Классификация и сборка отчёта — скрипты в `C:\Users\artkudr\oy_classify.py`, `oy_build.py`, `oy_report.py`; отчёт: `C:\Users\artkudr\oy-catalog\1c-mcp-ai-catalog.md` + `catalog.csv` (151 репозиторий, 14 категорий) — подробности в `references/openyellow-catalog.md`.

## Классификация — проверенные правила

- Отбирать строго по `name + description + tags` (word-boundary regex), **не по `ai_summary`** — там ложные срабатывания («инструкции», «агент», «бот» в слове «работа»).
- Дедупликация форков: предпочитать `isFork=0`, при равных — максимум звёзд.
- Категории (порядок приоритета, финальная схема T1–T14): каталоги/гайды, фреймворки MCP, MCP-данные и метаданные, MCP-контекст платформы, MCP-семантика/RAG, MCP-Напарник (code.1c.ai), MCP-инфраструктура, навыки/агенты, ИИ-ассистенты, LLM-интеграции, бенчмарки LLM, RAG-базы знаний, OCR/речь, инфраструктура AI (парсеры BSL/AST/HBK).
- Выбрасывать: EDT/VSCode-плагины (даже если в названии «MCP»), сканеры штрихкодов/OCR-плагины, не-LLM-парсеры логов и CI-пайплайны, форки чужих репозиториев.
- **«МСП» в запросе пользователя = MCP серверы** (уточнено напрямую), не малый бизнес.

## Карта MCP-экосистемы 1С (топ-выбор)

Фреймворки своих серверов: `1c_mcp` (vladimir-kharin, 474★), `autumn-mcp` (OneScript!), `mcp-1c-platform-tools`. Готовые серверы данные: `OpenIntegrations` (660★), `EDT-MCP`, `1c-mcp-toolkit` (ROCTUP — мост пользователя), `mcp-1c` (feenlace, Go). Контекст платформы: `mcp-bsl-platform-context` (Java 17+, читает установленную 1С). Семантика/RAG: `rlm-tools-bsl` (RLM без векторизации, Python-песочница, служба Windows, HTTP `:9000/mcp`), `bsl-atlas` (Docker, SQLite-FTS/embedding). Навыки: `cc-1c-skills` (509★, PowerShell-рантайм, ветки под Cursor/Codex/OpenCode), `1c-ai-development-kit` (требует 8.3.24+). Напарник: `1c-buddy` (ROCTUP, Docker `:6002`, OpenAI-совместимый API; **развёрнут 2026-08-10, MCP 8 инструментов** → `references/1c-buddy-naparnik.md`). LLM SDK из 1С: `GigaChat_SDK_1C`, `1c-ai-connector`, `deepseek_for_1c`, `ollama-function-calling-1c`.

## BSL-анализаторы 1С (сводка → `references/bsl-analyzers.md`, гайд → `~/guides/05-1c-bsl-analyzers.md`)

Эталон — `bsl-language-server` (Java, ~240 диагностик, MCP-режим экспериментальный Spring AI, требует Java 17); альтернатива без Java — `bsl-analyzer` (itrous, **Rust**, альфа 0.1.x, один exe: LSP+MCP+SARIF); `1c_hbk_bsl` — **Python** (не Rust/Go!). Полноценного Go-анализатора нет (Go = только парсеры goyacc + MCP-сервер `mcp-1c`). ИИ-обвязки: `mcp-bsl-lsp-bridge` (Go), `bsl-context` (Rust — валидация API, анти-галлюцинации), `code-index-mcp` (Rust, структурный поиск), `claude-code-bsl-lsp`, `mcp-bsl-platform-context` (186★). У 1c-syntax плагина SonarQube НЕТ (`sonar-bsl`, `bsl-bot` → 404): пути в CI — SARIF → GitHub Code Scanning, generic/json → SonarQube, или `edt-sonarq-plugin`. **Решение владельца 2026-08-09: основной анализатор — `bsl-language-server` (bslc) через Docker** (`ghcr.io/1c-syntax/bsl-language-server`; CLI `analyze --reporter json|sarif` по запросу; Java в контейнере), `bsl-analyzer` (Rust) — опция LSP-семантики, **`bsl-context` — не в базовом наборе** (дубль: сверка с API уже у справки/Напарника). Детали развёртки, multi-base и «только расширения» — в `1c-mcp-ai-tooling` → `references/ecosystem-decisions.md`.

## Портирование MCP-сервера на autumn-mcp (проверенный рецепт)

Пример: `lekot/mcp-1c` — **НЕ форк** feenlace/mcp-1c (Go): самостоятельный рукописный stdio/JSON-RPC MCP на OneScript (15★, GPL-3.0, автор прямо пишет «написано ИИ-агентами»; 5 инструментов: `bsl_search`, `xml_search`, `config_list`, `read_module`, `syntax_help_search`; пакет `sql` + SQLite-справка `shcntx_help.db`; есть готовый .mdc-rule для Cursor). Порт на autumn-mcp:
1. **Выбросить** рукописный протоколь-слой целиком (main.os-цикл stdio, Dispatcher, StdioAdapter, JsonRpcSerializer, McpProtocol, ToolRegistry, InitializeSession, ListTools, CallTool, ToolArgs).
2. **Переобъявить** каждый обработчик аннотированной функцией: `&Инструмент(Имя=..., Описание=...)`, `&ПараметрИнструмента(Имя=, Описание=, Тип=, Обязательный=)`, `&ВыполнениеИнструмента`; бизнес-логику перенести 1:1.
3. Выигрыши: авто-schema, `Аннотация Функция()` (readOnlyHint/destructiveHint), кэш опций на сессию, `&MCPДлительная` для фоновых задач (taskId/поллинг/живой лог).
4. Smoke-тест: `echo '{"method":"initialize",...}' | oscript main.os` — должен вернуть `protocolVersion`; далее `tools/list` и один-два вызова инструмента.
5. Ограничение: путь без кириллицы для Cursor; путь к бинарной SQLite-справке (`src/data/shcntx_help.db`) — файлом, не кодом.

## Реализуемость MCP на oscript: ключевой факт — COM нативно поддерживается

Перед оценкой «можно ли портировать на OneScript» — проверять канал доступа. Главный вывод (проверено 2026-08-11, полный отчёт → `~/guides/09-1c-mcp-analyst-oscript.md`, детальная таблица по 18 репозиториям → `references/analytics-mcp-oscript-feasibility.md`):

- **OneScript поддерживает COM-механизм**: `Новый COMОбъект("V83.ComConnector")` — подтверждено issue-трекингом (EvilBeaver/OneScript #321, #1029, #1422: получение констант, списков кластеров, выполнение запросов). ⚠️ НО: на машине без зарегистрированной COM-компоненты платформы — `REGDB_E_CLASSNOTREG (0x80040154)` (проверено на движке 2.1.0). «oscript умеет COM» ≠ «COM работает на этой машине»: нужна установленная 1С с COM-сервером + лицензия сессии. Механизм доступен, но не «из коробки».
- Каналы доступа: XML-выгрузка 🟢 (уже в autumn) · COM 🟡 (живая база без публикации, нужна платформа+лицензия сессии) · HTTP-сервис 1С 🟢 для oscript (BSL-ядро остаётся в 1С, oscript = шлюз+MCP-обвязка) · OData 🟡 (HTTP+JSON) · прямой SQL через пакет `sql` 🔴 (маппинг ReferenceN/таблиц = проект уровня DaJet) · чтение `1Cv8.1CD` 🔴 (нет парсера; звать 1creader как внешний процесс) · embeddings/векторный поиск 🔴 (избыточно для аналитика — SQLite FTS5 хватает). ⚠️ HTTP-клиент в ядре oscript ОТСУТСТВУЕТ (только пакет `1c-http` через opm) — «HTTP-вызовы toolkit из autumn» требуют доустановки пакета.
- **Анализ отчётов из EDT-проекта — реально новое поле (не обёртка)**: СКД-отчёты лежат в XML (`src/cf/Reports/<Отчёт>/Templates/ОсновнаяСхемаКомпоновкиДанных/Ext/Template.xml`, namespace `data-composition-system/schema`) и отдают поля (dataPath/dimension) + полный текст запроса с регистрами — «какие данные трогает отчёт» видно без рантайма. Дизайн инструментов `report_list`/`report_data_sources`/`report_structure`/`report_find` и проверка на qbik-dev → `references/edt-report-analysis.md` + `~/guides/09-1c-mcp-analyst-oscript.md` §8.
- Правило отбора «для аналитика, не кодинг»: оставлять чтение данных/метаданных/прав/журнала регистрации/заполненности/документации конфигурации; выбрасывать генерацию кода, LSP, синтакс-справку, шаблоны, формы/EDT, тест-раннеры, индексаторы кодовой базы, фреймворки, инфраструктуру.
- Из 18 оценённых решений: лёгкий порт (🟢) — только `1c-llm-requests` (запрос→TSV, расширение ~20 строк BSL) и `onec-cfg2md`; дубли с нашим стеком не нужны (onebridge = форк 1c-mcp-toolkit :6003); `mcp-1c-v1` — 162★, но RAG/Qdrant для аналитика избыточен; `onec-mcp-universal` — репо удалён (404).
- **BSL-часть неизбежна** в любом «живом» варианте (расширение/EPF) — oscript заменяет транспорт и логику MCP, но не рантайм 1С; единственное исключение — COM-канал.

## Разборка/сборка .epf/.erf/.cf на oscript (2026-08-11, вопрос владельца про «разборку сборку отчётов через MCP»)

Вывод: полный цикл «бинарный контейнер ⇄ XML» возможен без платформы 1С и БЕЗ java:
- **Разборка нативно из oscript**: компонента `oscript-library/v8unpack` — `Новый ЧтениеФайла8`/`ФайлФормата8`, методы `Извлечь`/`ИзвлечьВсе`; `opm install v8unpack`. ⚠️ Только parse (read-only, сделана для gitsync) — сборки в компоненте НЕТ.
- **Полный цикл unpack+pack**: `saby-integration/v8unpack` (Python, PyPI `pip install v8unpack`, 98★): cf/cfe/epf/erf без платформы, человекочитаемое JSON-дерево, код отдельными файлами; oscript зовёт `ЗапуститьПриложение` (Python 3.11 есть).
- **Готовый LLM-пайплайн-референс**: `MRDK80/v8unpack-agent` (Python, обновлён 2026-08-09): `unpack_erf → extract_skd_queries → skd_queries.json → rag.rebuild` — ровно наш сценарий «аналитика по внешним отчётам».
- Смежное: `v8metadata-reader` (oscript: метаданные из исходников), `v8runner` (128★: запуск 1С/конфигуратора из CLI).
- Дизайн autumn-инструментов `report_unpack`/`report_pack` и детали — `references/onec-binary-unpack-pack.md`.

## Подключение HTTP MCP к Hermes и LLM-шлюзы (1c-buddy/Напарник) — проверено 2026-08-10

- **Ключевое решение для Hermes**: доменную LLM-модель (1С:Напарник) подключаем ТОЛЬКО как MCP-сервер (tools) — оркестратор остаётся общей моделью, Напарник = эксперт-подпрограмма. Provider `base_url=/v1` = замена мозга всего агента (planning/выбор инструментов) доменной моделью — НЕ для основного профиля; уместен только отдельному Hermes-профилю «1С-консультант». Вопрос владельца «зачем переписываем base_url» → ответ: для экспертных ответов в диалоге он не нужен, их даёт MCP.
- **Автоматизация `hermes mcp add` (HTTP-сервер)**: команда интерактивная, ДВА промпта — «Does this server require authentication? [Y/n]» и «Enable all N tools? [Y/n/select]». Неинтерактивно: `printf 'n\nY\n' | hermes mcp add NAME --url http://localhost:PORT/mcp --connect-timeout 60`. Питфолл: одного `n` НЕ достаточно — второй промпт получает EOF и операция завершается «Cancelled» без сохранения конфига.
- **Питфолл MSYS→docker**: `docker --env-file` с путём `C:/…` в git-bash молча конвертит его в `/c/…`, Windows-docker падает «cannot find the path». Фикс: `ENV_WIN="$(cygpath -w "$ENV_FILE")"` (зеркально в windows-toolchain-setup).
- **Секреты**: токен (ONEC_AI_TOKEN) — в локальный `tools/run/*.env`, владелец вписывает сам, в чат не светить; запуск через `--env-file`.
- **Безопасность**: у buddy `/mcp` и `/chat` БЕЗ аутентификации → bind только `-p 127.0.0.1:6002:6002`.
- Инструменты MCP видны только в НОВОЙ сессии Hermes (discovery на старте процесса) — владельца просим переоткрыть.

## Формат итогового результата: гайд в ~/guides/ (предпочтение пользователя)

Когда собран каталог (151 репо, `oy_final.json`), **финальный артефакт — Markdown-гайд в `~/guides/`**, а не «план интеграции» и не список для чтения. Пользователь дважды направил: «сделай гайд по отобранным проектам», «из всех данных что собрал сделай гайд по отобранным проектам» — план интеграции он отклоняет. Соседние гайды (актуально на 2026-08): `00-1c-ecosystem-consolidated.md`, `01-1c-mcp-bridge.md`, `02-1c-oscript-toolkit.md`, `03-1c-mcp-ai-openyellow.md`, `04-1c-tools-inventory.md`, `05-1c-bsl-analyzers.md`. **Питфолл: перед созданием нового гайда делать `ls ~/guides/`** — номер 04 уже занят инвентарём (04-1c-tools-inventory.md), BSL-гайд получил 05; иначе конфликт нумерации, который пришлось исправлять переименованием.

Структура гайда (проверена): 1) сводная таблица категорий с количеством; 2) карточки ключевых проектов (по README, не по описанию из каталога); 3) полный каталог таблицами «репо × автор × ⭐ × обновлён × лицензия × возможности»; 4) поэтапный план интеграции с критериями готовности; 5) критерии приёмки; 6) ссылки/файлы.

Сборка: `oy_guide_build.py` (чает сводку + таблицы из `oy_final.json`) + `oy_guide_cards.py` (склейка с карточками) → `~/guides/03-1c-mcp-ai-openyellow.md`.

## Питфоллы сборки гайда/каталога

- **Списки исключений (REMOVE/MOVE) должны совпадать на 100% между `oy_report.py` и скриптом гайда** — при расхождении хотя бы одного варианта имени каталог «дрейфует» (152 против эталонных 151).
- **Варианты имени с дефисом и подчёркиванием — разные записи**: `erp-feature` ≠ `erp_feature`, `jenkins-pipeline-1c-tests` ≠ `jenkins_pipeline_1c_tests`. В REMOVE заносить ОБА варианта.
- **Сверка наборов имён — case-insensitive**: каталог печатает имена в оригинальном регистре (`OpenIntegrations`, `MCP35`), рег сам выполняет `lower()`, поэтому сравнение «только в гайде / только в каталоге» делать через `{n.lower() for n in ...}`, иначе 27 ложных «расхождений» из-за одного регистра.
- Битые ссылки/описатель: возможности в таблицах обрезать ~200 chars, экранировать `|` и переносы.

## Технические препятствия (обходные пути)

- `web_extract` с бэкендом SearXNG — только поиск, контента не отдаёт. README тянем: `curl -sL https://raw.githubusercontent.com/<owner>/<repo>/HEAD/README.md` (и ветки `port-*`).
- Мета данных репозитория (звёзды, isFork, pushed_at): `curl https://api.github.com/repos/<owner>/<repo>`.
- `read_file` может посчитать валидный UTF-8 README «бинарным» — читать через `python3 -c "print(open(f, encoding='utf-8').read()[:N])"`.

См. также: `references/openyellow-catalog.md` (детали классификации и скрипты), `references/autumn-mcp-porting.md` (аннотации и рецепт порта), `references/bsl-analyzers.md` (карта BSL-анализаторов, способы проверки фактов по GitHub API), `references/analytics-mcp-oscript-feasibility.md` (каналы доступа oscript→1С, оценка реализуемости 18 аналитических MCP-решений), `references/oscript-engine-capabilities.md` (проверенные возможности движка 2.1.0, формат .epf, REST toolkit), `references/edt-report-analysis.md` (статический разбор СКД-отчётов из EDT-проекта: поля + источники данных), `references/onec-binary-unpack-pack.md` (инструментарий разборки/сборки .epf/.erf/.cf: oscript-компонента v8unpack, saby v8unpack Python, v8unpack-agent, дизайн report_unpack/report_pack).