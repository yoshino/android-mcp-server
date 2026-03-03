# Android MCP Server

Gemini CLI や Claude Code などの MCP クライアントから、Android デバイスを操作できる MCP サーバーです。
Ruby で実装され、Docker コンテナとして提供されます。stdio トランスポート（JSON-RPC）で動作します。

[English README](README.md)

## 提供ツール

### UI 操作

| ツール名 | 説明 |
|---|---|
| `tap` | 指定座標をタップ |
| `swipe` | スワイプ操作（スクロール・ページ遷移等） |
| `input_text` | フォーカス中のフィールドにテキスト入力 |
| `press_key` | キーイベント送信（BACK, HOME, ENTER 等） |

### アプリ管理

| ツール名 | 説明 |
|---|---|
| `launch_app` | アプリを起動（ランチャーインテント or Activity 指定） |
| `stop_app` | アプリを強制停止（テスト間の状態リセット用） |
| `get_packages` | インストール済みパッケージ一覧を取得 |
| `get_package_action_intents` | パッケージのアクションインテント一覧を取得 |

### 画面・デバイス情報

| ツール名 | 説明 |
|---|---|
| `get_screenshot` | スクリーンショットを撮影 |
| `get_uilayout` | UI 要素情報を取得（テキスト、座標等。全要素 or クリック可能のみ選択可） |
| `get_device_info` | デバイス情報を取得（モデル名、Android バージョン、画面サイズ等） |
| `get_logcat` | logcat ログを取得（クラッシュ・エラー検出用） |

## 前提条件

- Docker
- Android SDK Platform-Tools（ADB）
- Android デバイスまたはエミュレータ

## セットアップ

### 1. リポジトリのクローン

```bash
git clone https://github.com/yoshino/android-mcp-server.git
cd android-mcp-server
```

### 2. Docker イメージのビルド

```bash
docker build -t android-mcp-server .
```

### 3. ADB サーバーの起動確認

ホスト側で ADB サーバーが起動している必要があります（Android Studio が起動していれば自動的に起動済みです）。

```bash
adb start-server
adb devices  # デバイスが表示されることを確認
```

### 4. 動作確認

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}' \
  | docker run --rm -i android-mcp-server
```

`serverInfo` を含む JSON レスポンスが返れば OK です。

## MCP クライアントへの設定

### Gemini CLI

プロジェクトルートに `.gemini/settings.json` を作成:

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

プロジェクトルートに `.mcp.json` を作成:

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

## 設定（オプション）

複数デバイスが接続されている場合、`config.yaml` で対象デバイスを指定できます。

```bash
cp config.yaml.example config.yaml
```

```yaml
device:
  name: "emulator-5554"  # adb devices で表示されるシリアル番号
```

設定後は Docker イメージを再ビルドしてください。

## テスト

Docker 経由で実行します（ローカルに Ruby 環境がなくても OK）。

```bash
# イメージビルド（初回 or コード変更時）
docker build -t android-mcp-server .

# 全テスト実行
docker run --rm android-mcp-server bundle exec rspec --format documentation

# 特定ファイルのみ
docker run --rm android-mcp-server bundle exec rspec spec/adb_device_manager_spec.rb
docker run --rm android-mcp-server bundle exec rspec spec/tools_spec.rb
```

## アーキテクチャ

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

## 参考

- [minhalvp/android-mcp-server](https://github.com/minhalvp/android-mcp-server)
- [Ruby MCP SDK](https://github.com/modelcontextprotocol/ruby-sdk)
