# frozen_string_literal: true

require_relative "../../lib/adb_device_manager"
require_relative "../../lib/tools/press_key_tool"

RSpec.describe PressKeyTool do
  let(:manager) { instance_double(AdbDeviceManager) }
  let(:server_context) { { device_manager: manager } }

  it "returns confirmation message" do
    allow(manager).to receive(:press_key).with("BACK")

    response = described_class.call(key: "BACK", server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:type]).to eq("text")
    expect(content[0][:text]).to eq("Pressed key: BACK")
  end

  it "has correct tool metadata" do
    expect(described_class.tool_name).to eq("press_key")
  end
end
