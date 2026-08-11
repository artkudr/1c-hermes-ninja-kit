# bslc в режиме MCP: механика roots, ошибки, отладка

Источники: официальные доки репозитория (`docs/features/McpMode.md`, `docs/features/ConfigurationFile.md`, ветка develop), вскрытие классов jar 1.0.7, живой прогон контейнера `bslc:1.0.7` (2026-08-09). Всё ниже — проверенные факты; **кроме** раздела «Адаптер для Hermes» (спроектирован, не проверен).

## Запуск
- `docker run -d --name bslc-mcp -v C:/hermes:/hermes -p 18080:8080 bslc:1.0.7 mcp --protocol streamable --server.port=8080` (8080 на хосте занят SearXNG).
- Entrypoint образа = `java -jar /opt/bslc/bsl-language-server.jar`, CWD = `/opt/bslc`; аргументы `docker run` идут прямо в jar.
- Транспорты: `stdio` (default), `sse`, `streamable` (эндпоинт `/mcp`); комбинированные режимы `lsp --mcp`, `websocket --mcp`.
- Пиновать версию образа: MCP строится на Spring AI 2.0 milestone — API может меняться между релизами.

## Инструменты (10) и сигнатуры
analyze_file[file], document_symbols[file], find_references[file,line,character], call_hierarchy[file,line,character], hover[file,line,character], definition[file,line,character], type_at_position[file,line,character], type_info[typeName,fileType,root], global_member_info[name,fileType,root], global_member_search[...,root]. Позиции line/character — с нуля. `root` обязателен у инструментов контекста конфигурации; у файловых инструментов файл должен лежать внутри зарегистрированного root.

## Механика roots (главное, на чём все спотыкаются)
- «Какие папки читать» задаёт ТОЛЬКО клиент через MCP roots. Параметра командной строки для папок нет. `configurationRoot` в `.bsl-language-server.json` — про другое (подкаталог конфигурации внутри корня).
- **Проактивного roots/list на initialize нет.** Bootstrap (`McpRootsBootstrapper.bootstrapIfNeeded`) вызывается из `McpToolSpecificationsBootstrapWrapper` — BeanPostProcessor'а, оборачивающего каждый tool call: сервер запрашивает `roots/list` при ПЕРВОМ вызове любого инструмента, если клиент задекларировал roots-capability.
- Bootstrap одноразовый (AtomicBoolean): roots от первого roots-capable клиента регистрируются на весь сервер и разделяются всеми клиентами. Дальнейшие изменения — через `notifications/roots/list_changed` (`McpRootsChangeConsumer`, лог `Workspace ... added from MCP root (N files)`).
- Логи успеха: `Proactive roots/list returned {} root(s); registering workspaces`, `Indexed {} files in workspace`. При клиенте без roots-capability: `Skipping proactive roots/list — client does not declare roots capability`.
- Типовые ошибки и их смысл:
  - `File is not part of any registered workspace: <path>` — roots не зарегистрированы (клиент не отдал).
  - `No registered workspace matches root: <uri>` — то же для инструментов с параметром `root`.
  - Молчание 20 с + `TimeoutException ... 'source(MonoCreate)'` в логах — сервер запросил `roots/list`, клиент задекларировал capability, но не ответил. Частая причина: python mcp-SDK с дефолтным `_default_list_roots_callback` (возвращает INVALID_REQUEST). Лечение: `ClientSession(..., list_roots_callback=lambda ctx: types.ListRootsResult(roots=[...]))`. Таймаут запроса — 20 с.
- URI: `file:///hermes/...` (в контейнере при mount `C:\hermes`→`/hermes`). Кириллица в путях работает (проверено вызовами); спецсимволы (`>` и т.п.) недопустимы — `Illegal character in path` от java.net.URI. Windows-URI нормализуются (`normalizeWindowsFileUri`).

## Адаптер для Hermes (СТАТУС: спроектирован, НЕ проверен)
Hermes не реализует MCP roots (grep по `hermes-agent`: нет roots-capability/`list_roots_callback`). Поэтому для Hermes нужен тонкий proxy: stdio (со стороны Hermes) ↔ streamable-http к bslc-mcp, отвечающий на `roots/list` фиксированным списком корней из конфига проекта (аналог `Ailirag/onec-wrapper-bsl-server`, но python и без авто-поиска Configuration.xml — структура известна: `src/cf` + `src/cfe/<Имя>`). Не считать рабочим решением до сухого прогона `analyze_file` + `global_member_info` через proxy.

## Рецепты отладки (переиспользуемые)
- **Инспекция jar без JDK** (в образе нет unzip/javap): `docker cp <container>:/opt/bslc/bsl-language-server.jar .` → python `zipfile`; чтение строк класса: `re.findall(rb'[ -~]{6,}', z.read(name))` — видны сигнатуры, log-сообщения, имена классов/вызовов (бед-мэн's javap). Зависимости в `BOOT-INF/lib/*.jar` — второй zipfile поверх `io.BytesIO`.
- **Сырой прогон streamable-http MCP** (без SDK): POST `http://localhost:18080/mcp`, заголовки `Accept: application/json, text/event-stream`; из ответа на `initialize` забрать заголовок `Mcp-Session-Id` и слать его во всех дальнейших запросах; после initialize — `notifications/initialized` (202, без тела); ответы — SSE, парсить строки `data: `. Так изолируется поведение сервера от капризов клиентского SDK.
- Логи сервера: `docker logs --tail N bslc-mcp` (stacktrace-хвосты резать grep'ом по `^\s*at `).

## Официальная справка
- McpMode: https://1c-syntax.github.io/bsl-language-server/features/McpMode/
- Конфиг (поиск `.bsl-language-server.json`: `-c` → CWD → $HOME; per-workspace — в корне workspace, автоперечитывание): https://1c-syntax.github.io/bsl-language-server/features/ConfigurationFile/
