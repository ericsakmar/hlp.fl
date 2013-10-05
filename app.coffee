@app = angular.module 'app', []

@app.run ['$rootScope', ($rootScope) -> $rootScope.appName = 'hlpr']

@app.factory 'Projects', ->
  indexedDB = window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB;
  request = indexedDB.open "hlpr", 2
  request.onerror = (event) -> console.log event
  request.onsuccess = (event) -> 
    @db = request.result
    @db.onerror = (event) -> console.log event    
  request.onupgradeneeded = (event) ->
    db = event.target.result
    objectStore = db.createObjectStore("projects", { keyPath: "name" })

  {
    db: @db
    find: (name) ->
      console.log @db
      @db.transaction(["hlpr"]).objectStore("projects").get(name).onsuccess = (event) ->
        console.log request

    getOrCreate: (name) -> @find(name)
  }


@app.controller 'TaskListController', ['$scope', 'Projects', ($scope, Projects) ->

  $scope.createTask = -> 
    # get or create project
    projectName = parseProjectName $scope.newTask
    project = Projects.getOrCreate projectName

    # create task
    taskName = parseTaskName $scope.newTask

    # check if it should be marked as next
    isNext = parseIsNext $scope.newTask
    
  parseProjectName = (rawTask) -> /^\@[\w>\-]+/.exec(rawTask)[0]

  parseTaskName = (rawTask) -> /\s[\w\s]+!?$/.exec(rawTask)[0].replace(/(^\s)|(!$)/g, '')

  parseIsNext = (rawTask) -> rawTask.indexOf('!') == rawTask.length - 1
]