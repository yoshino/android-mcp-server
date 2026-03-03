# frozen_string_literal: true

require_relative "../../lib/adb_device_manager"
require_relative "../../lib/tools/swipe_tool"

RSpec.describe SwipeTool do
  let(:manager) { instance_double(AdbDeviceManager) }
  let(:server_context) { { device_manager: manager } }

  it "returns confirmation message with default duration" do
    allow(manager).to receive(:swipe).with(100, 200, 300, 400, 300)

    response = described_class.call(start_x: 100, start_y: 200, end_x: 300, end_y: 400, server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:type]).to eq("text")
    expect(content[0][:text]).to eq("Swiped from (100, 200) to (300, 400) in 300ms")
  end

  it "accepts custom duration" do
    allow(manager).to receive(:swipe).with(0, 500, 0, 100, 500)

    response = described_class.call(start_x: 0, start_y: 500, end_x: 0, end_y: 100, duration_ms: 500, server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:text]).to include("500ms")
  end

  it "has correct tool metadata" do
    expect(described_class.tool_name).to eq("swipe")
  end
end
