#!/usr/bin/env ruby

require 'rubygems'
require 'etc'
require 'yaml'
require 'rmodbus'
require 'clickatell'

mb = ModBus::TCPClient.new '192.168.0.189'

cc = YAML.load_file File.join(Etc.getpwuid.dir, '.clickatell')
clickatell = Clickatell::API.authenticate cc['api_key'], cc['username'], cc['password']
fire_warned = false

begin
  loop do
    ra, rb = mb.read_holding_registers 5391, 2
		# four inputs on my Modbus hardware from Scheider
    a, b, c, d = (0..3).map {|bit| ra[bit] }

#    puts 'a: %s' % a.to_s
#    puts 'b: %s' % b.to_s
#    puts 'c: %s' % c.to_s
#    puts 'd: %s' % d.to_s

		fire_detected ||= (a == 0)

		if not fire_warned and fire_detected
			while true
				begin
					puts 'Sending SMS!'
					%w(4740220423 4740402040).each do |tel|
						clickatell.send_message tel, 'Røykvarsler eller vannvarsler aktivert'
					end
					break
				rescue
					wait = 10.0
					$stderr.puts 'Could not send SMS, try again in %.0f seconds' % wait
					sleep wait
				end
			end
		end

		fire_warned = fire_detected

#    [5356, 5366, 5357, 5382, 5383, 5391, 5392].each do |addr|
#      puts '%d: %d' % [addr, mb.read_holding_registers(addr, 1).first]
#    end
    sleep 5.0
  end
ensure
  mb.close
end
