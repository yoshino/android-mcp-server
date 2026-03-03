# frozen_string_literal: true

require_relative "../../lib/adb_device_manager"
require_relative "../../lib/tools/input_text_tool"

RSpec.describe InputTextTool do
  let(:manager) { instance_double(AdbDeviceManager) }
  let(:server_context) { { device_manager: manager } }

  it "returns confirmation message" do
    allow(manager).to receive(:input_text).with("hello")

    response = described_class.call(text: "hello", server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:type]).to eq("text")
    expect(content[0][:text]).to eq("Input text: hello")
  end

  it "has correct tool metadata" do
    expect(described_class.tool_name).to eq("input_text")
  end
end
