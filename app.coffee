class Project
  constructor: (@name) ->
    @tasks = []
    @finished = []

  @wrap: (rawProject) ->
    project = null
    if rawProject?
      project = new Project(rawProject.name)
      project.next = rawProject.next
      project.tasks = rawProject.tasks
      project.finished = rawProject.finished
    project

  addTask: (task, isNext) -> if isNext then @setNext task else @tasks.push task

  removeTask: (task) -> 
    if task == @next
      @next = null
    else
      i = @tasks.indexOf task
      @tasks.splice i, 1
    
  setNext: (task) ->
    # add the current next task to the list of tasks
    @addTask(@next, false) if @next?

    # set next
    @next = task

    # if the task was already in the list, remove it
    i = @tasks.indexOf task
    @tasks.splice(i, 1) if i != -1

  parentName: ->
    i = @name.indexOf '>'
    if i == -1 then @name else @name.substring 0, i

class Task
  constructor: (@name) ->
    @created = new Date()

@app = angular.module 'app', []

@app.run ['$rootScope', ($rootScope) -> $rootScope.appName = 'hlp.fl']

@app.factory 'Projects', ->

  openDb: (callback) ->
    indexedDB = window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB;
    request = indexedDB.open "hlpr", 2

    request.onerror = (event) -> console.log event

    request.onsuccess = (event) -> 
      db = request.result
      db.onerror = (event) -> console.log event
      callback db

    request.onupgradeneeded = (event) ->
      db = event.target.result
      objectStore = db.createObjectStore("projects", { keyPath: "name" })

  findAll: (callback) ->
    @openDb (db) ->
      projects = [];
      db.transaction(["projects"]).objectStore("projects").openCursor().onsuccess = (event) ->
        cursor = event.target.result
        if cursor?
          project = Project.wrap(cursor.value)
          projects.push project if project.next? or project.tasks.length > 0
          cursor.continue()
        else
          callback projects

  find: (name, callback) ->
    @openDb (db) -> 
      db.transaction(["projects"]).objectStore("projects").get(name).onsuccess = (event) ->
        callback Project.wrap(event.target.result)

  findOrCreate: (name, callback) -> 
    @find name, (project) ->
      if project? then callback(project) else callback(new Project(name))

  store: (project, callback) ->
    @openDb (db) ->
      db.transaction(["projects"], "readwrite").objectStore("projects").put(project).onsuccess = (event) ->
        callback project
  

@app.controller 'TaskListController', ['$scope', 'Projects', ($scope, Projects) ->

  refreshProjects = -> 
    Projects.findAll (projects) -> 
      sorted = projects.sort (left, right) -> 
        if (left.parentName() < right.parentName())
          -1
        else if (left.parentName() > right.parentName()) 
          1
        else 
          0

      groups = []
      group = []
      parent = null
      for project in sorted
        if parent? and parent.name == project.parentName()
          group.push project
        else
          # this is the parent
          parent = project
          group = []
          group.push parent
          groups.push group

      $scope.$apply ->
        $scope.projects = projects
        $scope.projectGroups = groups

  refreshProjects()
  
  $scope.createTask = -> 
    # get or create project
    projectName = parseProjectName $scope.newTask
    Projects.findOrCreate projectName, (project) ->
      # create task
      taskName = parseTaskName $scope.newTask
      task = new Task(taskName)
      
      # add to project
      isNext = parseIsNext $scope.newTask
      project.addTask task, isNext

      Projects.store project, (project) -> 
        refreshProjects()
        $scope.newTask = null

  parseProjectName = (rawTask) -> /^\@[\w>\-\.]+/.exec(rawTask)[0]

  parseTaskName = (rawTask) -> /\s.+!?$/.exec(rawTask)[0].replace(/(^\s)|(!$)/g, '')

  parseIsNext = (rawTask) -> rawTask.indexOf('!') == rawTask.length - 1

  $scope.markDone = (project, task) ->
    project.finished.push task
    project.removeTask task
    Projects.store project, (project) -> refreshProjects()

  $scope.markNext = (project, task) ->
    project.setNext task
    Projects.store project, (project) -> refreshProjects()

  $scope.deleteTask = (project, task) ->
    project.removeTask task
    Projects.store project, (project) -> refreshProjects()    
]
