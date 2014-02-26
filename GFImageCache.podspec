Pod::Spec.new do |s|
  s.name = 'GFImageCache'
  s.version = '0.0.1'
  s.platform = :ios
  s.ios.deployment_target = '5.0'
  s.prefix_header_file = 'GFImageCache/GFImageCache/GFImageCache-Prefix.pch'
  s.source_files = 'GFImageCache/*.{h,m}'
  s.requires_arc = true
  s.dependency 'ReactiveCocoa', '2.2.4'
end
