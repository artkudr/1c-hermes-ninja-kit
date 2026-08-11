# 1c-buddy :6002 — развёртывание (проверено 2026-08-10)

Шлюз к сервису 1С:Напарник (code.1c.ai): веб-чат + HTTP MCP (`POST /mcp`) + опциональный
OpenAI-совместимый `/v1` (монтируется ТОЛЬКО при заданном `OPENAI_COMPAT_API_KEY`).
Автор: ROCTUP. Образ `roctup/1c-buddy`, проверенная версия сервера 1.4.1, docker 29.6.2.

## 8 инструментов MCP

`ask_1c_ai`, `explain_1c_syntax`, `check_1c_code`, `modify_1c_code`,
`search_1c_documentation`, `search_its`, `fetch_its`, `diff_1c_documentation_versions`.

## ⚠️ ТоС (обязательно озвучить владельцу до развёртывания)

API code.1c.ai по пользовательскому соглашению предназначено для работы из **1С:EDT**;
сторонние клиенты соглашением не предусмотрены. Напарник детектирует не-EDT вызовы и
периодически вставляет в ответы приписку «API предназначено для 1С:EDT»; худший случай —
блокировка токена/учётной записи. Использование — на страх и риск владельца.

## Развёртывание (Windows + git-bash + docker)

```bash
docker pull roctup/1c-buddy
```

Env-файл `C:\hermes\tools\run\buddy.env` (владелец вписывает токен САМ, в чат не светить):
```
ONEC_AI_TOKEN=<токен с code.1c.ai>
```
Без `OPENAI_COMPAT_API_KEY` — `/v1` не включаем (решение «только MCP»).

Запуск (bind ТОЛЬКО локалхост — у `/mcp` и `/chat` нет аутентификации):
```bash
ENV_WIN="$(cygpath -w C:/hermes/tools/run/buddy.env)"   # MSYS иначе конвертит в /c/… и docker падает
docker run -d --name 1c-buddy --restart unless-stopped \
  -p 127.0.0.1:6002:6002 --env-file "$ENV_WIN" roctup/1c-buddy
```
Рабочая обёртка: `bash C:/hermes/tools/run/buddy-start.sh [start|stop|logs]`
(внутри уже есть cygpath-фикс; `start` проверяет, что токен заполнен).

## Приёмка (гейт этапа 1.5)

1. Контейнер healthy: `docker ps --filter name=1c-buddy`.
2. Health: `curl -s http://localhost:6002/health` → `{"status":"ok","version":"1.4.1"}`.
3. MCP-рукопожатие (smoke перед `hermes mcp add`):
   ```bash
   curl -s -X POST http://localhost:6002/mcp -H 'Content-Type: application/json' \
     -H 'Accept: application/json, text/event-stream' \
     -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"0.1"}}}'
   # → serverInfo: {"name":"1C.ai Gateway MCP","version":"1.4.1"}
   ```
4. Регистрация в Hermes (2 интерактивных промпта — закрываются через stdin):
   ```bash
   printf 'n\nY\n' | hermes mcp add 1c-buddy --url http://localhost:6002/mcp --connect-timeout 60
   # → "✓ Saved '1c-buddy' ... (8/8 tools enabled)"
   ```
   Питфолл: только один `printf 'n\n'` → второй промпт «Enable all 8 tools?» получает EOF → «Cancelled», конфиг НЕ пишется.
5. Инструменты появятся только в НОВОЙ сессии Hermes — владельца просим переоткрыть.

## Управление и наблюдение

- Логи: `bash buddy-start.sh logs` (docker logs -f).
- Список серверов: `hermes mcp list` (3 сервера: 1c-toolkit :6003, mcp-1c stdio, 1c-buddy :6002).
- После переоткрытия — сквозной тест: `ask_1c_ai` (вопрос по платформе) + `search_its` (поиск по ИТС).

## Контекст решения

- Подключаем только MCP; provider `base_url=/v1` НЕ трогаем (замена оркестратора доменной
  моделью; уместно лишь для отдельного профиля «1С-консультант» или SDK-клиентов без MCP).
- Cursor и YaXUnit сняты с плана (решения 2026-08-10); bslc-анализ закрыт — статик-контур = lekot/mcp-1c.