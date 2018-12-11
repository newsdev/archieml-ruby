#!/usr/bin/env ruby

# Updated 12/2018 by @agness to work with Google Drive API V3, since Google no
# longer maintains documentation for OAuth on legacy API versions.
# Google V3 Auth guide: https://developers.google.com/drive/api/v3/about-auth
# This example expects your client secret in `~/.googlecloud/credentials.json`,
# created via https://console.developers.google.com/apis/credentials; and your
# personal access token in `~/.googlecloud/token.yaml`, which is generated and
# automatically stored on disk once you've run this code once.
#
# Adapted from example code Copyright 2018 by Google Inc.,
# Licensed under the Apache License, Version 2.0.
# https://github.com/gsuitedevs/ruby-samples/blob/master/drive/quickstart/quickstart.rb

FILE_ID = "1JjYD90DyoaBuRYNxa4_nqrHKkgZf1HrUj30i3rTWX1s"

require 'archieml'
require 'google/apis/drive_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'nokogiri'
require 'pp'

OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'.freeze
APPLICATION_NAME = 'Drive API Ruby Quickstart'.freeze
CREDENTIALS_PATH = (ENV['HOME']+'/.googlecloud/credentials.json').freeze
TOKEN_PATH = (ENV['HOME']+'/.googlecloud/token.yaml').freeze
SCOPE = Google::Apis::DriveV3::AUTH_DRIVE_READONLY

##
# Ensure valid credentials, either by restoring from the saved credentials
# files or intitiating an OAuth2 authorization. If authorization is required,
# the user's default browser will be launched to approve the request.
#
# @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
def authorize
  client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
  authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
  user_id = 'default'
  credentials = authorizer.get_credentials(user_id)
  if credentials.nil?
    url = authorizer.get_authorization_url(base_url: OOB_URI)
    puts 'Open the following URL in the browser and enter the ' \
         "resulting code after authorization:\n" + url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI
    )
  end
  credentials
end

# Authenticate
service = Google::Apis::DriveV3::DriveService.new
service.client_options.application_name = APPLICATION_NAME
service.authorization = authorize

# Text version
text_aml = service.export_file(FILE_ID, 'text/plain').force_encoding('utf-8')
parsed = Archieml.load(text_aml)
puts parsed

puts "======"

# HTML version
html_data = service.export_file(FILE_ID, 'text/html').force_encoding('utf-8')

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
