require "http"
require "http/headers"
require "openssl"
require "json"
require "base64"

class ExampleFile
  @lines = [] of String

  def self.from_path(path)
    new(File.read(path))
  end

  def self.from_url(url)
    context = OpenSSL::SSL::Context::Client.new
    headers = HTTP::Headers.new
    headers["Accept"] = "*/*"
    response = HTTP::Client.get(url, tls: context)
    json_response = JSON.parse(response.body)
    content = Base64.decode_string(json_response.as_h["content"].as_s)
    new(content)
  end

  def self.from_github(
    org : String,
    repo : String,
    path : String,
    ref : String = "main"
  )
    url = "https://api.github.com/repos/#{org}/#{repo}/contents/#{path}?ref=#{ref}"

    from_url(url)
  end

  def initialize(data)
    @lines = data.lines
  end

  def [](pos)
    @lines[pos]
  end

  def at(pos)
    self[pos - 1]
  end

  def between(range)
    adjusted_range = (range.begin - 1)..(range.end - 1)
    @lines[adjusted_range].join("\n")
  end
end
