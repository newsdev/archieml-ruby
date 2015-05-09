# Archieml

Parse Archie Markup Language (ArchieML) documents into Ruby Hashes.

Read about the ArchieML specification at [archieml.org](http://archieml.org).

The current version is `v0.2.0`.

## Installation

`gem install archieml`

## Usage

```
require 'archieml'

Archieml.load("key: value")
=> {"key"=>"value"}

File.write("text.aml", "key: value")
Archieml.load_file("text.aml")
=> {"key"=>"value"}
```

### Using with Google Documents

We use `archieml` at The New York Times to parse Google Documents containing AML. This requires a little upfront work to download the document and convert it into text that `archieml` can load.

The first step is authenticating with the Google Drive API, and accessing the document. For this, you will need a user account that is authorized to view the document you wish to download.

For this example, I'm going to use the official `google-api-client` Ruby gem, but you can use another library or authentication method if you like. Whatever mechanism, you'll need to be able to export the document either as text, or html, at which point the instructions will be identical.

The full example is at [`examples/google_drive.rb`](https://github.com/newsdev/archieml-ruby/blob/master/examples/google_drive.rb).

First, install the gem directly, or using a Gemfile:

```
$ gem install google-api-client
```

Next, open up `irb` and run the follow code to authorize a user, and initialize and OAuth client. Note that if you want to use this on a server, you'll have to set up a more re-usable way of authorizing users.

```
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/installed_app'

client = Google::APIClient.new(:application_name => 'Ruby Drive sample', :application_version => '1.0.0')
client_secrets = Google::APIClient::ClientSecrets.load
flow = Google::APIClient::InstalledAppFlow.new(
  :client_id => client_secrets.client_id,
  :client_secret => client_secrets.client_secret,
  :scope => ['https://www.googleapis.com/auth/drive']
)
client.authorization = flow.authorize
```

Log into your Google account and authorize the application to access your Google Drive files.

Now that you have an authenticated `client`, you can make an API call to a document saved in Drive. Create a document with some basic AML inside (such as "key: value"), save it, and note the long string of characters at the end of the URL: 

`https://docs.google.com/a/nytimes.com/document/d/[FILE_ID]/edit`

FILE_ID is defaulted to a public test file.

```
FILE_ID = "1JjYD90DyoaBuRYNxa4_nqrHKkgZf1HrUj30i3rTWX1s"
drive = client.discovered_api('drive', 'v2')

result = client.execute(
  :api_method => drive.files.get,
  :parameters => { 'fileId' => FILE_ID })
```

If result executes correctly, you should now have the file's metadata. The next step is to download the body of the file. The metadata has a property called `exportLinks` which gives you URLs to different formats that you can export the document as. Let's start with `text/plain`.

```
text_url = result.data['exportLinks']['text/plain']
text_aml = client.execute(uri: text_url).body
```

`text_aml` should now contain your document in plain text! You're all set to run the text through the ArchieML parser.

```
require 'archieml'
parsed = Archieml.load(text_aml)
```

Check out parsed, and ensure that it has any data you entered into the document.

There are a few extra steps that we do to make working with Google Documents more useful. With a little more prep, we generally process the documents to:

* Include links that users enter in the google document as HTML `<a>` tags
* Remove smart quotes inside tag brackets `<>` (which Google loves to add for you)
* Ensure that list bullet points are turned into `*`s

Unfortunately, google strips out links when you export as `text/plain`, so if you want to preserve them, we have to export the document in a different format, `text/html`.

```
html_url = result.data['exportLinks']['text/html']
html_data = client.execute(uri: html_url).body
```

At the other extreme, `html_data` now contains far too *much* data - there's a whole DOM represented in that text! We want to turn that HTML body back into plain text so that ArchieML can load it, and we want to preserve any links that we find.

This is a lightweight DOM traverser which requires using the `nokogiri` gem: `gem install nokogiri`. It moves through the HTML document and constructs a simple text representation of the document, without things like images or tables that would be ignored by AML anyway.

```
require 'nokogiri'

def convert(node)
  str = ''
  node.children.each do |child|
    if func = @node_types[child.name || child.type]
      str += func.call(child)
    end
  end
  return str
end

@node_types = {
  'text' => lambda { |node| return node.content },
  'span' => lambda { |node| convert(node) },
  'p'    => lambda { |node| return convert(node) + "\n" },
  'li'   => lambda { |node| return '* ' + convert(node) + "\n" },
  'a'    => lambda { |node|
    return convert(node) unless node.attributes['href'] && node.attributes['href'].value

    # Google changes all links to be served from a google domain.
    # We need to strip off the real url, which has been moved to the
    # "q" querystring parameter.

    href = node.attributes['href'].value
    if !href.index('?').nil? && parsed_url = CGI.parse(href.split('?')[1])
      href = parsed_url['q'][0] if parsed_url['q']
    end

    str = "<a href=\"#{href}\">"
    str += convert(node)
    str += "</a>"
    return str
  }
}

%w(ul ol).each { |tag| @node_types[tag] = @node_types['span'] }
%w(h1 h2 h3 h4 h5 h6 br hr).each { |tag| @node_types[tag] = @node_types['p'] }

html_doc = Nokogiri::HTML(html_data)
html_aml = convert(html_doc.children[1].children[1])

require 'archieml'
aml = Archieml.load(html_aml)
```

`aml` should now have your document with links included, and bullet points should continue to work (we transformed each `<li>` element into a separate line beginning with a `*`).

One additional step we perform is removing smart quotes. You can run `html_aml` through this before calling `Archieml.load`:

```
html_aml.gsub!(/<[^<>]*>/) do |match|
  match.gsub("‘", "'")
       .gsub("’", "'")
       .gsub("“", '"')
       .gsub("”", '"')
end
aml = Archieml.load(html_aml)
```

## Tests

There is a full test suite using rspec. `bundle install`, and then `rspec` to execute them.

## Changelog

* `0.2.0` - Updated to support an updated ArchieML spec: [2015-05-09](http://archieml.org/spec/1.0/CR-20150509.html). Adds support for nested arrays.
* `0.1.1` - More consistent handling of newlines. Fixed bugs around detecting the scope of multi-line values.
* `0.1.0` - Initial release supporting the first version of the ArchieML spec, published [2015-03-06](http://archieml.org/spec/1.0/CR-20150306.html).
