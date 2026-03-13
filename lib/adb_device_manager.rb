# frozen_string_literal: true

require "open3"
require "nokogiri"
require "base64"
require "tempfile"

class AdbDeviceManager
  ADB_COMMAND = "adb"

  attr_reader :device_name

  def initialize(device_name: nil)
    check_adb_installed!

    devices = available_devices
    if devices.empty?
      raise "No Android devices connected. Please connect a device or start an emulator."
    end

    if device_name
      unless devices.include?(device_name)
        raise "Device '#{device_name}' not found. Available devices: #{devices.join(', ')}"
      end
      @device_name = device_name
    elsif devices.length == 1
      @device_name = devices.first
    else
      raise "Multiple devices connected: #{devices.join(', ')}. Please specify a device name in config.yaml."
    end
  end

  def check_adb_installed!
    _, status = Open3.capture2(ADB_COMMAND, "version")
    unless status.success?
      raise "ADB is not installed or not accessible."
    end
  rescue Errno::ENOENT
    raise "ADB command not found. Please ensure ADB is installed."
  end

  def available_devices
    output, status = Open3.capture2(ADB_COMMAND, "devices")
    return [] unless status.success?

    output.lines
      .drop(1) # skip "List of devices attached" header
      .map(&:strip)
      .reject(&:empty?)
      .select { |line| line.include?("device") }
      .map { |line| line.split("\t").first }
  end

  def get_packages
    output = adb_shell("pm list packages")
    output.lines
      .map { |line| line.strip.sub(/\Apackage:/, "") }
      .reject(&:empty?)
      .join("\n")
  end

  def tap(x, y)
    x = Integer(x)
    y = Integer(y)
    adb_shell("input tap #{x} #{y}")
  end

  def swipe(start_x, start_y, end_x, end_y, duration_ms = 300)
    start_x = Integer(start_x)
    start_y = Integer(start_y)
    end_x = Integer(end_x)
    end_y = Integer(end_y)
    duration_ms = Integer(duration_ms)
    adb_shell("input swipe #{start_x} #{start_y} #{end_x} #{end_y} #{duration_ms}")
  end

  def input_text(text)
    escaped = text.gsub(" ", "%s").gsub("'", "\\'")
    adb_shell("input text '#{escaped}'")
  end

  ALLOWED_KEYS = %w[BACK HOME ENTER MENU TAB DEL DPAD_UP DPAD_DOWN DPAD_LEFT DPAD_RIGHT APP_SWITCH POWER VOLUME_UP VOLUME_DOWN].freeze

  def press_key(key)
    key_name = key.upcase.start_with?("KEYCODE_") ? key.upcase : "KEYCODE_#{key.upcase}"
    short_name = key_name.sub("KEYCODE_", "")
    unless ALLOWED_KEYS.include?(short_name)
      raise "Key '#{key}' is not allowed. Allowed keys: #{ALLOWED_KEYS.join(', ')}"
    end
    adb_shell("input keyevent #{key_name}")
  end

  def launch_app(package_name, activity: nil)
    validate_package_name!(package_name)
    if activity
      adb_shell("am start -n #{package_name}/#{activity}")
    else
      adb_shell("monkey -p #{package_name} -c android.intent.category.LAUNCHER 1")
    end
  end

  def stop_app(package_name)
    validate_package_name!(package_name)
    adb_shell("am force-stop #{package_name}")
  end

  def get_logcat(tag: nil, level: "E", lines: 50)
    lines = Integer(lines)
    filter = tag ? "#{tag}:#{level}" : "*:#{level}"
    adb_shell("logcat -d -t #{lines} #{filter} *:S")
  end

  def get_device_info
    info = {}
    info[:model] = adb_shell("getprop ro.product.model").strip
    info[:android_version] = adb_shell("getprop ro.build.version.release").strip
    info[:sdk_version] = adb_shell("getprop ro.build.version.sdk").strip
    info[:screen_size] = adb_shell("wm size").strip
    info[:screen_density] = adb_shell("wm density").strip
    info
  end

  def find_element(text: nil, description: nil)
    doc = dump_ui_hierarchy
    return nil unless doc

    doc.xpath("//node").each do |node|
      node_text = node["text"].to_s
      node_desc = node["content-desc"].to_s
      bounds = node["bounds"].to_s

      matched = false
      matched = true if text && node_text.include?(text)
      matched = true if description && node_desc.include?(description)
      next unless matched

      if bounds =~ /\[(\d+),(\d+)\]\[(\d+),(\d+)\]/
        x1, y1, x2, y2 = $1.to_i, $2.to_i, $3.to_i, $4.to_i
        return { center_x: (x1 + x2) / 2, center_y: (y1 + y2) / 2 }
      end
    end

    nil
  end

  def get_uilayout(clickable_only: true)
    doc = dump_ui_hierarchy
    return "Failed to dump UI layout" unless doc

    # Detect scrollable containers
    scroll_info = detect_scrollable_containers(doc)

    # Detect overlay layers
    layers = detect_layers(doc)

    if layers
      # Multi-layer output
      parts = []
      parts << scroll_info << "---" unless scroll_info.empty?

      has_elements = false
      layers.each do |layer|
        layer_elements = extract_elements(layer[:node], clickable_only: clickable_only)
        next if layer_elements.empty?

        has_elements = true
        parts << "\n[Layer: #{layer[:name]}]"
        parts << layer_elements.join("\n")
      end

      return "No elements found in the current UI" unless has_elements

      parts.join("\n")
    else
      # Single layer (no overlay detected)
      elements = extract_elements(doc, clickable_only: clickable_only)

      if elements.empty?
        "No elements found in the current UI"
      else
        parts = []
        parts << scroll_info << "---" unless scroll_info.empty?
        parts << elements.join("\n")
        parts.join("\n")
      end
    end
  end

  def take_screenshot
    # Capture screenshot directly as PNG binary via exec-out
    output, status = Open3.capture2(
      ADB_COMMAND, "-s", @device_name, "exec-out", "screencap", "-p",
      binmode: true
    )
    raise "Failed to take screenshot" unless status.success?

    Base64.strict_encode64(output)
  end

  def get_package_action_intents(package_name)
    validate_package_name!(package_name)
    output = adb_shell("dumpsys package #{package_name}")

    intents = []
    in_activity_resolver = false
    in_non_data_actions = false

    non_data_indent = nil

    output.each_line do |line|
      stripped = line.strip
      next if stripped.empty?

      # Measure indentation of the original line
      indent = line.match(/\A(\s*)/)[1].length

      # Track when we enter/exit Activity Resolver Table
      if stripped.start_with?("Activity Resolver Table:")
        in_activity_resolver = true
        next
      end

      # Exit on next top-level resolver table section
      if in_activity_resolver && stripped.match?(/Resolver Table:\z/)
        in_activity_resolver = false
        in_non_data_actions = false
        non_data_indent = nil
        next
      end

      if in_activity_resolver
        if stripped.start_with?("Non-Data Actions:")
          in_non_data_actions = true
          non_data_indent = indent
          next
        end

        # Exit non-data actions when we hit a line at the same or lesser indent level
        # that is NOT an action line
        if in_non_data_actions && non_data_indent && indent <= non_data_indent &&
           !stripped.match?(/\A(android\.|com\.)/)
          in_non_data_actions = false
          non_data_indent = nil
          next
        end

        if in_non_data_actions
          # Extract action lines starting with "android." or "com."
          if stripped.match?(/\A(android\.|com\.)/)
            action = stripped.sub(/:\z/, "")
            intents << action unless intents.include?(action)
          end
        end
      end
    end

    intents
  end

  private

  OVERLAY_CLASS_PATTERNS = /BottomSheet|Dialog|PopupWindow|Popup|AlertDialog/.freeze

  def extract_elements(scope, clickable_only: true)
    elements = []
    xpath = clickable_only ? ".//node[@clickable='true']" : ".//node"
    scope.xpath(xpath).each do |node|
      text = node["text"].to_s
      content_desc = node["content-desc"].to_s
      bounds = node["bounds"].to_s
      class_name = node["class"].to_s
      checkable = node["checkable"] == "true"
      checked = node["checked"] == "true"

      if text.empty? && content_desc.empty?
        next unless checkable || class_name.match?(/Switch|Toggle|Checkbox|SeekBar|Slider/)
      end

      if bounds =~ /\[(\d+),(\d+)\]\[(\d+),(\d+)\]/
        x1, y1, x2, y2 = $1.to_i, $2.to_i, $3.to_i, $4.to_i
        center_x = (x1 + x2) / 2
        center_y = (y1 + y2) / 2

        element_info = []
        element_info << "Text: #{text}" unless text.empty?
        element_info << "Description: #{content_desc}" unless content_desc.empty?
        element_info << "Class: #{class_name}" if checkable || class_name.match?(/Switch|Toggle|Checkbox|SeekBar|Slider/)
        element_info << "Checkable: #{checkable}" if checkable
        element_info << "Checked: #{checked}" if checkable
        element_info << "Bounds: #{bounds}"
        element_info << "Center: (#{center_x}, #{center_y})"

        elements << element_info.join(", ")
      end
    end
    elements
  end

  def detect_layers(doc)
    hierarchy = doc.at_xpath("//hierarchy") || doc.root
    return nil unless hierarchy

    top_level_nodes = hierarchy.xpath("node")

    # Case 1: Multiple top-level window containers (e.g. dialog over main activity)
    # Only treat as multi-window if nodes are actual containers (have child nodes)
    window_nodes = top_level_nodes.select { |n| n.xpath("node").length > 0 }
    if window_nodes.length > 1
      layers = window_nodes.each_with_index.map do |node, i|
        name = i == window_nodes.length - 1 ? "Overlay" : "Background"
        { name: name, node: node }
      end
      return layers
    end

    # Case 2: Single window but contains an overlay container (BottomSheet, Dialog, etc.)
    container = window_nodes.first || top_level_nodes.first
    return nil unless container

    overlay_node = find_overlay_container(container)
    return nil unless overlay_node

    [
      { name: "Background", node: container },
      { name: "Overlay", node: overlay_node }
    ]
  end

  def find_overlay_container(node)
    node.xpath(".//node").each do |child|
      class_name = child["class"].to_s
      resource_id = child["resource-id"].to_s
      if class_name.match?(OVERLAY_CLASS_PATTERNS) || resource_id.match?(OVERLAY_CLASS_PATTERNS)
        return child
      end
    end
    nil
  end

  def detect_scrollable_containers(doc)
    containers = []
    doc.xpath("//node[@scrollable='true']").each do |node|
      bounds = node["bounds"].to_s
      class_name = node["class"].to_s
      resource_id = node["resource-id"].to_s

      next unless bounds =~ /\[(\d+),(\d+)\]\[(\d+),(\d+)\]/

      x1, y1, x2, y2 = $1.to_i, $2.to_i, $3.to_i, $4.to_i
      width = x2 - x1
      height = y2 - y1

      direction = if height > width
                    "vertical"
                  elsif width > height
                    "horizontal"
                  else
                    "both"
                  end

      info = "Scrollable: true (#{direction})"
      info << ", Class: #{class_name}" unless class_name.empty?
      info << ", Resource-ID: #{resource_id}" unless resource_id.empty?
      info << ", Bounds: #{bounds}"
      containers << info
    end

    containers.join("\n")
  end

  def dump_ui_hierarchy
    dump_path = "/sdcard/window_dump.xml"

    adb_shell("uiautomator dump #{dump_path}")

    begin
      xml_content = adb_shell("cat #{dump_path}")
    rescue RuntimeError
      return nil
    ensure
      adb_shell("rm -f #{dump_path}") rescue nil
    end

    xml_start = xml_content.index("<?xml")
    return nil unless xml_start

    Nokogiri::XML(xml_content[xml_start..])
  end

  def validate_package_name!(package_name)
    unless package_name.match?(/\A[a-zA-Z][a-zA-Z0-9_.]*\z/)
      raise "Invalid package name: #{package_name}"
    end
  end

  def adb_shell(command)
    output, status = Open3.capture2(ADB_COMMAND, "-s", @device_name, "shell", command)
    raise "ADB command failed: #{command}" unless status.success?

    output
  end
end
