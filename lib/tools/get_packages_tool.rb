# frozen_string_literal: true

require "mcp"

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
