# frozen_string_literal: true

require "mcp"

class GetUiLayoutTool < MCP::Tool
  tool_name "get_uilayout"
  description "Retrieves information about UI elements in the current screen, including text, descriptions, bounds and center coordinates. By default returns only clickable elements. Set clickable_only to false to return all elements (useful for verifying displayed text and error messages)."
  input_schema(
    properties: {
      clickable_only: { type: "boolean", description: "If true, return only clickable elements. If false, return all elements. (default: true)" }
    }
  )

  class << self
    def call(clickable_only: true, server_context:)
      manager = server_context[:device_manager]
      result = manager.get_uilayout(clickable_only: clickable_only)
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end
