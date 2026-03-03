# frozen_string_literal: true

require "mcp"

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
        mimeType: "image/png"
      }])
    end
  end
end
