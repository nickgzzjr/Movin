Pod::Spec.new do |s|
  s.name         = "Movin"
  s.version      = "1.2.0"
  s.summary      = "UIViewPropertyAnimator based View Transition Animator."
  s.homepage     = "https://github.com/xxxAIRINxxx/Movin"
  s.license      = 'MIT'
  s.author       = { "Airin" => "xl1138@gmail.com" }
  s.source       = { :git => "https://github.com/xxxAIRINxxx/Movin.git", :tag => s.version.to_s }

  s.requires_arc = true
  s.platform     = :ios, '10.0'

  s.source_files = 'Sources/*.swift'
end
