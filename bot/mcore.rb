require 'rubygems'
require 'blather/client'

require './bot/anne'

require 'logger'

# Core Logger init
log       = Logger.new(STDOUT)
log.level = Logger::DEBUG

# Login info
botUsername = ''
botPassword = ''
# found under Asana settings
asanaKey    = ''

anne = Bot::Anne.new(asanaKey)

setup botUsername, botPassword, 'talk.google.com', 5222

# Sends all the messages in a list of messages
def send_messages(messages)
    messages.each { |m| write_to_stream m }
end

when_ready do 
    log.warn "[Core]: Ready!"
end

# Handlers

# Online/offline handling
status do |s| 
    fromNodeName = s.from.stripped
    log.debug "[Core]: status of "+s.from.to_s+" is "+s.state.to_s
    if not fromNodeName.to_s == botUsername
        send_messages anne.onStatus fromNodeName
    end
end

# Subscription handling
subscription :request? do |s|
    write_to_stream s.approve!
    log.info "[Core]: approved "+s.to.to_s
end

# Message handling
message :chat?, :body do |message| 
    # Pass to bots for processing
    send_messages anne.onMessage(message) { |progressMessage| write_to_stream progressMessage }
end

