# Живой мост 1c-mcp-toolkit: проверенный развёрт (2026-08-10)

Прокси-режим (Docker + EPF в живой сессии 1С) — РАБОТАЕТ. Проверено на
qbik-dev (УНФ, платформа 8.3.27.2130 x86).

## Схема

агент → прокси :6003 (/mcp + /api/*) → long-polling /1c/poll?channel=default
→ обработка MCP_Toolkit.epf в сессии 1С (вход вручную владельцем).

## Развёрт (3 шага)

1. Прокси (идемпотентно):
   docker run -d --name 1c-mcp-toolkit-proxy -p 6003:6003 \
     -e ALLOW_DANGEROUS_WITH_APPROVAL=true --restart unless-stopped \
     roctup/1c-mcp-toolkit-proxy
   Дефолты образа: RESPONSE_FORMAT=toon, ANONYMIZATION_ENABLED=false.

2. Сессия 1С (пароль вводит владелец, НЕ храним):
   "<1cv8.exe>" ENTERPRISE /F "<база>" \
     /Execute "<...>\build\MCP_Toolkit_x86.epf" \
     /C "startup;mode=proxy;url=http://localhost:6003;channel=default"
   → диалог входа (вручную) → подтверждение открытия внешней обработки → Да
   → обработка сама подключается (startup;mode=proxy).

3. MCP в Hermes:
   hermes mcp add 1c-toolkit --url http://127.0.0.1:6003/mcp --connect-timeout 20
   → интерактив: auth? → n; Enable all 12 tools? → y. Работает в НОВОЙ сессии.

## Ключевые проверки

- health: curl http://localhost:6003/health → active_sessions_count ≥ 1.
- В логах контейнера: GET /1c/poll?channel=default ... 204 — сессия жива.
- REST (12 эндпоинтов): POST /api/get_metadata, /api/execute_query,
  /api/get_event_log, /api/get_bsl_syntax_help.
  get_bsl_syntax_help: keywords — МАССИВ, не строка: {"keywords":["Запрос","Выполнить"]}.

## Пифоллы (все проверены)

- **x86-платформа → x86-EPF.** На тонком x86-клиенте нужен
  MCP_Toolkit_x86.epf (Native-компоненты SyntaxHelpReader/ScreenCapture
  собираются под разрядность). С обычным EPF get_bsl_syntax_help отвечает
  «SyntaxHelpReader не загружен».
- Обработка живёт, пока открыта сессия 1С; закрыл 1С — команды истекают
  по TIMEOUT (180 c), прокси остаётся healthy.
- Разные dev-базы — разные channel=<имя>, один прокси.
- Команды кладутся в очередь канала; пока 1С не подключилась — health
  показывает pending_commands, потом timeout (это нормально, не ошибка).
- ALLOW_DANGEROUS_WITH_APPROVAL=true даёт execute_code/close_1c_session
  только с подтверждением; без флага опасные инструменты отключены.
- Скиллы тулкита calling-1c-rest-api-via-curl и composing-1c-queries
  скопированы в Hermes as-is (категория 1c) — они в формате SKILL.md.

Полный рецепт также в ките: docs/INSTALL.md §12, docs/DECISIONS.md
(2026-08-10), шаблон AGENTS.md.tpl («Живой доступ»).