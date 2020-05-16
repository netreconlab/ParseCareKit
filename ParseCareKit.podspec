#
# Be sure to run `pod lib lint ParseCareKit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ParseCareKit'
  s.version          = '1.0'
  s.summary          = 'Synchronize CareKit 2.0 data to Parse Server'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  This framework is an API to synchronize [CareKit](https://github.com/carekit-apple/CareKit) 2.0+ data with [parse-server](https://github.com/parse-community/parse-server). Note that CareKit data is extremely sensitive and you are responsible for ensuring your parse-server meets HIPAA compliance. Look at hipaa-mongo and [hipaa_mongo](https://github.com/netreconlab/hipaa_mongodb) and [hipaa-postges]()(will post soon) to get started with HIPAA compliant databases that can be configured with pare-server. An example of how to use parse-server with [postgres](https://www.postgresql.org) and [parse-dashboard](https://github.com/parse-community/parse-dashboard) can be found at [parse-postgres](https://github.com/netreconlab/parse-postgres).
                       DESC

  s.homepage         = 'https://github.com/netreconlab/ParseCareKit/'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'cbaker6' => 'coreyearleon@icloud.com' }
  s.source           = { :git => 'https://github.com/netreconlab/ParseCareKit.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target  = '10.0'
  s.osx.deployment_target  = '10.15'
  s.swift_versions = ['5.0']
  s.source_files = 'ParseCareKit/**/*.swift'
  
  # s.resource_bundles = {
  #   'ParseCareKit' => ['ParseCareKit/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'CareKitStore', '~> 2.0'
  s.dependency 'Parse', '~> 1.18'
end
