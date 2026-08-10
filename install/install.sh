#!/usr/bin/env bash
# ============================================================
# 1c-hermes-ninja-kit — идемпотентная установка окружения 1С
# Запуск:  ./install/install.sh [PROJECTS_ROOT]
# Повторный запуск безопасен: ставит только недостающее.
# Секретов не содержит; токены — из переменных окружения / .env (вне git).
#
# Особенности:
#  - oscript ставится САМОДОСТАТОЧНЫМ zip-дистрибутивом (последняя версия с
#    https://oscript.io/api/archive/latest) в {PROJECTS_ROOT}/tools/engine/ —
#    без UAC, без Program Files, всё в папке проектов;
#  - opm-пакеты ставятся в движок (права не нужны);
#  - анализатор кода: статический контур mcp-1c (LSP-серверы не ставим);
#  - LLM-ядро: 1c-buddy (шлюз к 1С:Напарник) — MCP-only, порт 127.0.0.1:6002.
# ============================================================
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------- конфиг ----------
OSCRIPT_ARCHIVES_URL="${OSCRIPT_ARCHIVES_URL:-https://oscript.io/api/archive/latest}"
PROJECTS_ROOT="${1:-${PROJECTS_ROOT:-}}"

# подтягиваем .env, если есть (в репозитории .env никогда нет)
if [ -f "$KIT_DIR/.env" ]; then
  set -a; . "$KIT_DIR/.env"; set +a
fi

# ---------- утилиты ----------
say()  { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  OK  \033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m WARN \033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m FAIL \033[0m %s\n' "$*"; exit 1; }
has()  { command -v "$1" >/dev/null 2>&1; }

if [ -z "$PROJECTS_ROOT" ]; then
  read -r -p "Корневая папка проектов (например C:/hermes): " PROJECTS_ROOT
fi
PROJECTS_ROOT="${PROJECTS_ROOT%/}"
[ -n "$PROJECTS_ROOT" ] || fail "PROJECTS_ROOT не задан"
say "Корень проектов: $PROJECTS_ROOT"

TOOLS="$PROJECTS_ROOT/tools"
ENGINE_DIR="$TOOLS/engine"

# ---------- 1. Базовые инструменты ----------
say "Проверка базовых инструментов..."
has git  || fail "git не найден (нужен Git for Windows)"
has docker || fail "docker не найден (нужен Docker Desktop)"
has unzip || warn "unzip не найден — понадобится для распаковки движка"
docker info >/dev/null 2>&1 || fail "docker daemon не запущен"
ok "git = $(git --version | cut -d' ' -f3), docker = $(docker --version | cut -d' ' -f3 | cut -d, -f1)"

# ---------- 2. Инфраструктура tools ----------
say "Создание инфраструктуры: $TOOLS"
mkdir -p "$TOOLS"/{cfg,context,repos,scripts,reports,downloads,engine}
if [ ! -f "$TOOLS/.env" ]; then
  cp "$KIT_DIR/.env.example" "$TOOLS/.env"
  printf '\n# автоматически внесено install.sh\nPROJECTS_ROOT=%s\n' "$PROJECTS_ROOT" >> "$TOOLS/.env"
  warn "создан $TOOLS/.env — заполните ONEC_AI_TOKEN (код 1С:Напарник: https://code.1c.ai)"
else
  ok "$TOOLS/.env уже есть"
fi
if [ ! -f "$TOOLS/projects.json" ]; then
  printf '{"projects":{}}\n' > "$TOOLS/projects.json"
  ok "создан $TOOLS/projects.json (реестр баз)"
fi

# ---------- 3. oscript (последняя версия, zip, без UAC) ----------
OSCRIPT_EXE=""
if compgen -G "$ENGINE_DIR"/oscript-*/bin/oscript.exe >/dev/null 2>&1; then
  OSCRIPT_EXE="$(compgen -G "$ENGINE_DIR"/oscript-*/bin/oscript.exe | head -1)"
  ok "oscript уже в tools: $OSCRIPT_EXE"
else
  say "Скачиваю реестр дистрибутивов oscript ($OSCRIPT_ARCHIVES_URL)..."
  WIN_ZIP="$(curl -sL --max-time 60 "$OSCRIPT_ARCHIVES_URL" | grep -oE '"link":"[^"]*win-x64[^"]*"' | head -1 | cut -d'"' -f4)"
  [ -n "$WIN_ZIP" ] || fail "не удалось определить ссылку на win-x64 zip oscript"
  OSCRIPT_FN="$(basename "$WIN_ZIP")"
  VER="$(printf '%s' "$OSCRIPT_FN" | sed -E 's/^OneScript-([0-9.]+)-win-x64\.zip$/\1/')"
  say "Актуальная версия oscript: $VER — скачиваю $OSCRIPT_FN..."
  curl -sL --max-time 600 -o "$TOOLS/downloads/$OSCRIPT_FN" "https://oscript.io$WIN_ZIP"
  mkdir -p "$ENGINE_DIR/oscript-$VER"
  unzip -q -o "$TOOLS/downloads/$OSCRIPT_FN" -d "$ENGINE_DIR/oscript-$VER"
  OSCRIPT_EXE="$ENGINE_DIR/oscript-$VER/bin/oscript.exe"
  [ -f "$OSCRIPT_EXE" ] || fail "oscript.exe не появился после распаковки"
  ok "oscript установлен: $($OSCRIPT_EXE -version | head -1)"
fi
# пути в POSIX-форме: bash корректно транслирует их cmd-процессам (opm.bat),
# а C:/…-форму cmd.exe внутри батника видеть отказывается
case "$OSCRIPT_EXE" in
  [A-Za-z]:/*) OSCRIPT_EXE="$(cygpath -u "$OSCRIPT_EXE" 2>/dev/null || echo "$OSCRIPT_EXE")" ;;
esac
OSCRIPT_BIN_DIR="$(dirname "$OSCRIPT_EXE")"
case ":$PATH:" in *":$OSCRIPT_BIN_DIR:"*) ;; *) export PATH="$OSCRIPT_BIN_DIR:$PATH" ;; esac

OPM_EXE="${OSCRIPT_EXE%/oscript.exe}/opm.bat"
[ -f "$OPM_EXE" ] || OPM_EXE="$(command -v opm.bat || true)"
if [ -n "$OPM_EXE" ] && [ -f "$OPM_EXE" ]; then
  ok "opm: $("$OPM_EXE" version 2>&1 | head -1)"
else
  warn "opm не найден (должен идти с oscript) — opm-пакеты пропущу"
  OPM_EXE=""
fi

# ---------- 4. opm-пакеты ----------
if [ -n "$OPM_EXE" ]; then
  say "Установка opm-пакетов (sql, autumn, autumn-mcp)..."
  for pkg in sql autumn autumn-mcp; do
    if "$OPM_EXE" list 2>/dev/null | grep -qi "^${pkg}[[:space:]]"; then
      ok "opm: $pkg уже установлен"
    else
      "$OPM_EXE" install "$pkg" 2>&1 | tail -1 | sed 's/^/         /' && ok "opm: $pkg установлен" \
        || warn "opm: $pkg не установился"
    fi
  done
  # yaxunit (тесты BSL) — СНЯТ с базового набора 2026-08-10 (решение владельца);
  # при необходимости вернуть: opm install https://github.com/xDrivenDevelopment/yaxunit
fi

# ---------- 5. Статический контур mcp-1c-autumn (порт lekot на autumn-mcp) ----------
if command -v hermes >/dev/null 2>&1; then
  say "Статический контур mcp-1c-autumn..."
  bash "$KIT_DIR/install/install-mcp1c-autumn.sh" "$PROJECTS_ROOT" || warn "mcp-1c-autumn: установка прервана (см. лог)"
else
  warn "hermes CLI не найден — статический контур mcp-1c-autumn пропущен; после установки Hermes: bash install/install-mcp1c-autumn.sh \"$PROJECTS_ROOT\""
fi

# ---------- 6. LLM-ядро: 1c-buddy (1С:Напарник) ----------
if command -v hermes >/dev/null 2>&1; then
  say "LLM-ядро 1c-buddy (1С:Напарник)..."
  bash "$KIT_DIR/install/install-buddy.sh" "$PROJECTS_ROOT" || warn "1c-buddy: установка прервана (см. лог — обычно не заполнен ONEC_AI_TOKEN в $TOOLS/.env)"
else
  warn "hermes CLI не найден — 1c-buddy пропущен; после установки Hermes: bash install/install-buddy.sh \"$PROJECTS_ROOT\""
fi

# ---------- итог ----------
say "Готово. Проверка:"
ok "PROJECTS_ROOT = $PROJECTS_ROOT"
[ -f "$OSCRIPT_EXE" ] && ok "oscript = $("$OSCRIPT_EXE" -version 2>&1 | head -1)"
[ -n "$OPM_EXE" ] && [ -f "$OPM_EXE" ] && ok "opm = $("$OPM_EXE" version 2>&1 | head -1)"
echo "Следующий шаг: scripts/ninja.sh new <имя-базы>  (создание проекта по конвенции)"