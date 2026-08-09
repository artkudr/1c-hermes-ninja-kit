#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""pi-bridge.py — файловая шина для prime-agent RPC (Windows, без TTY/FIFO).

Запускает prime-agent --mode rpc (провайдер opencode, модель как в Hermes)
с PIPE-каналами, НЕ зависит от stdin/PTY фонового процесса:
  - команды:     C:/hermes/tools/run/pi-cmd/<имя>.json
                 содержимое = строка JSON-команды RPC, напр.
                 {"type":"prompt","id":"1","message":"..."}
  - ответы:      C:/hermes/tools/run/pi-out.log   (append, JSONL по строкам)
  - отметки:     обработанные файлы перемещаются в pi-cmd/.done/
Ключ OPENCODE_API_KEY берётся из .env Hermes (OPENCODE_ZEN_API_KEY).
Ошибки моста — в C:/hermes/tools/run/pi-bridge.err.log.

Проверено 2026-08-09 (v0.7.2): prompt/response, get_state, делегирование;
супервизор-ретрай на старте; чистая версия без скрытых десктопов/хаков окон.
Безоконность: служба LocalSystem (сессия 0) + CREATE_NO_WINDOW в Popen.
"""
import json
import os
import pathlib
import subprocess
import threading
import time
import traceback

RUN = pathlib.Path("C:/hermes/tools/run")
CMD = RUN / "pi-cmd"
OUT = RUN / "pi-out.log"
ERR = RUN / "pi-bridge.err.log"
DONE = CMD / ".done"
HENV = pathlib.Path("C:/Users/artkudr/AppData/Local/hermes/.env")


def read_key():
    for line in HENV.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("OPENCODE_ZEN_API_KEY="):
            return line.split("=", 1)[1].strip().strip('"\r')
    return ""


def log_exc(context):
    with ERR.open("a", encoding="utf-8") as f:
        f.write("[%s] %s\n%s\n" % (time.strftime("%H:%M:%S"), context,
                                   traceback.format_exc()))


def main():
    DONE.mkdir(parents=True, exist_ok=True)
    with ERR.open("a", encoding="utf-8") as f:
        f.write("[%s] startup\n" % time.strftime("%H:%M:%S"))
    env = dict(os.environ)
    env["OPENCODE_API_KEY"] = read_key()
    # В сессии 0 (служба LocalSystem) PATH — системный: там нет ни node,
    # ни git, ни python-венва. Добавляем пользовательские каталоги явно.
    extra_path = ["C:/Users/artkudr/AppData/Local/hermes/node",
                  "C:/Users/artkudr/AppData/Local/hermes/git/mingw64/bin",
                  "C:/Users/artkudr/AppData/Local/hermes/git/cmd",
                  "C:/Users/artkudr/AppData/Local/hermes/hermes-agent/venv/Scripts"]
    env["PATH"] = os.pathsep.join(extra_path + [env.get("PATH", "")])
    # prime-agent — shim-скрипт без .exe: запускаем node с cli.js напрямую
    node_exe = "C:/Users/artkudr/AppData/Local/hermes/node/node.exe"  # absolute!
    node_cli = ("C:/Users/artkudr/AppData/Local/hermes/node/node_modules/"
                "prime-agent/dist/bundle/cli.js")
    cmd = [node_exe, node_cli, "--mode", "rpc",
           "--provider", "opencode", "--model", "deepseek-v4-flash-free"]
    # Супервизор-ретрай: сразу после загрузки системы prime-daemon (pipe
    # \\\\.\\pipe\\prime-agent-daemon) может быть ещё не готов — node падает на
    # старте (DaemonSocketClosedError) и служба рестартует цикл по кругу.
    # Здесь node, упавший в первые GRACE_SEC, перезапускается ЛОКАЛЬНО с
    # бэкоффом; переживший GRACE_SEC считаем стабильным и выходим штатно
    # (дальше — обычный цикл автозапуска NSSM). CREATE_NO_WINDOW в Popen:
    # консольные окна node не рисуются (сессия 0 и так их не показывает).
    def pump_out():
        try:
            with OUT.open("a", encoding="utf-8") as f:
                for line in p.stdout:
                    f.write(line)
                    f.flush()
                    OUT.touch()  # маркер новизны для читающей стороны
        except Exception:
            log_exc("pump_out")

    GRACE_SEC = 20.0
    backoff, attempt = 1.0, 0
    seen = {f.name for f in DONE.glob("*.json")}
    while True:
        try:
            p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT, text=True, encoding="utf-8",
                                 errors="replace", env=env, cwd="C:/hermes", bufsize=1,
                                 creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        except Exception:
            log_exc("Popen(node)")
            raise
        threading.Thread(target=pump_out, daemon=True).start()
        started = time.time()
        interrupted = False
        try:
            while p.poll() is None:
                for f in sorted(CMD.glob("*.json")):
                    if f.name in seen:
                        continue
                    body = f.read_text(encoding="utf-8", errors="replace").strip()
                    p.stdin.write(body + "\n")
                    p.stdin.flush()
                    seen.add(f.name)
                    f.rename(DONE / f.name)
                time.sleep(0.2)
        except KeyboardInterrupt:
            interrupted = True
        finally:
            try:
                p.stdin.close()
            except Exception:
                pass
            try:
                p.wait(timeout=5)
            except Exception:
                p.kill()
        if interrupted:
            return
        lifetime = time.time() - started
        if lifetime >= GRACE_SEC:
            with ERR.open("a", encoding="utf-8") as f:
                f.write("[%s] node стабилен %.0fs, выходим (NSSM подхватить)\n" %
                        (time.strftime("%H:%M:%S"), lifetime))
            return
        attempt += 1
        if attempt > 8:
            with ERR.open("a", encoding="utf-8") as f:
                f.write("[%s] 8 ретраев не хватило, выходим (NSSM перезапустит)\n" %
                        time.strftime("%H:%M:%S"))
            return
        delay = min(backoff, 15.0)
        with ERR.open("a", encoding="utf-8") as f:
            f.write("[%s] node упал через %.1fs (стартовый race?), retry %d через %.0fs\n" %
                    (time.strftime("%H:%M:%S"), lifetime, attempt, delay))
        time.sleep(delay)
        backoff *= 1.5


if __name__ == "__main__":
    try:
        main()
    except Exception:
        log_exc("main")
        raise