# frozen_string_literal: true

require "mcp"

class SwipeTool < MCP::Tool
  tool_name "swipe"
  description "Swipe on the device screen from start to end coordinates. Useful for scrolling and page navigation."
  input_schema(
    properties: {
      start_x: { type: "integer", description: "Start X coordinate" },
      start_y: { type: "integer", description: "Start Y coordinate" },
      end_x: { type: "integer", description: "End X coordinate" },
      end_y: { type: "integer", description: "End Y coordinate" },
      duration_ms: { type: "integer", description: "Swipe duration in milliseconds (default: 300)" }
    },
    required: ["start_x", "start_y", "end_x", "end_y"]
  )

  class << self
    def call(start_x:, start_y:, end_x:, end_y:, duration_ms: 300, server_context:)
      manager = server_context[:device_manager]
      manager.swipe(start_x, start_y, end_x, end_y, duration_ms)
      MCP::Tool::Response.new([{ type: "text", text: "Swiped from (#{start_x}, #{start_y}) to (#{end_x}, #{end_y}) in #{duration_ms}ms" }])
    end
  end
end
