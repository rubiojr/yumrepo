$: << File.join(File.dirname(__FILE__), "../lib")

require 'yumrepo'

settings = YumRepo::Settings.instance
settings.log_level = :debug

pl = YumRepo::PackageList.new "http://rbel.frameos.org/stable/el5/x86_64"

count = 0
pl.each do |p|
  count += 1
  puts "#{p.name}-#{p.version}-#{p.release}"
  puts "Provides: "
  puts "  #{p.provides.join("\n  ")}"
  puts "Requires: "
  puts "  #{p.requires.join("\n  ")}"
end

puts "Total packages: #{count}"
