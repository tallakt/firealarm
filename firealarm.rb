#!/usr/bin/env ruby
$stdout.sync = true

require 'rubygems'
require 'bundler/setup'
require 'yaml'
require 'rmodbus'
require 'clickatell'
require 'logger'

# Simple class to monitor a signal and call
# the block when signal is triggered
class BoolSignal
	def initialize
		yield self if block_given?
	end

	def on_re(&block)
		@on_re = block
	end

	def on_fe(&block)
		@on_fe = block
	end

	# current value
	def v
		@old_v
	end

	def v=(v)
		if !v && @old_v
			@on_fe && @on_fe.call
		end
		if v && !@old_v
			@on_re && @on_re.call
		end
		@old_v = !!v
	end
end

class FireAlarm
	SAMPLE_TIME = 20.0
	SMS_RECIPIENTS = [4740220423]
	attr_reader :log

	def initialize
		@test_sms_active = false
		@log = Logger.new STDERR
		@test_active = BoolSignal.new do |s|
			s.on_re { send_test_sms }
		end
		@fire_detected = BoolSignal.new do |s|
			s.on_re { fire_detected }
			s.on_fe { fire_alarm_gone }
		end
	end

	def run
		log.info 'Fire alarm started'
		begin
			with_modbus do |slave|
				send_sms 'Fire alarm system started ok'
				loop do 
					@test_active.v = is_thursday_afternoon
					@fire_detected.v = check_fire_detected slave
					sleep SAMPLE_TIME
				end
				# runs forever
			end
		rescue => e
			log.error 'Modbus connection lost'
			log.info e
			send_sms 'Firealarm: Modbus connection was lost'
			retry
		end
	end

	def is_thursday_afternoon
		Date.today.wday == 4 && (Time.now.hour >= 12)
	end

	def send_test_sms
		log.info 'Weekly test activated'
		send_sms "Firealarm: weekly test"
	end

	def fire_detected
		log.info 'Fire detected'
		send_sms 'Smoke or water detector activated'
	end

	def fire_alarm_gone
		log.info 'Fire alarm no longer active'
	end

	def with_modbus
		ModBus::TCPClient.new '192.168.0.189' do |mb|
			mb.with_slave 1 do |slave|
				log.info 'Connected to modbus server'
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
		log.info "Sending messages"
		recipients = SMS_RECIPIENTS.dup

		begin
			with_clickatell do |clickatell|
				log.info 'Connected to Clickatell'
				while recipients.any?
					log.info 'Sending SMS to %s with the text: %s' % [recipients.first, text]
					clickatell.send_message recipients.first, text
					recipients.shift
				end
			end
			log.info 'SMS sending finished'
		rescue => e
			log.error 'Unable to send SMS'
			log.info e
			wait = 10.0
			puts 'Could not send SMS, try again in %.0f seconds' % wait
			sleep wait
			retry
		end
	end
end


FireAlarm.new.run
