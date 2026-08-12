# OpenYellow catalog — reference (2026-08-08)

## API

- Base: `https://openyellow.openintegrations.dev/api`
- `GET /api/repos/stats` — счётчики.
- `GET /api/repos/filters` — фильтры.
- `GET /api/repos?filter=top&pageSize=N&page=P` — карточки.
  - **pageSize капается до 100** (запрос `pageSize=4000` вернул 100). Полный каталог: 3587 репо = 36 страниц.
  - `filter=top` отдаёт полный каталог (не «топ»).
- Поля карточки (проверять `.get()`): `id, name, url, author, stars, forks, license, isFork, createddate, updated, description, tags, ai_summary`.
- CORS/открытый доступ: работает через `urllib`/`curl` без ключей.

## Схема категорий (итоговая, 14)

1. T1_Каталоги_и_гайды — агрегаторы MCP/навыков для 1С (1c-mcp Untru 135★, neuraldeep 100★, cc-1c-init).
2. T2_Фреймворки_MCP — каркасы своих серверов (1c_mcp vladimir-kharin 474★ — эталон, mcp-1c-platform-tools, autumn-mcp, autumn-mcpify).
3. T3_MCP_данные_и_метаданные — доступ к метаданным/модулям/данным ИБ (OpenIntegrations 660★, EDT-MCP 240★, 1c-mcp-toolkit ROCTUP 224★ — уже стоит у пользователя на :6003, mcp-1c feenlace 187★, MCP-DB-Client, dajet-mcp-server, onec-cfg2md).
4. T4_MCP_контекст_платформы — справка/синтаксис BSL для агента (mcp-bsl-platform-context alkoleft 185★, mcp-bsl-lsp-bridge 66★, platform-context-exporter 47★, onec-help-mcp 22★).
5. T5_MCP_семантика_и_RAG — семантический поиск/RAG по коду (rlm-tools-bsl 168★, mcp-1c-v1 162★, code-index-mcp 93★, bsl-atlas 74★).
6. T6_MCP_Напарник — шлюзы к 1С:Напарник / code.1c.ai (1c-buddy 92★, spring-mcp-1c-copilot 44★).
7. T7_MCP_инфраструктура — прокси/безопасность/docker (1c-trusted-gateway 27★, compose4mcp 36★).
8. T8_Навыки_и_агенты — Skills/rules для агентов (cc-1c-skills 509★, 1c-ai-development-kit 151★, 1c-ai-feature-dev-workflow 151★, unica 136★, 1c-batch 107★).
9. T9_ИИ_ассистенты — ассистенты внутри 1С (mini-ai-1c 238★, AI_agent 81★).
10. T10_LLM_интеграции — SDK/коннекторы из кода 1С (GigaChat_SDK_1C, deepseek_for_1c, 1C-Yandex-GPT, ollama-function-calling-1c, ione, R1C, 1c-ai-connector 77★ «ИИкона»).
11. T11_Бенчмарки_LLM (llm_1c_benckmark, prism, bench).
12. T12_RAG_базы_знаний (scraping_its 48★ — парсер ИТС, 1c-analyzer-wiki-rag 40★, kb-factory 6★, hbk-to-md 10★, ru-buh).
13. T13_OCR_речь (TesseractOCR1C 17★, speechrecognizer, Voice1C).
14. T14_Инфраструктура_AI — парсеры BSL/AST/HBK (1c-language-parser 67★, bsl-parser 62★, hbk-viewer, v8unpack-agent, 1c-ast-builder).

**Итог отбора:** 151 уникальных репозиторий (после дедупликации форков и курации).

## Как классифицировать (пифоллы)

- Только `name + description + tags`, lowercase, regex `\b(mcp|ai|llm|agent|skill|rag|copilot|benchmark|giga|yandex gpt|deepseek|claude|codex|напарник)\b` — иначе ложняки.
- `ai_summary` — НЕ источник матчинга (субстроки «агент» в религии, «бот» внутри «работа»). Полезен только как «возможности» в таблице выдачи (обрезать ~220–600 симв.).
- Дедуп: `isFork==0` предпочтителен; если оба форки — макс. звёзд. (SandersNeo и ещё ряд авторов форкают чужие репо пачками — в выдаче оставлять оригинал.)
- Клин «Что вырезать» (по exact lowercase более): EDT/VSCode-плагины (`edt.*`, `vscodepluginfor1cdev`), парсеры техжурнала без AI, CI-пайплайны (jenkins*), драйверы ШК (`androidscannerdriverfor1c`, `scansoft`, `infoscan`), подсветка синтаксиса («syntax-for-gitlab» и пр.), плагины БИТ, `1c-ai-codegen-*` (бумага, не инструмент), `v8std` (редактор стандартов), `knowledge-graph`, `osm`.
- Перебрасывать (не вырезать): `1c-ai-sandbox-client-server` → T8, `mcp-rsv-data` → T3, `bsl-ai-toolkit`/`v8std-standards-harness` → T8, `mcp-bsl-context` → T4; `scraping_its` → T12 (классификатор его при исходном прогоне терял — добавить ручно из `oy_all_repos.json`).

## Готовые артефакты на диске (C:\Users\artkudr)

- `oy_all_repos.json` — полный дамп каталога (~4 МБ, 3587 карточек) — сырьё для любых пересборочных прогонов.
- `oy_classify.py` — шаг 1: отбор+категоризация → `oy_selected.json`.
- `oy_build.py` — шаг 2: дедуп форков, DROP/NAME_MAP, cat-fallback → `oy_final.json`.
- `oy_report.py` — шаг 3: MD + CSV (`oy-catalog/1c-mcp-ai-catalog.md`, `catalog.csv`, 151 репо).
- Обновление при «свежескрейпенном» каталоге: скрипт API → новые `oy_selected/final`, реюзать `oy_report.py`.

## Рекомендуемый стек интеграции (для пользователя)

У пользователя уже работает `1c-mcp-toolkit` (ROCTUP) как прокси-мост (:6003, /mcp Streamable HTTP + /api REST, EPF в живой 1С). Достройка:

1. **Контекст платформы** → `mcp-bsl-platform-context` (185★): агент перестанет выдумывать API.
2. **Навыки** → `cc-1c-skills` (509★) / `1c-ai-development-kit` (151★).
3. **RAG по своей конфигурации** → `rlm-tools-bsl` / `bsl-atlas` / (для легкости) `1c-litecode-mcp`.
4. **1С:Напарник** → `1c-buddy` (92★), если нужен код через code.1c.ai.
5. **LLM из кода 1С** → `GigaChat_SDK_1C` / `1c-ai-connector` (ИИкона) / `ollama-function-calling-1c`.
6. **Безопасность** → `1c-trusted-gateway` (27★) для прода; тест-прокси уже есть.

Гайд пользователя по мосту: `~/guides/01-1c-mcp-bridge.md` (детали в memory: `Bridge: 1c-mcp-toolkit ROCTUP proxy — :6003`).