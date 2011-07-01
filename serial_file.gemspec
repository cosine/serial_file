# Copyright (c) 2009, Michael H. Buselli
# See LICENSE for details.  All other rights reserved.

Gem::Specification.new do |s|
  s.name = 'serial_file'
  s.version = "0.1.0"
  s.summary = "Tool to pipe information through a filesystem"
  s.description = "#{s.summary}\n"
  s.author = "Michael H. Buselli"
  s.email = "cosine@cosine.org"
  s.homepage = "http://cosine.org/"
  #s.files = ["LICENSE"] + Dir.glob('lib/**/*')
  # ruby -e "p ['LICENSE'] + Dir.glob('lib/**/*')"
  s.files = ["LICENSE", "lib/serial_file.rb"]
  s.require_paths = ['lib']
  s.rubyforge_project = "serial_file"
  s.has_rdoc = false
end
