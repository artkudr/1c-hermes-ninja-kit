# Опыт стенда qbikdev → правки кита (итоговая сверка 2026-08-11)

## Стенд

- `C:\hermes\qbik-dev` — целевой стенд верификации: Hermes-проект (id `p_6947e22f`, якорь = корень базы), EDT-выгрузка (`src/cf` — типовая, read-only; `src/cfe/<ИмяРасширения>/` — рабочие расширения).
- Реальные расширения стенда: `src/cfe/Компас_Кьюбик`, `src/cfe/АРМНоменклатураИПроизводство` (кириллические имена — проверено, что работают).
- Принцип: диск — источник истины, сессия — интерфейс к документации; `notes/state.md` — координатор; `tasks/task_N/` — одна папка на задачу; латиница только в служебных именах.

## Что из опыта стенда вошло в кит (хронология коммитов)

| Коммит | Что внесено из опыта qbikdev |
|---|---|
| `fb44099` | Версионизация JAR bslc через `--build-arg`; расширения с кириллицей в `ninja new`; напоминание про Hermes-привязку |
| `60e993f` | bslc вычищен из кита — «БЕЗ НАДОБНОСТИ» (контейнер завис, анализ решён статикой+мостом); архив `C:\hermes\bsl-server-fail` |
| `7105acb`/`81734b4` | Статический контур mcp-1c (lekot) — install-скрипт + INSTALL §13 |
| `894d572` | **Перевод статики на mcp-1c-autumn** (порт lekot на autumn-mcp): `install/install-mcp1c-autumn.sh`, `templates/mcp-server-autumn/`, фикс sql DLL (oscript 2.1 + sql 1.3.2 → копии System.Data.SqlClient.dll/SQLite.Interop.dll в Components/dotnet), кавычки-«ёлочки» в аннотациях `&Инструмент` |
| `4560e6c` | Живой мост 1c-mcp-toolkit :6003 (INSTALL §12) |
| `7517be2` | LLM-ядро 1c-buddy :6002 (install-buddy.sh, INSTALL §14) — только MCP, без /v1 |
| `dad1b6b` | **Итоговая сверка 2026-08-11**: шаблоны баз переведены со старого имени контура (`mcp-1c (lekot)`, `mcp__mcp1c__*`) на `mcp-1c-autumn` / `mcp__mcp_1c_autumn__*` — 4 файла: `templates/AGENTS.md.tpl`, `templates/project/README.md`, `templates/project/notes/state.md`, `templates/project/tasks/task_1/README.md` |

## Как делалась сверка

1. `git status -sb` + `git log --oneline` + `git log origin/main..main` (пусто = всё запушено).
2. `session_search("qbikdev")` → сессии стенда (поиск по «qbik» нашёл: сессии 20260809_190936, 20260809_232105, 20260810_212330, 20260810_224750, 20260811_000459).
3. Свеп старых имён по всему киту: `grep -rn "mcp__mcp1c\|mcp-1c (lekot)\|mcp-1c (лекот)" . --include="*.md" --include="*.tpl" --include="*.sh" | grep -v "/.git/"` — нашёл 4 хвоста в шаблонах.
4. Правка → `dad1b6b` → пуш (github.com разово таймаутил, ретрай прошёл).

## Не сделано (заблокировано гейтом одобрений)

- Публикация репо → public (PATCH api.github.com `{"private": false}`) — промпт одобрения дважды протаймаутил; шаг оставлен пользователю. Аналогично заблокировался запуск bash-верификатора в Temp (в нём `rm -rf`). Read-only верификация (terminal grep / read_file) гейт не триггерит.