#!/usr/bin/env ruby
#
# Ruby script to get DSL connection rate stats from an EchoLife HG612 modem
# outputs the current stats to a CSV file
# 

require 'net-telnet'
require 'optparse'
require 'time'
require 'csv'


options = {
  :hostname => '192.168.1.1',
  :username => 'admin',
  :password => 'admin',
  :csv_filename => 'dslstats.csv'
}

OptionParser.new do |opts|
  opts.banner = 'Usage: dslstats.rb [options]'

  opts.on('-f', '--filename', 'The CSV filename to write to') do |csv_filename|
    options[:csv_filename] = csv_filename
  end
  opts.on('-H', '--hostname', 'The hostname or IP address of the router') do |hostname|
    options[:hostname] = hostname
  end
  opts.on('-u', '--username', 'Username to connect to the router with') do |username|
    options[:username] = username
  end
  opts.on('-p', '--password', 'Password to connect to the router with') do |password|
    options[:password] = password
  end
  opts.on('-h', '--help', 'Prints this help') do
    puts opts
    exit
  end
end.parse!


def fetch_stats(options)
  telnet = Net::Telnet::new('Host' => options[:hostname],
                            'Timeout' => 10,
                            'Prompt' => /[$%#>] ?\z/n)

  telnet.login(options[:username], options[:password])
  telnet.cmd('sh')
  lines = telnet.cmd('xdslcmd info --state').split(/[\r\n]+/)
  telnet.close

  data = {:time => Time.now.iso8601}
  lines.each do |line|
    case line
    when /^Status:\s+(.+)/i
      data[:status] = $1
    when /^Retrain Reason:\s+(.+)/i
      data[:retrain_reason] = $1
    when /^Last initialization procedure status:\s+(.+)/i
      data[:init_status] = $1
    when /^Max:\s+Upstream rate = (\d+) Kbps, Downstream rate = (\d+) Kbps/i
      data[:max_upstream] = $1.to_i
      data[:max_downstream] = $2.to_i
    when /^Bearer:\s+(\d+), Upstream rate = (\d+) Kbps, Downstream rate = (\d+) Kbps/i
      data["bearer_#{$1}_upstream".to_sym] = $2.to_i
      data["bearer_#{$1}_downstream".to_sym] = $3.to_i
    end
  end
  return data
end


data = fetch_stats(options)


columns = [
  :time,
  :status,
  :retrain_reason,
  :init_status,
  :max_upstream,
  :max_downstream,
  :bearer_0_upstream,
  :bearer_0_downstream,
  :bearer_1_upstream,
  :bearer_1_downstream
]

if File.exist?(options[:csv_filename])
  # Append to existing file
  csv = CSV.open(options[:csv_filename], 'ab')
else
  # Create new file
  csv = CSV.open(options[:csv_filename], 'wb')
  csv << columns
end

# Output data in the same order as the columns
csv << columns.map {|c| data[c]}

csv.close
