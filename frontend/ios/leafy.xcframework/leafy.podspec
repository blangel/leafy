Pod::Spec.new do |s|
  s.name             = 'leafy'
  s.version          = '1.0.0'
  s.summary          = 'code transcompiled from gomobile for leafy'
  s.vendored_frameworks = 'leafy.xcframework'
  s.platform         = :ios, '13.0'
  s.homepage         = 'https://leafybitcoin.com'
  s.license          = { :type => 'Apache 2.0', :file => '../../../LICENSE' }
  s.author           = { 'Brian Langel' => 'blangel@leafybitcoin.com' }
  s.source           = { :http => 'https://github.com/blangel/leafy' }
end
