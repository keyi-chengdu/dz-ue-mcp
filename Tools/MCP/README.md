# MCP direct-call tools

Use these helpers when the chat session does not expose `mcp__unreal__*`, but the
editor's local MCP server is running on `http://127.0.0.1:8000/mcp`.

| Tool | Purpose |
|---|---|
| `mcp_direct.py` | Initialize a Streamable HTTP session, call a toolset tool, list toolsets, or describe a toolset schema. |

Initialize:

```powershell
python .\mcp_direct.py init --session-file C:\path\to\mcp-session.txt
```

Call:

```powershell
python .\mcp_direct.py call --session-file C:\path\to\mcp-session.txt `
  --toolset editor_toolset.toolsets.asset.AssetTools `
  --tool save_assets `
  --args '{"asset_paths":["/Game/Foo"]}'
```

The `call` command retries transient empty responses, decodes JSON and SSE
responses, prints the first text content item, and exits nonzero when Unreal
returns an MCP tool error.
