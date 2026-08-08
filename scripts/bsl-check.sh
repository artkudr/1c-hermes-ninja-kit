#!/usr/bin/env bash
# ============================================================
# bsl-check — статический анализ расширения 1С через bslc (docker)
#
#   bsl-check <база> <расширение> [--reporter json|sarif]
#
# Источник — src/cfe/<расширение> (только расширения!); контекст типовой —
# src/cf (второй --srcDir). Отчёт — reports/<расширение>_<ts>.json/sarif.
# ============================================================
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECTS_ROOT="${PROJECTS_ROOT:-$(dirname "$KIT_DIR")}"
[ -f "$PROJECTS_ROOT/tools/.env" ] && { set -a; . "$PROJECTS_ROOT/tools/.env"; set +a; }
TOOLS="$PROJECTS_ROOT/tools"
BSL_IMAGE="${BSL_IMAGE:-bslc:1.0.7}"

say()  { printf '\033[1;34m[bsl-check]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  OK  \033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m FAIL \033[0m %s\n' "$*"; exit 1; }

REPORTER="json"
POS_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --reporter) REPORTER="$2"; shift 2 ;;
    *) POS_ARGS+=("$1"); shift ;;
  esac
done
[ "${#POS_ARGS[@]}" -ge 2 ] || fail "bsl-check <база> <расширение> [--reporter json|sarif]"
NAME="${POS_ARGS[0]}"; EXT="${POS_ARGS[1]}"

# путь базы: из projects.json, иначе PROJECTS_ROOT/<имя>
JSON_WIN="$(cygpath -w "$TOOLS/projects.json" 2>/dev/null || echo "$TOOLS/projects.json")"
BPATH=""
if [ -f "$TOOLS/projects.json" ]; then
  BPATH="$(python "$(cygpath -w "$KIT_DIR/scripts/ninja_json.py")" get "$JSON_WIN" "$NAME" 2>/dev/null || true)"
fi
[ -n "$BPATH" ] || BPATH="$PROJECTS_ROOT/$NAME"
BASE_WIN="${BPATH//\//\\}" # windows пути из json уже с обратными слэшами — не трогаем
BASE_POSIX="$(cygpath -u "$BPATH" 2>/dev/null || echo "$BPATH")"
[ -d "$BASE_POSIX" ] || fail "база «$NAME» не найдена (каталог $BASE_POSIX отсутствует)"
[ -d "$BASE_POSIX/src/cfe/$EXT" ] || fail "нет расширения «$EXT» в $BASE_POSIX/src/cfe"

mkdir -p "$BASE_POSIX/reports"
TS="$(date +%Y%m%d-%H%M%S)"
OUT="$BASE_POSIX/reports/${EXT}_${TS}.${REPORTER}"

# контекст типовой: src/cf включаем только если он непустой (bslc падает на пустом srcDir)
CF_ARGS=()
if [ -n "$(find "$BASE_POSIX/src/cf" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
  CF_ARGS=(--srcDir /ws/src/cf)
  say "Контекст типовой: src/cf (непустой)"
fi

say "Анализ: $NAME / $EXT  (репортер: $REPORTER)"
docker run --rm \
  -v "$BPATH:/ws" \
  "$BSL_IMAGE" analyze \
  --srcDir "/ws/src/cfe/$EXT" \
  "${CF_ARGS[@]}" \
  --configuration "/ws/.bsl-language-server.json" \
  --reporter "$REPORTER" \
  --outputDir "/ws/reports" >/dev/null 2> "$BASE_POSIX/reports/docker.err" || {
    sed 's/^/         /' "$BASE_POSIX/reports/docker.err" | head -5;
    fail "bslc упал (см. reports/docker.err)";
  }
[ -f "$BASE_POSIX/reports/bsl-json.json" ] || fail "отчёт не создан (репортер молчит)"
mv "$BASE_POSIX/reports/bsl-json.json" "$OUT"

# резюме
if [ "$REPORTER" = "json" ]; then
  OUT_FOR_PY="$(cygpath -w "$OUT" 2>/dev/null || echo "$OUT")"
  N="$(python -c 'import json,sys
try:
    d=json.load(open(sys.argv[1],encoding="utf-8"))
    n=sum(len(f.get("diagnostics",[])) for f in d.get("fileinfos",[]))
    print(n)
except Exception:
    print("?")' "$OUT_FOR_PY" 2>/dev/null || echo "?")"
else
  N="(см. файл)"
fi
ok "диагностик: $N"
ok "отчёт: $OUT"
rm -f "$BASE_POSIX/reports/docker.err"