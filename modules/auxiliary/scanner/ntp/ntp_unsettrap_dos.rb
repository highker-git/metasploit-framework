##
# This module requires Metasploit: http//metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core'

class Metasploit3 < Msf::Auxiliary

  include Msf::Auxiliary::Report
  include Msf::Exploit::Remote::Udp
  include Msf::Auxiliary::UDPScanner
  include Msf::Auxiliary::NTP

  def initialize
    super(
      'Name'        => 'NTP Mode 6 UNSETTRAP DRDoS Scanner',
      'Description' => %q{
        This module identifies NTP servers which permit mode 6 UNSETTRAP requests that
        can be used to conduct DRDoS attacks.  In some configurations, NTP servers will
        respond to UNSETTRAP requests with multiple packets, allowing remote attackers to
        cause a denial of services (traffic amplification) via spoofed requests.
      },
      'References'  =>
        [
        ],
      'Author'      => 'Jon Hart <jon_hart[at]rapid7.com>',
      'License'     => MSF_LICENSE
    )
  end

  # Called for each IP in the batch
  def scan_host(ip)
    scanner_send(@probe, ip, datastore['RPORT'])
  end

  # Called for each response packet
  def scanner_process(data, shost, sport)
    @results[shost] ||= []
    @results[shost] << Rex::Proto::NTP::NTPControl.new(data)
  end

  # Called before the scan block
  def scanner_prescan(batch)
    @results = {}
    @probe = Rex::Proto::NTP::NTPControl.new
    @probe.version = 2
    @probe.operation = 31
    vprint_status("Sending probes to #{batch[0]}->#{batch[-1]} (#{batch.length} hosts)")
  end

  # Called after the scan block
  def scanner_postscan(batch)
    @results.keys.each do |k|
      packets = @results[k]
      report_service(
        :host  => k,
        :proto => 'udp',
        :port  => rport,
        :name  => 'ntp'
      )
      total_size = packets.map(&:size).reduce(:+)
      if packets.size > 1 || total_size > @probe.size
        print_good("#{k}:#{rport} NTP unsettrap request permitted with amplified response (#{packets.size} packets, #{total_size} bytes)")
      end
    end
  end
end
