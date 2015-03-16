require 'spec_helper'

describe Archieml::Loader do
  before(:each) do
    @loader = Archieml::Loader.new()
    allow(@loader).to receive(:parse_scope).with(any_args).and_call_original
    allow(@loader).to receive(:parse_start_key).with(any_args).and_call_original
    allow(@loader).to receive(:parse_command_key).with(any_args).and_call_original
  end

  describe "parsing values" do
    it "parses key value pairs" do
      @loader.load("key:value")['key'].should == 'value'
    end
    it "ignores spaces on either side of the key" do
      @loader.load("  key  :value")['key'].should == 'value'
    end
    it "ignores tabs on either side of the key" do
      @loader.load("\t\tkey\t\t:value")['key'].should == 'value'
    end
    it "ignores spaces on either side of the value" do
      @loader.load("key:  value  ")['key'].should == 'value'
    end
    it "ignores tabs on either side of the value" do
      @loader.load("key:\t\tvalue\t\t")['key'].should == 'value'
    end
    it "dupliate keys are assigned the last given value" do
      @loader.load("key:value\nkey:newvalue")['key'].should == 'newvalue'
    end
    it "allows non-letter characters at the start of values" do
      @loader.load("key::value")['key'].should == ':value'
    end
    it "keys are case sensitive" do
      @loader.load("key:value\nKey:Value").keys.should == ['key', 'Key']
    end
    it "non-keys don't affect parsing" do
      @loader.load("other stuff\nkey:value\nother stuff")['key'].should == 'value'
    end
  end

  describe "valid keys" do

    it "letters, numbers, dashes and underscores are valid key components" do
      @loader.load("a-_1:value")['a-_1'].should == 'value'
    end
    it "spaces are not allowed in keys" do
      @loader.load("k ey:value").keys.length.should == 0
    end
    it "symbols are not allowed in keys" do
      @loader.load("k&ey:value").keys.length.should == 0
    end
    it "keys can be nested using dot-notation" do
      @loader.load("scope.key:value")['scope']['key'].should == 'value'
    end
    it "earlier keys within scopes aren't deleted when using dot-notation" do
      @loader.load("scope.key:value\nscope.otherkey:value")['scope']['key'].should == 'value'
      @loader.load("scope.key:value\nscope.otherkey:value")['scope']['otherkey'].should == 'value'
    end
    it "the value of key that used to be a string should be replaced with an object if necessary" do
      @loader.load("scope.level:value\nscope.level.level:value")['scope']['level']['level'].should == 'value'
    end
    it "the value of key that used to be a parent object should be replaced with a string if necessary" do
      @loader.load("scope.level.level:value\nscope.level:value")['scope']['level'].should == 'value'
    end

  end

  describe "valid values" do

    it "HTML is allowed" do
      @loader.load("key:<strong>value</strong>")['key'].should == '<strong>value</strong>'
    end

  end

  describe "skip" do

    it "ignores spaces on either side of :skip" do
      expect(@loader).to receive(:parse_command_key).with('skip').once
      @loader.load("  :skip  \nkey:value\n:endskip").keys.length.should == 0
    end
    it "ignores tabs on either side of :skip" do
      expect(@loader).to receive(:parse_command_key).with('skip').once
      @loader.load("\t\t:skip\t\t\nkey:value\n:endskip").keys.length.should == 0
    end
    it "ignores spaces on either side of :endskip" do
      expect(@loader).to receive(:parse_command_key).with('endskip').once
      @loader.load(":skip\nkey:value\n  :endskip  ").keys.length.should == 0
    end
    it "ignores tabs on either side of :endskip" do
      expect(@loader).to receive(:parse_command_key).with('endskip').once
      @loader.load(":skip\nkey:value\n\t\t:endskip\t\t").keys.length.should == 0
    end
    it "starts parsing again after :endskip" do
      expect(@loader).to receive(:parse_start_key).with('key', 'value').once
      @loader.load(":skip\n:endskip\nkey:value").keys.length.should == 1
    end
    it ":skip and :endskip are case insensitive" do
      expect(@loader).to receive(:parse_command_key).with('skip').once
      expect(@loader).to receive(:parse_command_key).with('endskip').once
      @loader.load(":sKiP\nkey:value\n:eNdSkIp").keys.length.should == 0
    end
    it "parse :skip as a special command even if more is appended to word" do
      expect(@loader).to receive(:parse_command_key).with('skip')
      @loader.load(":skipthis\nkey:value\n:endskip").keys.length.should == 0
    end
    it "ignores all content on line after :skip + space" do
      expect(@loader).to receive(:parse_command_key).with('skip').once
      expect(@loader).to_not receive(:parse_start_key).with('key', 'value')
      @loader.load(":skip this text  \nkey:value\n:endskip").keys.length.should == 0
    end
    it "ignores all content on line after :skip + tab" do
      expect(@loader).to receive(:parse_command_key).with('skip').once
      expect(@loader).to_not receive(:parse_start_key).with('key', 'value')
      @loader.load(":skip\tthis text\t\t\nkey:value\n:endskip").keys.length.should == 0
    end
    it "parse :endskip as a special command even if more is appended to word" do
      expect(@loader).to receive(:parse_command_key).with('endskip')
      @loader.load(":skip\n:endskiptheabove\nkey:value").keys.length.should == 1
    end
    it "ignores all content on line after :endskip + space" do
      expect(@loader).to receive(:parse_command_key).with('endskip').once
      expect(@loader).to receive(:parse_start_key).with('key', 'value').once
      @loader.load(":skip\n:endskip the above\nkey:value").keys.length.should == 1
    end
    it "ignores all content on line after :endskip + tab" do
      expect(@loader).to receive(:parse_command_key).with('endskip').once
      expect(@loader).to receive(:parse_start_key).with('key', 'value').once
      @loader.load(":skip\n:endskip\tthe above\nkey:value").keys.length.should == 1
    end
    it "does not parse :end as an :endskip" do
      expect(@loader).to_not receive(:parse_command_key).with('endskip')
      @loader.load(":skip\n:end\tthe above\nkey:value").keys.length.should == 0
    end
    it "ignores keys within a skip block" do
      expect(@loader).to_not receive(:parse_start_key).with('other', 'value')
      @loader.load("key1:value1\n:skip\nother:value\n\n:endskip\n\nkey2:value2").keys.should == ['key1', 'key2']
    end

  end

  describe "ignore" do

    it "text before ':ignore' should be included" do
      @loader.load("key:value\n:ignore")['key'].should == 'value'
    end
    it "text after ':ignore' should be ignored" do
      expect(@loader).to_not receive(:parse_start_key)
      @loader.load(":ignore\nkey:value").keys.length.should == 0
    end
    it "':ignore' is case insensitive" do
      expect(@loader).to receive(:parse_command_key).with('ignore').once
      @loader.load(":iGnOrE\nkey:value").keys.length.should == 0
    end
    it "ignores spaces on either side of :ignore" do
      expect(@loader).to receive(:parse_command_key).with('ignore').once
      @loader.load(":iGnOrE\nkey:value").keys.length.should == 0
      @loader.load("  :ignore  \nkey:value")
    end
    it "ignores tabs on either side of :ignore" do
      expect(@loader).to receive(:parse_command_key).with('ignore').once
      @loader.load(":iGnOrE\nkey:value").keys.length.should == 0
      @loader.load("\t\t:ignore\t\t\nkey:value")
    end
    it "parses :ignore as a special command even if more is appended to word" do
      expect(@loader).to receive(:parse_command_key).with('ignore')
      @loader.load(":ignorethis\nkey:value").keys.length.should == 0
    end
    it "ignores all content on line after :ignore + space" do
      expect(@loader).to receive(:parse_command_key).with('ignore').once
      @loader.load(":iGnOrE\nkey:value").keys.length.should == 0
      @loader.load(":ignore the below\nkey:value")
    end
    it "ignores all content on line after :ignore + tab" do
      expect(@loader).to receive(:parse_command_key).with('ignore').once
      @loader.load(":iGnOrE\nkey:value").keys.length.should == 0
      @loader.load(":ignore\tthe below\nkey:value")
    end

  end

  describe "multi line values" do

    it "adds additional lines to value if followed by an ':end'" do
      @loader.load("key:value\nextra\n:end")['key'].should == "value\nextra"
    end
    it "':end' is case insensitive" do
      expect(@loader).to receive(:parse_command_key).with('end').once
      @loader.load("key:value\nextra\n:EnD")
    end
    it "preserves blank lines and whitespace lines in the middle of content" do
      @loader.load("key:value\n\n\t \nextra\n:end")['key'].should == "value\n\n\t \nextra"
    end
    it "doesn't preserve whitespace at the end of the key" do
      @loader.load("key:value\nextra\t \n:end")['key'].should == "value\nextra"
    end
    it "preserves whitespace at the end of the original line" do
      @loader.load("key:value\t \nextra\n:end")['key'].should == "value\t \nextra"
    end
    it "ignores whitespace and newlines before the ':end'" do
      @loader.load("key:value\nextra\n \n\t\n:end")['key'].should == "value\nextra"
    end
    it "ignores spaces on either side of :end" do
      expect(@loader).to receive(:parse_command_key).with('end').once
      @loader.load("key:value\nextra\n  :end  ")
    end
    it "ignores tabs on either side of :end" do
      expect(@loader).to receive(:parse_command_key).with('end').once
      @loader.load("key:value\nextra\n\t\t:end\t\t")
    end
    it "parses :end as a special command even if more is appended to word" do
      expect(@loader).to receive(:parse_command_key).with('end')
      @loader.load("key:value\nextra\n:endthis")['key'].should == "value\nextra"
    end
    it "does not parse :endskip as an :end" do
      expect(@loader).to_not receive(:parse_command_key).with('end')
      @loader.load("key:value\nextra\n:endskip")['key'].should == "value"
    end
    it "ordinary text that starts with a colon is included" do
      @loader.load("key:value\n:notacommand\n:end")['key'].should == "value\n:notacommand"
    end
    it "ignores all content on line after :end + space" do
      expect(@loader).to receive(:parse_command_key).with('end').once
      @loader.load("key:value\nextra\n:end this")['key'].should == "value\nextra"
    end
    it "ignores all content on line after :end + tab" do
      expect(@loader).to receive(:parse_command_key).with('end').once
      @loader.load("key:value\nextra\n:end\tthis")['key'].should == "value\nextra"
    end
    it "doesn't escape colons on first line" do
      @loader.load("key::value\n:end")['key'].should == ":value"
      @loader.load("key:\\:value\n:end")['key'].should == "\\:value"
    end
    it "does not allow escaping keys" do
      @loader.load("key:value\nkey2\\:value\n:end")['key'].should == "value\nkey2\\:value"
    end
    it "allows escaping key lines with a leading backslash" do
      @loader.load("key:value\n\\key2:value\n:end")['key'].should == "value\nkey2:value"
    end
    it "allows escaping commands at the beginning of lines" do
      @loader.load("key:value\n\\:end\n:end")['key'].should == "value\n:end"
    end
    it "allows escaping commands with extra text at the beginning of lines" do
      @loader.load("key:value\n\\:endthis\n:end")['key'].should == "value\n:endthis"
    end
    it "allows escaping of non-commandc at the beginning of lines" do
      @loader.load("key:value\n\\:notacommand\n:end")['key'].should == "value\n:notacommand"
    end
    it "allows simple array style lines" do
      @loader.load("key:value\n* value\n:end")['key'].should == "value\n* value"
    end
    it "escapes '*' within multi-line values when not in a simple array" do
      @loader.load("key:value\n\\* value\n:end")['key'].should == "value\n* value"
    end
    it "allows escaping scope keys at the beginning of lines" do
      @loader.load("key:value\n\\{scope}\n:end")['key'].should == "value\n{scope}"
      @loader.load("key:value\n\\[comment]\n:end")['key'].should == "value"
      @loader.load("key:value\n\\[[array]]\n:end")['key'].should == "value\n[array]"
    end
    it "arrays within a multi-line value breaks up the value" do
      @loader.load("key:value\ntext\n[array]\nmore text\n:end")['key'].should == "value"
    end
    it "objects within a multi-line value breaks up the value" do
      @loader.load("key:value\ntext\n{scope}\nmore text\n:end")['key'].should == "value"
    end
    it "bullets within a multi-line value do not break up the value" do
      @loader.load("key:value\ntext\n* value\nmore text\n:end")['key'].should == "value\ntext\n* value\nmore text"
    end
    it "skips within a multi-line value do not break up the value" do
      @loader.load("key:value\ntext\n:skip\n:endskip\nmore text\n:end")['key'].should == "value\ntext\nmore text"
    end
    it "allows escaping initial backslash at the beginning of lines" do
      @loader.load("key:value\n\\\\:end\n:end")['key'].should == "value\n\\:end"
    end
    it "escapes only one initial backslash" do
      @loader.load("key:value\n\\\\\\:end\n:end")['key'].should == "value\n\\\\:end"
    end
    it "allows escaping multiple lines in a value" do
      @loader.load("key:value\n\\:end\n\\:ignore\n\\:endskip\n\\:skip\n:end'")['key'].should == "value\n:end\n:ignore\n:endskip\n:skip"
    end
    it "doesn't escape colons after beginning of lines" do
      @loader.load("key:value\nLorem key2\\:value\n:end")['key'].should == "value\nLorem key2\\:value"
    end

  end

  describe "scopes" do

    it "{scope} creates an empty object at 'scope'" do
      @loader.load("{scope}")['scope'].class.should == Hash
    end
    it "ignores spaces on either side of {scope}" do
      expect(@loader).to receive(:parse_scope).with('{', 'scope').once
      @loader.load("  {scope}  ")
    end
    it "ignores tabs on either side of {scope}" do
      expect(@loader).to receive(:parse_scope).with('{', 'scope').once
      @loader.load("\t\t{scope}\t\t")['scope'].should == {}
    end
    it "ignores text after {scope}" do
      expect(@loader).to receive(:parse_scope).with('{', 'scope').once
      @loader.load("{scope}a")['scope'].should == {}
    end
    it "ignores spaces on either side of {scope} variable name" do
      expect(@loader).to receive(:parse_scope).with('{', 'scope').once
      @loader.load("{  scope  }")['scope'].should == {}
    end
    it "ignores tabs on either side of {scope} variable name" do
      expect(@loader).to receive(:parse_scope).with('{', 'scope').once
      @loader.load("{\t\tscope\t\t}")['scope'].should == {}
    end
    it "items before a {scope} are not namespaced" do
      @loader.load("key:value\n{scope}")['key'].should == 'value'
    end
    it "items after a {scope} are namespaced" do
      @loader.load("{scope}\nkey:value")['key'].should == nil
      @loader.load("{scope}\nkey:value")['scope']['key'].should == 'value'
    end
    it "scopes can be nested using dot-notaion" do
      @loader.load("{scope.scope}\nkey:value")['scope']['scope']['key'].should == 'value'
    end
    it "scopes can be reopened" do
      @loader.load("{scope}\nkey:value\n{}\n{scope}\nother:value")['scope'].keys.should =~ ["key", "other"]
    end
    it "scopes do not overwrite existing values" do
      @loader.load("{scope.scope}\nkey:value\n{scope.otherscope}key:value")['scope']['scope']['key'].should == 'value'
    end
    it "{} resets to the global scope" do
      expect(@loader).to receive(:parse_scope).with('{', '').once
      @loader.load("{scope}\n{}\nkey:value")['key'].should == 'value'
    end
    it "ignore spaces inside {}" do
      expect(@loader).to receive(:parse_scope).with('{', '').once
      @loader.load("{scope}\n{  }\nkey:value")['key'].should == 'value'
    end
    it "ignore tabs inside {}" do
      expect(@loader).to receive(:parse_scope).with('{', '').once
      @loader.load("{scope}\n{\t\t}\nkey:value")['key'].should == 'value'
    end
    it "ignore spaces on either side of {}" do
      expect(@loader).to receive(:parse_scope).with('{', '').once
      @loader.load("{scope}\n  {}  \nkey:value")['key'].should == 'value'
    end
    it "ignore tabs on either side of {}" do
      expect(@loader).to receive(:parse_scope).with('{', '').once
      @loader.load("{scope}\n\t\t{}\t\t\nkey:value")['key'].should == 'value'
    end

  end

  describe "arrays" do

    it "[array] creates an empty array at 'array'" do
      @loader.load("[array]")['array'].should == []
    end
    it "ignores spaces on either side of [array]" do
      expect(@loader).to receive(:parse_scope).with('[', 'array').once
      @loader.load("  [array]  ")
    end
    it "ignores tabs on either side of [array]" do
      expect(@loader).to receive(:parse_scope).with('[', 'array').once
      @loader.load("\t\t[array]\t\t")
    end
    it "ignores text after [array]" do
      expect(@loader).to receive(:parse_scope).with('[', 'array').once
      @loader.load("[array]a")['array'].should == []
    end
    it "ignores spaces on either side of [array] variable name" do
      expect(@loader).to receive(:parse_scope).with('[', 'array').once
      @loader.load("[  array  ]")
    end
    it "ignores tabs on either side of [array] variable name" do
      expect(@loader).to receive(:parse_scope).with('[', 'array').once
      @loader.load("[\t\tarray\t\t]")
    end
    it "arrays can be nested using dot-notaion" do
      @loader.load("[scope.array]")['scope']['array'].should == []
    end
    it "array values can be nested using dot-notaion" do
      @loader.load("[array]\nscope.key: value\nscope.key: value")['array'].should == [{'scope' => {'key' => 'value'}}, {'scope' => {'key' => 'value'}}]
    end
    it "[] resets to the global scope" do
      @loader.load("[array]\n[]\nkey:value")['key'].should == 'value'
    end
    it "ignore spaces inside []" do
      expect(@loader).to receive(:parse_scope).with('[', '').once
      @loader.load("[array]\n[  ]\nkey:value")['key'].should == 'value'
    end
    it "ignore tabs inside []" do
      expect(@loader).to receive(:parse_scope).with('[', '').once
      @loader.load("[array]\n[\t\t]\nkey:value")['key'].should == 'value'
    end
    it "ignore spaces on either side of []" do
      expect(@loader).to receive(:parse_scope).with('[', '').once
      @loader.load("[array]\n  []  \nkey:value")['key'].should == 'value'
    end
    it "ignore tabs on either side of []" do
      expect(@loader).to receive(:parse_scope).with('[', '').once
      @loader.load("[array]\n\t\t[]\t\t\nkey:value")['key'].should == 'value'
    end

  end

  describe "simple arrays" do

    it "creates a simple array when an '*' is encountered first" do
      @loader.load("[array]\n*Value")['array'].first.should == 'Value'
    end
    it "ignores spaces on either side of '*'" do
      @loader.load("[array]\n  *  Value")['array'].first.should == 'Value'
    end
    it "ignores tabs on either side of '*'" do
      @loader.load("[array]\n\t\t*\t\tValue")['array'].first.should == 'Value'
    end
    it "adds multiple elements" do
      @loader.load("[array]\n*Value1\n*Value2")['array'].should == ['Value1', 'Value2']
    end
    it "ignores all other text between elements" do
      @loader.load("[array]\n*Value1\nNon-element\n*Value2")['array'].should == ['Value1', 'Value2']
    end
    it "ignores key:value pairs between elements" do
      @loader.load("[array]\n*Value1\nkey:value\n*Value2")['array'].should == ['Value1', 'Value2']
    end
    it "parses key:values normally after an end-array" do
      @loader.load("[array]\n*Value1\n[]\nkey:value")['key'].should == 'value'
    end
    it "multi-line values are allowed" do
      @loader.load("[array]\n*Value1\nextra\n:end")['array'].first.should == "Value1\nextra"
    end
    it "allows escaping of '*' within multi-line values in simple arrays" do
      @loader.load("[array]\n*Value\n\\* extra\n:end")['array'].first.should == "Value\n* extra"
    end
    it "allows escaping of command keys within multi-line values" do
      @loader.load("[array]\n*Value\n\\:end\n:end")['array'].first.should == "Value\n:end"
    end
    it "does not allow escaping of keys within multi-line values" do
      @loader.load("[array]\n*Value\nkey\\:value\n:end")['array'].first.should == "Value\nkey\\:value"
    end
    it "allows escaping key lines with a leading backslash" do
      @loader.load("[array]\n*Value\n\\key:value\n:end")['array'].first.should == "Value\nkey:value"
    end
    it "does not allow escaping of colons not at the beginning of lines" do
      @loader.load("[array]\n*Value\nword key\\:value\n:end")['array'].first.should == "Value\nword key\\:value"
    end
    it "arrays within a multi-line value breaks up the value" do
      @loader.load("[array]\n* value\n[array]\nmore text\n:end")['array'].first.should == "value"
    end
    it "objects within a multi-line value breaks up the value" do
      @loader.load("[array]\n* value\n{scope}\nmore text\n:end")['array'].first.should == "value"
    end
    it "key/values within a multi-line value do not break up the value" do
      @loader.load("[array]\n* value\nkey: value\nmore text\n:end")['array'].first.should == "value\nkey: value\nmore text"
    end
    it "bullets within a multi-line value break up the value" do
      @loader.load("[array]\n* value\n* value\nmore text\n:end")['array'].first.should == "value"
    end
    it "skips within a multi-line value do not break up the value" do
      @loader.load("[array]\n* value\n:skip\n:endskip\nmore text\n:end")['array'].first.should == "value\nmore text"
    end
    it "arrays that are reopened add to existing array" do
      @loader.load("[array]\n*Value\n[]\n[array]\n*Value")['array'].should == ['Value', 'Value']
    end
    it "simple arrays that are reopened remain simple" do
      @loader.load("[array]\n*Value\n[]\n[array]\nkey:value")['array'].should == ['Value']
    end
    it "simple arrays overwrite existing keys" do
      @loader.load("a.b:complex value\n[a.b]\n*simple value")['a']['b'][0].should == 'simple value'
    end

  end

  describe "complex arrays" do

    it "keys after an [array] are included as items in the array" do
      @loader.load("[array]\nkey:value")['array'].first.should == {'key' => 'value' }
    end
    it "array items can have multiple keys" do
      @loader.load("[array]\nkey:value\nsecond:value")['array'].first.keys.should =~ ['key', 'second']
    end
    it "when a duplicate key is encountered, a new item in the array is started" do
      @loader.load("[array]\nkey:value\nsecond:value\nkey:value")['array'].length.should == 2
      @loader.load("[array]\nkey:first\nkey:second")['array'].last.should == {'key' => 'second'}
      @loader.load("[array]\nscope.key:first\nscope.key:second")['array'].last.should == {'scope' => {'key' => 'second'}}
    end
    it "duplicate keys must match on dot-notation scope" do
      @loader.load("[array]\nkey:value\nscope.key:value")['array'].length.should == 1
    end
    it "duplicate keys must match on dot-notation scope" do
      @loader.load("[array]\nscope.key:value\nkey:value\notherscope.key:value")['array'].length.should == 1
    end
    it "arrays within a multi-line value breaks up the value" do
      @loader.load("[array]\nkey:value\n[array]\nmore text\n:end")['array'].first['key'].should == "value"
    end
    it "objects within a multi-line value breaks up the value" do
      @loader.load("[array]\nkey:value\n{scope}\nmore text\n:end")['array'].first['key'].should == "value"
    end
    it "key/values within a multi-line value break up the value" do
      @loader.load("[array]\nkey:value\nother: value\nmore text\n:end")['array'].first['key'].should == "value"
    end
    it "bullets within a multi-line value do not break up the value" do
      @loader.load("[array]\nkey:value\n* value\nmore text\n:end")['array'].first['key'].should == "value\n* value\nmore text"
    end
    it "skips within a multi-line value do not break up the value" do
      @loader.load("[array]\nkey:value\n:skip\n:endskip\nmore text\n:end")['array'].first['key'].should == "value\nmore text"
    end
    it "arrays that are reopened add to existing array" do
      @loader.load("[array]\nkey:value\n[]\n[array]\nkey:value")['array'].length.should == 2
    end
    it "complex arrays that are reopened remain complex" do
      @loader.load("[array]\nkey:value\n[]\n[array]\n*Value")['array'].should == [{'key' => 'value'}]
    end
    it "complex arrays overwrite existing keys" do
      @loader.load("a.b:complex value\n[a.b]\nkey:value")['a']['b'][0]['key'].should == 'value'
    end

  end

  describe "inline comments" do

    it "ignore comments inside of [single brackets]" do
      @loader.load("key:value [inline comments] value")['key'].should == "value  value"
    end
    it "supports multiple inline comments on a single line" do
      @loader.load("key:value [inline comments] value [inline comments] value")['key'].should == "value  value  value"
    end
    it "supports adjacent comments" do
      @loader.load("key:value [inline comments] [inline comments] value")['key'].should == "value   value"
    end
    it "supports no-space adjacent comments" do
      @loader.load("key:value [inline comments][inline comments] value")['key'].should == "value  value"
    end
    it "supports comments at beginning of string" do
      @loader.load("key:[inline comments] value")['key'].should == "value"
    end
    it "supports comments at end of string" do
      @loader.load("key:value [inline comments]")['key'].should == "value"
    end
    it "whitespace before a comment that appears at end of line is ignored" do
      @loader.load("key:value [inline comments] value [inline comments]")['key'].should == "value  value"
    end
    it "unmatched single brackets are preserved" do
      @loader.load("key:value ][ value")['key'].should == "value ][ value"
    end

    it "inline comments are supported on the first of multi-line values" do
      @loader.load("key:value [inline comments] on\nmultiline\n:end")['key'].should == "value  on\nmultiline"
    end
    it "inline comments are supported on subsequent lines of multi-line values" do
      @loader.load("key:value\nmultiline [inline comments]\n:end")['key'].should == "value\nmultiline"
    end
    it "whitespace around comments is preserved, except at the beinning and end of a value" do
      @loader.load("key: [] value [] \n multiline [] \n:end")['key'].should == "value  \n multiline"
    end

    it "inline comments cannot span multiple lines" do
      @loader.load("key:value [inline\ncomments] value\n:end")['key'].should == "value [inline\ncomments] value"
      @loader.load("key:value \n[inline\ncomments] value\n:end")['key'].should == "value \n[inline\ncomments] value"
    end
    it "text inside [[double brackets]] is included as [single brackets]" do
      @loader.load("key:value [[brackets]] value")['key'].should == "value [brackets] value"
    end
    it "unmatched double brackets are preserved" do
      @loader.load("key:value ]][[ value")['key'].should == "value ]][[ value"
    end
    it "comments work in simple arrays" do
      @loader.load("[array]\n*Val[comment]ue")['array'].first.should == "Value"
    end
    it "double brackets work in simple arrays" do
      @loader.load("[array]\n*Val[[real]]ue")['array'].first.should == "Val[real]ue"
    end

  end
end
