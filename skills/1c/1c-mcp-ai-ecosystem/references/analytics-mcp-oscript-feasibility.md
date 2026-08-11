# Реализуемость аналитических MCP на OneScript (проверено 2026-08-11)

Оценка 18 отобранных решений «анализ базы для аналитика» (не кодинг) из OpenYellow-каталога
на реализуемость на стеке пользователя: OneScript + autumn-mcp + XML-выгрузка.
Полный отчёт: `~/guides/09-1c-mcp-analyst-oscript.md`; README репозиториев: `~/oy-catalog/readmes/<owner>_<repo>.md`.

## Карта каналов доступа oscript → данные 1С (главный вывод)

| Канал | Реализуемость на oscript | Сложность | Примечание |
|---|---|---|---|
| Статический: XML-выгрузка / CFG / EDT | ✅ Да (уже работает в autumn) | 🟢 лёгкая | Метаданные, модули, права, подсистемы — всё из выгрузки |
| **COM-соединение** `Новый COMОбъект("V83.ComConnector")` | ✅ **Да, нативно поддерживается** — issue-трекер OneScript #321, #1029, #1422 (получение констант, списков кластеров, запросов) | 🟡 средняя | Живая база без веб-публикации: файловая/серверная; нужна установленная платформа + лицензия сессии. Позволяет oscript быть клиентом базы без Go/Python-моста |
| HTTP-сервис в расширении 1С (BSL) | ⚠️ Частично: BSL-часть остаётся в 1С, oscript = шлюз/MCP-обвязка + HTTP-клиент (`HTTPСоединение`) | 🟢 лёгкая | Самый распространённый паттерн «живых» MCP (MCP35, RSV, toolkit) |
| OData (опубликованная база) | ✅ Да: HTTP + JSON (`ЧтениеJSON`), OData-запросы строятся вручную | 🟡 средняя | Без расширения, но нужна публикация и знание OData-синтаксиса |
| Прямой SQL к СУБД (MS SQL/Postgres) | ✅ Да: пакет `sql` (System.Data.SqlClient уже в lib) | 🔴 сложная | Маппинг ReferenceN/таблиц 1С — проект уровня DaJet; только read-only, высокий риск |
| Чтение `1Cv8.1CD` напрямую | ❌ Нет готового парсера на oscript | 🔴 очень сложная | 1creader = Python-реверс формата; порт = отдельный проект. Проще звать как внешний процесс |
| Векторный поиск / embeddings | ⚠️ Нет нативных моделей; только HTTP к внешнему сервису | 🔴 сложная | Для аналитика избыточно: SQLite FTS5 закрывает ~90% задач |
| Графовые БД (Neo4j/Memgraph) | ⚠️ HTTP-API доступен, но нагружает стек | 🟡-🔴 | Для «где используется/цепочки зависимостей» хватает SQLite-таблиц связей |

## Правило отбора «анализ базы vs кодинг» (по просьбе пользователя)

**Оставляем** (анализ данных/структуры для аналитика): чтение данных и запросы, остатки/обороты/проводки,
дебиторка/ДЗ/КЗ, заполненность объектов, права доступа, журнал регистрации, метаданные/структура,
использования/зависимости, документация конфигурации, битые ссылки.

**Выбрасываем** (кодинг-инструменты): генерация/ревью BSL-кода, синтакс-справка и контекст платформы
(`mcp-bsl-platform-context`, `1c-syntax-helper-mcp`, `bsl-context`), LSP-мосты (`mcp-bsl-lsp-bridge`,
`claude-code-bsl-lsp`), шаблоны кода (`1c_templates_mcp`, `1c-templates-mcp`), формы и конструкторы
(`1c-formsserver`, EDT-плагины), тест-раннеры (`mcp-onec-test-runner`, `v8-runner-rust`),
индексаторы кода (`code-index-mcp`, `rlm-tools-bsl`, `bsl-atlas` — анализ _кодовой_ базы, не _данных_),
фреймворки (`1c_mcp`, `autumn-mcpify`), инфраструктура (`compose4mcp`, `1c-trusted-gateway`),
бенчмарки, RAG по ИТС-документации, OCR.

## Оценки по репозиториям (18)

| Решение (автор, ⭐) | Инструменты (ключ) | Архитектура | Реализуемость на oscript | Оценка |
|---|---|---|---|---|
| **mcp-rsv-data** (prepod2003, 33★) | `query` (данные простым языком!), `execute_query`, `get_structure`, `describe`, `config`, `ping`, `help` | CFE-расширение + мост Go (COM или HTTP) | Заменить Go-мост на autumn + COM-канал oscript; расширение (BSL) остаётся | 🟡 средняя |
| **MCP35** (infaton, 30★) | 51: `execute_query`, `get_balance`, `get_register_totals`, `get_accounting_entries`, `get_related_documents`, `get_event_log`, `get_rights`, `find_duplicates`, `get_changes_since`… | CFE (51 tool, 4263 строки BSL) + stdio-прокси Node→HTTP | stdio-прокси → oscript тривиально; BSL-ядро остаётся. Образец read-only списка: явный `ONEC_ALLOWED_TOOLS` | 🟡 средняя |
| **1c-odata-mcp** (evilbruce666, 15★) | 55: `read.analytics.get_debtors/inventory/sales/cashflow/…_breakdown/get_taxes_paid`, `read.schema.*`, `read.counterparty.*` | Node, чистый OData, read-only по умолчанию | Да: OData-клиент на oscript; готовая «аналитическая витрина» как образец набора | 🟡 средняя |
| **aprovodka** (theYahia, 8★) | 34: справочники, документы, все 4 вида регистров + виртуальные таблицы, константы, discovery, запись с гейтом | TypeScript, OData 3.0, без расширения | Да: OData-механика; аналитику нужна только read-часть | 🟡 средняя |
| **onec-mcp** (ruslan-hut, 2★) | 16: `sales_report`, `top_products`, `customer_summary`, `stock_balance`, `cash_balance`, `cash_flow`, `receivables_balance`, `payables_balance`, `purchases_report` | Go-шлюз к HTTP-сервисам 1С, OAuth, multi-db | Да: HTTP-клиент + MCP на autumn; BSL-эндпоинты в расширении | 🟡 средняя |
| **1c-llm-requests** (fserg, 57★) | 1 HTTP-сервис: запрос 1С → TSV | Расширение 1С (~20 строк BSL) | ✅ Самый дешёвый канал «запрос→данные»; oscript = HTTP-клиент + MCP-обвязка | 🟢 лёгкая |
| **onebridge** (thmoscow-byte, 12★) | 8: `execute_query`, `get_metadata`, `get_event_log`, `get_access_rights`, `find_references_to_object`… | EPF внутри 1С, SSE :1414 | **Дубль 1c-mcp-toolkit :6003** → не нужен | ⏭️ дубль |
| **1C_MCP_metadata** (artesk, 60★) | 4: `get_metadata_structure`, `get_metadata_object_details`, `search_metadata`, `validate_query` | CFE + HTTP-сервис + PowerShell-обвязка stdio | PS-обвязку → autumn; BSL-часть остаётся. validate_query — полезно | 🟡 средняя |
| **1c-mcp-metacode** (ROCTUP, 84★) | 22: `find_metadata_objects`, `get_metadata_object_structure`, `find_metadata_usages`, `get_access_rights`, `find_dependency_paths`, `get_form_structure`, `search_bsl_routines`, `get_bsl_call_graph`… | Neo4j-граф, streamable-http :6001, флаги загрузки | usages/структура/права — по XML-выгрузке (наш `xml_search` уже близко) 🟢; граф вызовов BSL — нужен парсер 🔴 | 🟡-🔴 |
| **1c-litecode-mcp** (svhov, 10★) | 16: `browse`, `object_structure`, `get_children`, `find_by_child`, `get_access`, `get_references`, `get_routines`, `get_call_graph`, `search_by_embedding` | Memgraph + ONNX-эмбеддинги, Docker | Структурная часть — по XML в SQLite 🟢; семантика/embeddings — нет | 🟡-🔴 |
| **dajet-mcp-server** (zhichkin, 24★) | 9: `get_database_metadata`, `search_metadata_names`, `get_metadata_object`, `resolve_metadata_references`, `execute_query` (SQL по таблицам 1С) | .NET, прямой SQL Server без 1С | Технически oscript+sql может, но маппинг таблиц 1С = проект уровня DaJet; рискованно | 🔴 сложная |
| **1creader** (vengeoff, 10★) | 11: `config_index`, `config_find`, `config_get_object`, `config_get_module`, `config_search_code`, `config_catalog_data` + Obsidian-карты | Python, чтение `1Cv8.1CD` без платформы, MCP stdio | Порт парсера 1CD на oscript — огромный проект; использовать как внешний процесс | 🔴 очень сложная |
| **onec-cfg2md** (pravets, 38★) | CLI: CFG/EDT → Markdown-карточки + objects.csv | Go, статический конвертер | ✅ Идеальный кандидат на порт: XML-выгрузку уже умеем, генерация MD простая | 🟢 лёгкая |
| **1c-conf-doc** (gybson63, 3★) | `conf_doc_search`, `conf_doc_get_object`, `conf_doc_get_object_chunk` | Python: XML → SQLite + FAISS, Docker | FTS5-часть уже есть; FAISS для аналитика не нужен | 🟡 средняя |
| **mcp-1c-v1** (fserg, 162★) | RAG по структуре конфигурации (Qdrant, мультивектор RRF) | Python + EPF-выгрузка + Qdrant, docker-compose | Выгрузка структуры — лёгкая; Qdrant/embeddings избыточно, FTS5 хватит | 🟡-🔴 |
| **onec_assistant** (agibalovsa, 37★) | дерево метаданных, права (объект-роль-пользователь, уровень реквизитов), заполненность объектов/реквизитов, битые ссылки, имена СУБД-таблиц/индексов, XDTO | Инструмент внутри 1С (не MCP) | Гибрид: дерево/права — из XML 🟢; заполненность/битые ссылки — только живой доступ 🟡 | 🟢-🟡 |
| **AI_agent** (msrv-tech, 81★) | NL-агент в базе: RAG по метаданным, автогенерация запросов, read-only режим | Расширение 1С (LangGraph runtime) | Не переносится (нужен рантайм 1С); ориентир UX «спроси базу по-русски» | ⏭️ не порт |
| **1c-analyzer-wiki-rag** (1C-Migration-Lab, 40★) | — (пусто) | План: AST/IR/wiki/RAG | Следить; делать нечего | ⏸️ пусто |

**Недоступно:** `onec-mcp-universal` (AlekseiSeleznev) — репо удалён/переименован (404), в отчёт не включён.

## Что уже покрывает стек пользователя (сверка с 1c-mcp-toolkit :6003)

Уже развёрнут живой мост: `execute_query`, `execute_code`, `get_metadata`, `get_event_log`,
`get_object_by_link`, `get_link_of_object`, `find_references_to_object`, `get_access_rights`,
`get_bsl_syntax_help`, `get_screenshot` → аналитическое ядро из MCP35/onebridge/RSV уже есть.
**Чего нет и что добавляют кандидаты:** NL→запрос (`rsv-data.query`), аналитическая витрина
(`odata-mcp.read.analytics.*`, `onec-mcp`, `MCP35`), дешёвый канал запрос→TSV (`1c-llm-requests`),
статическая документация конфигурации (`onec-cfg2md`, `1c-conf-doc`), анализ прав и заполненности (`onec_assistant`).

## План-минимум для аналитика (рекомендация из отчёта)

1. 🥇 **Канал «запрос → TSV»** (идея `1c-llm-requests`): расширение ~20 строк BSL + инструмент `execute_query_tsv` в autumn — 🟢 1–2 дня.
2. 🥇 **Структура/права/использования из XML-выгрузки** (метаданные-часть metacode/litecode/cfg2md):
   `get_metadata_structure`, `find_metadata_usages` (XML + SQLite-индекс связей), `get_access_rights` (Roles/*.xml) — 🟢-🟡.
3. 🥈 **Аналитическая витрина** (дебиторка/остатки/продажи/ДДС): OData-канал oscript или HTTP-сервисы в расширении, 6–10 инструментов — 🟡 1–2 недели.
4. 🥉 **NL-запросы к базе** (`rsv-data.query`-подобное): COM-канал oscript — `query_nl` (LLM-перевод фразы + safe read-only + обезличивание) — 🟡.
5. ⏸️ Отложить: граф вызовов BSL, embeddings, 1CD-парсер, прямой SQL — 🔴.

Всегда помнить: **BSL-часть неизбежна** в любом «живом» варианте (расширение/EPF) — oscript заменяет
транспорт и логику MCP-сервера, но не рантайм 1С. Единственное исключение — COM-канал.

## Методика пакетного сбора README (рабочий рецепт)

- Скачивать батчем в `~/oy-catalog/readmes/<owner>_<repo>.md` (слэш → `_`):
  `for repo in ...; do curl -sL https://raw.githubusercontent.com/$repo/main/readme.md -o ...; done`.
- **404-фолбэк**: проверить репо через `api.github.com/repos/<owner>/<repo>`; README может лежать
  на `main/readme.md` (нижний регистр), а файлы внутри репо — не на ветке `main`, а на `master`
  (пример: `ROCTUP/1c-mcp-metacode/docs/mcp-tools.md` → отдаётся только веткой `master` или через
  `api.github.com/repos/.../contents/<path>` + base64-декод).
- Таблицы инструментов вытаскивать grep'ом: `^\| ?\`[a-z_]+\`? ?\|` по README.