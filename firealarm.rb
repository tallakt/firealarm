#!/usr/bin/env ruby
$stdout.sync = true

require 'rubygems'
require 'bundler/setup'
require 'yaml'
require 'rmodbus'
require 'clickatell'

class FireAlarm
	SAMPLE_TIME = 5.0
	SMS_RECIPIENTS = [4740220423, 4793242788]
	#SMS_RECIPIENTS = [4740220423]

	def initialize
		@test_sms_active = false
	end

	def run
		puts 'Fire alarm started'
		begin
			with_modbus do |slave|
				send_sms 'Fire alarm system started ok'
				loop do 
					fire_undetected_loop(slave)
					fire_detected_loop(slave)
				end
			end
		rescue => e
			puts e.to_s
			puts e.backtrace
			send_sms 'Firealarm: Modbus connection was lost'
			retry
		end
	end

	def is_thursday
		Date.today.wday == 4
	end

	def test_sms(slave)
		new_test_sms = is_thursday && (Time.now.hour >= 12)
		if new_test_sms && !@test_sms_active
			send_sms "Firealarm: weekly test, currect status is #{check_fire_detected(slave) ? 'burning' : 'ok'}"
		end
		@test_sms_active = new_test_sms
	end

	def fire_undetected_loop(slave)
		while not check_fire_detected(slave) do
			test_sms(slave)
			sleep SAMPLE_TIME
		end
	end

	def fire_detected_loop(slave)
		send_sms 'Smoke or water detector activated'
		while check_fire_detected(slave) do
			test_sms(slave)
			sleep SAMPLE_TIME
		end
		puts 'Fire alarm no longer active'
	end

	def with_modbus
		ModBus::TCPClient.new '192.168.0.189' do |mb|
			mb.with_slave 1 do |slave|
				yield slave
			end
		end
	end

	def with_clickatell
		cc = YAML.load_file File.join(Etc.getpwuid.dir, '.clickatell')
		yield Clickatell::API.authenticate cc['api_key'], cc['username'], cc['password']
	end

	def check_fire_detected(slave)
		ra, rb = slave.holding_registers[5391..5392]
		a, b, c, d = (0..3).map {|bit| ra[bit] }
		a == 0
	end

	def send_sms(text)
		recipients = SMS_RECIPIENTS.dup

		begin
			with_clickatell do |clickatell|
				while recipients.any?
					puts 'Sending SMS to %s with the text: %s' % [recipients.first, text]
					clickatell.send_message recipients.first, text
					recipients.shift
				end
			end
		rescue => e
			puts e.to_s
			puts e.backtrace
			wait = 10.0
			puts 'Could not send SMS, try again in %.0f seconds' % wait
			sleep wait
			retry
		end
	end
end


FireAlarm.new.run
