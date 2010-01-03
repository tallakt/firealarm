#!/usr/bin/env ruby

require 'rubygems'
require 'etc'
require 'yaml'
require 'rmodbus'
require 'clickatell'
require 'daemons'

class FireAlarm
	SAMPLE_TIME = 5.0

	def run
		log 'Fire alarm daemon started'
		with_modbus do
			init_clickatell
			loop do 
				fire_undetected_loop
				fire_detected_loop
			end
		end
	end

	def fire_undetected_loop
		while not check_fire_detected do
			sleep SAMPLE_TIME
		end
	end

	def fire_detected_loop
		send_sms 'Smoke or water detector activated'
		while check_fire_detected do
			sleep SAMPLE_TIME
		end
		log 'Fire alarm no longer active'
	end

	def with_modbus
		@mb = ModBus::TCPClient.new '192.168.0.189'
		begin
			yield
		ensure
			@mb.close
		end
	end

	def init_clickatell
		cc = YAML.load_file File.join(Etc.getpwuid.dir, '.clickatell')
		@clickatell = Clickatell::API.authenticate cc['api_key'], cc['username'], cc['password']
	end

	def check_fire_detected
		ra, rb = @mb.read_holding_registers 5391, 2
		a, b, c, d = (0..3).map {|bit| ra[bit] }
		a == 0
	end

	def send_sms(text)
		%w(4740220423 4740402040).each do |tel|
			begin
				log 'Sending SMS to %s with the text: %s' % [tel, text]
				@clickatell.send_message tel, text
			rescue
				wait = 10.0
				log 'Could not send SMS, try again in %.0f seconds' % wait
				sleep wait
				retry
			end
		end
	end

	def log(text)
		puts Time.new.to_s + ' > ' + text
	end
end


FireAlarm.new.run
