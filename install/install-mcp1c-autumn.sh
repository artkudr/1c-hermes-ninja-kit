#!/usr/bin/env bash
# ============================================================
# 1c-hermes-ninja-kit — статический контур "mcp-1c-autumn"
# Ставит порт lekot/mcp-1c на autumn-mcp из шаблона кита:
#   bsl_search, xml_search, config_list, read_module, syntax_help_search
# (поиск по выгрузке + справка синтакс-помощника из SQLite, БЕЗ живой сессии 1С).
# Запуск: ./install/install-mcp1c-autumn.sh [PROJECTS_ROOT] [--force]
#   --force — переустановить (заново скопировать шаблон + перерегистрировать).
# Повторный запуск безопасен: переходит в состояние «уже есть».
# Origin: производная работа lekot/mcp-1c (GPL-3.0), см. README сервера.
# Секретов не содержит.
#
# Проверено исполнением 2026-08-11 (Windows 10, git-bash, Hermes desktop).
# ============================================================
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------- конфиг ----------
TEMPLATE_DIR="$KIT_DIR/templates/mcp-server-autumn"
PROJECTS_ROOT="${1:-${PROJECTS_ROOT:-}}"
FORCE=0
[ "${2:-}" = "--force" ] && FORCE=1

# подтягиваем .env, если есть (в репозитории .env никогда нет)
if [ -f "$KIT_DIR/.env" ]; then
  set -a; . "$KIT_DIR/.env"; set +a
fi

# ---------- утилиты ----------
say()  { printf '\033[1;34m[mcp-1c-autumn]\033[0m %s\n' "$*"; }
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
MCP_DIR="$TOOLS/mcp-1c-autumn"
MCP_MAIN_OS="$MCP_DIR/main.os"
MCP_HELP_DB="$MCP_DIR/src/data/shcntx_help.db"

# ---------- 0. базовые инструменты ----------
[ -d "$TEMPLATE_DIR" ] || fail "шаблон не найден: $TEMPLATE_DIR (кит развёрнут полностью?)"
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

# ---------- 1. копирование шаблона (идемпотентно, --force переустанавливает) ----------
needs_install=0
[ -f "$MCP_MAIN_OS" ] || needs_install=1
[ -f "$MCP_HELP_DB" ] || needs_install=1
if [ "$FORCE" = "1" ]; then
  say "--force: переустановка $MCP_DIR"
  rm -rf "$MCP_DIR"
  needs_install=1
fi

if [ "$needs_install" = "0" ]; then
  ok "сервер mcp-1c-autumn уже развёрнут: $MCP_DIR"
else
  say "Копирую шаблон $TEMPLATE_DIR -> $MCP_DIR ..."
  rm -rf "$MCP_DIR"
  mkdir -p "$(dirname "$MCP_DIR")"
  cp -r "$TEMPLATE_DIR" "$MCP_DIR"
  # из шаблона убираем артефакты (если вдруг попали): логи/бинарный мусор
  rm -f "$MCP_DIR"/_test.log "$MCP_DIR"/_out.bin "$MCP_DIR"/_err.bin 2>/dev/null || true
  [ -f "$MCP_MAIN_OS" ] || fail "main.os не найден после копирования"
  [ -f "$MCP_HELP_DB" ] || fail "shcntx_help.db не найден ($MCP_HELP_DB)"
  ok "сервер развёрнут: $MCP_DIR"
fi

# ---------- 1.5 фикс sql-пакета (обязательно для syntax_help_search) ----------
# oscript 2.1.0 + sql 1.3.2: NuGet-раскладка кладёт сборки в runtimes/, а не в
# Components/dotnet -> «System.Data.SqlClient 4.6.1.6 not found». Лечим копиями
# (cp -n — не перезаписывает уже скопированные, идемпотентно).
DOTNET_DIR="$(compgen -G "$TOOLS/engine"/oscript-*/lib/sql/Components/dotnet 2>/dev/null | head -1)"
if [ -n "$DOTNET_DIR" ] && [ -d "$DOTNET_DIR" ]; then
  SRC_SQLCLIENT="$DOTNET_DIR/runtimes/win/lib/netcoreapp2.1/System.Data.SqlClient.dll"
  SRC_INTEROP="$DOTNET_DIR/runtimes/win-x64/native/SQLite.Interop.dll"
  if [ -f "$SRC_SQLCLIENT" ] && [ -f "$SRC_INTEROP" ]; then
    cp -n "$SRC_SQLCLIENT" "$DOTNET_DIR/"
    cp -n "$SRC_INTEROP" "$DOTNET_DIR/"
    ok "фикс sql: DLL скопированы в $DOTNET_DIR"
  else
    warn "runtimes-сборки sql не найдены в $DOTNET_DIR — syntax_help_search может падать; см. INSTALL.md §13.2 п.6"
  fi
else
  warn "lib/sql/Components/dotnet не найден в движке — проверь установку oscript (INSTALL.md §13.2 п.6)"
fi

# ---------- 2. регистрация в Hermes (mcp add + env-фикс) ----------
has hermes || warn "hermes CLI не найден — сервер развёрнут, но в Hermes не зарегистрирован (запусти install-mcp1c-autumn.sh после установки Hermes)"
if has hermes; then
  MCP_WIN="$(cygpath -w "$MCP_DIR" 2>/dev/null || echo "$MCP_DIR")"
  ARGS_WIN="$MCP_WIN\\main.os"
  HELP_DB_WIN="$MCP_WIN\\src\\data\\shcntx_help.db"

  if hermes mcp list 2>/dev/null | grep -q "mcp-1c-autumn"; then
    ok "Hermes MCP 'mcp-1c-autumn' уже зарегистрирован"
  else
    say "Регистрирую MCP-сервер 'mcp-1c-autumn' в Hermes..."
    # ВАЖНО: --args ДОЛЖЕН быть последним (всё после него — аргументы сервера);
    # env SHCNTX_HELP_DB — фикс cwd-бага syntax_help_search (см. INSTALL.md §13);
    # интерактивный промпт подтверждения закрываем подачей 'Y'
    printf 'Y\n' | hermes mcp add mcp-1c-autumn --command oscript \
      --env "SHCNTX_HELP_DB=$HELP_DB_WIN" --args "$ARGS_WIN"
    hermes mcp list 2>/dev/null | grep -q "mcp-1c-autumn" || fail "сервер не зарегистрировался"
    ok "зарегистрирован 'mcp-1c-autumn' (command=oscript, env SHCNTX_HELP_DB, args=[$ARGS_WIN])"
  fi

  say "Проверка соединения (hermes mcp test)..."
  if hermes mcp test mcp-1c-autumn 2>&1 | grep -q "Tools discovered"; then
    ok "mcp-1c-autumn: соединение и инструменты в порядке"
  else
    warn "hermes mcp test не показал 'Tools discovered' — проверь вручную: hermes mcp test mcp-1c-autumn"
  fi
fi

# ---------- итог ----------
if has hermes; then
  echo
  say "Готово. Инструменты (5): bsl_search, xml_search, config_list, read_module, syntax_help_search."
  printf '\033[1;33m >>> Переоткрой Hermes (новая сессия), чтобы инструменты mcp__mcp_1c_autumn__* появились. <<<\033[0m\n'
else
  echo
  warn "Сервер развёрнут, но hermes CLI недоступен — регистрация в Hermes не выполнялась."
fi