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

        # Asana interactions

        def findWorkspace(workspaceName) 
            # Fetch workspace listing -> cache
            # Fuzzy search for workspace
        end

        def findTask(taskName, workspace)
            # Fetch tasks from workspace

        end

        # Messaging

        def buildMessage(user, body) 
            return Blather::Stanza::Message.new user, body
        end

        # Events

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
            # TODO 
            # Creation 

            # Tasks must have associated workspace
                # Single line
                # "anne, create ... [taskname] ... [workspacename] "
            elsif condition
                    workspace = findWorkspace workspaceName
                    # Create task
                    workspace.create_task(:name => taskName)
                    return buildMessage message.from.stripped ("Anne: ")

            elsif condition
            # Story
                # Single line
                # "anne, ... comment on ... [story] ... [taskname] ... [workspacename]"
                    workspace = findWorkspace workspaceName
                    # Fuzzy search for task
                    task = findTask taskName workspace
                    # Create story task
                    task.create_story(:text => commentText)
                    return buildMessage message.from.stripped ("Anne: ")
            
            elsif condition            
            # Completion
                # Single line
                # "anne, ... complete ... [taskname] ... [workspacename]"
                    workspace = findWorkspace workspaceName
                    # Find task
                    task = findTask taskName workspace
                    # Update task
                    task.update_attributed(:completed, true)
                    return buildMessage message.from.stripped ("Anne: ")

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