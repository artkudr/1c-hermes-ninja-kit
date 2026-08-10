# Smoke-тест порта mcp-1c-autumn: все 5 инструментов через официальный MCP Python SDK.
# Данные: qbik-dev (EDT-выгрузка: src/cf — 14k .bsl + 15k .xml).
# Запуск: python port_test.py
import asyncio

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

SERVER = r"C:\hermes\tools\mcp-1c-autumn\main.os"
QBIK_CF = r"C:\hermes\qbik-dev\src\cf"
SMALL_BSL_DIR = r"C:\hermes\qbik-dev\src\cf\AccountingRegisters\Управленческий"
SMALL_BSL = SMALL_BSL_DIR + r"\Ext\ManagerModule.bsl"


def txt(r):
    return "".join(c.text if hasattr(c, "text") else str(c) for c in r.content)


async def main():
    params = StdioServerParameters(
        command="oscript",
        args=[SERVER],
        cwd=r"C:\hermes\tools\mcp-1c-autumn",
    )
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            init = await session.initialize()
            print("serverInfo:", init.serverInfo.name, init.serverInfo.version)
            print("protocolVersion:", init.protocolVersion)

            tools = (await session.list_tools()).tools
            print(f"\ntools/list -> {len(tools)} tools:")
            for t in tools:
                props = t.inputSchema.get("properties", {})
                print(f"  - {t.name}: params {list(props.keys())} | required {t.inputSchema.get('required', [])}")

            # 1) bsl_search: подстрока по реальному BSL (путь с кириллицей)
            r = await session.call_tool("bsl_search", {"path": SMALL_BSL_DIR, "query": "Процедура"})
            lines = txt(r).splitlines()
            print(f"\n== bsl_search('Процедура', {SMALL_BSL_DIR}): hiti = {len(lines)}, isError = {r.isError}")
            for l in lines[:3]:
                print("   ", l[:140])

            # 2) bsl_search: useRegex=true
            r = await session.call_tool(
                "bsl_search",
                {"path": SMALL_BSL_DIR, "query": r"Процедура|Функция", "useRegex": True},
            )
            print(f"== bsl_search(regex): hiti = {len(txt(r).splitlines())}, isError = {r.isError}")

            # 3) xml_search: uuid в XML метаданных (AccountingRegisters — 15 xml, быстро и с реальными хитами)
            r = await session.call_tool(
                "xml_search",
                {"path": r"C:\hermes\qbik-dev\src\cf\AccountingRegisters", "query": "uuid="},
            )
            lines = txt(r).splitlines()
            print(f"\n== xml_search('uuid='): hiti = {len(lines)}, isError = {r.isError}")
            for l in lines[:3]:
                print("   ", l[:140])

            # 4) config_list: дерево глубиной 1
            r = await session.call_tool("config_list", {"path": SMALL_BSL_DIR, "maxDepth": 1})
            print(f"\n== config_list(maxDepth=1): isError = {r.isError}")
            print("   ", txt(r)[:300].replace("\n", "\n    "))

            # 5) read_module: весь модуль
            r = await session.call_tool("read_module", {"path": SMALL_BSL})
            print(f"\n== read_module(whole): isError = {r.isError}, строк = {len(txt(r).splitlines())}")

            # 6) read_module: список объявлений
            r = await session.call_tool("read_module", {"path": SMALL_BSL, "method": "*"})
            print(f"== read_module(method='*'): isError = {r.isError}")
            print("   ", txt(r)[:300].replace("\n", "\n    "))

            # 7) read_module: тело конкретного метода (по имени из объявлений)
            r = await session.call_tool("read_module", {"path": SMALL_BSL, "method": "ПриЗаполненииОграниченияДоступа"})
            lines = txt(r).splitlines()
            print(f"== read_module(method='ПриЗаполненииОграниченияДоступа'): строк = {len(lines)}, isError = {r.isError}")
            if lines:
                print("   first:", lines[0][:120])

            # 8) syntax_help_search: дефолтный резолвинг БД (cwd -> src/data/shcntx_help.db)
            r = await session.call_tool("syntax_help_search", {"query": "Запрос", "limit": 3})
            lines = txt(r).splitlines()
            print(f"\n== syntax_help_search('Запрос', limit 3, db по умолчанию): строк = {len(lines)}, isError = {r.isError}")
            for l in lines[:3]:
                print("   ", l[:130])

            # 9) syntax_help_search: явный dbPath + snippet_length
            r = await session.call_tool(
                "syntax_help_search",
                {
                    "query": "Запрос.Текст",
                    "dbPath": r"C:\hermes\tools\mcp-1c-autumn\src\data\shcntx_help.db",
                    "limit": 2,
                    "snippet_length": 80,
                },
            )
            print(f"== syntax_help_search('Запрос.Текст', dbPath явный, snippet 80): isError = {r.isError}")
            print("   ", txt(r)[:250].replace("\n", "\n    "))

            # 10) отрицательный тест: нет обязательного параметра
            r = await session.call_tool("bsl_search", {"query": "Процедура"})
            print(f"\n== bsl_search(no path): isError = {r.isError}")
            print("   ", txt(r)[:150].replace("\n", " "))


asyncio.run(main())