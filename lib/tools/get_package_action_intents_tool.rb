# frozen_string_literal: true

require "mcp"

class GetPackageActionIntentsTool < MCP::Tool
  tool_name "get_package_action_intents"
  description "Get all non-data actions from Activity Resolver Table for a package"
  input_schema(
    properties: {
      package_name: { type: "string", description: "The package name to get intents for" }
    },
    required: ["package_name"]
  )

  class << self
    def call(package_name:, server_context:)
      manager = server_context[:device_manager]
      intents = manager.get_package_action_intents(package_name)
      MCP::Tool::Response.new([{ type: "text", text: intents.join("\n") }])
    end
  end
end
