require 'logger'
require 'blather/stanza/message'
require 'asana'
require 'amatch'

module Bot
    class Anne 
        def initialize(apiKey)
            @apiKey    = apiKey
            @log       = Logger.new(STDOUT)
            @log.level = Logger::DEBUG
        end

        # Asana interactions

        def findWorkspace(workspaceName) 

            # Fuzzy search for workspace
            maxscore = 0.0;
            targetWorkspace = nil
            matcher = Jaro.new(workspaceName)
            Asana::Workspace.all.each do |workspace| 
                score = matcher.match workspace.name
                if score > maxscore 
                    targetWorkspace = workspace
                    maxscore = score
                end
            end

            # TODO: Do we want to have a threshold for matches?
            return targetWorkspace
        end

        def findTask(taskName, workspace)
            # Fetch tasks from workspace
            maxscore = 0.0
            targetTask = nil
            matcher = Jaro.new(taskName)
            workspace.tasks.each do |task| 
                score = matcher.match task.name
                if score > maxscore
                    targetTask = task
                    maxscore = score
                end
            end

            # TODO: Do we want to have a threshold for matches?
            return targetTask
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

            queryText = message.body # Strip the Anne part out

            # Global
            if queryText.match /hey/i or queryText.match /hello/i
                # Just a greeting
                return buildMessage message.from.stripped ("Anne: Hello "+senderName)

            # Listing
            # TODO 

            # Creation 

            # Tasks must have associated workspace
                # Single line
                # "anne, ... create task (first) [taskname] in (last) [workspacename] "
            elsif condition

                # Parse out taskName and workspaceName

                workspace = findWorkspace workspaceName
                # Create task
                workspace.create_task(:name => taskName)
                return buildMessage message.from.stripped ("Anne: Created task, "+taskName+", in "+workspace.name)

            elsif condition
            # Story
                # Single line
                # "anne, ... post (first) [story] on [taskname] in (last) [workspacename]"

                # Parse out story, taskName, and workspaceName

                workspace = findWorkspace workspaceName
                # Fuzzy search for task
                task = findTask taskName workspace
                # Create story task
                task.create_story(:text => commentText)
                return buildMessage message.from.stripped ("Anne: Added comment to "+workspace.name+" task, "+task.name)
            
            elsif condition            
            # Completion
                # Single line
                # "anne, ... complete (first) [taskname] in (last) [workspacename]"

                # Parse out taskName and workspaceName

                workspace = findWorkspace workspaceName
                # Find task
                task = findTask taskName workspace
                # Update task
                task.update_attributed(:completed, true)
                return buildMessage message.from.stripped ("Anne: Marked "+workspace.name" task, "+task.name+", complete.")
 
            else
                # Default / Give up
                return buildMessage message.from.stripped ("Anne: Sorry? Is there a way I can help?")
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