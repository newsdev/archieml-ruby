#!/usr/bin/env ruby

# Adapted from example code Copyright 2012 by Google Inc.,
# Licensed under the Apache License, Version 2.0.
# https://github.com/google/google-api-ruby-client-samples/blob/master/drive/drive.rb

FILE_ID = "1JjYD90DyoaBuRYNxa4_nqrHKkgZf1HrUj30i3rTWX1s"

require 'archieml'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/file_storage'
require 'google/api_client/auth/installed_app'
require 'nokogiri'
require 'pp'

client = Google::APIClient.new(:application_name => 'Ruby Drive sample', :application_version => '1.0.0')

CREDENTIAL_STORE_FILE = "oauth2.json"

# FileStorage stores auth credentials in a file, so they survive multiple runs
# of the application. This avoids prompting the user for authorization every
# time the access token expires, by remembering the refresh token.
# Note: FileStorage is not suitable for multi-user applications.
file_storage = Google::APIClient::FileStorage.new(CREDENTIAL_STORE_FILE)
if file_storage.authorization.nil?
  client_secrets = Google::APIClient::ClientSecrets.load
  flow = Google::APIClient::InstalledAppFlow.new(
    :client_id => client_secrets.client_id,
    :client_secret => client_secrets.client_secret,
    :scope => ['https://www.googleapis.com/auth/drive']
  )
  client.authorization = flow.authorize(file_storage)
else
  client.authorization = file_storage.authorization
end

drive = client.discovered_api('drive', 'v2')
result = client.execute(
  :api_method => drive.files.get,
  :parameters => { 'fileId' => FILE_ID })

# Text version

text_url = result.data['exportLinks']['text/plain']
text_aml = client.execute(uri: text_url).body
parsed = Archieml.load(text_aml)

# HTML version

html_url = result.data['exportLinks']['text/html']
html_data = client.execute(uri: html_url).body

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

html_aml.gsub!(/<[^<>]*>/) do |match|
  match.gsub("‘", "'")
       .gsub("’", "'")
       .gsub("“", '"')
       .gsub("”", '"')
end

aml = Archieml.load(html_aml)

pp aml
