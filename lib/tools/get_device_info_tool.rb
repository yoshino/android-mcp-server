# frozen_string_literal: true

require "mcp"

class GetDeviceInfoTool < MCP::Tool
  tool_name "get_device_info"
  description "Get device information including model name, Android version, SDK version, screen size, and screen density"
  input_schema(properties: {})

  class << self
    def call(server_context:)
      manager = server_context[:device_manager]
      info = manager.get_device_info
      text = [
        "Model: #{info[:model]}",
        "Android Version: #{info[:android_version]}",
        "SDK Version: #{info[:sdk_version]}",
        "Screen Size: #{info[:screen_size]}",
        "Screen Density: #{info[:screen_density]}"
      ].join("\n")
      MCP::Tool::Response.new([{ type: "text", text: text }])
    end
  end
end
