#
# Be sure to run `pod lib lint com.awareframework.ios.sensor.healthkit.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
    s.name             = 'com.awareframework.ios.sensor.healthkit'
    s.version          = '0.7.0'
    s.summary          = 'A HealthKit Module for AWARE Framework'
    
    # This description is used to generate tags and improve search results.
    #   * Think: What does it do? Why did you write it? What is the focus?
    #   * Try to keep it short, snappy and to the point.
    #   * Write the description between the DESC delimiters below.
    #   * Finally, don't worry about the indent, CocoaPods strips it!
    
    s.description      = <<-DESC
    TODO: Add long description of the pod here.
    DESC
    
    s.homepage         = 'https://github.com/awareframework/com.awareframework.ios.sensor.healthkit'
    # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
    s.license          = { :type => 'Apache2', :file => 'LICENSE' }
    s.author           = { 'Yuuki Nishiyama' => 'yuukin@iis.u-tokyo.ac.jp' }
    s.source           = { :git => 'https://github.com/awareframework/com.awareframework.ios.sensor.healthkit.git', :tag => s.version.to_s }
    # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'
    
    s.ios.deployment_target = '13.0'
    
    s.swift_version = '5'
    
    s.source_files = 'com.awareframework.ios.sensor.healthkit/Classes/**/*'
    
    s.frameworks = 'HealthKit' 
    
    s.dependency 'com.awareframework.ios.sensor.core', '~> 0.7.7'
    
end
