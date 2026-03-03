# frozen_string_literal: true

require_relative "../../lib/adb_device_manager"
require_relative "../../lib/tools/get_ui_layout_tool"

RSpec.describe GetUiLayoutTool do
  let(:manager) { instance_double(AdbDeviceManager) }
  let(:server_context) { { device_manager: manager } }

  it "returns clickable elements by default" do
    allow(manager).to receive(:get_uilayout).with(clickable_only: true).and_return("Text: Settings, Bounds: [0,100][200,200], Center: (100, 150)")

    response = described_class.call(server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:type]).to eq("text")
    expect(content[0][:text]).to include("Settings")
  end

  it "returns all elements when clickable_only is false" do
    allow(manager).to receive(:get_uilayout).with(clickable_only: false).and_return("Text: Settings\nText: Label")

    response = described_class.call(clickable_only: false, server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:text]).to include("Label")
  end

  it "has correct tool metadata" do
    expect(described_class.tool_name).to eq("get_uilayout")
  end
end
