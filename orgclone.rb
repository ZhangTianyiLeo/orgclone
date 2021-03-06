#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'optparse'
require 'uri'

def fetch_repos_list(org, token)
  uri = URI("https://api.github.com/orgs/#{org}/repos?per_page=100")
  req = Net::HTTP::Get.new(uri)
  req['Authorization'] = "token #{token}"

  res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
    http.request(req)
  end

  if res.is_a? Net::HTTPOK
    puts "Fetched list of repositories from GitHub API"
  else
    abort "Failed to connect to GitHub API: #{res.code} #{res.message}"
  end

  JSON.parse(res.body)
end

def clone_matching_repos(repos, prefix)
  repos.select { |repo| repo['name'].start_with? "#{prefix}-" }.map do |repo|
    puts "Cloning #{repo['name']}..."
    %x( git clone #{repo['ssh_url']} )
    repo['name']
  end
end

def parse_options(options={})
  parser = OptionParser.new do |opts|
    opts.banner = 'Usage: orgclone.rb [options]'
    opts.on('-o', '--organization ORGANIZATION', 'Organization from which to clone repositories') do |org|
      options[:org] = org
    end
    opts.on('-p', '--prefix PREFIX', 'Prefix of repositories to clone') do |prefix|
      options[:prefix] = prefix
    end
  end

  begin
    parser.parse!
    missing = [:org, :prefix].select { |o| options[o].nil? }
    raise OptionParser::MissingArgument.new(missing.join(', ')) unless missing.empty?
  rescue OptionParser::InvalidOption, OptionParser::MissingArgument
    puts $!.to_s
    puts parser
    exit
  end

  options[:token] = ENV['GITHUB_API_TOKEN']
  options
end

opts   = parse_options
repos  = fetch_repos_list(opts[:org], opts[:token])
cloned = clone_matching_repos(repos, opts[:prefix])

puts "#{cloned.size} repositories cloned."
