# frozen_string_literal: true

require "mcp"

class LaunchAppTool < MCP::Tool
  tool_name "launch_app"
  description "Launch an app on the device. If activity is omitted, launches via the default launcher intent."
  input_schema(
    properties: {
      package_name: { type: "string", description: "The package name to launch (e.g. com.example.myapp)" },
      activity: { type: "string", description: "The activity to launch (e.g. .MainActivity). Optional." }
    },
    required: ["package_name"]
  )

  class << self
    def call(package_name:, activity: nil, server_context:)
      manager = server_context[:device_manager]
      manager.launch_app(package_name, activity: activity)
      msg = activity ? "Launched #{package_name}/#{activity}" : "Launched #{package_name}"
      MCP::Tool::Response.new([{ type: "text", text: msg }])
    end
  end
end
