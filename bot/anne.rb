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

            @log.debug "[Anne]: Found workspace: "+targetWorkspace.name+" -> "+maxscore
            # TODO: Do we want to have a threshold for matches?
            return targetWorkspace
        end

        def findProject(projectName) 
            # Fuzzy search for workspace
            maxscore = 0.0;
            targetProject = nil
            matcher = Amatch::Jaro.new(projectName)
            Asana::Project.all.each do |project| 
                score = matcher.match project.name
                if score > maxscore 
                    targetProject = project
                    maxscore = score
                end
            end

            @log.debug "[Anne]: Found project: "+targetProject.name+" -> "+maxscore
            # TODO: Do we want to have a threshold for matches?
            return targetProject
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
            
            @log.debug "[Anne]: Found Task: "+targetTask.name+" -> "+maxscore
            # TODO: Do we want to have a threshold for matches?
            return targetTask
        end

        def popAndBuild(stopWord, stack)
            buffer = []
            while not stack.empty?
                word = stack.pop
                if word == stopWord
                    break
                end
                buffer.push word
            end
            return buffer.reverse.join(' ')
        end

        def parseWorkspace(queryText)

        end

        def parseProject(queryText)

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
            workspaceName = popAndBuild 'in',   stack
            taskName      = popAndBuild 'task', stack
            
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
            workspaceName = popAndBuild 'in',      stack
            taskName      = popAndBuild 'task',    stack
            story         = popAndBuild 'comment', stack
            
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

        # Query
        def onQuery(message)
            # Anne Queries
            senderName = message.from.node.to_s

            queryText = message.body # Strip the Anne part out

            # Global
            if queryText.match /hey/i or queryText.match /hello/i or queryText.match /Hi/i
                @log.debug "[Anne]: Responding to greeting"
                # Just a greeting
                return [(buildMessage message.from.stripped, ("Anne: Hello "+senderName))]

            # Listing
                        
            # Get all workspaces
            elsif queryText.match /list workspaces/i
                # List of workspaces
                workspaces = Asana::Workspace.all.map { |workspace| workspace.name  }
                return [(buildMessage message.from.stripped, ("Anne: "+senderName+", your workspaces are: "+workspaces.join(', ')))] 

            # Get specific workspace
            
            # Get all projects in given workspace
            elsif queryText.match /list projects in/i
                # Parse the workspace name
                workspaceName = parseWorkspace queryText
                # Find workspace
                workspace = findWorkspace workspaceName
                projects  = workspace.projects.map { |project| project.name  }
                return [(buildMessage message.from.stripped, ("Anne: "+senderName+", here are the projects in "+workspace.name+": "+projects.join(', ')))]    
            
            elsif queryText.match /list projects/i
                projects = Asana::Project.all.map { |project| project.name  }
                return [(buildMessage message.from.stripped, ("Anne: "+senderName+", here are all of your projects: "+projects.join(', ')))]
        
            
            # Get all tasks in a given workspace associated with a specific user
            
            # Get all users with access to a given workspace

            # Get a specific project (fuzzy search?)
            
            # Get all tasks in a given workspace
            elsif queryText.match /list tasks in/i
                projectName  = parseWorkspace queryText

                workspace = findWorkspace workspaceName

                tasks = workspace.tasks(Asana::User.me.id)
                return [(buildMessage message.from.stripped, ("Anne: "+senderName+", here are the tasks in "+workspace.name+": "+tasks.join(', ')))]

            # Get all tasks in a given project
            elsif queryText.match /list tasks for/i
                projectName  = parseProject queryText

                project = findProject projectName

                tasks = project.tasks
                return [(buildMessage message.from.stripped, ("Anne: "+senderName+", here are the tasks for "+project.name+": "+tasks.join(', ')))]
            
            # Get all stories for a given task

            # Creation 

            # Tasks must have associated workspace
                # Single line
                # "anne, ... create task [taskname] in [workspacename] "
            elsif queryText.match /create task/i

                # Parse out taskName and workspaceName
                params = parseTask queryText, 'create'
                return handleNewTask message.from.stripped, params[:taskName], params[:workspaceName] if params

            elsif queryText.match /post comment/i
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

            elsif queryText.match /help/i
                return [(buildMessage message.from.stripped, "Anne: Hi "+senderName+"! I can *list* workspaces, tasks, or projects. "),
                        (buildMessage message.from.stripped, "Anne: I can also help *create tasks* or *complete tasks*, or *post comments*. "),
                        (buildMessage message.from.stripped, "Anne: I'm happy to be of service. ")]

            elsif queryText.match /thank/i
                return [(buildMessage message.from.stripped, "Anne: No problem, "+senderName)]
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