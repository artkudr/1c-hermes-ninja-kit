# mcp-1c-autumn

MCP-сервер статического контура 1С: поиск по выгрузке конфигурации (BSL/XML) и справка
синтакс-помощника из SQLite. **5 инструментов, без живой сессии 1С.**

Это порт сервера [lekot/mcp-1c](https://github.com/lekot/mcp-1c) (рукописный JSON-RPC
на OneScript) на библиотечный фреймворк [autumn-mcp](https://github.com/autumn-library/autumn-mcp)
(DI-контейнер autumn + декларативные аннотации инструментов). Слой JSON-RPC (~750 строк)
удалён; бизнес-логика пяти хендлеров перенесена 1:1 — имена инструментов, параметры и
контракты сохранены без отклонений (`rules/1c-mcp-metadata.mdc`).

> **Origin и лицензия.** Логика инструментов — производная работа lekot/mcp-1c
> (автор: lekot) под **GPL-3.0**; фреймворк autumn-mcp — тоже GPL-3.0.
> Каркас порта, аннотации, тесты и фиксы — разработка этого проекта.

## Состав

```
main.os                          # бутстрап: autumn + autumn-mcp + ".", Поделка.ЗапуститьПриложение()
Классы/
  СервисФайловойСистемы.os       # адаптер ФС (перенос из lekot, без аннотаций — не инструмент)
  ИнструментПоискBSL.os          # bsl_search
  ИнструментПоискXML.os          # xml_search
  ИнструментСписокКонфигурации.os# config_list
  ИнструментЧтениеМодуля.os      # read_module
  ИнструментПоискВСправке.os     # syntax_help_search (пакет sql)
src/data/shcntx_help.db          # БД справки синтакс-помощника (копия из lekot)
rules/1c-mcp-metadata.mdc        # контракты инструментов
port_test.py                     # smoke-тест всех 5 инструментов (MCP Python SDK)
compare_test.py                  # A/B-сравнение со старым сервером (исторический артефакт)
mcp.json                         # конфиг регистрации (пример)
```

## Требования

- oscript 2.1.0 (движок — `C:\hermes\tools\engine\oscript-2.1.0`), opm-пакеты:
  `autumn 4.3.13`, `autumn-mcp 1.1.2`, `decorator 2.0.4`, `sql 1.3.2`.
- **Фикс sql-пакета** (иначе `syntax_help_search` падает с «System.Data.SqlClient
  4.6.1.6 not found»): скопировать в `<engine>\lib\sql\Components\dotnet\`:
  - `runtimes\win\lib\netcoreapp2.1\System.Data.SqlClient.dll`
  - `runtimes\win-x64\native\SQLite.Interop.dll`

## Запуск и регистрация

```bash
oscript C:\hermes\tools\mcp-1c-autumn\main.os          # stdio MCP-сервер
hermes mcp add mcp-1c-autumn --command oscript \
  --env SHCNTX_HELP_DB=C:\hermes\tools\mcp-1c-autumn\src\data\shcntx_help.db \
  --args C:\hermes\tools\mcp-1c-autumn\main.os
hermes mcp test mcp-1c-autumn                          # ✓ Tools discovered: 5
```

Путь к БД справки резолвится: параметр `dbPath` → env `SHCNTX_HELP_DB` →
файл `shcntx_help_db_path.txt` в текущем каталоге → `src/data/shcntx_help.db` относительно cwd.

## Инструменты

| Инструмент | Параметры | Что делает |
|---|---|---|
| `bsl_search` | `path`*, `query`*, `useRegex` | Поиск по BSL-файлам (`*.bsl`, рекурсивно); результат `путь:номер:фрагмент` |
| `xml_search` | `path`*, `query`* | Поиск по XML метаданных (рекурсивно) |
| `config_list` | `path`*, `maxDepth` | Дерево каталогов/файлов выгрузки с отступами |
| `read_module` | `path`*, `method` | Весь модуль / список объявлений (`*`) / тело метода |
| `syntax_help_search` | `query`*, `dbPath`, `limit`, `snippet_length` | Поиск по справке синтакс-помощника (SQLite, таблица nodes) |

Параметры без `*` — опциональны (отсутствует = `Неопределено`).

## Тесты

```bash
cd C:\hermes\tools\mcp-1c-autumn && python port_test.py     # зелёный = все 5 работают
```

Верифицировано на выгрузке qbik-dev (пути с кириллицей работают). A/B-сравнение со
старым сервером (2026-08-11): 16 сценариев, 13 идентичны 1:1, 3 — только обёртка ошибок.

## История

- 2026-08-11: перенос выполнен и верифицирован (эмпирически, отчёт
  `C:\Users\artkudr\guides\08-1c-autumn-mcp-port-report.md`); сервер подключён в Hermes;
  lekot-сервер отключён и перенесён в `C:\hermes\tools\archive\mcp-1c-lekot`.