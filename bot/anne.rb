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

            @matcher = FuzzyStringMatch::JaroWinkler.create( :native )
        end

        # Asana interactions

        def findWorkspace(workspaceName) 

            # Fuzzy search for workspace
            maxscore = 0.0;
            targetWorkspace = nil
            Asana::Workspace.all.each do |workspace| 
                score = matcher.getDistance(workspace.name, workspaceName) 
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
            workspace.tasks.each do |task| 
                score = matcher.getDistance(task.name, taskName)
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
                # "anne, ... create ... task [taskname] in [workspacename] "
            elsif condition
                workspace = findWorkspace workspaceName
                # Create task
                workspace.create_task(:name => taskName)
                return buildMessage message.from.stripped ("Anne: Created task, "+taskName+", in "+workspace.name)

            elsif condition
            # Story
                # Single line
                # "anne, ... post [story] on [taskname] in  [workspacename]"
                workspace = findWorkspace workspaceName
                # Fuzzy search for task
                task = findTask taskName workspace
                # Create story task
                task.create_story(:text => commentText)
                return buildMessage message.from.stripped ("Anne: Added comment to "+workspace.name+" task, "+task.name)
            
            elsif condition            
            # Completion
                # Single line
                # "anne, ... complete [taskname] in [workspacename]"
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