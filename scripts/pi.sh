#!/usr/bin/env bash
# pi.sh — one-shot вопрос к prime-agent через RPC (модель = как в Hermes).
# Проверено 2026-08-09 на v0.7.1 (RPC-протокол по фактам, не по докам):
#   - команда: {"type":"prompt","id":N,"message":"..."}   (поле message, НЕ prompt!)
#   - ответ команды: {"type":"response","id":N,"command":"prompt","success":true|false,"error":...}
#   - финальный текст ассистента: message_end с role=assistant, content[].text
#   - сервер умирает по EOF stdin -> держим stdin открытым (sleep-таймаут)
# Использование: bash pi.sh "сообщение" [таймаут_сек=60]
set -u

HKEY_FILE="C:/Users/artkudr/AppData/Local/hermes/.env"
MSG="${1:?usage: bash pi.sh <сообщение> [таймаут_сек]}"
TIMEOUT="${2:-60}"

HKEY="$(grep '^OPENCODE_ZEN_API_KEY=' "$HKEY_FILE" | head -1 | cut -d= -f2- | tr -d '\r\n')"
if [ -z "$HKEY" ]; then echo "ERR: OPENCODE_ZEN_API_KEY пуст в $HKEY_FILE" >&2; exit 2; fi

# JSON-экранирование сообщения через python (надёжнее printf)
MSG_JSON="$(python -c "import json,sys; print(json.dumps(sys.argv[1]))" "$MSG")"

CMD="{\"type\":\"prompt\",\"id\":\"1\",\"message\":$MSG_JSON}"

OUT="$( { printf '%s\n' "$CMD"; sleep "$TIMEOUT"; } | OPENCODE_API_KEY="$HKEY" \
  prime-agent --mode rpc --provider opencode --model deepseek-v4-flash-free 2>&1 )"

echo "$OUT" | python -c "
import sys, json
last = None; err = None
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try: e = json.loads(line)
    except Exception: continue
    t = e.get('type')
    if t == 'response' and e.get('command') == 'prompt':
        err = None if e.get('success') else e.get('error')
    if t == 'message_end' and (e.get('message') or {}).get('role') == 'assistant':
        c = (e.get('message') or {}).get('content') or []
        last = ' '.join(x.get('text','') for x in c if isinstance(x, dict)).strip()
if err: print('ERR:', err); sys.exit(1)
print(last if last else '(пустой ответ)')
"
