#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""pi-bridge.py — файловая шина для prime-agent RPC (Windows, без TTY/FIFO).

Запускает prime-agent --mode rpc (провайдер opencode, модель как в Hermes)
с PIPE-каналами, НЕ зависит от stdin/PTY фонового процесса:
  - команды:     C:/hemes/tools/run/pi-cmd/<имя>.json
                 содержимое = строка JSON-команды RPC, напр.
                 {"type":"prompt","id":"1","message":"..."}
  - ответы:      C:/hemes/tools/run/pi-out.log   (append, JSONL по строкам)
  - отметки:     обработанные файлы перемещаются в pi-cmd/.done/
Ключ OPENCODE_API_KEY берётся из .env Hermes (OPENCODE_ZEN_API_KEY).
Ошибки моста — в C:/hemes/tools/run/pi-bridge.err.log.

Проверено 2026-08-09 (v0.7.1): prompt/response, get_state, делегирование.
Запуск без окна: pythonw.exe (консоль не создаётся).
"""
import json
import os
import pathlib
import subprocess
import threading
import time
import traceback

RUN = pathlib.Path("C:/hemes/tools/run")
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


# --- подавитель мелькающих окон Windows Terminal ---------------------------
# Виндовс: каждое НОВОЕ консольное окно открывается в Windows Terminal
# (терминал по умолчанию), поэтому воркеры prime дают 3 вспышки окна на
# запрос (проверено по пути процесса). Скрываем такие окна, но ТОЛЬКО
# пока мост активен (есть непрочитанные команды или лог писался < 90с).
# Открытый самим пользователем Terminal в нерабочее время не трогаем.
def _start_window_silencer():
    try:
        import ctypes
        import ctypes.wintypes as wt
    except Exception:
        return  # не Windows — не нужно

    user32 = ctypes.windll.user32
    kernel32 = ctypes.windll.kernel32
    SW_HIDE = 0

    def _exe(pid):
        h = kernel32.OpenProcess(0x1000, False, pid)
        if not h:
            return ""
        try:
            buf = ctypes.create_unicode_buffer(2048)
            n = ctypes.c_ulong(2048)
            if kernel32.QueryFullProcessImageNameW(h, 0, buf, ctypes.byref(n)):
                return buf.value.lower()
            return ""
        finally:
            kernel32.CloseHandle(h)

    def _visible():
        out = {}
        cb = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)(
            lambda hwnd, _: (
                out.__setitem__(hwnd, None) if user32.IsWindowVisible(hwnd)
                and user32.GetWindowTextLengthW(hwnd) > 0 else None) or True)
        user32.EnumWindows(cb, 0)
        return out

    def watch():
        prev = _visible()
        while True:
            time.sleep(0.08)
            active = any(CMD.glob("*.json")) or (
                OUT.exists() and time.time() - OUT.stat().st_mtime < 90)
            cur = _visible()
            for hwnd in cur:
                if hwnd in prev or not active:
                    continue
                pid = wt.DWORD()
                user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
                if "windowsterminal" in _exe(pid.value):
                    user32.ShowWindow(hwnd, SW_HIDE)
                    with ERR.open("a", encoding="utf-8") as f:
                        f.write("[%s] скрыто окно WT воркера (pid=%d)\n" %
                                (time.strftime("%H:%M:%S"), pid.value))
            prev = cur

    threading.Thread(target=watch, daemon=True).start()


def _create_hidden_desktop():
    """Невидимый виртуальный десктоп: консольные окна воркеров prime
    (node + daemon + worker + kernel) создаются на нём и НИКОГДА не
    прорисовываются на экране пользователя — нет даже миллисекундной
    вспышки (проверено: ShowWindow-подавитель ловит с опозданием).
    Возвращает имя десктопа или None, если создать не вышло."""
    try:
        import ctypes
        user32 = ctypes.windll.user32
        name = "pi_bridge_hidden"
        h = user32.CreateDesktopW(name, None, None, 0, 0x10000000, None)
        return name if h else None
    except Exception:
        return None


def main():
    DONE.mkdir(parents=True, exist_ok=True)
    _start_window_silencer()
    desktop = _create_hidden_desktop()  # None если не вышло
    with ERR.open("a", encoding="utf-8") as f:
        f.write("[%s] startup: hidden-desktop=%s\n" %
                (time.strftime("%H:%M:%S"), desktop))
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
    si = None
    if desktop:
        si = subprocess.STARTUPINFO()
        si.lpDesktop = desktop
        si.dwFlags |= 1          # STARTF_USESHOWWINDOW
        si.wShowWindow = 0       # SW_HIDE
    try:
        p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, text=True, encoding="utf-8",
                             errors="replace", env=env, cwd="C:/hemes", bufsize=1,
                             creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
                             startupinfo=si)
    except Exception:
        log_exc("Popen(node)")   # без этого pythonw молча умирает
        raise
    # CREATE_NO_WINDOW: node/prime — консольные приложения, запускаемые из
    # бесконсольного pythonw, иначе Windows рисует окно консоли на каждый
    # процесс (проверено: 3 мелькания на запрос: node + daemon + worker).

    def pump_out():
        try:
            with OUT.open("a", encoding="utf-8") as f:
                for line in p.stdout:
                    f.write(line)
                    f.flush()
                    OUT.touch()  # маркер новизны для читающей стороны
        except Exception:
            log_exc("pump_out")

    threading.Thread(target=pump_out, daemon=True).start()

    seen = {f.name for f in DONE.glob("*.json")}
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
        pass
    finally:
        try:
            p.stdin.close()
        except Exception:
            pass
        try:
            p.wait(timeout=5)
        except Exception:
            p.kill()


if __name__ == "__main__":
    try:
        main()
    except Exception:
        log_exc("main")
        raise