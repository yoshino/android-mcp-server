# frozen_string_literal: true

require_relative "../../lib/adb_device_manager"
require_relative "../../lib/tools/tap_tool"

RSpec.describe TapTool do
  let(:manager) { instance_double(AdbDeviceManager) }
  let(:server_context) { { device_manager: manager } }

  it "taps at specified coordinates" do
    allow(manager).to receive(:tap).with(100, 200)

    response = described_class.call(x: 100, y: 200, server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:type]).to eq("text")
    expect(content[0][:text]).to eq("Tapped at (100, 200)")
  end

  it "finds element by text and taps it" do
    allow(manager).to receive(:find_element).with(text: "Settings", description: nil).and_return({ center_x: 150, center_y: 250 })
    allow(manager).to receive(:tap).with(150, 250)

    response = described_class.call(text: "Settings", server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:text]).to eq("Tapped 'Settings' at (150, 250)")
  end

  it "finds element by description and taps it" do
    allow(manager).to receive(:find_element).with(text: nil, description: "Navigate up").and_return({ center_x: 50, center_y: 50 })
    allow(manager).to receive(:tap).with(50, 50)

    response = described_class.call(description: "Navigate up", server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:text]).to eq("Tapped 'Navigate up' at (50, 50)")
  end

  it "raises error when element not found by text" do
    allow(manager).to receive(:find_element).with(text: "Nonexistent", description: nil).and_return(nil)

    expect { described_class.call(text: "Nonexistent", server_context: server_context) }
      .to raise_error(RuntimeError, /Element not found/)
  end

  it "raises error when no coordinates or text provided" do
    expect { described_class.call(server_context: server_context) }
      .to raise_error(RuntimeError, /Either coordinates/)
  end

  it "has correct tool metadata" do
    expect(described_class.tool_name).to eq("tap")
  end
end
