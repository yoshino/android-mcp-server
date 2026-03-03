# frozen_string_literal: true

require "mcp"

class InputTextTool < MCP::Tool
  tool_name "input_text"
  description "Input text into the currently focused field on the device"
  input_schema(
    properties: {
      text: { type: "string", description: "The text to input" }
    },
    required: ["text"]
  )

  class << self
    def call(text:, server_context:)
      manager = server_context[:device_manager]
      manager.input_text(text)
      MCP::Tool::Response.new([{ type: "text", text: "Input text: #{text}" }])
    end
  end
end
