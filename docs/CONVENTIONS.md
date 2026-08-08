# Конвенции (CONVENTIONS.md)

## Структура репозитория

```
1c-hermes-ninja-kit/
  install/install.sh        # идемпотентная установка окружения
  install/bslc/Dockerfile   # локальный образ bslc (fallback для ghcr.io)
  scripts/ninja.sh          # создание/список/обзор баз
  scripts/ninja_json.py     # работа с tools/projects.json (python на Windows)
  scripts/bsl-check.sh      # статический анализ расширения через bslc
  templates/                # шаблоны для новых баз (см. ниже)
  docs/INSTALL.md           # проверенные шаги установки и эксплуатации
  docs/DECISIONS.md         # обоснованные решения
  .env.example              # шаблон секретов (токен Напарника)
```

## Корни

- `PROJECTS_ROOT` (по умолчанию `C:/hemes`) — корень всех 1С-проектов.
- `PROJECTS_ROOT/tools/` — инфраструктура (НЕ база): `cfg/ context/ repos/
  scripts/ reports/ downloads/ engine/`, `.env`, `projects.json`.
- Движки/бинари живут в `tools/engine/…` (ничего в Program Files).
- Репозиторий ninja-kit сам лежит рядом с `tools/` в корне проектов.

## Структура 1С-базы (создаёт `ninja new`)

```
<имя>/
  src/cf/            # выгрузка типовой — read-only, НЕ в git (версия — notes/registry.md)
  src/cfe/<Расширение>/  # расширения — единственное, что линтуем/редактируем
  notes/registry.md  # реестр: версия типовой (одна строка), состав расширений
  reports/           # отчёты bsl-check (json/sarif), НЕ в git
  .bsl-language-server.json
  AGENTS.md          # правила работы (из templates/AGENTS.md.tpl)
  .gitignore         # src/cf, reports/ вне git
```

## Имена

Служебные имена, базы, расширения — только латиница (`A-Za-z0-9-_`).
Проект = база; смена проекта = смена каталога.

## Git

- 1 база = 1 git-репозиторий (`git init -b main`; коммитов при создании нет).
- Ветки — на расширения.
- Conventional Commits: `feat(cfe/perprices): …`, `fix(…): …`, `docs: …`.
- Коммиты — только по явной команде владельца.
- `src/cf` и `reports/` игнорируются.

## Анализ

- Единственный анализатор — bslc (docker, CLI по запросу); Java только в контейнере.
- Источник — `src/cfe/<Расширение>`; контекст типовой — `src/cf` (если непуст).
- Обёртка: `bsl-check <база> <расширение>` (отчёт → reports/).
- Версию образа пинуем (`bslc:1.0.7`), не `latest`.

## Публикация

- Никаких секретов и личных путей; токены — в `.env` (вне git), `.env.example`.
- Идемпотентность скриптов: повторный запуск ничего не меняет.
- Публикация репозитория — только по отдельному «го», private по умолчанию.