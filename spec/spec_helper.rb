require 'rubygems'
require 'bundler'
Bundler.require

require 'workqueue'
require 'minitest/autorun'
require 'minitest/spec'
require 'wrong/adapters/minitest'

Wrong.config[:color] = true

class Minitest::Test
  include Wrong
end

Dir[File.expand_path('support/**/*.rb', File.dirname(__FILE__))].each {|f|
  require f
}
