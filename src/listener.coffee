{EventEmitter} = require 'events'

class Listener extends EventEmitter


consumeTasks = (tasks) ->
  #FIXME: dependency smell, refactor
  ivy = require './index'

  for task in tasks
    result = ivy.executeTask task.name, task.args

listener = new Listener

module.exports = {
  consumeTasks
  Listener
  listener
}
