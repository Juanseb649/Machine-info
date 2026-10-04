Pod::Spec.new do |s|
  s.name             = 'machine_info_native'
  s.version          = '0.1.0'
  s.summary          = 'machineinfo C core compiled for macOS.'
  s.description      = 'Hexagonal C core that collects hardware and software inventory.'
  s.homepage         = 'https://github.com/Juanseb649/machine-info'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Sebastian' => 'ibarrajuan930@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.15'
  s.frameworks = 'CoreFoundation', 'IOKit', 'DiskArbitration'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/../src/include" "${PODS_TARGET_SRCROOT}/../src"',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) MACHINEINFO_BUILDING=1 MACHINEINFO_VERSION=\\"0.1.0\\"',
    'GCC_C_LANGUAGE_STANDARD' => 'c11'
  }
  s.swift_version = '5.0'
end
