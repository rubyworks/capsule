require 'capsule'

When "say we have a Ruby script called '(((.*)))'" do |file, text|
  File.open(file, 'w'){ |f| f << text }
end

