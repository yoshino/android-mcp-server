# frozen_string_literal: true

require_relative "../../lib/adb_device_manager"
require_relative "../../lib/tools/wait_for_element_tool"

RSpec.describe WaitForElementTool do
  let(:manager) { instance_double(AdbDeviceManager) }
  let(:server_context) { { device_manager: manager } }

  it "returns immediately when element is found" do
    allow(manager).to receive(:find_element)
      .with(text: "Settings", description: nil)
      .and_return({ center_x: 100, center_y: 150 })

    response = described_class.call(text: "Settings", server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:text]).to eq("Element 'Settings' found at (100, 150)")
  end

  it "finds element by description" do
    allow(manager).to receive(:find_element)
      .with(text: nil, description: "Navigate up")
      .and_return({ center_x: 50, center_y: 50 })

    response = described_class.call(description: "Navigate up", server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:text]).to eq("Element 'Navigate up' found at (50, 50)")
  end

  it "retries and finds element on second attempt" do
    call_count = 0
    allow(manager).to receive(:find_element)
      .with(text: "Settings", description: nil) do
        call_count += 1
        call_count >= 2 ? { center_x: 100, center_y: 150 } : nil
      end

    stub_const("WaitForElementTool::POLL_INTERVAL", 0.01)
    response = described_class.call(text: "Settings", timeout_ms: 5000, server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:text]).to include("found")
    expect(call_count).to be >= 2
  end

  it "returns timeout message when element not found" do
    allow(manager).to receive(:find_element)
      .with(text: "Nonexistent", description: nil)
      .and_return(nil)

    stub_const("WaitForElementTool::POLL_INTERVAL", 0.01)
    response = described_class.call(text: "Nonexistent", timeout_ms: 50, server_context: server_context)
    content = response.to_h[:content]

    expect(content[0][:text]).to include("Timeout")
    expect(content[0][:text]).to include("Nonexistent")
  end

  it "raises error when neither text nor description provided" do
    expect { described_class.call(server_context: server_context) }
      .to raise_error(RuntimeError, /Either text or description/)
  end

  it "has correct tool metadata" do
    expect(described_class.tool_name).to eq("wait_for_element")
  end
end
