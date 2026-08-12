# Установка (INSTALL.md)

> Каждый пункт этого руководства ПРОВЕРЕН реальным исполнением на машине владельца
> (2026-08-09, Windows 10, git-bash). Не добавляйте непроверенные шаги.

## 0. Исходные требования

| Компонент | Статус у владельца | Проверка |
|---|---|---|
| Git for Windows | 2.54.0 | `git --version` |
| Docker Desktop | 29.6.2 (daemon работает) | `docker --version` + `docker info` |
| Python | есть (для скриптов тулкита) | `python --version` |
| ОС | Windows 10, git bash (MSYS) | — |

## 1. Установка oscript (последняя стабильная)

**Решение:** winget-пакет `OneScript.OneScript` — УСТАРЕВШИЙ (на 2026-08: 1.9.4);
последний стабильный релиз — **2.1.0** (oscript.io, 25.06.2026). Ставим
самодостаточный zip (без установки, без UAC, всё в `tools/`):

```bash
# 1) узнать актуальный дистрибутив (API сайта oscript.io):
curl -sL https://oscript.io/api/archive/latest | grep win-x64
#   → OneScript-2.1.0-win-x64.zip, /downloads/latest/OneScript-2.1.0-win-x64.zip

# 2) скачать и распаковать в <корень>/tools/engine/oscript-<ver>:
curl -sL -o tools/downloads/OneScript-2.1.0-win-x64.zip \
     https://oscript.io/downloads/latest/OneScript-2.1.0-win-x64.zip
mkdir -p tools/engine/oscript-2.1.0 && unzip -q ... -d tools/engine/oscript-2.1.0

# 3) движок в PATH (POSIX-форма! см. замечание ниже):
export PATH="/c/…/tools/engine/oscript-2.1.0/bin:$PATH"
oscript -version   # → 2.1.0
opm.bat version    # → 1.4.1 (opm входит в поставку)
```

**ВАЖНО (грабли):** `opm.bat` внутри себя вызывает `oscript` — поэтому каталог
`bin` движка должен быть в PATH **в POSIX-форме** (`/c/…/bin`). Если добавить
Windows-путь (`C:/…/bin`), cmd-процесс opm не находит oscript
(«"oscript" не является внутренней или внешней командой»). bash корректно
транслирует POSIX-пути в cmd, поэтому в скриптах используем `/c/…`.

## 2. opm-пакеты (экосистемные библиотеки)

```bash
export PATH="/c/…/tools/engine/oscript-2.1.0/bin:$PATH"
opm.bat install sql          # ✓ установлен
opm.bat install autumn       # ✓ (+ зависимость decorator)
opm.bat install autumn-mcp   # ✓ (+ зависимость fs)
opm.bat install yaxunit      # ⚠ в реестре не найден/сеть не даёт (см. ниже)
```

**yaxunit (тесты):** на дату проверки реестр opm.one и `github.com` из сети
владельца недоступны (HTTP 000 / git ls-remote пуст). Установить позже:
`opm.bat install https://github.com/xDrivenDevelopment/yaxunit`
(для Фазы 2/3 «YAXUNIT-тесты» не требуется).

## 3. Инфраструктура tools (создаётся install.sh, идемпотентно)

```
<корень>/tools/
  cfg/ context/ repos/ scripts/ reports/ downloads/ engine/
  .env           # из .env.example; ОБЯЗАТЕЛЬНО: ONEC_AI_TOKEN (https://code.1c.ai)
  projects.json  # {"projects":{}} — реестр баз
```

## 4. Полный запуск и идемпотентность

```bash
bash install/install.sh "C:/hermes"   # второй прогон ничего не меняет («уже есть»)
```

Повторный запуск подтвердил: все секции переходят в состояние «уже есть»
(движок, opм-пакеты списком) — установка безопасно повторяем.

## 5. ninja — создание баз (Фаза 2, проверено)

```bash
bash scripts/ninja.sh new demo-bp --ext DataExchange --ext PrintForms
```

Создаёт: `src/cf` (выгрузка типовой, read-only), `src/cfe/<расширение>…`,
`notes/registry.md` (версия типовой — строка TBD), `reports/`,
`AGENTS.md` (из `templates/AGENTS.md.tpl`),
`.gitignore` базы, `git init -b main`. Регистрирует базу в `tools/projects.json`.

**ОБЯЗАТЕЛЬНО после создания базы:** создать desktop-проект Hermes и привязать
его к папке базы (`project_create {name, path}`), проверить `pwd` = корень
базы. Без этой привязки база не работает как проект Hermes (переключение между
базами — `project_switch`, не `cd`; правила — `docs/CONVENTIONS.md`).

Грабли:
- имя БАЗЫ валидируется (только латиница/цифры/`-_`); имена РАСШИРЕНИЙ — как
  в 1С (кириллица допустима), запрещены только `/` и `\`;
- повторное создание при существующем каталоге — ошибка;
- json-реестр ведёт `scripts/ninja_json.py` (python на Windows не понимает
  MSYS-пути — все пути передаются в Windows-форме через `cygpath -w`).

## 6. Список и обзор баз (Фаза 4, проверено)

- `bash scripts/ninja.sh list` — реестр из `tools/projects.json`;
- `bash scripts/ninja.sh scan` — обход `PROJECTS_ROOT`: выявляет базы на диске
  (`<имя>/src/cfe`), в т.ч. НЕ зарегистрированные (с подсказкой команды добавления).

## 8. oscript в USER PATH (Windows, без админ-прав; проверено 2026-08-09)

По умолчанию `install.sh` ничего не меняет за пределами `C:\hermes`: движок живёт
в `C:\hermes\tools\engine\oscript-2.1.0`, а сессии делают
`export PATH="/c/hermes/tools/engine/oscript-2.1.0/bin:$PATH"`. Чтобы oscript/opm
были видны всем клиентам (IDE, любые терминалы) без ручного export,
допишите `bin` в **USER PATH** (реестр HKCU — админ-права не нужны):

```bash
CUR="$(reg query 'HKCU\Environment' /v Path 2>/dev/null | sed -n 's/^[[:space:]]*Path[[:space:]]*REG_[A-Z_]*[[:space:]]*//p')"
NEW="${CUR:+$CUR;}C:\hermes\tools\engine\oscript-2.1.0\bin"
reg add 'HKCU\Environment' /v Path /t REG_EXPAND_SZ /d "$NEW" /f
```

Проверка (имитация свежей сессии — Machine+User PATH):
```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
oscript -version        # → 2.1.0
cmd /c opm.bat version  # → 1.4.1
```

Грабли:
- **НЕ используйте `setx` или `[Environment]::SetEnvironmentVariable`** — они
  пишут `REG_SZ` и ломают разворачивание `%SystemRoot%` в существующем Path;
  нужен `reg add /t REG_EXPAND_SZ`;
- команда идемпотентна (проверяет наличие oscript в значении);
- уже открытые окружения (в т.ч. Hermes) подхватят PATH после перезапуска сессии —
  broadcast WM_SETTINGCHANGE отправляется, но Explorer перечитывает не всегда.

## 9. prime-agent — ОТЛОЖЕНО / архив (см. C:\\hermes\\prime-fail)

> **ОТЛОЖЕНО 2026-08-12.** Prime Agent (prime-agent, v0.7.1) выписан из
> проекта как сырой и дублирующий контур. Подробности, скрипты и
> конфиги — в `C:\\hermes\\prime-fail\README.md`. В рабочем контуре
> остаются: `mcp-1c-autumn` (статический), `1c-mcp-toolkit :6003`
> (живой мост), `1c-buddy :6002` (LLM-ядро).

## 10. Публикация на GitHub (Фаза 6 — ВЫПОЛНЕНО 2026-08-10)

Репозиторий опубликован: **`github.com/artkudr/1c-hermes-ninja-kit`** (private, ветка
`main`). Сеть, где github.com ранее был недоступен (запись от 2026-08-09 ниже),
на 2026-08-10 открылась — `git ls-remote https://github.com/...` проходит.

Как публиковали (на будущее — для нового репо):
1. Создать private-репо через API (gh CLI не обязателен, токен из
   `~/.git-credentials`): `POST /user/repos` `{"name": ..., "private": true}`.
2. `git remote add origin https://github.com/<user>/<repo>.git`
3. `git push -u origin main`

Запасной вариант (использовался, пока сеть была закрыта): самодостаточный bundle
всей истории `C:\hermes\1c-hermes-ninja-kit.bundle` — восстановление см. ниже.
После публикации bundle можно не обновлять (репо живёт на GitHub).
```bash
# восстановление из bundle (на любой машине с git)
git clone C:/hermes/1c-hermes-ninja-kit.bundle 1c-hermes-ninja-kit
cd 1c-hermes-ninja-kit && git remote remove origin   # bundle-клон создаёт origin

# публикация (private)
git remote add origin git@github.com:<owner>/1c-hermes-ninja-kit.git
git push -u origin main
# или через gh CLI (когда установлен и авторизован):
#   winget install GitHub.cli && gh auth login
#   gh repo create 1c-hermes-ninja-kit --private --source . --push
```

## 11. Что НЕ сделано / требует сети

- `yaxunit` (тесты BSL) — **снят с плана 2026-08-10** (опция; при
  необходимости: `opm install https://github.com/xDrivenDevelopment/yaxunit`).
- CI (.github/workflows) — отложено, до git-флоу.

## 12. Живой мост в 1С: 1c-mcp-toolkit на :6003 (проверено 2026-08-10)

Мост = Docker-прокси + обработка `MCP_Toolkit.epf` внутри живой dev-сессии 1С.
Агент (Hermes MCP / curl REST) ходит в прокси на `:6003`, прокси передаёт команды
в сессию 1С long-polling-ом (`/1c/poll?channel=<канал>`), обработка исполняет их
в контексте базы. Даёт: `execute_query`, `get_metadata`, `get_event_log`,
`get_access_rights`, `get_object_by_link`, `find_references_to_object`,
`get_bsl_syntax_help`, `execute_code` (с подтверждением), скриншот окна,
управление сессией. Read-only операций достаточно для контуров A/B/C: справка BSL
приходит прямо из живой базы (`get_bsl_syntax_help`) — внешний SQL-контур (lekot)
можно не поднимать.

### 12.1 Прокси (Docker)

```bash
# Форк исходников (наш, правка бинда 127.0.0.1 зашита в docker-compose.yml):
#   https://github.com/artkudr/1c-mcp-toolkit  (upstream: ROCTUP/1c-mcp-toolkit)
# Локальная сборка из форка — Docker Hub не нужен (compose build: .).
git clone https://github.com/artkudr/1c-mcp-toolkit.git "$PROJECTS_ROOT/tools/run/1c-mcp-toolkit"
cd "$PROJECTS_ROOT/tools/run/1c-mcp-toolkit"
docker compose up -d --build
# контейнер 1c-mcp-toolkit-proxy поднимается на 127.0.0.1:6003 (restart: unless-stopped)
```

Полезные переменные (дефолты из образа):
- `PORT=6003`; `TIMEOUT=180` (сек, время жизни команды в очереди);
- `RESPONSE_FORMAT=toon` (компактный; `json` — читаемый);
- `ANONYMIZATION_ENABLED=false` (маскирование перс. данных в ответах);
- `ALLOW_DANGEROUS_WITH_APPROVAL=true` — `execute_code`/`close_1c_session`
  требуют подтверждающего запроса (без этого флага опасные инструменты
  отключены вовсе — для read-only контуров так даже правильнее).

Проверка: `curl http://localhost:6003/health` → `{status: healthy, ...}`.

### 12.2 Сессия 1С с обработкой (вход — вручную, пароль не храним)

EPF отдаёт и обычный `MCP_Toolkit.epf`, и `MCP_Toolkit_x86.epf` (для тонкого
клиента x86 — Native-компоненты справки/скриншота собираются под разрядность).
На x86-платформе (как у нас: `C:\Program Files (x86)\1cv8\...`) брать **x86**-версию.

```bash
"/c/Program Files (x86)/1cv8/8.3.27.2130/bin/1cv8.exe" ENTERPRISE \
  /F "C:\1C\bases\qbik-dev" \
  /Execute "C:\hermes\tools\run\1c-mcp-toolkit\build\MCP_Toolkit_x86.epf" \
  /C "startup;mode=proxy;url=http://localhost:6003;channel=default"
```

Порядок (проверено): запуск → диалог входа (пользователь вводит пароль сам;
если `Start-Process` — окно 1С открывается, это ожидаемо) → вопрос об открытии
внешней обработки → «Да» → обработка сама подключается к прокси
(`/C startup;mode=proxy`).

Проверка связки: `curl http://localhost:6003/health` →
`active_sessions_count ≥ 1`; в логах контейнера —
`GET /1c/poll?channel=default HTTP/1.1" 204`.

### 12.3 Подключение к Hermes (MCP)

```bash
hermes mcp add 1c-toolkit --url http://127.0.0.1:6003/mcp --connect-timeout 20
# интерактив: «Does this server require authentication?» → n
#             «Enable all 12 tools?» → y
```
Появляется 12 инструментов `mcp__1ctoolkit__*`; работает только в НОВОЙ сессии.

### 12.4 Проверка через REST (curl)

```bash
J='-H Content-Type:application/json'
# метаданные базы (что есть)
curl -s -X POST http://localhost:6003/api/get_metadata $J -d '{"types":["Справочник"],"limit":5}'
# живые данные
curl -s -X POST http://localhost:6003/api/execute_query $J \
  -d '{"query":"ВЫБРАТЬ ПЕРВЫЕ 3 Ссылка, Код, Наименование ИЗ Справочник.Контрагенты"}'
# журнал регистрации
curl -s -X POST http://localhost:6003/api/get_event_log $J -d '{"limit":2}'
# справка BSL (keywords — массив)
curl -s -X POST http://localhost:6003/api/get_bsl_syntax_help $J \
  -d '{"keywords":["Запрос","Выполнить"],"limit":2}'
```

### 12.5 Готовые скиллы для агентов

Из репозитория тулкита скопированы в навыки Hermes (категория `1c`):
- `calling-1c-rest-api-via-curl` — вызовы `/api/*` через curl (12 эндпоинтов,
  фичи: каналы, таймауты, форматы);
- `composing-1c-queries` — как писать корректные запросы для `execute_query`
  (функции/выражения, подводные камни).

### 12.6 Известные ограничения

- `get_bsl_syntax_help` требует Native-компоненту `SyntaxHelpReader` из EPF:
  на x86-клиенте — только `MCP_Toolkit_x86.epf`. Если компонента не поднялась,
  инструмент отвечает `SyntaxHelpReader не загружен` (не критично: справку
  закрывает статический контур lekot/mcp-1c, уже развёрнут — §13).
- Обработка живёт, пока открыта сессия 1С (окно/вход). Закрыл 1С — мост без
  получателя; прокси остаётся healthy, команды истекают по `TIMEOUT`.
- Несколько dev-баз одновременно — разные каналы (`channel=<имя>`), один прокси.
- SQL-инъекций нет, но `execute_query` исполняет произвольные запросы в контексте
  базы — это dev-инструмент; политика доступа — на владельце сессии 1С.

## 13. Статический контур: mcp-1c-autumn (порт lekot на autumn-mcp, проверено 2026-08-11)

Разворачивается установщиком `install/install-mcp1c-autumn.sh` (вызывается и из
`install.sh`, шаг 6). Сервер: `oscript tools/mcp-1c-autumn/main.os` (stdio MCP,
фреймворк autumn-mcp): `main.os` + `Классы/` (5 инструментов с аннотациями) +
`shcntx_help.db` (6 МБ, SQLite-справка синтакс-помощника — экспорт из 1С НЕ нужен).
Это порт оригинального lekot/mcp-1c: рукописный JSON-RPC заменён библиотечным
каркасом, контракты инструментов без изменений (origin и GPL-3.0 — в README
сервера). Контур работает БЕЗ живой сессии 1С, Docker и сети; инструменты Hermes
`mcp__mcp_1c_autumn__*` (5 шт.): `bsl_search`, `xml_search`, `config_list`,
`read_module`, `syntax_help_search`.

### 13.1 Установка (идемпотентная, повторный запуск безопасен)

```bash
bash install/install-mcp1c-autumn.sh "C:/hermes"          # копия шаблона + регистрация
bash install/install-mcp1c-autumn.sh "C:/hermes" --force  # переустановка с нуля
hermes mcp test mcp-1c-autumn        # ✓ Connected (≈1 с), ✓ Tools discovered: 5
```

Скрипт делает: (1) копирует шаблон `templates/mcp-server-autumn/` в
`tools/mcp-1c-autumn` (`main.os`, `Классы/`, `src/data/shcntx_help.db`, `rules/`,
`port_test.py`, `mcp.json`); (2) применяет фикс sql-пакета (копии DLL, грабли №6);
(3) `hermes mcp add mcp-1c-autumn --command oscript --env SHCNTX_HELP_DB=<путь к БД>
--args <tools>\mcp-1c-autumn\main.os` (промпт закрывается `printf 'Y\n' |`).

### 13.2 ГРАБЛИ (все проверены исполнением)

1. **cwd-баг `syntax_help_search`** — резолвинг БД: `dbPath` → env
   `SHCNTX_HELP_DB` → файл `shcntx_help_db_path.txt` → `src/data/shcntx_help.db`
   от cwd. Hermes стартует stdio-серверы из домашней папки → без фикса справка
   падает («База справки не найдена»). **Фикс: env `SHCNTX_HELP_DB`** прописывает
   установщик. Без перезапуска Hermes env не подхватится (инструменты — из новой
   сессии).
2. **`hermes mcp add` — `--args` ДОЛЖЕН быть последним**: всё, что после
   `--args ...`, попадает в аргументы сервера (таймауты сломают старт). Таймауты
   дописываем отдельно: `hermes config set mcp_servers.mcp-1c-autumn.connect_timeout 60`.
3. **`hermes mcp add` интерактивен**: промпт «Enable all 5 tools?» закрывается
   подачей `printf 'Y\n' |`.
4. **Инструменты появляются только в новой сессии** Hermes — после регистрации
   переоткрыть приложение.
5. **Кавычки в аннотациях `&Инструмент`/`&ПараметрИнструмента` запрещены**:
   декоратор autumn-mcp пере-сериализует строковые аргументы и не экранирует `"` —
   компиляция падает («Ожидается символ: ClosePar»). В описаниях — кавычки-«ёлочки».
   Внутри строк OneScript обратный слэш перед кавычкой не работает (строка
      закрывается) — только удвоение кавычки.
6. **Фикс sql-пакета (обязательно)**: oscript 2.1.0 + `sql` 1.3.2 падает
   «System.Data.SqlClient 4.6.1.6 not found» — NuGet-раскладка кладёт сборки в
   `runtimes/...`, а не в `Components/dotnet`. Лечится копированием двух DLL из
   `<engine>\lib\sql\Components\dotnet\runtimes\` (`win\lib\netcoreapp2.1\System.Data.SqlClient.dll`
   и `win-x64\native\SQLite.Interop.dll`) на уровень `Components\dotnet\`. Применяет
   установщик; после фикса — перезапуск Hermes.

### 13.3 Проверка (живые вызовы через SDK)

```bash
cd C:\hermes\tools\mcp-1c-autumn && python port_test.py   # все 5 инструментов, EXIT=0
```

`port_test.py` — smoke-прогон через официальный MCP SDK (bsl_search, xml_search,
config_list, read_module, syntax_help_search + негативные сценарии). Исторический
A/B со старым сервером — `compare_test.py`; прежний lekot-сервер отключён, исходники
и история — `tools/archive/mcp-1c-lekot`.

В Hermes-сессии после переоткрытия: `mcp__mcp_1c_autumn__bsl_search` ищет по
`src/cfe/<Расширение>` (кириллические пути работают), `read_module` читает
модуль целиком по пути (`C:\...\Ext\Form\Module.bsl`), `config_list` обходит
структуру расширения, `xml_search` находит объекты в XML-метаданных.

## 14. LLM-ядро: 1c-buddy (1С:Напарник) на :6002 (проверено 2026-08-10)

Разворачивается установщиком `install/install-buddy.sh` (вызывается и из
`install.sh`, шаг 6). Поднимает контейнер `roctup/1c-buddy` — HTTP-шлюз к
сервису 1С:Напарник (code.1c.ai): MCP (`POST /mcp`), веб-чат (`/chat`) и
опционально OpenAI-совместимый `/v1`. **Мы используем только MCP** — 8
инструментов Hermes `mcp__1c_buddy__*`; `/v1` не включаем (решение «только
MCP»: мозг Hermes не меняем, см. DECISIONS.md).

Инструменты:

| Инструмент | Что делает |
|---|---|
| `ask_1c_ai` | общий вопрос по платформе и практическим сценариям |
| `explain_1c_syntax` | объяснение объекта/метода/конструкции платформы |
| `check_1c_code` | проверка BSL: синтаксис или code review |
| `modify_1c_code` | правка BSL по явному заданию |
| `search_1c_documentation` | поиск по документации платформы 1С |
| `search_its` | поиск по базе знаний ИТС (embedding) |
| `fetch_its` | чтение документа/раздела ИТС по id (id отдаёт `search_its`) |
| `diff_1c_documentation_versions` | сравнение документации платформы между версиями |

### 14.1 Установка (идемпотентная, повторный запуск безопасен)

```bash
bash install/install-buddy.sh "C:/hermes"        # токен — из tools/.env (ONEC_AI_TOKEN)
bash install/install-buddy.sh "C:/hermes" --force  # пересоздать контейнер с нуля
hermes mcp test 1c-buddy        # ✓ Connected, ✓ Tools discovered: 8
```

Требования: Docker Desktop запущен, `hermes` CLI в PATH, в `tools/.env`
заполнен `ONEC_AI_TOKEN` (бесплатно: https://code.1c.ai). Токен также можно
держать отдельным файлом `tools/run/buddy.env` (строка `ONEC_AI_TOKEN=...`) —
скрипт подхватит его с приоритетом.

Скрипт делает: (1) проверяет токен; (2) `docker run -d --name 1c-buddy
--restart unless-stopped -p 127.0.0.1:6002:6002 --env-file <файл токена>
roctup/1c-buddy`; (3) ждёт `/health` и делает MCP-рукопожатие (initialize);
(4) `hermes mcp add 1c-buddy --url http://localhost:6002/mcp`.

### 14.2 ГРАБЛИ (все проверены исполнением)

1. **`--env-file` принимает ТОЛЬКО Windows-путь.** git-bash транслирует
   `C:/…` в `/c/…`, docker.exe падает: `docker: --env-file: open
   /c/hermes/tools/run/buddy.env: The system cannot find the path specified`.
   Лечим `cygpath -w` (установщик делает это сам).
2. **`hermes mcp add` для HTTP-сервера задаёт ДВА промпта**: «Does this server
   require authentication?» → `n` и «Enable all 8 tools?» → `Y`. Закрываем
   `printf 'n\nY\n' |` (одиночный `Y` провалит первый промпт — сервер будет
   помечен как требующий auth).
3. **В `/mcp` и веб-чате аутентификации НЕТ** — порт публикуем только на
   `127.0.0.1` (`-p 127.0.0.1:6002:6002`); дефолтный `-p 6002:6002` открывает
   порт на все интерфейсы. Наружу не выставлять.
4. **ТоС code.1c.ai**: API по пользовательскому соглашению предназначено для
   работы из 1С:EDT; сторонний вызов соглашением не предусмотрен. Напарник
   детектирует такие вызовы: в ответах периодически появляется приписка «API
   предназначено для 1С:EDT» (на работу не влияет), в худшем случае возможна
   блокировка токена/учётки. Использование — на свой страх и риск (согласовано
   с владельцем 2026-08-10).
5. **Инструменты появляются только в новой сессии** Hermes (как и §12.3/§13):
   после регистрации/правки конфига — переоткрыть Hermes.

### 14.3 Проверка (здоровая связка)

```bash
curl http://localhost:6002/health        # {"status":"ok","version":"1.4.1"}
# MCP-рукопожатие:
curl -s -X POST http://localhost:6002/mcp \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"0.1"}}}'
# → result.serverInfo.name = "1C.ai Gateway MCP"
```

В Hermes-сессии после переоткрытия: `mcp__1c_buddy__ask_1c_ai` отвечает по
платформе, `mcp__1c_buddy__search_its` возвращает документы ИТС с id —
дальше `mcp__1c_buddy__fetch_its` читает конкретный документ.
## 15. Скиллы кита: skills.external_dirs (проверено 2026-08-11)

1С-скиллы живут **в ките** (`skills/<категория>/<скилл>/SKILL.md`), а не в
профиле Hermes: одна копия, диск = источник истины, правки — коммитом в кит,
на стенде — `git pull`.

### 15.1 Подключение (делает install.sh, шаг 7)

```bash
hermes config set --force skills.external_dirs "C:/hermes/1c-hermes-ninja-kit/skills"
```

- `external_dirs` — штатный механизм Hermes: внешние каталоги сканируются
  наравне с `~/.hermes/skills/` (локальный всегда первый, внешние — в порядке
  конфига);
- принимает строку или список; пути поддерживают `~` и `${VAR}`;
- внешние скиллы помечаются externally owned — куратор их не трогает
  (не архивирует как простаивающие), но `skill_manage` править может;
- видны в `hermes skills list`, slash-командах, баннере — как обычные скиллы.

### 15.2 Список скиллов

| Категория | Скилл | Назначение |
|---|---|---|
| 1c | 1c-mcp-ai-ecosystem | Каталоги MCP/AI-инструментов 1С (OpenYellow и др.) |
| 1c | 1c-ninja-kit-ops | Сопровождение кита: проверка/коммит/пуш/публикация |
| 1c | calling-1c-rest-api-via-curl | Вызовы REST API 1С через curl |
| 1c | composing-1c-queries | Язык запросов 1С: структура, виртуальные таблицы, оптимизация |
| software-development | 1c-mcp-ai-tooling | Поиск и интеграция MCP/AI-инструментов для 1С |

### 15.3 ГРАБЛИ

1. **`hermes config set skills.external_dirs.0 <путь>` пишет СЛОВАРЬ, а не список**
   (`'0': путь`) — код внешних каталогов такой конфиг не читает. Нужен скаляр
   или список: `hermes config set --force skills.external_dirs "<путь>"`.
2. **`--force` заменяет секцию целиком** — если `external_dirs` уже содержит
   другие каталоги (не кит), их надо дописать в config.yaml вручную после
   установки (список YAML: `external_dirs: [путь1, путь2]`).
3. **Скиллы видны в новой сессии** (как и MCP-инструменты, §12.3/§13):
   после правки конфига — переоткрыть Hermes.
4. **Правки скиллов — через git**: изменили SKILL.md в ките → коммит → пуш →
   `git pull` на стенде. Неправить напрямую в `~/.hermes/skills/` — там
   локальных копий больше нет (удалены при переносе).
