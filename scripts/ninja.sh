#!/usr/bin/env bash
# ============================================================
# ninja — работа с базами 1С по конвенции 1c-hermes-ninja-kit
#
#   ninja new <имя> [--ext <Расширение> ...]   создать базу
#   ninja list                                 список баз (projects.json)
#
# Имена баз/расширений — только латиница (A-Za-z0-9-_).
# ============================================================
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECTS_ROOT="${PROJECTS_ROOT:-$(dirname "$KIT_DIR")}"
TOOLS="$PROJECTS_ROOT/tools"
PROJECTS_JSON="$TOOLS/projects.json"

say()  { printf '\033[1;34m[ninja]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  OK  \033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m WARN \033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m FAIL \033[0m %s\n' "$*"; exit 1; }

# --- читаем PROJECTS_ROOT из tools/.env, если переменная не задана ---
if [ -z "${PROJECTS_ROOT_SET:-}" ] && [ -f "$TOOLS/.env" ]; then
  set -a; . "$TOOLS/.env"; set +a
fi
TOOLS="$PROJECTS_ROOT/tools"
PROJECTS_JSON="$TOOLS/projects.json"

valid_name() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]]; }

# python на Windows не понимает MSYS-пути — передаём Windows-форму
NINJA_JSON_PY="$(cygpath -w "$KIT_DIR/scripts/ninja_json.py" 2>/dev/null || echo "$KIT_DIR/scripts/ninja_json.py")"
PROJECTS_JSON_WIN="$(cygpath -w "$PROJECTS_JSON" 2>/dev/null || echo "$PROJECTS_JSON")"
PY_RUN() { python "$NINJA_JSON_PY" "$@"; }

json_set() { # json_set <key> <path> <created> <exts-csv>
  PY_RUN set "$PROJECTS_JSON_WIN" "$1" "$2" "$3" "${4:-}"
}

json_del() {
  PY_RUN del "$PROJECTS_JSON_WIN" "$1"
}

cmd_new() {
  [ $# -ge 1 ] || fail "ninja new <имя> [--ext <Расширение> ...]"
  local NAME="$1"; shift
  valid_name "$NAME" || fail "имя базы '$NAME' — только латиница, цифры, - и _"
  [ -f "$PROJECTS_JSON" ] || fail "нет $PROJECTS_JSON — сначала install.sh"

  local EXTS=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --ext) EXTS+=("$2"); shift 2 ;;
      *) fail "неизвестный аргумент: $1" ;;
    esac
  done
  for e in "${EXTS[@]}"; do valid_name "$e" || fail "имя расширения '$e' — только латиница"; done

  local BASE="$PROJECTS_ROOT/$NAME"
  if [ -e "$BASE" ]; then fail "каталог $BASE уже существует"; fi

  say "Создание базы $NAME: $BASE"
  mkdir -p "$BASE/src/cf" "$BASE/src/cfe" "$BASE/reports" "$BASE/notes"
  touch "$BASE/src/cfe/.gitkeep"

  cp "$KIT_DIR/templates/bsl-language-server.json" "$BASE/.bsl-language-server.json"
  cp "$KIT_DIR/templates/AGENTS.md.tpl"            "$BASE/AGENTS.md"
  cp "$KIT_DIR/templates/gitignore"                "$BASE/.gitignore"
  say "Создан AGENTS.md (правила базы) — текст скопирован из templates/AGENTS.md.tpl, отредактируйте при необходимости"

  cat > "$BASE/notes/registry.md" <<EOF
# Реестр базы: $NAME

- Дата создания: $(date +%F)
- Типовая конфигурация (версия): TBD
- Расширения: ${EXTS[*]:-—}

> Версия типовой фиксируется ОДНОЙ строкой при выгрузке в src/cf.
EOF

  for e in "${EXTS[@]:-}"; do
    [ -z "$e" ] || mkdir -p "$BASE/src/cfe/$e"
  done

  ( cd "$BASE" && git init -q -b main )
  ok "git-репозиторий базы инициализирован (ветка main, без коммитов)"

  local WIN="$(cygpath -w "$BASE" 2>/dev/null || echo "$BASE")"
  local EXTS_CSV="$(IFS=,; echo "${EXTS[*]}")"
  json_set "$NAME" "$WIN" "$(date +%F)" "$EXTS_CSV"
  ok "зарегистрирована в $PROJECTS_JSON"

  say "База готова: $BASE"
  echo "  src/cf/    — выгрузка типовой (read-only, в git не хранится)"
  echo "  src/cfe/   — расширения: ${EXTS[*]:-пока нет (добавьте вручную или --ext)}"
  echo "  notes/registry.md — версия типовой (заполнить при выгрузке)"
}

cmd_list() {
  [ -f "$PROJECTS_JSON" ] || fail "нет $PROJECTS_JSON — сначала install.sh"
  PY_RUN list "$PROJECTS_JSON_WIN"
}

cmd_scan() {
  [ -f "$PROJECTS_JSON" ] || fail "нет $PROJECTS_JSON — сначала install.sh"
  say "Обзор каталогов баз в $PROJECTS_ROOT"
  local found=0
  for d in "$PROJECTS_ROOT"/*/; do
    [ -d "$d" ] || continue
    d="${d%/}"
    bn="$(basename "$d")"
    case "$bn" in tools) continue ;; esac
    if [ -d "$d/src/cfe" ]; then
      found=1
      reg="$(PY_RUN get "$PROJECTS_JSON_WIN" "$bn" 2>/dev/null || true)"
      if [ -n "$reg" ]; then
        ok "$bn — база, зарегистрирована"
      else
        warn "$bn — база на диске, НЕ в реестре (добавьте: python scripts/ninja_json.py set $PROJECTS_JSON_WIN \"$bn\" \"$(cygpath -w "$d")\" \"$(date +%F)\" \"\")"
      fi
    fi
  done
  [ "$found" = "1" ] || ok "баз на диске не обнаружено"
}

case "${1:-}" in
  new)  shift; cmd_new "$@" ;;
  list) shift; cmd_list "$@" ;;
  scan) shift; cmd_scan "$@" ;;
  *) echo "ninja: команды: new <имя> [--ext ...], list, scan"; exit 1 ;;
esac