#!/bin/bash
# scripts/start-elixir-ls-mcp.sh

set -e

# Default MCP port calculation (matches elixir-ls behavior: 3789 + hash)
# But we'll try to discover it from running elixir-ls processes or config

ELIXIR_LS_MCP_PORT=""

# Method 1: Check if port is set via environment variable
if [ -n "$ELIXIR_LS_MCP_PORT" ]; then
  echo "Using MCP port from ELIXIR_LS_MCP_PORT: $ELIXIR_LS_MCP_PORT"
  PORT=$ELIXIR_LS_MCP_PORT
else
  # Method 2: Try to find from lsof (if elixir-ls is running)
  PORT=$(lsof -i -P -n 2>/dev/null | grep elixir-ls | grep LISTEN | grep -o ':\*[0-9]*' | head -1 | cut -d: -f2 || echo "")
  
  if [ -z "$PORT" ]; then
    # Method 3: Check elixir-ls config for mcpPort setting
    # Look for .vscode/settings.json or similar
    if [ -f ".vscode/settings.json" ]; then
      PORT=$(grep -o '"elixirLS.mcpPort"\s*:\s*[0-9]*' .vscode/settings.json 2>/dev/null | grep -o '[0-9]*' || echo "")
    fi
    
    # Method 4: Default to 4328 (common default)
    if [ -z "$PORT" ]; then
      PORT=4328
      echo "Warning: Could not detect MCP port, using default: $PORT"
      echo "Make sure elixir-ls is running with MCP enabled"
    fi
  fi
fi

echo "Connecting to elixir-ls MCP server on port $PORT..."

# Start the bridge using the vendored script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elixir "$SCRIPT_DIR/tcp_to_stdio_bridge.exs" "$PORT"