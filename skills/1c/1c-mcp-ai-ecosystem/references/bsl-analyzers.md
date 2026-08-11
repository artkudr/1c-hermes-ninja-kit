# BSL-анализаторы 1С — карта экосистемы (сводка 2026-08-09)

Проверено батчами GitHub API (звёзды/даты/язык/лицензия) + README из raw.githubusercontent. Полный гайд: `~/guides/05-1c-bsl-analyzers.md`.

## Основные инструменты

| Инструмент | Автор | Язык | ⭐ | Статус | Роль |
|---|---|---|---|---|---|
| bsl-language-server (bslc) | 1c-syntax | Java | 464 | пуш 08.2026, стабильный | Эталон: ~240 диагностик, LSP+CLI+MCP, репортёры json/sarif/junit/generic, форматтер ИТС |
| bsl-analyzer | itrous | Rust | 85 | альфа 0.1.x (созд. 03.2026) | rust-analyzer-архитектура (Salsa/Rowan/HIR), 1 exe без Java, MCP «под ключ», SARIF/JSONL |
| 1c_hbk_bsl | mussolene | **Python** | 7 | пуш 07.2026 | 180 диаг., PyPI `onec-hbk-bsl`, LSP/CLI/MCP/форматтер |
| mcp-bsl-lsp-bridge | SteelMorgan | Go | 66 | пуш 07.2026 | Мост bslc(LSP) → MCP для ИИ-агентов |
| bsl-context | Regsorm | Rust | 19 | пуш 07.2026 | Валидация BSL-выражений против реального API платформы — ловит галлюцинации LLM |
| code-index-mcp | Regsorm | Rust | 93 | пуш 08.2026 | Структурный поиск по выгрузке кода, 31 инструмент, статический бинарник |
| claude-code-bsl-lsp | 1c-syntax | Shell | 32 | пуш 04.2026 | Плагин Claude Code: диагностики bslc |
| mcp-bsl-platform-context | alkoleft | Kotlin | 186 | пуш 03.2026 | Справка по платформе для агентов |
| rlm-tools-bsl | Dach-Coin | Python | 170 | пуш 08.2026 | Анализ больших BSL-баз без RAG, HTTP :9000 (паспорт 00) |

## Важные факты

- **«Анализатор на Go» не существует** — на Go только парсер goyacc (`1c-language-parser`, API 404 = переименован, звёзды брать из каталога OpenYellow) и MCP-сервер конфигурации `mcp-1c` (feenlace). Свежий «Rust-анализатор» из новостей = `bsl-analyzer` (itrous) или мост SteelMorgan.
- Плагина SonarQube первой-party у 1c-syntax НЕТ (`sonar-bsl*` → 404, `bsl-bot` → 404). Живые: `edt-sonarq-plugin` (Jimmo910, 10★, пуш 08.2026), SonarBslFileNaming (56★). Путь в SQ — репортёр generic/json bslc.
- Диагностики bslc ≈ 240 (посчитано: `git/trees/HEAD?recursive=1` → `*.java` в `*/diagnostics/*`, без тестов). У HBK — 180 (README).
- **MCP bslc — экспериментальный** (Spring AI 2.0 milestone), API может меняться; инструменты: `analyze_file`, `document_symbols`, `find_references`, `call_hierarchy`, `hover`, `definition`, `type_info`, `global_member_info`, `global_member_search`, `type_at_position`.
- bslc требует Java 17 (у пользователя Java НЕ установлена — Docker-образ или Rust-бинарник как обход).

## Паттерны проверки (пригодились)

- Батч-проверка репозиториев: один `python - <<EOF` скрипт → `urllib` на `api.github.com/repos/<owner>/<repo>`, вывод таблицей `stars|lang|created|pushed|archived|license`; 404 → репо переименован/скрыт → ищи в `oy_all_repos.json`.
- Страницы GitHub Pages (1c-syntax.github.io): `web_extract` НЕ отдаёт (SearXNG-бэкенд) → `curl` + regex-снятие тегов python (`<script/style>` вырезать до strip'а).
- Сценарии «несколько баз»: (а) multi-root/roots в LSP/MCP, (б) конфиг per-base `.bsl-language-server.json`, (в) CI-матрица. Анализатор работает ТОЛЬКО с исходниками (XML-выгрузка/EDT/git), не с ИБ.
- Связка под ИИ: анализатор (bslls или bsl-analyzer MCP) + валидатор API (`bsl-context`) + индексатор (`code-index-mcp`/`rlm-tools-bsl`); агентный альтернативный путь — вызов CLI `analyze --reporter sarif/json` и чтение отчёта = без новой инфраструктуры.