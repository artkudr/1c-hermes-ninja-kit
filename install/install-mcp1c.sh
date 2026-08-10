#!/usr/bin/env bash
# ============================================================
# 1c-hermes-ninja-kit — статический контур "mcp-1c" (lekot/mcp-1c)
# Ставит oscript-сервер статического контура 1С:
#   bsl_search, xml_search, config_list, read_module, syntax_help_search
# (поиск по выгрузке + справка синтакс-помощника из SQLite, БЕЗ живой сессии 1С).
# Запуск: ./install/install-mcp1c.sh [PROJECTS_ROOT] [--force]
#   --force — переустановить (заново скачать/распаковать + перерегистрировать).
# Повторный запуск безопасен: переходит в состояние «уже есть».
# Секретов не содержит.
#
# Проверено исполнением 2026-08-10 (Windows 10, git-bash, Hermes desktop).
# ============================================================
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------- конфиг ----------
MCP_REPO_URL="${MCP_REPO_URL:-https://github.com/lekot/mcp-1c}"
MCP_REPO_REF="${MCP_REPO_REF:-main}"          # ветка репо с актуальным build
PROJECTS_ROOT="${1:-${PROJECTS_ROOT:-}}"
FORCE=0
[ "${2:-}" = "--force" ] && FORCE=1

# подтягиваем .env, если есть (в репозитории .env никогда нет)
if [ -f "$KIT_DIR/.env" ]; then
  set -a; . "$KIT_DIR/.env"; set +a
fi

# ---------- утилиты ----------
say()  { printf '\033[1;34m[mcp-1c]\033[0m %s\n' "$*"; }
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
MCP_DIR="$TOOLS/mcp-1c"
MCP_ZIP="$TOOLS/downloads/mcp-1c-$MCP_REPO_REF.zip"
MCP_MAIN_OS="$MCP_DIR/main.os"
MCP_HELP_DB="$MCP_DIR/src/data/shcntx_help.db"

# ---------- 0. базовые инструменты ----------
has git   || fail "git не найден"
has python || fail "python не найден (нужен для распаковки архива)"
has oscript || {
  # подхватываем движок из tools/engine, как install.sh
  if compgen -G "$TOOLS/engine"/oscript-*/bin/oscript.exe >/dev/null 2>&1; then
    OB="$(compgen -G "$TOOLS/engine"/oscript-*/bin/oscript.exe | head -1)"
    OB="$(cygpath -u "$OB" 2>/dev/null || echo "$OB")"
    export PATH="$(dirname "$OB"):$PATH"
    say "oscript подхвачен из tools/engine: $(dirname "$OB")"
  else
    fail "oscript не найден в PATH и в $TOOLS/engine — сначала install.sh"
  fi
}
has oscript || fail "oscript не найден — сначала install.sh"
ok "oscript = $(oscript -version 2>&1 | head -1)"

# ---------- 1. скачивание и распаковка (идемпотентно, --force переустанавливает) ----------
needs_install=0
[ -f "$MCP_MAIN_OS" ] || needs_install=1
[ -f "$MCP_HELP_DB" ] || needs_install=1
if [ "$FORCE" = "1" ]; then
  say "--force: переустановка $MCP_DIR"
  rm -rf "$MCP_DIR"
  needs_install=1
fi

if [ "$needs_install" = "0" ]; then
  ok "сервер mcp-1c уже развёрнут: $MCP_DIR"
else
  say "Скачиваю архив $MCP_REPO_URL (ref=$MCP_REPO_REF)..."
  mkdir -p "$TOOLS"/downloads
  curl -sSL --max-time 300 -o "$MCP_ZIP" "$MCP_REPO_URL/archive/refs/heads/$MCP_REPO_REF.zip"
  [ -s "$MCP_ZIP" ] || fail "архив не скачался (пустой файл)"
  say "Распаковываю в $MCP_DIR..."
  rm -rf "$MCP_DIR"
  TMP="$MCP_DIR.tmp"
  rm -rf "$TMP"; mkdir -p "$TMP"
  # python zipfile надёжнее unzip (структура: mcp-1c-main/...)
  python - "$MCP_ZIP" "$TMP" <<'PY'
import os, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
prefix = z.namelist()[0].split('/')[0]
for n in z.namelist():
    if n == prefix + '/': continue
    dst = os.path.join(sys.argv[2], n[len(prefix)+1:])
    if n.endswith('/'):
        os.makedirs(dst, exist_ok=True)
        continue
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with z.open(n) as src, open(dst, 'wb') as out:
        out.write(src.read())
PY
  mv "$TMP" "$MCP_DIR"
  [ -f "$MCP_MAIN_OS" ] || fail "main.os не найден после распаковки"
  [ -f "$MCP_HELP_DB" ] || fail "shcntx_help.db не найден ($MCP_HELP_DB)"
  ok "сервер распакован: $MCP_DIR"
fi

# ---------- 2. регистрация в Hermes (mcp add + env-фикс) ----------
has hermes || warn "hermes CLI не найден — сервер развёрнут, но в Hermes не зарегистрирован (запусти install-mcp1c.sh после установки Hermes)"
if has hermes; then
  MCP_WIN="$(cygpath -w "$MCP_DIR" 2>/dev/null || echo "$MCP_DIR")"
  ARGS_WIN="$MCP_WIN\\main.os"
  HELP_DB_WIN="$MCP_WIN\\src\\data\\shcntx_help.db"

  if hermes mcp list 2>/dev/null | grep -q "mcp-1c"; then
    ok "Hermes MCP 'mcp-1c' уже зарегистрирован"
  else
    say "Регистрирую MCP-сервер 'mcp-1c' в Hermes..."
    # ВАЖНО: --args ДОЛЖЕН быть последним (всё после него — аргументы сервера);
    # интерактивный промпт подтверждения закрываем подачей 'Y'
    printf 'Y\n' | hermes mcp add mcp-1c --command oscript --args "$ARGS_WIN"
    hermes mcp list 2>/dev/null | grep -q "mcp-1c" || fail "сервер не зарегистрировался"
    ok "зарегистрирован 'mcp-1c' (command=oscript, args=[$ARGS_WIN])"
  fi

  # env-фикс cwd-бага syntax_help_search (см. INSTALL.md §13, DECISIONS.md):
  # main.os резолвит путь к БД от cwd запуска; Hermes стартует сервер из
  # домашней папки → без env справка падает «База справки не найдена».
  CUR_ENV="$(hermes config get "mcp_servers.mcp-1c.env.SHCNTX_HELP_DB" 2>/dev/null | tail -1)"
  if [ "$CUR_ENV" = "$HELP_DB_WIN" ]; then
    ok "env SHCNTX_HELP_DB уже задан: $HELP_DB_WIN"
  else
    hermes config set "mcp_servers.mcp-1c.env.SHCNTX_HELP_DB" "$HELP_DB_WIN" >/dev/null
    ok "env SHCNTX_HELP_DB => $HELP_DB_WIN"
  fi

  say "Проверка соединения (hermes mcp test)..."
  if hermes mcp test mcp-1c 2>&1 | grep -q "Tools discovered"; then
    ok "mcp-1c: соединение и инструменты в порядке"
  else
    warn "hermes mcp test не показал 'Tools discovered' — проверь вручную: hermes mcp test mcp-1c"
  fi
  # побочный файл cwd-бага: main.os пишет shcntx_help_db_path.txt в cwd hermes-процесса
  rm -f "$(pwd)/shcntx_help_db_path.txt" 2>/dev/null || true
fi

# ---------- итог ----------
if has hermes; then
  echo
  say "Готово. Инструменты (5): bsl_search, xml_search, config_list, read_module, syntax_help_search."
  printf '\033[1;33m >>> Переоткрой Hermes (новая сессия), чтобы инструменты mcp__mcp1c__* появились. <<<\033[0m\n'
else
  echo
  warn "Сервер развёрнут, но hermes CLI недоступен — регистрация в Hermes не выполнялась."
fi