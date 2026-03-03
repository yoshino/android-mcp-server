# Android MCP Server

An MCP server that allows you to control Android devices from MCP clients such as Gemini CLI and Claude Code.
Built with Ruby and delivered as a Docker container. Communicates via stdio transport (JSON-RPC).

[日本語版 README](README.ja.md)

## Available Tools

### UI Operations

| Tool | Description |
|---|---|
| `tap` | Tap at specified coordinates |
| `swipe` | Swipe gesture (scroll, page navigation, etc.) |
| `input_text` | Enter text into the focused field |
| `press_key` | Send key events (BACK, HOME, ENTER, etc.) |

### App Management

| Tool | Description |
|---|---|
| `launch_app` | Launch an app (via launcher intent or specific Activity) |
| `stop_app` | Force stop an app (for resetting state between tests) |
| `get_packages` | List installed packages |
| `get_package_action_intents` | List action intents for a package |

### Screen & Device Information

| Tool | Description |
|---|---|
| `get_screenshot` | Capture a screenshot |
| `get_uilayout` | Get UI element info (text, coordinates, etc. — all elements or clickable only) |
| `get_device_info` | Get device info (model name, Android version, screen size, etc.) |
| `get_logcat` | Retrieve logcat logs (for crash/error detection) |

## Prerequisites

- Docker
- Android SDK Platform-Tools (ADB)
- Android device or emulator

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/yoshino/android-mcp-server.git
cd android-mcp-server
```

### 2. Build the Docker Image

```bash
docker build -t android-mcp-server .
```

### 3. Verify ADB Server is Running

The ADB server must be running on the host (it starts automatically if Android Studio is open).

```bash
adb start-server
adb devices  # Verify your device is listed
```

### 4. Verify Installation

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}' \
  | docker run --rm -i android-mcp-server
```

If you receive a JSON response containing `serverInfo`, the setup is complete.

## MCP Client Configuration

### Gemini CLI

Create `.gemini/settings.json` in your project root:

```json
{
  "mcpServers": {
    "android": {
      "command": "docker",
      "args": [
        "run", "--rm", "-i",
        "-e", "ANDROID_ADB_SERVER_ADDRESS=host.docker.internal",
        "-e", "ANDROID_ADB_SERVER_PORT=5037",
        "android-mcp-server"
      ]
    }
  }
}
```

### Claude Code

Create `.mcp.json` in your project root:

```json
{
  "mcpServers": {
    "android": {
      "command": "docker",
      "args": [
        "run", "--rm", "-i",
        "-e", "ANDROID_ADB_SERVER_ADDRESS=host.docker.internal",
        "-e", "ANDROID_ADB_SERVER_PORT=5037",
        "android-mcp-server"
      ]
    }
  }
}
```

## Configuration (Optional)

If multiple devices are connected, you can specify the target device in `config.yaml`.

```bash
cp config.yaml.example config.yaml
```

```yaml
device:
  name: "emulator-5554"  # Serial number shown by adb devices
```

Rebuild the Docker image after updating the configuration.

## Testing

Run tests via Docker (no local Ruby environment required).

```bash
# Build image (first time or after code changes)
docker build -t android-mcp-server .

# Run all tests
docker run --rm android-mcp-server bundle exec rspec --format documentation

# Run specific test file
docker run --rm android-mcp-server bundle exec rspec spec/adb_device_manager_spec.rb
docker run --rm android-mcp-server bundle exec rspec spec/tools_spec.rb
```

## Architecture

```
MCP Client (Gemini CLI / Claude Code)
    │ stdio (JSON-RPC)
    ▼
Docker Container
    ├── server.rb          (MCP Server - stdio transport)
    ├── lib/tools/*.rb     (12 MCP Tool classes)
    └── lib/adb_device_manager.rb (ADB command execution)
            │ ADB_SERVER_HOST=host.docker.internal
            ▼
Host ADB Server (port 5037)
    │
    ▼
Android Device / Emulator
```

## References

- [minhalvp/android-mcp-server](https://github.com/minhalvp/android-mcp-server)
- [Ruby MCP SDK](https://github.com/modelcontextprotocol/ruby-sdk)
