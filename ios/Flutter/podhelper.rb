# A helper function that makes it easier to install pods from the Flutter plugin
# registry.
def install_flutter_plugins(flutter_application_path = nil)
    if !flutter_application_path
      flutter_application_path = File.join('..', '..')
    end
    generated_xcode_build_settings_path = File.join(flutter_application_path, '.ios', 'Flutter', 'Generated.xcconfig')
    unless File.exist?(generated_xcode_build_settings_path)
      raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
    end
  
    require_relative generated_xcode_build_settings_path
  
    platform = ENV['FLUTTER_TARGET_PLATFORM'] || 'ios'
    # Pods that are installed
    installed_plugins = {}
    podfile = File.open(File.join(File.dirname(__FILE__), '..', 'Podfile')).read
    podfile_dependencies = podfile.scan(/pod\s+['"]([^'"]+)['"]/)
  
    podfile_dependencies.each do |dep|
      installed_plugins[dep[0]] = {}
    end
  
    # Find and install all Flutter plugins from the .flutter-plugins file.
    plugins_file = File.join(flutter_application_path, '.flutter-plugins')
    if File.exist?(plugins_file)
      file_lines = File.read(plugins_file).split(/\n/)
      file_lines.each do |line|
        line_parts = line.split('=')
        if line_parts.length == 2
          plugin_name = line_parts[0].strip
          plugin_path = line_parts[1].strip
          if plugin_path
            podspec_path = File.join(flutter_application_path, plugin_path, 'ios')
            if File.exist?(podspec_path)
              podspec = File.join(podspec_path, "#{plugin_name}.podspec")
              if File.exist?(podspec)
                # If we already installed this pod, no need to do it again.
                unless installed_plugins.key?(plugin_name)
                  pod plugin_name, :path => podspec_path
                end
              end
            end
          end
        end
      end
    end
  end