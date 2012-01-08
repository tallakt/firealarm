#!/usr/bin/env ruby

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
		loop do 
			with_modbus do |slave|
				init_clickatell
				send_sms 'Fire alarm system started ok'
				loop do 
					fire_undetected_loop(slave)
					fire_detected_loop(slave)
				end
			end
			send_sms 'Firealarm: Modbus connection was lost'
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

	def init_clickatell
		cc = YAML.load_file File.join(Etc.getpwuid.dir, '.clickatell')
		@clickatell = Clickatell::API.authenticate cc['api_key'], cc['username'], cc['password']
	end

	def check_fire_detected(slave)
		ra, rb = slave.holding_registers[5391..5392]
		a, b, c, d = (0..3).map {|bit| ra[bit] }
		a == 0
	end

	def send_sms(text)
		SMS_RECIPIENTS.each do |tel|
			begin
				puts 'Sending SMS to %s with the text: %s' % [tel, text]
				@clickatell.send_message tel, text
			rescue
				wait = 10.0
				puts 'Could not send SMS, try again in %.0f seconds' % wait
				sleep wait
				retry
			end
		end
	end
end


FireAlarm.new.run
