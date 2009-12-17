#!/usr/bin/env ruby

require 'rubygems'
require 'etc'
require 'yaml'
require 'rmodbus'
require 'clickatell'

mb = ModBus::TCPClient.new '192.168.0.189'

cc = YAML.load_file File.join(Etc.getpwuid.dir, '.clickatell')
clickatell = Clickatell::API.authenticate cc['api_key'], cc['username'], cc['password']

begin
  loop do
    ra, rb = mb.read_holding_registers 5391, 2
    a, b, c, d = (0..3).map {|bit| ra[bit] }

    puts 'a: %s' % a.to_s
    puts 'b: %s' % b.to_s
    puts 'c: %s' % c.to_s
    puts 'd: %s' % d.to_s

    clickatell.send_message '4740220423', 'BRANN!' if a == 0

#    [5356, 5366, 5357, 5382, 5383, 5391, 5392].each do |addr|
#      puts '%d: %d' % [addr, mb.read_holding_registers(addr, 1).first]
#    end
    sleep 10.0
  end
ensure
  mb.close
end
