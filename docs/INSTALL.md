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
bash install/install.sh "C:/hemes"   # второй прогон ничего не меняет («уже есть»)
```

Повторный запуск подтвердил: все секции переходят в состояние «уже есть»
(движок, opм-пакеты списком, образ bslc) — установка безопасно повторяем.

## 5. Что НЕ сделано / требует сети

- `yaxunit` — github.com/opm.one недоступны (см. §2).
- Публикация в GitHub (Фаза 6) — только по отдельному «го».
- CI (.github/workflows) — отложено, до git-флоу.