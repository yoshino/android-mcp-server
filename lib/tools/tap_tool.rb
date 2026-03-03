# frozen_string_literal: true

require "mcp"

class TapTool < MCP::Tool
  tool_name "tap"
  description "Tap on the specified coordinates or find an element by text/description and tap it"
  input_schema(
    properties: {
      x: { type: "integer", description: "X coordinate to tap" },
      y: { type: "integer", description: "Y coordinate to tap" },
      text: { type: "string", description: "Text of the element to tap (alternative to x/y)" },
      description: { type: "string", description: "Content description of the element to tap (alternative to x/y)" }
    }
  )

  class << self
    def call(x: nil, y: nil, text: nil, description: nil, server_context:)
      manager = server_context[:device_manager]

      if text || description
        element = manager.find_element(text: text, description: description)
        raise "Element not found: #{text || description}" unless element

        x = element[:center_x]
        y = element[:center_y]
      end

      raise "Either coordinates (x, y) or text/description must be provided" unless x && y

      manager.tap(x, y)

      label = text || description
      if label
        MCP::Tool::Response.new([{ type: "text", text: "Tapped '#{label}' at (#{x}, #{y})" }])
      else
        MCP::Tool::Response.new([{ type: "text", text: "Tapped at (#{x}, #{y})" }])
      end
    end
  end
end
