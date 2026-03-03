# frozen_string_literal: true

require_relative "../../lib/adb_device_manager"
require_relative "../../lib/tools/get_package_action_intents_tool"

RSpec.describe GetPackageActionIntentsTool do
  let(:manager) { instance_double(AdbDeviceManager) }
  let(:server_context) { { device_manager: manager } }

  it "returns intents as text" do
    allow(manager).to receive(:get_package_action_intents)
      .with("com.example.app")
      .and_return(["android.intent.action.MAIN", "com.example.action.CUSTOM"])

    response = described_class.call(package_name: "com.example.app", server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:type]).to eq("text")
    expect(content[0][:text]).to eq("android.intent.action.MAIN\ncom.example.action.CUSTOM")
  end

  it "has correct tool metadata" do
    expect(described_class.tool_name).to eq("get_package_action_intents")
  end
end
