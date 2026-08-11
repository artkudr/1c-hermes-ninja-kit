#!/usr/bin/env python3
"""Probe any stdio MCP server BEFORE registering it in Hermes.

Initializes the server, lists tools, optionally calls one tool — proves
transport, encoding and parameter names before Hermes ever sees the server.
Works for lekot/mcp-1c, bsl-analyzer, rlm-tools and any stdio JSON-RPC MCP.

Usage:
  python probe_stdio_mcp.py --command oscript \
      --args "C:\\hermes\\tools\\mcp-1c\\main.os" \
      --tool bsl_search --call '{"path":"C:\\proj\\src\\cfe","query":"Процедура"}'

Requirements: python 3.11+, `mcp` SDK (pip install mcp).
"""
import argparse
import asyncio
import json

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


async def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--command", required=True, help="binary to spawn (e.g. oscript, npx, java)")
    ap.add_argument("--args", action="append", default=[], help="arg for the command (repeatable)")
    ap.add_argument("--tool", default=None, help="optional: call a tool after listing")
    ap.add_argument("--call", default=None, help='optional: JSON arguments for --tool, e.g. \'{"query":"X"}\'')
    a = ap.parse_args()

    params = StdioServerParameters(command=a.command, args=a.args)
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            init = await session.initialize()
            print("server:", init.serverInfo.name, init.serverInfo.version, flush=True)
            tools = (await session.list_tools()).tools
            print("tools:", len(tools), flush=True)
            for t in tools:
                print("  -", t.name, "|", (t.description or "")[:70], flush=True)
            if a.tool:
                args = json.loads(a.call) if a.call else {}
                r = await session.call_tool(a.tool, args)
                txt = "".join(c.text if hasattr(c, "text") else str(c) for c in r.content)
                print(f"\n== {a.tool}: isError={r.isError}", flush=True)
                print(txt[:2000], flush=True)


if __name__ == "__main__":
    asyncio.run(main())