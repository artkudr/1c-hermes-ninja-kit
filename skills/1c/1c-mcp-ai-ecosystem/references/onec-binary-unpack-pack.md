# Разборка/сборка бинарных контейнеров 1С (.epf/.erf/.cf) — инструментарий (2026-08-11)

Вопрос владельца: «можно ли oscript использовать для разборки/сборки отчётов (через MCP), какой инструментарий даёт oscript для взаимодействия с конфигурацией». Ответ: **да, полный цикл «контейнер ⇄ XML» возможен без платформы 1С и без java**.

## Контейнер «Формат8»

- .epf/.erf/.cf — бинарный контейнер 1С (сигнатура `FF FF FF 7F`, кодовое имя «Формат8», не zip). Внутри — бинарные блоки со сжатием (макеты, формы).
- Ядро oscript не умеет бинарные примитивы (`ДвоичныеДанные`/`Deflate` отсутствуют) — «в лоб» не разобрать. Но экосистема закрывает это компонентой и внешними утилитами.

## Вариант 1: oscript-компонента `v8unpack` — разборка нативно (read-only)

- Репо: `oscript-library/v8unpack` (4★, master; форк-клон `dmpas/oscript-v8unpack`, 10★, 2026-06). Описание: «Компонента распаковки восьмофайлов для Односкрипта».
- Это нативная oscript-компонента (C#), НЕ java-утилита: классы `ЧтениеФайла8` / `ФайлФормата8`, методы `Извлечь` / `ИзвлечьВсе`.
- **Только parse** — README прямо: «взята только команда parse исключительно для работы с gitsync». Обратной сборки (build) НЕТ.
- Установка: `opm install v8unpack`. Работает внутри autumn-сервера: `Новый ЧтениеФайла8` → `Извлечь` → config.xml + src/*.bsl → дальше наш XML-парсер.

## Вариант 2: `saby-integration/v8unpack` (Python) — полный цикл unpack+pack — выбор для сборки

- Репо: `saby-integration/v8unpack` (98★, pushed 2026-07-22, PyPI `pip install v8unpack`). Основан на Infactum/onec_dtools (Python-реализация v8unpack).
- Полный цикл: **распаковка и запаковка** cf/cfe/epf/erf БЕЗ технологической платформы.
- Отличия от классического v8unpack: структура ≈ метаданным, человекочитаемые имена; код всегда отдельными файлами (можно дробить); общие объекты из субмодулей; двоичные макеты/картинки как есть; файлы в JSON; при сборке под 8.1/8.2 автокомментируются директивы 8.3.
- Назначение: автопостроение приложений 1С (расширения, внешние обработки) под разные платформы из одних исходников + хранение исходников в VCS.
- Вызов из oscript: `ЗапуститьПриложение("python ...")` (в ядре ✅). Python 3.11 на машине есть.

## Вариант 3: `MRDK80/v8unpack-agent` (Python) — LLM-пайплайн, референс под наш кейс

- Репо: `MRDK80/v8unpack-agent` (7★, обновлён 2026-08-09 — свежак на момент проверки, MIT, python>=3.10). Надстройка над saby v8unpack для агентных/LLM-пайплайнов: сам бинарное не трогает, распаковку делает upstream.
- Пайплайн (README): `index_cf → scan_forms → unpack_all_forms → parse_elem_json → object_decoder/type_resolver/catalog_resolver/form_classifier → unpack_erf → extract_skd_queries → skd_queries.json → update_forms_index → check_drift → rag.rebuild`.
- Это буквально сценарий «анализ базы для аналитика»: `unpack_erf` + `extract_skd_queries` дают «какие данные трогает .erf» — аналог нашего статического разбора EDT Template.xml, но для внешних отчётов.

## Смежные oscript-инструменты для конфигурации

- `v8metadata-reader` (oscript-library, 6★, 2025-09): чтение информации о метаданных 1С по файлам исходников — данные поддержки, основная информация о конфигурации, путь к файлу по строке метаданных.
- `v8runner` (oscript-library, 128★, 2026-07): управление запуском 1С из командной строки (конфигуратор/клиент) — штатная выгрузка конфигурации.

## Дизайн MCP-инструментов autumn

```
report_unpack(path.epf) → компонента v8unpack (ЧтениеФайла8/Извлечь) → config.xml + src/*.bsl → наш XML-парсер
report_pack(xml)        → ЗапуститьПриложение("python saby-v8unpack") → path.epf
```

Итог для владельца: разборка — нативно в oscript (компонента), сборка — Python saby v8unpack; платформа и java НЕ нужны; внешние .epf индексируются без ручного «Сохранить как XML» в конфигураторе.

## Проверочные команды (GitHub API без ключей)

```bash
curl -s "https://api.github.com/search/repositories?q=v8unpack+in:name" | python -c "import sys,json;[print(r['full_name'],r.get('description') or '',r['stargazers_count'],r['pushed_at'][:10]) for r in json.load(sys.stdin)['items']]"
curl -s "https://api.github.com/orgs/oscript-library/repos?per_page=100&sort=pushed" | python -c "..."   # фильтр по имени
curl -s "https://raw.githubusercontent.com/<owner>/<repo>/<branch>/README.md"   # ветки перебирать: master/main
```