require 'logger'
require 'blather/stanza/message'
require 'asana'

module Bot
    class Anne 
        def initialize(apiKey)
            @apiKey    = apiKey
            @log       = Logger.new(STDOUT)
            @log.level = Logger::DEBUG
        end

        def buildMessage(user, body) 
            return Blather::Stanza::Message.new user, body
        end

        def onStatus(fromNodeName)
            # Dont do anything on status
            return []
        end

        def onQuery(message)
            # Anne Queries
            senderName = message.from.node.to_s

            # TODO handle Asana queries

            # Global
            if message.body.match /hey/ or message.body.match /hello/
                # Just a greeting
                return buildMessage message.from.stripped ("Anne: Hello "+senderName)
            else
                # Default / Give up
                return buildMessage message.from.stripped "Anne: Sorry "+senderName+", I can't help you with that."
            end

        end

        def onMessage(message)
            # Query handling
            queryMsgs = []
            if message.body.match /Anne/ or message.body.match /anne/
                queryMsgs = onQuery(message)
            end

            return queryMsgs
        end

    end
end