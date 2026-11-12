#!/usr/bin/env python3
"""Direct HTTP client for the Unreal MCP endpoint when IDE tools are unavailable.

Commands:
  init    Initialize a session and write its id to a file.
  call    Invoke a toolset tool through the generic call_tool meta-tool.
  list    Print the available toolset list.
  describe  Print one toolset schema.

Examples:
  python mcp_direct.py init --session-file .mcp-session
  python mcp_direct.py call --session-file .mcp-session ^
    --toolset editor_toolset.toolsets.asset.AssetTools --tool save_assets ^
    --args '{"asset_paths":["/Game/Foo"]}'
  python mcp_direct.py list --session-file .mcp-session
  python mcp_direct.py describe --session-file .mcp-session ^
    --toolset editor_toolset.toolsets.asset.AssetTools
"""

import argparse
import json
import pathlib
import sys
import time
import urllib.error
import urllib.request


DEFAULT_PORT = 8000
DEFAULT_PROTOCOL = "2025-03-26"


def base_url(port: int) -> str:
    return f"http://127.0.0.1:{port}/mcp"


def post(
    url: str,
    payload: dict | None,
    session_id: str | None = None,
    timeout: int = 300,
) -> tuple[int, str, str | None]:
    body = b"" if payload is None else json.dumps(payload, ensure_ascii=False).encode("utf-8")
    headers = {
        "Content-Type": "application/json; charset=utf-8",
        "Accept": "application/json, text/event-stream",
    }
    if session_id:
        headers["mcp-session-id"] = session_id
    request = urllib.request.Request(url, data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            status = response.status
            raw = response.read()
            returned_session = response.headers.get("mcp-session-id")
    except urllib.error.HTTPError as error:
        status = error.code
        raw = error.read()
        returned_session = error.headers.get("mcp-session-id") if error.headers else None
    return status, raw.decode("utf-8", errors="replace"), returned_session


def decode_response(text: str) -> dict:
    """Decode a plain JSON response or concatenate the data lines of an SSE response."""
    stripped = text.strip()
    if not stripped.startswith("data:"):
        return json.loads(stripped)

    data_lines = []
    for line in stripped.splitlines():
        if line.startswith("data:"):
            data_lines.append(line[5:].lstrip())
    return json.loads("\n".join(data_lines))


def rpc(url: str, method: str, params: dict | None, session_id: str | None) -> dict:
    payload = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": method,
    }
    if params is not None:
        payload["params"] = params

    last_error = None
    for attempt in range(3):
        try:
            _, response_text, _ = post(url, payload, session_id)
            if not response_text.strip():
                raise RuntimeError("empty HTTP response")
            decoded = decode_response(response_text)
            if "error" in decoded:
                raise RuntimeError(json.dumps(decoded["error"], ensure_ascii=False))
            return decoded
        except (RuntimeError, urllib.error.URLError, json.JSONDecodeError) as error:
            last_error = error
            if attempt < 2:
                time.sleep(0.7)
    raise RuntimeError(f"MCP request failed after retries: {last_error}")


def response_text(decoded: dict) -> str:
    result = decoded.get("result", {})
    if result.get("isError"):
        content = result.get("content") or []
        text = content[0].get("text", "") if content else json.dumps(result, ensure_ascii=False)
        raise RuntimeError(text)
    content = result.get("content") or []
    if not content:
        return json.dumps(result, ensure_ascii=False)
    return "\n".join(str(item.get("text", "")) for item in content if item.get("text") is not None)


def call_tool(url: str, session_id: str, toolset: str, tool: str, arguments: dict) -> str:
    params = {
        "name": "call_tool",
        "arguments": {
            "toolset_name": toolset,
            "tool_name": tool,
            "arguments": arguments,
        },
    }
    return response_text(rpc(url, "tools/call", params, session_id))


def list_toolsets(url: str, session_id: str) -> str:
    return response_text(rpc(url, "tools/call", {"name": "list_toolsets"}, session_id))


def describe_toolset(url: str, session_id: str, toolset: str) -> str:
    params = {"name": "describe_toolset", "arguments": {"toolset_name": toolset}}
    return response_text(rpc(url, "tools/call", params, session_id))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser("init", help="initialize and save a session id")
    init_parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    init_parser.add_argument("--protocol", default=DEFAULT_PROTOCOL)
    init_parser.add_argument("--session-file", default=".mcp-session")

    call_parser = subparsers.add_parser("call", help="call a toolset tool")
    call_parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    call_parser.add_argument("--session-file", required=True)
    call_parser.add_argument("--toolset", required=True)
    call_parser.add_argument("--tool", required=True)
    call_parser.add_argument("--args", default="{}")

    list_parser = subparsers.add_parser("list", help="list toolsets")
    list_parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    list_parser.add_argument("--session-file", required=True)

    describe_parser = subparsers.add_parser("describe", help="describe one toolset")
    describe_parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    describe_parser.add_argument("--session-file", required=True)
    describe_parser.add_argument("--toolset", required=True)

    args = parser.parse_args()
    url = base_url(args.port)

    if args.command == "init":
        initialize_payload = {
            "protocolVersion": args.protocol,
            "capabilities": {},
            "clientInfo": {"name": "dz-ue-tools-direct", "version": "1.0"},
        }
        _, response_text_raw, session_id = post(url, initialize_payload, None, timeout=30)
        if not session_id:
            raise RuntimeError("server did not provide mcp-session-id")
        decoded = decode_response(response_text_raw)
        if "error" in decoded:
            raise RuntimeError(json.dumps(decoded["error"], ensure_ascii=False))
        post(
            url,
            {"jsonrpc": "2.0", "method": "notifications/initialized"},
            session_id,
            timeout=30,
        )
        pathlib.Path(args.session_file).write_text(session_id, encoding="utf-8")
        print(session_id)
        return 0

    session_id = pathlib.Path(args.session_file).read_text(encoding="utf-8").strip()
    if not session_id:
        raise RuntimeError(f"empty session file: {args.session_file}")

    if args.command == "list":
        print(list_toolsets(url, session_id))
    elif args.command == "describe":
        print(describe_toolset(url, session_id, args.toolset))
    else:
        arguments = json.loads(args.args)
        print(call_tool(url, session_id, args.toolset, args.tool, arguments))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(1)
