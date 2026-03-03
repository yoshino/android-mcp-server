# frozen_string_literal: true

require_relative "../../lib/adb_device_manager"
require_relative "../../lib/tools/launch_app_tool"

RSpec.describe LaunchAppTool do
  let(:manager) { instance_double(AdbDeviceManager) }
  let(:server_context) { { device_manager: manager } }

  it "returns confirmation without activity" do
    allow(manager).to receive(:launch_app).with("com.example.app", activity: nil)

    response = described_class.call(package_name: "com.example.app", server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:type]).to eq("text")
    expect(content[0][:text]).to eq("Launched com.example.app")
  end

  it "returns confirmation with activity" do
    allow(manager).to receive(:launch_app).with("com.example.app", activity: ".MainActivity")

    response = described_class.call(package_name: "com.example.app", activity: ".MainActivity", server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:text]).to eq("Launched com.example.app/.MainActivity")
  end

  it "has correct tool metadata" do
    expect(described_class.tool_name).to eq("launch_app")
  end
end
