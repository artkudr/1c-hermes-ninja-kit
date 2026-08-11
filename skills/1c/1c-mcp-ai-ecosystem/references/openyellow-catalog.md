# OpenYellow catalog: API, скрейп, классификация

## API (рабочий, проверено 2026-08)

- Base: `https://openyellow.openintegrations.dev/api`
- `GET /api/repos/stats` — количество репо/авторов
- `GET /api/repos/filters` — доступные фильтры
- `GET /api/repos?filter=top&pageSize=N&page=P` — список карточек
- **pageSize капается до 100** (запрос 4000 вернул 100). Полный дамп: 36 страниц по 100 → 3587 репозиториев на 2026-08-08.
- `filter=top` = весь каталог (не только топ).
- Карточка: `name`, `url`, `author`, `stars`, `license`, `description`, `tags`, `ai_summary`, `updated`, `isFork`, `createddate` (точный состав ключей — как в первой карточке ответа).

## Пагинация (python3, без зависимостей)

```python
import json, urllib.request
base = "https://openyellow.openintegrations.dev/api/repos?filter=top&pageSize=100&page={}"
all_repos = []
p = 1
while True:
    with urllib.request.urlopen(base.format(p), timeout=30) as r:
        data = json.load(r)
    items = data if isinstance(data, list) else data.get("items", data.get("repos", []))
    if not items: break
    all_repos.extend(items)
    p += 1
    if len(items) < 100: break
json.dump(all_repos, open("oy_all_repos.json", "w", encoding="utf-8"), ensure_ascii=False)
# всего: 3587
```

## Поля классификации и шум

- **Отбор строго по `name + description + tags`** с word-boundary regex. `ai_summary` шумит: «инструкции», «агент» в иных смыслах, «бот» — подстрока «работ» (например «работа»).
- «МСП» в каталоге нет ни одного репозитория — термин пользователя расшифрован как MCP (подтверждено в диалоге).
- Дедуп форков: предпочитать `isFork=0`; иначе максимум звёзд. Имя может встречаться у исходного автора и у форкеров (SandersNeo и др.).

## Итоговая схема категорий (T1–T14) с количествами на 2026-08

| Категория | Репо | Топ-3 (звёзды) |
|---|---|---|
| T1 Каталоги_и_гайды | 4 | 1c-mcp (Untru, 135), neuraldeep (100), cc-1c-init (15) |
| T2 Фреймворки_MCP | 4 | 1c_mcp (474), mcp-1c-platform-tools (29), autumn-mcp (23) |
| T3 MCP_данные_и_метаданные | 29 | OpenIntegrations (660), EDT-MCP (240), 1c-mcp-toolkit (224) |
| T4 MCP_контекст_платформы | 10 | mcp-bsl-platform-context (185), mcp-bsl-lsp-bridge (66), platform-context-exporter (47) |
| T5 MCP_семантика_и_RAG | 8 | rlm-tools-bsl (168), mcp-1c-v1 (162), code-index-mcp (93) |
| T6 MCP_Напарник | 6 | 1c-buddy (92), spring-mcp-1c-copilot (44), 1C-ai-mcp (21) |
| T7 MCP_инфраструктура | 4 | compose4mcp (36), perform_comparison_1c_rag_mcp (29), 1c-trusted-gateway (27) |
| T8 Навыки_и_агенты | 29 | cc-1c-skills (509), vscode-1c-platform-tools (151), 1c-ai-feature-dev-workflow (151) |
| T9 ИИ_ассистенты | 10 | mini-ai-1c (238), AI_agent (81), 1c-designer-copilot (23) |
| T10 LLM_интеграции | 14 | 1c-ai-connector (77), deepseek_for_1c (22), GigaChat_SDK_1C (20) |
| T11 Бенчмарки_LLM | 6 | llm_1c_benckmark (29), prism (24), bench (14) |
| T12 RAG_базы_знаний | 9 | scraping_its (48), 1c-analyzer-wiki-rag (40), hbk-to-md (10) |
| T13 OCR_речь | 3 | TesseractOCR1C (17), speechrecognizer (8), Voice1C (1) |
| T14 Инфраструктура_AI | 15 | 1c-language-parser (67), bsl-parser (62), hbk-viewer (33) |

Итого 159 (в CSV 151 после ручной курации и удалением дублей/плагинов — числа зависят от даты дампа; пересоздавать при свежем скрейпе).

## Мусор, который выкидываем при курации

EDT/VSCode-плагины (`edt.*`, `vscode*`, `edt-plugin-*`), сканеры ШК (`androidscannerdriverfor1c`, `scansoft`, `infoscan-*`), парсеры логов/ТЖ (не-AI), CI-пайплайны (`jenkins*`, `erp_feature`), «журналы» экспортеры (YY.*), гермаршал-мусор (рюкзаки `Aqarionz-desighLabz`, `lopassss12kvnwdf`), вики/хайди-хай-синтаксис (не MCP/AI).

## Артефакты на диске (Windows)

- `C:\Users\artkudr\oy_all_repos.json` — полный дамп 3587 карточек (~4 МБ)
- `C:\Users\artkudr\oy_classify.py` — категоризатор (правила, dedup, корзина) → `oy_selected.json`
- `C:\Users\artkudr\oy_build.py` — дедуп форков + ручная карта исключений/переносов → `oy_final.json`
- `C:\Users\artkudr\oy_report.py` — генерация MD+CSV из `oy_final.json`
- `C:\Users\artkudr\oy-catalog\1c-mcp-ai-catalog.md` + `catalog.csv` — итоговые артефакты
- `C:\Users\artkudr\oy-readmes\` — выкачанные README для анализа

Порядок регенерации: `python oy_build.py` → `python oy_report.py` (используют свои JSON и долгое время не трогают каталог; для полного обновления сначала скрейп → oy_selected... — актуальную последовательность смотри в oy_classify.py: он читает `oy_all_repos.json`).