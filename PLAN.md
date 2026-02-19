# Android MCP Server (Ruby実装) - 実装計画

## 概要
参考リポジトリ (https://github.com/minhalvp/android-mcp-server) のPython実装をRubyで再実装する。
Android Studio (Gemini) からMCPサーバー経由でAndroidデバイスを操作できるようにする。

---

## 実装タスク

### Step 1: プロジェクト基盤
- [ ] `Gemfile` 作成
- [ ] `Dockerfile` 作成

### Step 2: コア実装
- [ ] `lib/adb_device_manager.rb` - AdbDeviceManager クラス
  - [ ] `initialize` / `check_adb_installed!` / `available_devices`
  - [ ] `get_packages`
  - [ ] `execute_adb_shell_command`
  - [ ] `get_uilayout`
  - [ ] `take_screenshot`
  - [ ] `get_package_action_intents`

### Step 3: MCPツール
- [ ] `lib/tools/get_packages_tool.rb`
- [ ] `lib/tools/execute_adb_command_tool.rb`
- [ ] `lib/tools/get_ui_layout_tool.rb`
- [ ] `lib/tools/get_screenshot_tool.rb`
- [ ] `lib/tools/get_package_action_intents_tool.rb`

### Step 4: エントリポイント・設定
- [ ] `server.rb` - メインエントリポイント
- [ ] `config.yaml.example` - 設定ファイルサンプル

### Step 5: ビルド・動作確認
- [ ] `docker build` 成功
- [ ] `docker run --rm -i` で起動確認（stdioモードで待機）
- [ ] Android Studio MCP設定で接続確認

---

## 環境
- **開発・実行環境**: Docker コンテナ（ローカル環境を汚さない）
- Ruby 3.3, Bundler
- ADB: コンテナ内にインストール。ホスト側のADBサーバー (`host.docker.internal:5037`) に接続
- MCP SDK: `mcp` gem (v0.6.0+)
- トランスポート: stdio

## Docker構成

MCPサーバーはstdioトランスポートのため、コンテナのstdin/stdoutが直接MCPクライアントと接続される。
ホスト側で起動しているADBサーバーにネットワーク経由で接続する。

### 前提条件
- ホスト側で `adb start-server` が実行済み（Android Studioが起動していればOK）
- Androidデバイス/エミュレータがホスト側ADBに接続済み

### ADB接続方式
コンテナ内から `ADB_SERVER_HOST=host.docker.internal` を設定し、ホスト側のADBサーバー (port 5037) に接続する。
これにより、USB接続のデバイスもエミュレータもコンテナ内から操作可能。

## ディレクトリ構成

```
android-mcp-server/
├── Dockerfile
├── Gemfile
├── server.rb                  # エントリポイント
├── config.yaml.example        # 設定ファイルサンプル
└── lib/
    ├── adb_device_manager.rb  # ADBデバイス管理クラス
    └── tools/
        ├── get_packages_tool.rb
        ├── execute_adb_command_tool.rb
        ├── get_ui_layout_tool.rb
        ├── get_screenshot_tool.rb
        └── get_package_action_intents_tool.rb
```

---

## ファイル別 実装詳細

### 0. `Dockerfile`

```dockerfile
FROM ruby:3.3-slim

# ADB (android-tools) インストール
RUN apt-get update && \
    apt-get install -y --no-install-recommends android-tools-adb && \
    rm -rf /var/lib/apt/lists/*

# ホスト側ADBサーバーに接続するための環境変数
ENV ADB_SERVER_HOST=host.docker.internal

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

# stdioトランスポート: stdin/stdoutをそのまま使う
CMD ["bundle", "exec", "ruby", "server.rb"]
```

ポイント:
- `ruby:3.3-slim` ベースで軽量
- `android-tools-adb` パッケージでadbクライアントをインストール
- `ADB_SERVER_HOST=host.docker.internal` でホスト側ADBサーバーに接続
- CMD で stdio モードのサーバーを起動

### 1. `Gemfile`

```ruby
source "https://rubygems.org"

gem "mcp"
gem "nokogiri"
gem "base64"
```

- `mcp`: 公式Ruby MCP SDK（サーバー・ツール定義・stdioトランスポート）
- `nokogiri`: UI hierarchy XMLのパース
- `base64`: スクリーンショットのBase64エンコード

---

### 2. `lib/adb_device_manager.rb` - AdbDeviceManager クラス

ADBコマンドを `Open3.capture2` で直接実行する。Python版が `ppadb` を使っていた部分もすべてadbコマンド経由で実現。

#### メソッド一覧

| メソッド | 説明 |
|---|---|
| `initialize(device_name: nil)` | デバイス自動選択 or 指定。ADB存在確認→デバイス一覧→選択 |
| `check_adb_installed!` | `adb version` 実行、失敗時は例外 |
| `available_devices` | `adb devices` パースしてシリアル番号の配列を返す |
| `get_packages` | `adb shell pm list packages` → `package:` prefix除去 → 改行区切り文字列 |
| `execute_adb_shell_command(command)` | 先頭の `adb shell` / `adb` を除去してから `adb -s <device> shell <command>` 実行 |
| `get_uilayout` | `uiautomator dump` → XML取得 → Nokogiriでパース → clickable要素のtext/content-desc/bounds/中心座標を抽出 |
| `take_screenshot` | `screencap` → pull → Base64文字列を返す |
| `get_package_action_intents(package_name)` | `dumpsys package <pkg>` → Activity Resolver Table解析 → `android.*` / `com.*` のアクション抽出 |

#### 実装ポイント

- **ADBパス**: コンテナ内では `adb` がPATHに存在するためデフォルトは `"adb"`
- **デバイス選択**: デバイスが1台ならそれを自動選択、複数台なら `device_name` 指定必須
- **コマンド実行**: すべて `Open3.capture2` で実行し、終了ステータスも確認
- **スクリーンショット**: `adb exec-out screencap -p` でPNGバイナリを直接取得 → Base64エンコード
  - Python版はPILで30%リサイズしているが、Ruby版では外部依存を減らすためリサイズは省略
- **UIレイアウト**: `uiautomator dump /dev/tty` でXMLを直接stdout取得 → Nokogiriパース
  - bounds `[x1,y1][x2,y2]` から中心座標 `((x1+x2)/2, (y1+y2)/2)` を計算
  - clickable=true かつ text or content-desc が空でない要素のみ抽出

---

### 3. `lib/tools/*.rb` - MCPツール定義

各ツールは `MCP::Tool` を継承し、`call` クラスメソッドで処理を実行する。
`server_context` 経由で `AdbDeviceManager` インスタンスを受け取る。

#### 3-1. `GetPackagesTool`

```ruby
class GetPackagesTool < MCP::Tool
  tool_name "get_packages"
  description "Get all installed packages on the device"
  input_schema(properties: {})

  class << self
    def call(server_context:)
      manager = server_context[:device_manager]
      result = manager.get_packages
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end
```

#### 3-2. `ExecuteAdbCommandTool`

```ruby
class ExecuteAdbCommandTool < MCP::Tool
  tool_name "execute_adb_shell_command"
  description "Executes an ADB command and returns the output or an error"
  input_schema(
    properties: {
      command: { type: "string", description: "The shell instruction to run" }
    },
    required: ["command"]
  )

  class << self
    def call(command:, server_context:)
      manager = server_context[:device_manager]
      result = manager.execute_adb_shell_command(command)
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end
```

#### 3-3. `GetUiLayoutTool`

```ruby
class GetUiLayoutTool < MCP::Tool
  tool_name "get_uilayout"
  description "Retrieves information about clickable elements in the current UI, including text, descriptions, bounds and center coordinates"
  input_schema(properties: {})

  class << self
    def call(server_context:)
      manager = server_context[:device_manager]
      result = manager.get_uilayout
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end
```

#### 3-4. `GetScreenshotTool`

```ruby
class GetScreenshotTool < MCP::Tool
  tool_name "get_screenshot"
  description "Takes a screenshot of the device and returns it"
  input_schema(properties: {})

  class << self
    def call(server_context:)
      manager = server_context[:device_manager]
      base64_data = manager.take_screenshot
      MCP::Tool::Response.new([{
        type: "image",
        data: base64_data,
        mime_type: "image/png"
      }])
    end
  end
end
```

#### 3-5. `GetPackageActionIntentsTool`

```ruby
class GetPackageActionIntentsTool < MCP::Tool
  tool_name "get_package_action_intents"
  description "Get all non-data actions from Activity Resolver Table for a package"
  input_schema(
    properties: {
      package_name: { type: "string", description: "The package name to get intents for" }
    },
    required: ["package_name"]
  )

  class << self
    def call(package_name:, server_context:)
      manager = server_context[:device_manager]
      intents = manager.get_package_action_intents(package_name)
      MCP::Tool::Response.new([{ type: "text", text: intents.join("\n") }])
    end
  end
end
```

---

### 4. `server.rb` - エントリポイント

```ruby
require "mcp"
require "yaml"
require_relative "lib/adb_device_manager"
require_relative "lib/tools/get_packages_tool"
require_relative "lib/tools/execute_adb_command_tool"
require_relative "lib/tools/get_ui_layout_tool"
require_relative "lib/tools/get_screenshot_tool"
require_relative "lib/tools/get_package_action_intents_tool"

# config.yaml読み込み（オプション）
config = {}
config_path = File.join(__dir__, "config.yaml")
if File.exist?(config_path)
  config = YAML.safe_load_file(config_path) || {}
end

device_name = config.dig("device", "name")
device_manager = AdbDeviceManager.new(device_name: device_name)

server = MCP::Server.new(
  name: "android-mcp-server",
  version: "1.0.0",
  tools: [
    GetPackagesTool,
    ExecuteAdbCommandTool,
    GetUiLayoutTool,
    GetScreenshotTool,
    GetPackageActionIntentsTool,
  ],
  server_context: { device_manager: device_manager }
)

transport = MCP::Server::Transports::StdioTransport.new(server)
transport.open
```

---

### 5. `config.yaml.example`

```yaml
# Android MCP Server Configuration

# Device configuration (optional)
# device:
#   name: "emulator-5554"  # Specify device serial number
```

---

## 動作確認方法

### Dockerイメージビルド
```bash
docker build -t android-mcp-server .
```

### 起動テスト（対話的に確認）
```bash
docker run --rm -i android-mcp-server
```
stdioモードで待機状態になればOK。`--add-host` は不要（Docker Desktop for Macは `host.docker.internal` を自動解決）。

### Android Studio MCP設定
```json
{
  "mcpServers": {
    "android": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "android-mcp-server"]
    }
  }
}
```

stdioトランスポートのため、`docker run -i`（interactive、stdin接続）で起動する。
`-t` (tty割当) は付けない（JSON-RPCバイナリストリームが壊れるため）。

---

## Python版との差異

| 項目 | Python版 | Ruby版 |
|------|----------|--------|
| 実行環境 | ローカル (uv) | Docker コンテナ |
| ADB接続 | `ppadb` ライブラリ経由 | `adb` コマンド直接実行 (`Open3`) → ホストADBサーバー経由 |
| XMLパース | `xml.etree.ElementTree` | `Nokogiri` |
| スクリーンショットリサイズ | PIL で30%リサイズ | リサイズなし（元サイズPNG） |
| MCP SDK | Python MCP SDK | `mcp` gem (Ruby SDK) |
| ツール定義 | デコレータベース | クラス継承ベース (`MCP::Tool`) |
