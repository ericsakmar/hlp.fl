class Project
  constructor: (@name) ->
    @tasks = []

  addTask: (task, isNext) ->
    if isNext
      @setNext task
    else
      # add to top of array
      @tasks.splice 0, 0, task

  setNext: (task) ->
    # move the old one into the regular array
    @addTask(@next) if @next?

    # set next
    @next = task

class Task
  constructor: (@name) ->
    @created = new Date()

@app = angular.module 'app', []

@app.run ['$rootScope', ($rootScope) -> $rootScope.appName = 'hlpr']

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
          projects.push cursor.value
          cursor.continue()
        else
          callback projects

  find: (name, callback) ->
    @openDb (db) -> 
      db.transaction(["projects"]).objectStore("projects").get(name).onsuccess = (event) ->
        callback event.target.result

  findOrCreate: (name, callback) -> 
    @find name, (project) ->
      if project? then callback(project) else callback(new Project(name))

  store: (project, callback) ->
    @openDb (db) ->
      db.transaction(["projects"], "readwrite").objectStore("projects").add(project).onsuccess = (event) ->
        console.log event.target.result
        callback project
  

@app.controller 'TaskListController', ['$scope', 'Projects', ($scope, Projects) ->

  refreshProjects = -> 
    Projects.findAll (projects) -> 
      $scope.$apply ->
        $scope.projects = projects

  refreshProjects()
  $scope.newTask = '@test new task'

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

      Projects.store(project, (project) -> refreshProjects())
  
  parseProjectName = (rawTask) -> /^\@[\w>\-]+/.exec(rawTask)[0]

  parseTaskName = (rawTask) -> /\s[\w\s]+!?$/.exec(rawTask)[0].replace(/(^\s)|(!$)/g, '')

  parseIsNext = (rawTask) -> rawTask.indexOf('!') == rawTask.length - 1
]
