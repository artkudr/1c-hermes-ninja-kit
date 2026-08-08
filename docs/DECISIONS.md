# Решения (DECISIONS.md) — зафиксированные обоснования

> Обновляется вместе с изменениями. Дата + причина.

## 2026-08-09

- **oscript ставим НЕ через winget.** Пакет `OneScript.OneScript` в winget-каталоге
  отстаёт (1.9.4 против актуальной 2.1.0). Используем самодостаточный zip с
  `https://oscript.io/api/archive/latest` — он же не требует UAC и кладётся в
  `tools/engine` (вся экосистема — в корне проектов, ничего в Program Files).
- **bslc — локальный образ из Maven Central, а не ghcr.io** — из сети владельца
  ghcr.io выдаёт 403/denied (блокировка токена), Docker Hub образа не содержит;
  актуальная версия bslc 1.0.7 доступна на Maven Central (`-exec.jar`).
  Тег образа: `bslc:1.0.7` — пинуем версию, `latest` не используем.
- **Java на хосте не ставим** — только в контейнере (eclipse-temurin:21-jre).
- **opm.bat и POSIX-пути** — .bat-скрипты внутри зовут `oscript` по PATH;
  Windows-пути `C:/…` в PATH cmd-процесс не принимает, нужны `/c/…`.
- **yaxunit из git** — пакет в реестре opm может отсутствовать; канал установки —
  `opm install https://github.com/xdriven…/yaxunit`.
- **json-реестр баз** — отдельным python-файлом (`scripts/ninja_json.py`), а не
  bash-вставками: python на Windows не понимает MSYS-пути, все пути передаются
  в Windows-форме (`cygpath -w`), иначе `C:\c\hemes\…`.
- **bslc 1.0.7 (json-формат отчёта)** — не массив, а dict
  `{date, sourceDir, fileinfos:[{path, mdoRef, diagnostics:[…]}]}`;
  счётчик суммирует `fileinfos[].diagnostics`.
- **пустой srcDir** — bslc падает на пустом `--srcDir`; контекст `src/cf`
  включается, только если каталог непустой.
- **отчёт пишется в файл** контейнера (`--outputDir` + фиксированное имя
  `bsl-json.json`), поэтому обёртка переименовывает его в
  `<Расширение>_<ts>.json`.