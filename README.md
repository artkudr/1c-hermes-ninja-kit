# 1c-hermes-ninja-kit

**Самоустанавливающийся плейбук ИИ-экосистемы разработки 1С.**

Ставит окружение (oscript последней версии, анализатор bslc в docker, opm-пакеты),
создаёт 1С-базы по единой конвенции и даёт агентам (Hermes и другим) понятный
контур работы: `src/cf` — типовая (read-only контекст), `src/cfe/*` — расширения.

## Быстрый старт (чистая машина с Hermes + Docker)

1. Hermes читает ссылку на этот репозиторий, спрашивает корневую папку проектов
   (например `C:/hemes`) и клонирует себя туда.
2. `bash install/install.sh "C:/hemes"` — идемпотентная установка:
   - oscript (последняя стабильная версия, самодостаточный zip в `tools/engine`,
     без UAC — winget-каталог отстаёт, не используем);
   - opm-пакеты (`sql`, `autumn`, `autumn-mcp`); `yaxunit` — отдельно из git;
   - docker-образ bslc: официальный ghcr → если недоступен, локальный образ
     из exec-jar с Maven Central (`install/bslc/Dockerfile`, Java только в контейнере);
   - создаётся `C:/hemes/tools/` (всё не-докерное: `.env`, `projects.json`, движки).
3. Повторный запуск безопасен — скрипт идемпотентный.

## Работа с базами

```bash
bash scripts/ninja.sh new <имя> --ext <ExtA> [--ext <ExtB> …]  # создать базу
bash scripts/ninja.sh list        # реестр баз (tools/projects.json)
bash scripts/ninja.sh scan        # базы на диске + кто не в реестре

bash scripts/bsl-check.sh <база> <расширение> [--reporter json|sarif]
                                  # статический анализ расширения (bslc в docker)
```

Структура каждой базы:

```
<имя>/
  src/cf/            # выгрузка типовой — read-only, в git не хранится
  src/cfe/<Расширение>/  # расширения (единственное, что линтуем)
  notes/registry.md  # реестр: версия типовой одной строкой
  reports/           # отчёты анализа
  .bsl-language-server.json  AGENTS.md  .gitignore
```

## Документация

- `docs/INSTALL.md` — пошаговое руководство, **каждый пункт проверен исполнением**;
- `docs/CONVENTIONS.md` — конвенции структуры и git;
- `docs/DECISIONS.md` — почему именно так (bslc, zip-oscript, локальный образ и т.п.).

## Лицензия

MIT. Публикация на GitHub — по решению владельца (по умолчанию private).
Секретов и личных путей в репозитории нет: токены — в `.env` (вне git),
ориентиры — в `.env.example`.