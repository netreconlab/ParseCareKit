Pod::Spec.new do |s|
  s.name             = 'ParseCareKit'
  s.version          = '1.0'
  s.summary          = 'Synchronize CareKit 2.0 data to Parse Server'

  s.description      = <<-DESC
  This framework is an API to synchronize [CareKit](https://github.com/carekit-apple/CareKit) 2.0+ data with [parse-server](https://github.com/parse-community/parse-server). For the backend, it is suggested to use [parse-hipaa](https://github.com/netreconlab/parse-hipaa/tree/parse-obj-sdk) which is an out-of-the-box HIPAA compliant Parse/[Postgres](https://www.postgresql.org) or Parse/[Mongo](https://www.mongodb.com) server that comes with [Parse Dashboard](https://github.com/parse-community/parse-dashboard). Since [parse-hipaa](https://github.com/netreconlab/parse-hipaa/tree/parse-obj-sdk) is a pare-server, it can be used for [iOS](https://docs.parseplatform.org/ios/guide/), [Android](https://docs.parseplatform.org/android/guide/), and web based apps. API's such as [GraphQL](https://docs.parseplatform.org/graphql/guide/), [REST](https://docs.parseplatform.org/rest/guide/), and [JS](https://docs.parseplatform.org/js/guide/) are also enabled in parse-hipaa and can be accessed directly or tested via the "API Console" in parse-dashboard. See the [Parse SDK documentation](https://parseplatform.org/#sdks) for details. These docker images include the necessary database auditing and logging for HIPAA compliance.
                       DESC

  s.homepage         = 'https://github.com/netreconlab/ParseCareKit/tree/parse-objc'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'cbaker6' => 'coreyearleon@icloud.com' }
  s.source           = { :git => 'https://github.com/netreconlab/ParseCareKit.git', :tag => s.version.to_s }
 
  s.platform = :ios, :watchos
  s.ios.deployment_target  = '13.0'
  s.watchos.deployment_target = '6.0'
  s.osx.deployment_target  = '10.15'
  s.swift_versions = ['5.0']
  s.source_files = 'ParseCareKit/**/*.swift'

  s.dependency 'CareKitStore', '~> 2.0'
  s.dependency 'Parse', '~> 1.19.1'
  s.dependency 'ParseLiveQuery', '~> 2.8.0'
end
