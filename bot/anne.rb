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

        # Messaging

        def buildMessage(user, body) 
            return Blather::Stanza::Message.new user, body
        end

        # Asana interactions

        def findWorkspace(workspaceName) 

            # Fuzzy search for workspace
            maxscore = 0.0;
            targetWorkspace = nil
            matcher = Amatch::Jaro.new(workspaceName)
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
            matcher = Amatch::Jaro.new(taskName)
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

        # Creation parsing
        def parseNewTask(queryText)

        end

        def parseNewComment(queryText)

        end

        def parseCompleteTask(queryText)

        end

        # Creation handle
        def handleNewTask(taskName, workspaceName)
            workspace = findWorkspace workspaceName
            # Create task
            workspace.create_task(:name => taskName)
            return [(buildMessage message.from.stripped, ("Anne: I've created the task, "+taskName+", in "+workspace.name))]
        end       

        def handleNewComment(commentText, taskName, workspaceName)
            workspace = findWorkspace workspaceName
            # Fuzzy search for task
            task = findTask taskName workspace
            # Create story task
            task.create_story(:text => commentText)
            return [(buildMessage message.from.stripped, ("Anne: I've added a comment to "+workspace.name+" task, "+task.name))]
        end

        def handleCompleteTask(taskName, workspaceName)
            workspace = findWorkspace workspaceName
            # Find task
            task = findTask taskName workspace
            # Update task
            task.update_attributed(:completed, true)
            return [(buildMessage message.from.stripped, ("Anne: I've marked "+workspace.name+" task, "+task.name+", complete."))]
        end

        # Events

        def onStatus(fromNodeName)
            # Dont do anything on status
            return []
        end

        def onQuery(message)
            condition = false
            # Anne Queries
            senderName = message.from.node.to_s

            queryText = message.body # Strip the Anne part out

            # Global
            if queryText.match /hey/i or queryText.match /hello/i or queryText.match /Hi/i
                # Just a greeting
                return [(buildMessage message.from.stripped, ("Anne: Hello "+senderName))]

            # Listing
            # TODO 

            # Creation 

            # Tasks must have associated workspace
                # Single line
                # "anne, ... create task [taskname] in [workspacename] "
            elsif queryText.match /create task/i

                # Parse out taskName and workspaceName
                params = parseNewTask queryText
                return handleNewTask params.taskName, params.workspaceName if params

            elsif condition
            # Story
                # Single line
                # "anne, ... post [story] on [taskname] in (last) [workspacename]"

                # Parse out story, taskName, and workspaceName
                params = parseNewComment queryText
                return handleNewComment params.story, params.taskName, params.workspaceName if params
            
            elsif queryText.match /complete/i            
            # Completion
                # Single line
                # "anne, ... complete [taskname] in [workspacename]"

                # Parse out taskName and workspaceName
                params = parseCompleteTask queryText
                return handleCompleteTask params.taskName, params.workspaceName if params
            end
            
            # Default / Give up
            return [(buildMessage message.from.stripped, "Anne: Sorry? Is there a way I can help?")]

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