# frozen_string_literal: true

require_relative "../../lib/adb_device_manager"
require_relative "../../lib/tools/get_logcat_tool"

RSpec.describe GetLogcatTool do
  let(:manager) { instance_double(AdbDeviceManager) }
  let(:server_context) { { device_manager: manager } }

  it "returns logcat output with defaults" do
    allow(manager).to receive(:get_logcat).with(tag: nil, level: "E", lines: 50).and_return("E/App: error\n")

    response = described_class.call(server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:type]).to eq("text")
    expect(content[0][:text]).to eq("E/App: error\n")
  end

  it "passes optional parameters" do
    allow(manager).to receive(:get_logcat).with(tag: "MyApp", level: "W", lines: 100).and_return("W/MyApp: warn\n")

    response = described_class.call(tag: "MyApp", level: "W", lines: 100, server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:text]).to eq("W/MyApp: warn\n")
  end

  it "has correct tool metadata" do
    expect(described_class.tool_name).to eq("get_logcat")
  end
end
