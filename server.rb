# frozen_string_literal: true

require "mcp"
require "yaml"
require_relative "lib/adb_device_manager"
require_relative "lib/tools/get_packages_tool"
require_relative "lib/tools/get_ui_layout_tool"
require_relative "lib/tools/get_screenshot_tool"
require_relative "lib/tools/get_package_action_intents_tool"
require_relative "lib/tools/tap_tool"
require_relative "lib/tools/swipe_tool"
require_relative "lib/tools/input_text_tool"
require_relative "lib/tools/press_key_tool"
require_relative "lib/tools/launch_app_tool"
require_relative "lib/tools/stop_app_tool"
require_relative "lib/tools/get_logcat_tool"
require_relative "lib/tools/get_device_info_tool"
require_relative "lib/tools/wait_for_element_tool"

# config.yaml読み込み（オプション）
config = {}
config_path = File.join(__dir__, "config.yaml")
if File.exist?(config_path)
  config = YAML.safe_load_file(config_path) || {}
end

device_name = config.dig("device", "name")

# Lazy-initialize device manager on first tool call
# so the MCP server can start even without a connected device
manager_instance = nil
manager_mutex = Mutex.new

lazy_context = Object.new
lazy_context.define_singleton_method(:[]) do |key|
  case key
  when :device_manager
    manager_mutex.synchronize do
      manager_instance ||= AdbDeviceManager.new(device_name: device_name)
    end
  end
end

server = MCP::Server.new(
  name: "android-mcp-server",
  version: "1.0.0",
  tools: [
    GetPackagesTool,
    GetUiLayoutTool,
    GetScreenshotTool,
    GetPackageActionIntentsTool,
    TapTool,
    SwipeTool,
    InputTextTool,
    PressKeyTool,
    LaunchAppTool,
    StopAppTool,
    GetLogcatTool,
    GetDeviceInfoTool,
    WaitForElementTool,
  ],
  server_context: lazy_context
)

transport = MCP::Server::Transports::StdioTransport.new(server)
transport.open
