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

## 3. Анализатор bslc (docker, без Java на хосте)

**ghcr.io из сети недоступен** (403 на токене/denied) — официальный образ
`ghcr.io/1c-syntax/bsl-language-server` не тянется. Рабочий путь: локальный образ
из исполняемого jar с Maven Central (**актуальная версия bslc = 1.0.7**):

```bash
# jar (130 МБ):
curl -sL -o tools/downloads/bsl-language-server-1.0.7-exec.jar \
  https://repo1.maven.org/maven2/io/github/1c-syntax/bsl-language-server/1.0.7/bsl-language-server-1.0.7-exec.jar

# Dockerfile — в install/bslc/Dockerfile (база eclipse-temurin:21-jre, hub доступен):
docker build -t bslc:1.0.7 -f install/bslc/Dockerfile "…/tools/downloads"

# проверка (CLI с подкомандами analyze/format/version/lsp/websocket/mcp):
docker run --rm bslc:1.0.7 --help
```

Образ помечен `bslc:1.0.7`; имя используется всеми обёртками (`scripts/bsl-check.sh`).

## 3а. Инфраструктура tools (создаётся install.sh, идемпотентно)

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
(движок, opм-пакеты списком, образ bslc) — установка безопасно повторяем.

## 5. ninja — создание баз (Фаза 2, проверено)

```bash
bash scripts/ninja.sh new demo-bp --ext DataExchange --ext PrintForms
```

Создаёт: `src/cf` (выгрузка типовой, read-only), `src/cfe/<расширение>…`,
`notes/registry.md` (версия типовой — строка TBD), `reports/`,
`.bsl-language-server.json`, `AGENTS.md` (из `templates/AGENTS.md.tpl`),
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

## 6. bsl-check — статический анализ (Фаза 3, проверено)

```bash
bash scripts/bsl-check.sh <база> <расширение> [--reporter json|sarif]
```

Docker-обёртка bslc (образ `bslc:1.0.7`): `--srcDir src/cfe/<расширение>` +
`--srcDir src/cf` (контекст типовой — только если каталог НЕ пуст: bslc падает
на пустом srcDir), `--configuration .bsl-language-server.json`, `--outputDir
/ws/reports`. Отчёт — `reports/<Расширение>_<ts>.json`; резюме — сумма
`fileinfos[].diagnostics` (формат bslc 1.0.7: dict с ключами date/fileinfos/sourceDir).

Проверено: файл с ошибками переноса → 7 диагностик; корректный модуль → 1
(Hint по стилю). Тег образа пинуем версией, не `latest`.

## 7. Список и обзор баз (Фаза 4, проверено)

- `bash scripts/ninja.sh list` — реестр из `tools/projects.json`;
- `bash scripts/ninja.sh scan` — обход `PROJECTS_ROOT`: выявляет базы на диске
  (`<имя>/src/cfe`), в т.ч. НЕ зарегистрированные (с подсказкой команды добавления).

## 8. oscript в USER PATH (Windows, без админ-прав; проверено 2026-08-09)

По умолчанию `install.sh` ничего не меняет за пределами `C:\hermes`: движок живёт
в `C:\hermes\tools\engine\oscript-2.1.0`, а сессии делают
`export PATH="/c/hermes/tools/engine/oscript-2.1.0/bin:$PATH"`. Чтобы oscript/opm
были видны всем клиентам (IDE, prime-agent, любые терминалы) без ручного export,
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

## 9. prime-agent — установка (Фаза B, проверено 2026-08-09)

Нативный CLI-агент Prime Intellect (v0.7.1), ставится в глобальный Node
(у нас — node Hermes, `C:\Users\<user>\AppData\Local\hermes\node`; bin уже в PATH).

Особенности сети: `github.com` не резолвится, поэтому **ассеты релиза качаются
в обход** — через `api.github.com` (он доступен; цепочка
api.github.com → objects.githubusercontent.com не затрагивает github.com):

```bash
cd <downloads>
# 1) id ассетов из релиза
python - <<'PY'
import json,urllib.request
d=json.load(urllib.request.urlopen("https://api.github.com/repos/PrimeIntellect-ai/prime-agent/releases/latest"))
for a in d["assets"]:
    if a["name"].endswith(".tgz"): print(a["name"], a["id"])
PY
# 2) скачать (prime-agent-0.7.1.tgz и core/ai/tui) с Accept: application/octet-stream
curl -sL -H "Accept: application/octet-stream" -o <имя>.tgz \
  https://api.github.com/repos/PrimeIntellect-ai/prime-agent/releases/assets/<id>
# 3) npm: разрешить remote-зависимости (иначе EALLOWREMOTE)
npm config set allow-remote all
# 4) установка: ретраи + verbose обязательны (сеть рвёт ECONNRESET при массовых загрузках),
#    --ignore-scripts допустимо: бандл самодостаточен (chunk-файлы, подпакеты не нужны)
npm i -g --ignore-scripts --loglevel=verbose --fetch-retries=4 \
  "C:\...\prime-agent-0.7.1.tgz" "C:\...\prime-agent-core-0.7.1.tgz" \
  "C:\...\prime-agent-ai-0.7.1.tgz" "C:\...\prime-agent-tui-0.7.1.tgz"
# 5) проверка
prime-agent --version   # → 0.7.1
prime-agent --help
prime-agent model list  # провайдер называется `opencode` (это OpenCode Zen);
                        # модель `deepseek-v4-flash-free` есть в списке
# 6) первый вызов (ключ — из Hermes .env: OPENCODE_ZEN_API_KEY = OPENCODE_API_KEY)
HKEY=$(grep '^OPENCODE_ZEN_API_KEY=' "$HOME/AppData/Local/hermes/.env" | cut -d= -f2-)
OPENCODE_API_KEY="$HKEY" prime-agent --provider opencode --model deepseek-v4-flash-free \
  -p "Ответь одним словом: ок"          # text: «ок» (≈11 c)
OPENCODE_API_KEY="$HKEY" prime-agent --mode json --provider opencode --model deepseek-v4-flash-free \
  "Сколько будет 2+2? Ответь цифрой."   # JSONL: session→agent_start→message_*→agent_end
```

Грабли:
- `npm config set allow-remote true` — **невалидное значение** (нужно `all|none|root`);
- Node 22.8+ обязателен (в cli.js есть version-check);
- **ключ runtime читается только из env** `OPENCODE_API_KEY` (`getEnvApiKey` в коде);
  `~/.prime/agent/auth.json` для этого НЕ используется (он для `/login` в TUI) —
  при запуске всегда `OPENCODE_API_KEY=...` или export в профиль;
- имя провайдера в CLI — `opencode` (в Hermes конфиге он называется `opencode-zen`,
  это один и тот же сервис); модель — `deepseek-v4-flash-free` (как в Hermes);
- модель «как в Hermes»: текущая сессия Hermes = `deepseek-v4-flash-free` (opencode-zen) —
  проверено: `prime-agent model list` содержит эту модель;
- при неверифицированной сети первый запуск агента может потребовать доступа
  к недоступным хостам — проверять по фактическим ошибкам.

### RPC-режим и обёртка one-shot (проверено 2026-08-09)

RPC работает поверх stdin/stdout (JSONL по LF, strip `\r`). Фактический протокол
(сверен по коду бандла, не по докам):
- команда: `{"type":"prompt","id":"1","message":"..."}` — поле **`message`**,
  а не `prompt` (иначе `success:false`, `Cannot read properties of undefined`);
- ответ на команду: `{"id":"1","type":"response","command":"prompt","success":true}`;
- события потока: `agent_start → turn_start → message_start/update/end →
  turn_end → agent_end`; текст ассистента — `message_end` с `role:"assistant"`,
  конкатенация `content[].text`;
- `get_state` даёт модель/сессию (`~/.prime/agent/sessions/*.jsonl`);
- сервер завершается по EOF stdin — держать stdin открытым (sleep-таймаут).

Готовая обёртка one-shot: `C:\hermes\tools\scripts\pi.sh`
(ключ берёт из `.env` Hermes, сама та же модель, таймаут по умолчанию 60 с):

```bash
bash C:/hermes/tools/scripts/pi.sh "Сколько будет 7*6?"   # → 42
bash C:/hermes/tools/scripts/pi.sh "переведи: hello world"  # → «привет мир»
```

### Делегирование задач из Hermes — файловая шина (проверено 2026-08-09)

Развернуть живой RPC-процесс через stdin фонового терминала **нельзя**:
у background-процессов Hermes stdin сразу EOF (cat умирает), FIFO на Windows
ломается (`read ENOTCONN` в Node), PTY не читает ответы. Рабочий канал —
**файловая шина**: `python`-мост держит prime-agent (PIPE), команды — файлами,
ответы — в лог.

```bash
# 1) запуск моста (держит prime-agent --mode rpc в фоне, БЕЗ окон):
#    ⚠ ВАРИАНТ ДЛЯ ОТЛАДКИ: сам pythonw не создаёт консоли, но воркеры prime
#    всё равно открывают окна Windows Terminal поверх (проверено).
#    БОЕВОЙ вариант — служба Windows, см. раздел «Режим фоновой службы» ниже.
#    pythonw.exe = GUI-вариант python: консольное окно не создаётся вообще.
"C:/Users/artkudr/AppData/Local/hermes/hermes-agent/venv/Scripts/pythonw.exe" \
  "C:/hermes/tools/scripts/pi-bridge.py"
#    (обычный python.exe тоже можно, но при каждом запуске мелькает окно)
# 2) делегирование: пишем команду файлом
echo '{"type":"prompt","id":"p1","message":"Текст задачи"}' \
  > "C:/hermes/tools/run/pi-cmd/002-task.json"
# 3) ответ — в логе (JSONL; финал: agent_end → content[].text):
tail -c 2000 "C:/hermes/tools/run/pi-out.log"
```

- каталоги: команды `C:/hermes/tools/run/pi-cmd/*.json` → после обработки
  переезжают в `pi-cmd/.done/`; ответы и события — `pi-out.log` (append);
- команды: `{"type":"prompt","id":N,"message":"..."}` — и любой RPC-набор
  (get_state, steer, abort и т.д.);
- **шim `prime-agent` Popen не находит** (нет .exe) — мост запускает
  `node <node_modules>/prime-agent/dist/bundle/cli.js --mode rpc ...`;
- мост запускает node с `CREATE_NO_WINDOW` — иначе Windows рисует окно
  консоли на каждый консольный процесс (node + daemon + worker = 3 мелькания
  на запрос; проверено и устранено 2026-08-09);
- мост тянет `OPENCODE_API_KEY` из `.env` Hermes (`OPENCODE_ZEN_API_KEY`),
  в PATH полагаться не нужно;
- первый prompt разворачивает kernel-venv + Windows-pipe daemon
  (~1 мин bootstrap), затем серия живёт в `~/.prime/agent/sessions/*.jsonl`;
- остановить мост: `taskkill /F /PID <pid>` (или закрыть вкладку процесса).

### Режим фоновой службы (сессия 0 — ноль окон, проверено 2026-08-09)

Даже с pythonw + CREATE_NO_WINDOW Windows Terminal открывает окно на каждую
новую консоль воркера prime (daemon/worker/kernel) — мелькания видны.
Радикальное решение: мост живёт как СЛУЖБА Windows в неинтерактивной
сессии 0 — окнам физически негде появиться (проверено: запрос «Финляндия →
Хельсинки» обработан, все процессы — SessionId 0).

```bash
# 1) один раз: NSSM (обёртка: берёт на себя контракт с SCM, иначе
#    sc create даёт ошибку 1053 «служба не ответила своевременно»)
winget install -e --id NSSM.NSSM

# 2) установка службы — из-под админа (UAC-промпт):
#    scripts/install-service.ps1 создаёт службу pi-bridge (NSSM):
#    pythonw.exe + pi-bridge.py, AppDirectory C:/hermes,
#    AppExit Default Restart (автоперезапуск при падении).
#    Запуск из обычной сессии: UAC-обёртка (см. ниже).

# 3) управление (из обычного терминала не работает — нужен админ):
nssm status pi-bridge    # SERVICE_RUNNING
nssm stop pi-bridge
nssm start pi-bridge
nssm remove pi-bridge confirm
```

Важно (сессия 0 = окружение LocalSystem, а не пользователя):
- node/git/python в PATH службы ОТСУТСТВУЮТ → pi-bridge.py сам добавляет
  каталоги (hermes/node, hermes/git, venv/Scripts) и запускает node по
  абсолютному пути (node_exe). Без этого — FileNotFoundError (WinError 2).
- daemon prime пишет лог в %systemprofile%\.prime (у LocalSystem это
  C:\WINDOWS\system32\config\systemprofile) — не пугаться.
- первый «холодный» старт daemon может не уложиться в 30-секундный таймаут
  клиента (Timed out ... "create") — повторный запрос проходит.

UAC-обёртка из обычной сессии:
```bash
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -Wait   -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',  'C:\hermes\tools\scripts\install-service.ps1'"
```
Протокол установки — C:\hermes\tools\run\svc-install.log.

Автономность (после установки служба живёт сама):
- при включении Windows служба стартует автоматически (start=auto);
- упадёт мост — NSSM перезапустит его (AppExit Default Restart);
- принудительно: `nssm restart|stop pi-bridge` (из админ-консоли;
  status — из любой).
- монополия шины: НЕ запускать второй мост (pythonw вручную), пока служба
  жива, — два процесса будут конкурировать за pi-cmd/pi-out.log.

Перенос на другой ПК (развёртывание из репозитория):
- `scripts/pi-bridge.py`, `scripts/install-service.ps1`, `scripts/pi.sh`
  входят в репозиторий; перед установкой службы заменить в них
  `C:\Users\artkudr` на профиль нового пользователя (node.exe,
  node_modules/prime-agent, .env с ключом) и `C:\hermes\tools` при ином корне.
- после чего два шага: `winget install -e --id NSSM.NSSM` и
  `install-service.ps1` из-под админа (UAC-обёртка выше).

## 10. Публикация на GitHub (Фаза 6 — подготовлено, ждёт сети и «го»)

Сеть владельца на 2026-08-09: `api.github.com` отвечает (200), но `github.com`
по HTTPS/DNS и git-remote **недоступны** → обычный push сейчас невозможен.

Подготовлено:
- аудит содержимого чист (нет персональных путей/секретов; `C:/hermes` — только
  как пример дефолта);
- самодостаточный bundle всей истории: `C:\hermes\1c-hermes-ninja-kit.bundle`
  (24 КБ, 6 коммитов, main, HEAD `b100c3a`); проверен `git bundle verify`.

Когда сеть появится:
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

- `yaxunit` — github.com/opm.one недоступны (см. §2).
- Публикация в GitHub (Фаза 6) — только по отдельному «го».
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
# образ из Docker Hub (впервые — скачается); повторный запуск идемпотентен
docker run -d --name 1c-mcp-toolkit-proxy \
  -p 6003:6003 \
  -e ALLOW_DANGEROUS_WITH_APPROVAL=true \
  -e TIMEOUT=180 \
  --restart unless-stopped \
  roctup/1c-mcp-toolkit-proxy
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
  закрывает контур C через lekot/autumn-mcp, см. план 06).
- Обработка живёт, пока открыта сессия 1С (окно/вход). Закрыл 1С — мост без
  получателя; прокси остаётся healthy, команды истекают по `TIMEOUT`.
- Несколько dev-баз одновременно — разные каналы (`channel=<имя>`), один прокси.
- SQL-инъекций нет, но `execute_query` исполняет произвольные запросы в контексте
  базы — это dev-инструмент; политика доступа — на владельце сессии 1С.