require 'archieml/loader'

module Archieml
  def self.load(aml)
    loader = Archieml::Loader.new()
    loader.load(aml)
  end

  def self.load_file(filename)
    loader = Archieml::Loader.new()
    stream = File.open(filename)
    loader.load(stream)
  end
end
