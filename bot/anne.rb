require 'logger'
require 'blather/stanza/message'
require 'asana'
require 'amatch'

module Bot
    class Anne 
        def initialize(apiKey)
            @apiKey    = apiKey

            Asana.configure do |client|
                client.api_key = @apiKey
            end

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
            workspace.tasks(Asana::User.me.id).each do |task| 
                score = matcher.match task.name
                if score > maxscore
                    targetTask = task
                    maxscore = score
                end
            end

            # TODO: Do we want to have a threshold for matches?
            return targetTask
        end

        def popAndBuild(stopWord, stack)
            buffer = []
            while not stack.empty?
                word = stack.pop
                if word == 'in'
                    break
                end
                buffer.push word
            end
            return buffer.reverse.join(' ')
        end

        # Creation parsing
        def parseTask(queryText, action)
            # Tokenize
            parts = queryText.split(' ')

            # Consume until 'create'
            # This is a bit of a hack, iterator like behavior
            stack = []

            pushing = false
            parts.each do |word|
                if pushing
                    # Push all
                    stack.push word
                elsif word == action
                    pushing = true
                end
            end
            
            # Pop until in    -> workspace name
            workspaceName = popAndBuild 'in', stack

            # Pop until task  -> taskName
            taskName = popAndBuild 'task', stack
            
            return nil if taskName == '' or workspaceName == ''

            return { :workspaceName => workspaceName, :taskName => taskName }
        end

        def parseComment(queryText)
            # Tokenize
            parts = queryText.split(' ')

            # Consume until 'post'
            stack = []

            pushing = false
            parts.each do |word|
                if pushing
                    # Push all
                    stack.push word
                elsif word == 'post'
                    pushing = true
                end
            end
            
            # Pop until in    -> workspace name
            workspaceName = popAndBuild 'in', stack

            # Pop until task  -> taskName
            taskName = popAndBuild 'task', stack

            story = popAndBuild 'comment', stack
            
            return nil if taskName == '' or workspaceName == '' or story == ''

            return { :story => story, :workspaceName => workspaceName, :taskName => taskName }
        end

        # Creation handle
        def handleNewTask(requester, taskName, workspaceName)
            workspace = findWorkspace workspaceName
            # Create task
            workspace.create_task(:name => taskName)
            return [(buildMessage requester, ("Anne: I've created the task, "+taskName+", in "+workspace.name))]
        end       

        def handleNewComment(requester, commentText, taskName, workspaceName)
            workspace = findWorkspace workspaceName
            # Fuzzy search for task
            task = findTask taskName, workspace
            # Create story task
            task.create_story(:text => commentText)
            return [(buildMessage requester, ("Anne: I've added a comment to the "+workspace.name+" task, "+task.name))]
        end

        def handleCompleteTask(requester, taskName, workspaceName)
            workspace = findWorkspace workspaceName
            # Find task
            task = findTask taskName, workspace
            # Update task
            task.update_attribute(:completed, true)
            return [(buildMessage requester, ("Anne: I've marked the "+workspace.name+" task, "+task.name+", complete."))]
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
                params = parseTask queryText, 'create'
                return handleNewTask message.from.stripped, params[:taskName], params[:workspaceName] if params

            elsif condition
            # Story
                # Single line
                # "anne, ... post comment [story] on task [taskname] in [workspacename]"

                # Parse out story, taskName, and workspaceName
                params = parseComment queryText
                return handleNewComment message.from.stripped, params[:story], params[:taskName], params[:workspaceName] if params
            
            elsif queryText.match /complete/i            
            # Completion
                # Single line
                # "anne, ... complete task [taskname] in [workspacename]"

                # Parse out taskName and workspaceName
                params = parseTask queryText, 'complete'
                return handleCompleteTask message.from.stripped, params[:taskName], params[:workspaceName] if params
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