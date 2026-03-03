# frozen_string_literal: true

require_relative "../../lib/adb_device_manager"
require_relative "../../lib/tools/get_packages_tool"

RSpec.describe GetPackagesTool do
  let(:manager) { instance_double(AdbDeviceManager) }
  let(:server_context) { { device_manager: manager } }

  it "returns packages as text" do
    allow(manager).to receive(:get_packages).and_return("com.example.app1\ncom.example.app2")

    response = described_class.call(server_context: server_context)
    content = response.to_h[:content]

    expect(content.length).to eq(1)
    expect(content[0][:type]).to eq("text")
    expect(content[0][:text]).to include("com.example.app1")
  end

  it "has correct tool metadata" do
    expect(described_class.tool_name).to eq("get_packages")
  end
end
