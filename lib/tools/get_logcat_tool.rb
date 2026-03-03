# frozen_string_literal: true

require "mcp"

class GetLogcatTool < MCP::Tool
  tool_name "get_logcat"
  description "Get logcat logs from the device. Useful for detecting crashes and errors during QA testing."
  input_schema(
    properties: {
      tag: { type: "string", description: "Filter by log tag (e.g. MyApp). Optional." },
      level: { type: "string", description: "Log level: V, D, I, W, E, F (default: E)" },
      lines: { type: "integer", description: "Number of recent lines to return (default: 50)" }
    }
  )

  class << self
    def call(tag: nil, level: "E", lines: 50, server_context:)
      manager = server_context[:device_manager]
      result = manager.get_logcat(tag: tag, level: level, lines: lines)
      MCP::Tool::Response.new([{ type: "text", text: result }])
    end
  end
end
