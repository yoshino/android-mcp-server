# frozen_string_literal: true

require "mcp"

class PressKeyTool < MCP::Tool
  tool_name "press_key"
  description "Send a key event to the device. Allowed keys: BACK, HOME, ENTER, MENU, TAB, DEL, DPAD_UP, DPAD_DOWN, DPAD_LEFT, DPAD_RIGHT, APP_SWITCH, POWER, VOLUME_UP, VOLUME_DOWN"
  input_schema(
    properties: {
      key: { type: "string", description: "Key name (e.g. BACK, HOME, ENTER)" }
    },
    required: ["key"]
  )

  class << self
    def call(key:, server_context:)
      manager = server_context[:device_manager]
      manager.press_key(key)
      MCP::Tool::Response.new([{ type: "text", text: "Pressed key: #{key}" }])
    end
  end
end
