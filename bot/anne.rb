require 'logger'
require 'blather/stanza/message'
require 'asana'
require 'fuzzystringmatch'

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
            if message.body.match /hey/i or message.body.match /hello/i
                # Just a greeting
                return buildMessage message.from.stripped ("Anne: Hello "+senderName)

            # Listing

            # Creation 
            
            # Tasks must have associated workspace
                # Single line
                # "anne, create ... [taskname] ... [workspacename] "
                    # Fetch workspace listing
                    # Fuzzy search for workspace
                    # Create task

            # Story
                # Single line
                # "anne, ... comment on ... [story] ... [taskname] ... [workspacename]"
                    # Fetch workspace listing
                    # Fuzzy search for workspace
                    # Fuzzy search for task
                    # Create story task

            # Completion
                # Single line
                # "anne, ... complete ... [taskname] ... [workspacename]"
                    # Fetch workspace listing
                    # Fuzzy search for workspace
                    # Fuzzy search for task
                    # Update task

            else
                # Default / Give up
                return buildMessage message.from.stripped ("Anne: Sorry "+senderName+", I can't help you with that.")
            end

        end

        def onMessage(message)
            # Query handling
            queryMsgs = []
            if message.body.match /Anne/i 
                queryMsgs = onQuery(message)
            end

            return queryMsgs
        end

    end
end