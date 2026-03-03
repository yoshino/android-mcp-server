# frozen_string_literal: true

require_relative "../../lib/adb_device_manager"
require_relative "../../lib/tools/get_screenshot_tool"

RSpec.describe GetScreenshotTool do
  let(:manager) { instance_double(AdbDeviceManager) }
  let(:server_context) { { device_manager: manager } }

  it "returns image content with base64 data" do
    allow(manager).to receive(:take_screenshot).and_return("iVBORw0KGgo=")

    response = described_class.call(server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:type]).to eq("image")
    expect(content[0][:data]).to eq("iVBORw0KGgo=")
    expect(content[0][:mimeType]).to eq("image/png")
  end

  it "has correct tool metadata" do
    expect(described_class.tool_name).to eq("get_screenshot")
  end
end
