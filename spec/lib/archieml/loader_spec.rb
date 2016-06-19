require 'spec_helper'

describe Archieml::Loader do
  Dir.glob(File.expand_path('../../../archieml.org/test/1.0/*.aml', __FILE__)).each do |f|
    data = File.read(f)
    slug, idx = File.basename(f).split('.')

    # Parse without inline comments
    metadata = Archieml::Loader.new.load(data, comments: false)
    test     = metadata['test']
    result   = JSON.parse(metadata['result'])

    aml = Archieml::Loader.new.load(data)
    aml.delete('test')
    aml.delete('result')

    aml = JSON.parse(JSON.dump(aml))

    it "#{slug}.#{idx} #{test}" do
      aml.should == result
    end
  end

  it "freeforms / ruby: Text is added to freeforms when no trailing newline is present" do
    aml = Archieml::Loader.new.load("[+freeform]\nText")
    aml = JSON.parse(JSON.dump(aml))

    aml.should == {"freeform" => [{"type" => "text", "value" => "Text"}]}
  end
end
