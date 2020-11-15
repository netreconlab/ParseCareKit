# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

def shared_pods
  # Pods for ParseCareKit
  pod 'CareKitStore', :git => 'https://github.com/cbaker6/CareKit.git', :branch => 'pod'
  pod 'Parse', '~>1.19.1'
end

target 'ParseCareKit' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for ParseCareKit
  shared_pods
end

target 'TestHost' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for ParseCareKit
  shared_pods
end
