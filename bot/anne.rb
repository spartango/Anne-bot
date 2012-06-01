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

        def buildTaskListing(tasks)
            # Get taskinfo
            fullTasks = tasks.map { |task| Asana::Task.find(task.id) }

            # Select only tasks that are incomplete
            fullTasks.select! { |task| not task.completed }

            # Sort tasks by due date
            # TODO

            # Show due dates
            fullTasks.map! { |task| task.name +
                 (task.due_on ? (Date.parse task.due_on).strftime(", due on %-m/%-d/%Y") : "") +
                 (task.assignee ? ", assigned to " + task.assignee.name + ". " : "") } 
            return fullTasks.join("\n\n")
        end

        def findWorkspace(workspaceName) 
            # Fuzzy search for workspace
            maxscore = -0.1
            targetWorkspace = nil
            matcher = Amatch::Jaro.new(workspaceName)
            Asana::Workspace.all.each do |workspace| 
                score = matcher.match workspace.name
                if score > maxscore 
                    targetWorkspace = workspace
                    maxscore = score
                end
            end

            @log.debug "[Anne]: Found workspace: "+targetWorkspace.name
            # TODO: Do we want to have a threshold for matches?
            return targetWorkspace
        end

        def findProject(projectName) 
            # Fuzzy search for workspace
            maxscore = -0.1
            targetProject = nil
            matcher = Amatch::Jaro.new(projectName)
            Asana::Project.all.each do |project| 
                score = matcher.match project.name
                if score > maxscore 
                    targetProject = project
                    maxscore = score
                end
            end

            @log.debug "[Anne]: Found project: "+targetProject.name
            # TODO: Do we want to have a threshold for matches?
            return targetProject
        end

        def findTask(taskName, workspace)
            # Fetch tasks from workspace
            maxscore = -0.1
            targetTask = nil
            matcher = Amatch::Jaro.new(taskName)
            tasks = (workspace.users.map { |user| workspace.tasks(user) }).flatten
            tasks.each do |task| 
                score = matcher.match task.name
                if score > maxscore
                    targetTask = task
                    maxscore = score
                end
            end
            
            @log.debug "[Anne]: Found Task: "+targetTask.name
            # TODO: Do we want to have a threshold for matches?
            return targetTask
        end

        def findUser(userName, workspace)
            # Fetch users from workspace
            maxscore = -0.1
            targetUser = nil
            matcher = Amatch::Jaro.new(userName)
            workspace.users.each do |user| 
                score = matcher.match user.name
                if score > maxscore
                    targetUser = user
                    maxscore = score
                end
            end
            
            @log.debug "[Anne]: Found User: "+targetUser.name
            # TODO: Do we want to have a threshold for matches?
            return targetUser
        end

        def buildWordStack(stopWord, parts)
            # Consume until 'post'
            stack = []

            pushing = false
            parts.each do |word|
                if pushing
                    # Push all
                    stack.push word
                elsif word == stopWord
                    pushing = true
                end
            end
            return stack
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

        def parseSingle(queryText, startWord, stopWord)
            # Tokenize
            parts = queryText.split(' ')

            # Consume until stopWord
            stack = buildWordStack stopWord, parts

            # Pop until stopWord -> workspace name
            name = popAndBuild stopWord, stack

            return name
        end

        # Creation parsing
        def parseTask(queryText, action)
            # Tokenize
            parts = queryText.split(' ')

            # Consume until 'create'
            # This is a bit of a hack, iterator like behavior
            stack = buildWordStack action, parts
            
            # Pop until in    -> workspace name
            workspaceName = popAndBuild 'in',   stack
            taskName      = popAndBuild 'task', stack
            
            return nil if taskName == '' or workspaceName == ''

            return { :workspaceName => workspaceName, :taskName => taskName }
        end

        def parseAssignment(queryText)
            # Tokenize
            parts = queryText.split(' ')

            stack = buildWordStack 'assign', parts
            
            # Pop until in    -> workspace name
            workspaceName = popAndBuild 'in',   stack
            assignee      = popAndBuild 'to',   stack
            taskName      = popAndBuild 'task', stack
            
            return nil if taskName == '' or workspaceName == '' or assignee == ''

            return { :assignee => assignee, :workspaceName => workspaceName, :taskName => taskName }
        end

        def parseComment(queryText)
            # Tokenize
            parts = queryText.split(' ')

            stack = buildWordStack 'post', parts

            # Pop until in    -> workspace name
            workspaceName = popAndBuild 'in',         stack
            
            # TODO: parser leaves "on" in the comment - adding "on task" breaks Anne
            taskName      = popAndBuild 'task',    stack
            story         = popAndBuild 'comment',    stack
            
            return nil if taskName == '' or workspaceName == '' or story == ''

            return { :story => story, :workspaceName => workspaceName, :taskName => taskName }
        end

        # Creation handle
        def handleNewTask(requester, taskName, workspaceName)
            workspace = findWorkspace workspaceName
            # Create task
            workspace.create_task(:name => taskName)
            return [(buildMessage requester, ("I've created the task ''"+taskName+"'' in "+workspace.name+"."))]
        end       

        def handleNewComment(requester, commentText, taskName, workspaceName)
            workspace = findWorkspace workspaceName
            # Fuzzy search for task
            task = findTask taskName, workspace
            # Create story task
            task.create_story(:text => commentText)
            return [(buildMessage requester, ("I've added a comment to the "+workspace.name+" task ''"+task.name+".''"))]
        end

        def handleCompleteTask(requester, taskName, workspaceName)
            workspace = findWorkspace workspaceName
            # Find task
            task = findTask taskName, workspace
            # Update task
            task.update_attribute(:completed, true)
            return [(buildMessage requester, ("I've marked the "+workspace.name+" task ''"+task.name+"'' complete."))]
        end

        def handleAssignment(requester, assignee, taskName, workspaceName) 
            workspace = findWorkspace workspaceName
            task = findTask taskName, workspace
            user = findUser assignee, workspace
            task.update_attribute(:assignee, user.id )
            return [(buildMessage requester, ("I've assigned the "+workspace.name+" task, "+task.name+", to "+user.name))]
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
            
            # Listing
                        
            # Get all workspaces
            if queryText.match /list workspaces/i
                @log.debug "[Anne]: Listing workspaces"

                # List of workspaces
                workspaces = Asana::Workspace.all.map { |workspace| workspace.name  }
                return [(buildMessage message.from.stripped, ("Your workspaces are: "+workspaces.join(', ')))] 
            
            # Get all projects in given workspace
            elsif queryText.match /list projects in/i
                @log.debug "[Anne]: Listing projects"
                # Parse the workspace name
                workspaceName = parseSingle queryText, 'projects', 'in'

                yield (buildMessage message.from.stripped, "Give me a moment...")

                # Find workspace
                workspace = findWorkspace workspaceName
                projects  = workspace.projects.map { |project| project.name  }
                return [(buildMessage message.from.stripped, ("Here are the projects in "+workspace.name+": "+projects.join(', ')))]    
            
            # Get all users with access to a given workspace
            elsif queryText.match /list users in/i
                @log.debug "[Anne]: Listing users"
                # Parse the workspace name
                workspaceName = parseSingle queryText, 'users', 'in'

                yield (buildMessage message.from.stripped, "Hold on please...")

                # Find workspace
                workspace = findWorkspace workspaceName
                users     = workspace.users.map { |user| user.name }
                return [(buildMessage message.from.stripped, ("Here are the users with access to "+workspace.name+": "+users.join(', ')))]    
            
            elsif queryText.match /list projects/i
                projects = Asana::Project.all.map { |project| project.name  }
                return [(buildMessage message.from.stripped, ("Here are all of your projects: "+projects.join(', ')))]
        
            # Get all tasks in a given workspace
            elsif queryText.match /list tasks in/i
                @log.debug "[Anne]: Listing tasks in a given workspace"
                workspaceName  = parseSingle queryText, 'tasks', 'in'

                workspace = findWorkspace workspaceName

                yield (buildMessage message.from.stripped, "Hold on a sec...")

                taskListings = workspace.users.map { |user| buildTaskListing(workspace.tasks(user.id)) }
                taskListing = taskListings.join("\n")
                return [(buildMessage message.from.stripped, ("Here are the tasks in "+workspace.name+": \n\n"+taskListing))]

            # Get all tasks in a given project
            elsif queryText.match /list tasks for/i
                @log.debug "[Anne]: Listing tasks for given project"
                projectName  = parseSingle queryText, 'tasks', 'for'

                project = findProject projectName

                yield (buildMessage message.from.stripped, "Hold on a sec...")

                taskListing = buildTaskListing(project.tasks)
                return [(buildMessage message.from.stripped, ("Here are the tasks for "+project.name+": "+taskListing))]
            # Creation 

            # Tasks must have associated workspace
                # Single line
                # "anne, ... create task [taskname] in [workspacename] "
            elsif queryText.match /create task/i

                # Parse out taskName and workspaceName
                params = parseTask queryText, 'create'

                yield (buildMessage message.from.stripped, "I'm on it...")

                return handleNewTask message.from.stripped, params[:taskName], params[:workspaceName] if params

                return [(buildMessage message.from.stripped, "Sorry, I couldn't create the task.")] # onError

            elsif queryText.match /post comment/i
            # Story
                # Single line
                # "anne, ... post comment [story] on task [taskname] in [workspacename]"

                # Parse out story, taskName, and workspaceName
                params = parseComment queryText

                yield (buildMessage message.from.stripped, "Posting...")

                return handleNewComment message.from.stripped, params[:story], params[:taskName], params[:workspaceName] if params
                
                return [(buildMessage message.from.stripped, "Sorry, I couldn't post the comment.")] # onError

            elsif queryText.match /complete/i            
            # Completion
                # Single line
                # "anne, ... complete task [taskname] in [workspacename]"

                yield (buildMessage message.from.stripped, "Working on it...")

                # Parse out taskName and workspaceName
                params = parseTask queryText, 'complete'
                return handleCompleteTask message.from.stripped, params[:taskName], params[:workspaceName] if params

                return [(buildMessage message.from.stripped, "Sorry, I couldn't complete the task.")] # onError

            elsif queryText.match /assign task/i
            # Assignment of a task
                params = parseAssignment queryText

                # "anne, ... assign task [taskname] in [workspacename] to [username]"
                yield (buildMessage message.from.stripped, "Assigning...")

                return handleAssignment message.from.stripped, params[:assignee], params[:taskName], params[:workspaceName] if params
                
                return [(buildMessage message.from.stripped, "Sorry, I couldn't assign that task.")] # onError

            elsif queryText.match /help/i
                sender = message.from.stripped
                return [(buildMessage sender, "Hi! I can *list* workspaces, tasks, or projects. "),
                        (buildMessage sender, "I can also help *create tasks* or *complete tasks*, or *post comments*. "),
                        (buildMessage sender, "I'm happy to be of service. Your wish is my command. ")]

            elsif queryText.match /thank/i
                return [(buildMessage message.from.stripped, "No problem. ")]
            
            elsif queryText.match /hi/i or queryText.match /hello/i or queryText.match /hey/i
                return [(buildMessage message.from.stripped, "Hello. ")]
            end  
            # Default / Give up
            return []
        end

        def onMessage(message, &onProgress)
            # Query handling
            queryMsgs = []
            if message.body.match /Anne/i 
                queryMsgs = onQuery message, &onProgress
            end

            return queryMsgs
        end

    end
end
