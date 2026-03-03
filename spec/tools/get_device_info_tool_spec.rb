# frozen_string_literal: true

require_relative "../../lib/adb_device_manager"
require_relative "../../lib/tools/get_device_info_tool"

RSpec.describe GetDeviceInfoTool do
  let(:manager) { instance_double(AdbDeviceManager) }
  let(:server_context) { { device_manager: manager } }

  it "returns formatted device info" do
    allow(manager).to receive(:get_device_info).and_return({
      model: "Pixel 6",
      android_version: "14",
      sdk_version: "34",
      screen_size: "Physical size: 1080x2400",
      screen_density: "Physical density: 420"
    })

    response = described_class.call(server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:type]).to eq("text")
    expect(content[0][:text]).to include("Model: Pixel 6")
    expect(content[0][:text]).to include("Android Version: 14")
    expect(content[0][:text]).to include("Screen Size: Physical size: 1080x2400")
  end

  it "has correct tool metadata" do
    expect(described_class.tool_name).to eq("get_device_info")
  end
end
