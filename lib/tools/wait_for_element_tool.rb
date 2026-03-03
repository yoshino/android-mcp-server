# frozen_string_literal: true

require "mcp"

class WaitForElementTool < MCP::Tool
  tool_name "wait_for_element"
  description "Wait until a UI element with the specified text or description appears on screen. Useful for waiting after screen transitions or dialog appearance."
  input_schema(
    properties: {
      text: { type: "string", description: "Text of the element to wait for" },
      description: { type: "string", description: "Content description of the element to wait for" },
      timeout_ms: { type: "integer", description: "Maximum wait time in milliseconds (default: 5000)" }
    }
  )

  POLL_INTERVAL = 0.3

  class << self
    def call(text: nil, description: nil, timeout_ms: 5000, server_context:)
      raise "Either text or description must be provided" unless text || description

      manager = server_context[:device_manager]
      timeout_ms = Integer(timeout_ms)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + (timeout_ms / 1000.0)
      target = text || description

      loop do
        element = manager.find_element(text: text, description: description)
        if element
          return MCP::Tool::Response.new([{ type: "text", text: "Element '#{target}' found at (#{element[:center_x]}, #{element[:center_y]})" }])
        end

        if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
          return MCP::Tool::Response.new([{ type: "text", text: "Timeout: element '#{target}' not found within #{timeout_ms}ms" }])
        end

        sleep POLL_INTERVAL
      end
    end
  end
end
