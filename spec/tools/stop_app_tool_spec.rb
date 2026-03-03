# frozen_string_literal: true

require_relative "../../lib/adb_device_manager"
require_relative "../../lib/tools/stop_app_tool"

RSpec.describe StopAppTool do
  let(:manager) { instance_double(AdbDeviceManager) }
  let(:server_context) { { device_manager: manager } }

  it "returns confirmation message" do
    allow(manager).to receive(:stop_app).with("com.example.app")

    response = described_class.call(package_name: "com.example.app", server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:type]).to eq("text")
    expect(content[0][:text]).to eq("Stopped com.example.app")
  end

  it "has correct tool metadata" do
    expect(described_class.tool_name).to eq("stop_app")
  end
end
