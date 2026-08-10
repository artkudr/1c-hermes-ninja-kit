#!/usr/bin/env bash
# ============================================================
# 1c-hermes-ninja-kit — LLM-ядро "1c-buddy" (шлюз к 1С:Напарник)
# Поднимает HTTP MCP-сервер 1С:Напарник (code.1c.ai) для агентов:
#   ask_1c_ai, explain_1c_syntax, check_1c_code, modify_1c_code,
#   search_1c_documentation, search_its, fetch_its, diff_1c_documentation_versions
# (8 инструментов; OpenAI /v1 НЕ включаем — решение «только MCP»).
# Запуск: ./install/install-buddy.sh [PROJECTS_ROOT] [--force]
#   --force — пересоздать контейнер (docker rm -f + run).
# Повторный запуск безопасен: переходит в состояние «уже есть».
# Секретов не содержит: токен читается из $TOOLS/.env (ONEC_AI_TOKEN,
# бесплатно: https://code.1c.ai) или из $TOOLS/run/buddy.env.
#
# Проверено исполнением 2026-08-10 (Windows 10, git-bash, Docker 29.6).
# ⚠ ТоС: API code.1c.ai по пользовательскому соглашению предназначено для
# 1С:EDT; вызов из стороннего клиента — на свой страх и риск (в ответах может
# появляться приписка «API предназначено для 1С:EDT», в худшем случае —
# блокировка токена). Согласовано с владельцем 2026-08-10.
# ============================================================
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------- конфиг ----------
BUDDY_IMAGE="${BUDDY_IMAGE:-roctup/1c-buddy}"
PROJECTS_ROOT="${1:-${PROJECTS_ROOT:-}}"
FORCE=0
[ "${2:-}" = "--force" ] && FORCE=1

# подтягиваем .env репозитория (если есть; в git его никогда нет)
if [ -f "$KIT_DIR/.env" ]; then
  set -a; . "$KIT_DIR/.env"; set +a
fi

# ---------- утилиты ----------
say()  { printf '\033[1;34m[buddy]\033[0m %s\n' "$*"; }
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
NAME="1c-buddy"
PORT="${PORT_BUDDY:-6002}"

# токен Напарника: приоритет — $TOOLS/run/buddy.env, затем $TOOLS/.env
ENV_FILE=""
if [ -f "$TOOLS/.env" ]; then
  set -a; . "$TOOLS/.env"; set +a
  ENV_FILE="$TOOLS/.env"
fi
if [ -f "$TOOLS/run/buddy.env" ]; then
  set -a; . "$TOOLS/run/buddy.env"; set +a
  ENV_FILE="$TOOLS/run/buddy.env"
fi

# ---------- 0. базовые инструменты ----------
has docker || fail "docker не найден (нужен Docker Desktop)"
docker info >/dev/null 2>&1 || fail "docker daemon не запущен"
has hermes || warn "hermes CLI не найден — контейнер подниму, регистрацию в Hermes пропущу (запусти позже)"
ok "docker = $(docker --version | cut -d' ' -f3 | cut -d, -f1)"

# ---------- 1. токен ----------
if [ -z "${ONEC_AI_TOKEN:-}" ] || [ "${#ONEC_AI_TOKEN}" -lt 10 ]; then
  fail "ONEC_AI_TOKEN не задан — заполни $TOOLS/.env (бесплатно: https://code.1c.ai); затем повтори"
fi
[ -n "$ENV_FILE" ] && [ -f "$ENV_FILE" ] || fail "нет файла-источника токена ($TOOLS/.env)"
ok "токен Напарника задан (${#ONEC_AI_TOKEN} симв.), источник: $ENV_FILE"

# ---------- 2. контейнер (идемпотентно; --force пересоздаёт) ----------
STATE=""
docker inspect "$NAME" >/dev/null 2>&1 && STATE="$(docker inspect -f '{{.State.Status}}' "$NAME")"
if [ "$FORCE" = "1" ] && [ -n "$STATE" ]; then
  say "--force: пересоздаю контейнер $NAME"
  docker rm -f "$NAME" >/dev/null
  STATE=""
fi
if [ -n "$STATE" ]; then
  if [ "$STATE" = "running" ]; then
    ok "контейнер $NAME уже запущен"
  else
    say "контейнер в состоянии $STATE — запускаю"
    docker start "$NAME" >/dev/null
    ok "контейнер запущен"
  fi
else
  say "Поднимаю $BUDDY_IMAGE (127.0.0.1:$PORT)..."
  ENV_WIN="$(cygpath -w "$ENV_FILE" 2>/dev/null || echo "$ENV_FILE")"
  # ВАЖНО (MSYS-грабли, проверено): --env-file принимает ТОЛЬКО Windows-путь.
  # git-bash транслирует C:/… в /c/…, docker.exe падает
  # «open /c/.../buddy.env: The system cannot find the path specified».
  docker run -d --name "$NAME" --restart unless-stopped \
    -p "127.0.0.1:${PORT}:${PORT}" \
    --env-file "$ENV_WIN" \
    "$BUDDY_IMAGE"
fi

# ---------- 3. health-check + smoke MCP ----------
HEALTH_OK=0
for _ in $(seq 1 12); do
  if curl -s -m 5 "http://127.0.0.1:${PORT}/health" 2>/dev/null | grep -q '"ok"'; then
    HEALTH_OK=1; break
  fi
  sleep 5
done
[ "$HEALTH_OK" = "1" ] || fail "контейнер не отвечает на /health за 60 с — смотри: docker logs $NAME"
ok "health: $(curl -s -m 5 "http://127.0.0.1:${PORT}/health")"

INIT="$(curl -s -m 10 -X POST "http://127.0.0.1:${PORT}/mcp" \
  -H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"kit-smoke","version":"0.1"}}}')"
if echo "$INIT" | grep -q '"serverInfo"'; then
  ok "MCP рукопожатие: $(echo "$INIT" | grep -o '"name":"[^"]*"' | head -1)"
else
  warn "initialize не дал serverInfo — проверь вручную: curl -X POST http://localhost:${PORT}/mcp"
fi

# ---------- 4. регистрация в Hermes (HTTP MCP, url) ----------
if has hermes; then
  if hermes mcp list 2>/dev/null | grep -q "$NAME"; then
    ok "Hermes MCP '$NAME' уже зарегистрирован"
  else
    say "Регистрирую MCP-сервер '$NAME' в Hermes..."
    # ВАЖНО: у HTTP-сервера ДВА интерактивных промпта:
    #   «Does this server require authentication?» → n
    #   «Enable all 8 tools?»                    → Y
    printf 'n\nY\n' | hermes mcp add "$NAME" --url "http://localhost:${PORT}/mcp" --connect-timeout 60
    hermes mcp list 2>/dev/null | grep -q "$NAME" || fail "сервер не зарегистрировался"
    ok "зарегистрирован '$NAME' (url=http://localhost:${PORT}/mcp)"
  fi
  say "Проверка соединения (hermes mcp test)..."
  if hermes mcp test "$NAME" 2>&1 | grep -q "Tools discovered"; then
    ok "$NAME: соединение и инструменты в порядке"
  else
    warn "hermes mcp test не показал 'Tools discovered' — проверь вручную: hermes mcp test $NAME"
  fi
fi

# ---------- итог ----------
echo
say "Готово. Инструменты (8): ask_1c_ai, explain_1c_syntax, check_1c_code,"
say "  modify_1c_code, search_1c_documentation, search_its, fetch_its, diff_1c_documentation_versions."
printf '\033[1;33m >>> Переоткрой Hermes (новая сессия), чтобы инструменты mcp__1c_buddy__* появились. <<<\033[0m\n'
printf '\033[1;33m >>> /mcp и веб-чат БЕЗ аутентификации — порт опубликован только на 127.0.0.1, наружу не выставляй. <<<\033[0m\n'