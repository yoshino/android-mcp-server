# frozen_string_literal: true

require_relative "../lib/adb_device_manager"

RSpec.describe AdbDeviceManager do
  let(:device_name) { "emulator-5554" }
  let(:success_status) { instance_double(Process::Status, success?: true) }
  let(:failure_status) { instance_double(Process::Status, success?: false) }

  before do
    # Mock adb version check (check_adb_installed!)
    allow(Open3).to receive(:capture2)
      .with("adb", "version")
      .and_return(["Android Debug Bridge version 1.0.41\n", success_status])

    # Mock adb devices (available_devices)
    allow(Open3).to receive(:capture2)
      .with("adb", "devices")
      .and_return(["List of devices attached\n#{device_name}\tdevice\n\n", success_status])
  end

  describe "#initialize" do
    it "auto-selects a single connected device" do
      manager = described_class.new
      expect(manager.device_name).to eq(device_name)
    end

    it "selects the specified device" do
      manager = described_class.new(device_name: device_name)
      expect(manager.device_name).to eq(device_name)
    end

    it "raises an error if specified device is not found" do
      expect { described_class.new(device_name: "nonexistent") }
        .to raise_error(RuntimeError, /not found/)
    end

    it "raises an error when no devices are connected" do
      allow(Open3).to receive(:capture2)
        .with("adb", "devices")
        .and_return(["List of devices attached\n\n", success_status])

      expect { described_class.new }
        .to raise_error(RuntimeError, /No Android devices connected/)
    end

    it "raises an error when multiple devices and no device_name specified" do
      allow(Open3).to receive(:capture2)
        .with("adb", "devices")
        .and_return(["List of devices attached\nemulator-5554\tdevice\nemulator-5556\tdevice\n\n", success_status])

      expect { described_class.new }
        .to raise_error(RuntimeError, /Multiple devices/)
    end

    it "raises an error when ADB is not installed" do
      allow(Open3).to receive(:capture2)
        .with("adb", "version")
        .and_raise(Errno::ENOENT)

      expect { described_class.new }
        .to raise_error(RuntimeError, /ADB command not found/)
    end
  end

  describe "#get_packages" do
    subject(:manager) { described_class.new }

    it "returns package names without 'package:' prefix" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "pm list packages")
        .and_return(["package:com.example.app1\npackage:com.example.app2\n", success_status])

      result = manager.get_packages
      expect(result).to eq("com.example.app1\ncom.example.app2")
    end
  end

  describe "#tap" do
    subject(:manager) { described_class.new }

    it "executes input tap with coordinates" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "input tap 100 200")
        .and_return(["", success_status])

      manager.tap(100, 200)
      expect(Open3).to have_received(:capture2)
        .with("adb", "-s", device_name, "shell", "input tap 100 200")
    end

    it "raises error for non-integer coordinates" do
      expect { manager.tap("abc", 200) }.to raise_error(ArgumentError)
    end
  end

  describe "#swipe" do
    subject(:manager) { described_class.new }

    it "executes input swipe with coordinates and default duration" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "input swipe 100 200 300 400 300")
        .and_return(["", success_status])

      manager.swipe(100, 200, 300, 400)
      expect(Open3).to have_received(:capture2)
        .with("adb", "-s", device_name, "shell", "input swipe 100 200 300 400 300")
    end

    it "accepts custom duration" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "input swipe 100 200 300 400 500")
        .and_return(["", success_status])

      manager.swipe(100, 200, 300, 400, 500)
      expect(Open3).to have_received(:capture2)
        .with("adb", "-s", device_name, "shell", "input swipe 100 200 300 400 500")
    end

    it "raises error for non-integer coordinates" do
      expect { manager.swipe("abc", 200, 300, 400) }.to raise_error(ArgumentError)
    end
  end

  describe "#input_text" do
    subject(:manager) { described_class.new }

    it "executes input text with escaped spaces" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "input text 'hello%sworld'")
        .and_return(["", success_status])

      manager.input_text("hello world")
      expect(Open3).to have_received(:capture2)
        .with("adb", "-s", device_name, "shell", "input text 'hello%sworld'")
    end

    it "executes input text without spaces" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "input text 'hello'")
        .and_return(["", success_status])

      manager.input_text("hello")
      expect(Open3).to have_received(:capture2)
        .with("adb", "-s", device_name, "shell", "input text 'hello'")
    end
  end

  describe "#press_key" do
    subject(:manager) { described_class.new }

    it "executes keyevent for allowed key" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "input keyevent KEYCODE_BACK")
        .and_return(["", success_status])

      manager.press_key("BACK")
      expect(Open3).to have_received(:capture2)
        .with("adb", "-s", device_name, "shell", "input keyevent KEYCODE_BACK")
    end

    it "accepts KEYCODE_ prefix" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "input keyevent KEYCODE_HOME")
        .and_return(["", success_status])

      manager.press_key("KEYCODE_HOME")
      expect(Open3).to have_received(:capture2)
        .with("adb", "-s", device_name, "shell", "input keyevent KEYCODE_HOME")
    end

    it "is case-insensitive" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "input keyevent KEYCODE_ENTER")
        .and_return(["", success_status])

      manager.press_key("enter")
      expect(Open3).to have_received(:capture2)
        .with("adb", "-s", device_name, "shell", "input keyevent KEYCODE_ENTER")
    end

    it "raises error for disallowed key" do
      expect { manager.press_key("CAMERA") }
        .to raise_error(RuntimeError, /not allowed/)
    end
  end

  describe "#launch_app" do
    subject(:manager) { described_class.new }

    it "launches app with monkey command when no activity specified" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "monkey -p com.example.app -c android.intent.category.LAUNCHER 1")
        .and_return(["Events injected: 1\n", success_status])

      manager.launch_app("com.example.app")
      expect(Open3).to have_received(:capture2)
        .with("adb", "-s", device_name, "shell", "monkey -p com.example.app -c android.intent.category.LAUNCHER 1")
    end

    it "launches app with am start when activity specified" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "am start -n com.example.app/.MainActivity")
        .and_return(["Starting: Intent...\n", success_status])

      manager.launch_app("com.example.app", activity: ".MainActivity")
      expect(Open3).to have_received(:capture2)
        .with("adb", "-s", device_name, "shell", "am start -n com.example.app/.MainActivity")
    end

    it "raises error for invalid package name" do
      expect { manager.launch_app("invalid package!") }
        .to raise_error(RuntimeError, /Invalid package name/)
    end
  end

  describe "#stop_app" do
    subject(:manager) { described_class.new }

    it "force-stops the app" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "am force-stop com.example.app")
        .and_return(["", success_status])

      manager.stop_app("com.example.app")
      expect(Open3).to have_received(:capture2)
        .with("adb", "-s", device_name, "shell", "am force-stop com.example.app")
    end

    it "raises error for invalid package name" do
      expect { manager.stop_app("invalid;rm -rf /") }
        .to raise_error(RuntimeError, /Invalid package name/)
    end
  end

  describe "#get_logcat" do
    subject(:manager) { described_class.new }

    it "gets error logs with defaults" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "logcat -d -t 50 *:E *:S")
        .and_return(["E/App: some error\n", success_status])

      result = manager.get_logcat
      expect(result).to eq("E/App: some error\n")
    end

    it "filters by tag and level" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "logcat -d -t 100 MyApp:W *:S")
        .and_return(["W/MyApp: warning\n", success_status])

      result = manager.get_logcat(tag: "MyApp", level: "W", lines: 100)
      expect(result).to eq("W/MyApp: warning\n")
    end
  end

  describe "#get_device_info" do
    subject(:manager) { described_class.new }

    it "returns device information" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "getprop ro.product.model")
        .and_return(["Pixel 6\n", success_status])
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "getprop ro.build.version.release")
        .and_return(["14\n", success_status])
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "getprop ro.build.version.sdk")
        .and_return(["34\n", success_status])
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "wm size")
        .and_return(["Physical size: 1080x2400\n", success_status])
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "wm density")
        .and_return(["Physical density: 420\n", success_status])

      result = manager.get_device_info
      expect(result[:model]).to eq("Pixel 6")
      expect(result[:android_version]).to eq("14")
      expect(result[:sdk_version]).to eq("34")
      expect(result[:screen_size]).to eq("Physical size: 1080x2400")
      expect(result[:screen_density]).to eq("Physical density: 420")
    end
  end

  describe "#find_element" do
    subject(:manager) { described_class.new }

    let(:dump_path) { "/sdcard/window_dump.xml" }

    let(:ui_xml) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <hierarchy rotation="0">
          <node clickable="true" text="Settings" content-desc="" bounds="[0,100][200,200]" />
          <node clickable="true" text="" content-desc="Navigate up" bounds="[0,0][100,100]" />
          <node clickable="false" text="Submit" content-desc="" bounds="[300,400][500,500]" />
        </hierarchy>
      XML
    end

    before do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "rm -f #{dump_path}")
        .and_return(["", success_status])
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "uiautomator dump #{dump_path}")
        .and_return(["UI hierchary dumped to: #{dump_path}\n", success_status])
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "cat #{dump_path}")
        .and_return([ui_xml, success_status])
    end

    it "finds element by text" do
      result = manager.find_element(text: "Settings")
      expect(result).to eq({ center_x: 100, center_y: 150 })
    end

    it "finds element by partial text match" do
      result = manager.find_element(text: "Sett")
      expect(result).to eq({ center_x: 100, center_y: 150 })
    end

    it "finds element by description" do
      result = manager.find_element(description: "Navigate up")
      expect(result).to eq({ center_x: 50, center_y: 50 })
    end

    it "returns nil when element not found" do
      result = manager.find_element(text: "Nonexistent")
      expect(result).to be_nil
    end
  end

  describe "#get_uilayout" do
    subject(:manager) { described_class.new }

    let(:dump_path) { "/sdcard/window_dump.xml" }

    let(:ui_xml) do
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <hierarchy rotation="0">
          <node clickable="true" text="Settings" content-desc="" bounds="[0,100][200,200]" />
          <node clickable="true" text="" content-desc="Navigate up" bounds="[0,0][100,100]" />
          <node clickable="false" text="Not clickable" content-desc="" bounds="[0,200][200,300]" />
          <node clickable="true" text="" content-desc="" bounds="[0,300][200,400]" />
        </hierarchy>
      XML
    end

    before do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "rm -f #{dump_path}")
        .and_return(["", success_status])
    end

    it "extracts clickable elements with text or content-desc" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "uiautomator dump #{dump_path}")
        .and_return(["UI hierchary dumped to: #{dump_path}\n", success_status])
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "cat #{dump_path}")
        .and_return([ui_xml, success_status])

      result = manager.get_uilayout
      lines = result.split("\n")

      expect(lines.length).to eq(2)
      expect(lines[0]).to include("Text: Settings")
      expect(lines[0]).to include("Center: (100, 150)")
      expect(lines[1]).to include("Description: Navigate up")
      expect(lines[1]).to include("Center: (50, 50)")
    end

    it "returns all elements when clickable_only is false" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "uiautomator dump #{dump_path}")
        .and_return(["UI hierchary dumped to: #{dump_path}\n", success_status])
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "cat #{dump_path}")
        .and_return([ui_xml, success_status])

      result = manager.get_uilayout(clickable_only: false)
      lines = result.split("\n")

      expect(lines.length).to eq(3)
      expect(lines[0]).to include("Text: Settings")
      expect(lines[1]).to include("Description: Navigate up")
      expect(lines[2]).to include("Text: Not clickable")
    end

    it "includes checkable widgets even without text or content-desc" do
      xml_with_switch = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <hierarchy rotation="0">
          <node clickable="true" text="" content-desc="" class="android.widget.Switch" checkable="true" checked="false" bounds="[800,100][1000,200]" />
          <node clickable="true" text="Settings" content-desc="" class="android.widget.TextView" checkable="false" checked="false" bounds="[0,100][200,200]" />
        </hierarchy>
      XML
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "uiautomator dump #{dump_path}")
        .and_return(["UI hierchary dumped to: #{dump_path}\n", success_status])
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "cat #{dump_path}")
        .and_return([xml_with_switch, success_status])

      result = manager.get_uilayout
      lines = result.split("\n")

      expect(lines.length).to eq(2)
      expect(lines[0]).to include("Class: android.widget.Switch")
      expect(lines[0]).to include("Checkable: true")
      expect(lines[0]).to include("Checked: false")
      expect(lines[0]).to include("Center: (900, 150)")
      expect(lines[1]).to include("Text: Settings")
    end

    it "returns message when no elements found" do
      empty_xml = '<?xml version="1.0" encoding="UTF-8"?><hierarchy rotation="0"></hierarchy>'
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "uiautomator dump #{dump_path}")
        .and_return(["UI hierchary dumped to: #{dump_path}\n", success_status])
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "cat #{dump_path}")
        .and_return([empty_xml, success_status])

      result = manager.get_uilayout
      expect(result).to eq("No elements found in the current UI")
    end

    it "returns failure message when cat fails" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "uiautomator dump #{dump_path}")
        .and_return(["UI hierchary dumped to: #{dump_path}\n", success_status])
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "cat #{dump_path}")
        .and_return(["", failure_status])

      result = manager.get_uilayout
      expect(result).to eq("Failed to dump UI layout")
    end
  end

  describe "#take_screenshot" do
    subject(:manager) { described_class.new }

    it "returns Base64-encoded PNG data" do
      png_data = "\x89PNG\r\n\x1a\n fake png data".b
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "exec-out", "screencap", "-p", binmode: true)
        .and_return([png_data, success_status])

      result = manager.take_screenshot
      expect(Base64.strict_decode64(result)).to eq(png_data)
    end

    it "raises an error when screenshot fails" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "exec-out", "screencap", "-p", binmode: true)
        .and_return(["", failure_status])

      expect { manager.take_screenshot }.to raise_error(RuntimeError, /Failed to take screenshot/)
    end
  end

  describe "#get_package_action_intents" do
    subject(:manager) { described_class.new }

    let(:dumpsys_output) do
      <<~TEXT
        Activity Resolver Table:
          Non-Data Actions:
              android.intent.action.MAIN:
                12345 com.example.app/.MainActivity filter abcdef
              com.example.action.CUSTOM:
                12345 com.example.app/.CustomActivity filter abcdef
          Schemes:
              http:
                12345 com.example.app/.WebActivity filter abcdef
        Service Resolver Table:
          Non-Data Actions:
              android.intent.action.SERVICE:
                12345 com.example.app/.MyService filter abcdef
      TEXT
    end

    it "extracts action intents from Activity Resolver Table" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "dumpsys package com.example.app")
        .and_return([dumpsys_output, success_status])

      result = manager.get_package_action_intents("com.example.app")
      expect(result).to eq([
        "android.intent.action.MAIN",
        "com.example.action.CUSTOM"
      ])
    end

    it "returns empty array when no intents found" do
      allow(Open3).to receive(:capture2)
        .with("adb", "-s", device_name, "shell", "dumpsys package com.empty")
        .and_return(["Some output without resolver table\n", success_status])

      result = manager.get_package_action_intents("com.empty")
      expect(result).to be_empty
    end

    it "raises error for invalid package name" do
      expect { manager.get_package_action_intents("invalid;cmd") }
        .to raise_error(RuntimeError, /Invalid package name/)
    end
  end
end
