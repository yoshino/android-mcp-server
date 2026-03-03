# frozen_string_literal: true

require "mcp"

class StopAppTool < MCP::Tool
  tool_name "stop_app"
  description "Force-stop an app on the device. Useful for resetting app state between tests."
  input_schema(
    properties: {
      package_name: { type: "string", description: "The package name to stop (e.g. com.example.myapp)" }
    },
    required: ["package_name"]
  )

  class << self
    def call(package_name:, server_context:)
      manager = server_context[:device_manager]
      manager.stop_app(package_name)
      MCP::Tool::Response.new([{ type: "text", text: "Stopped #{package_name}" }])
    end
  end
end
