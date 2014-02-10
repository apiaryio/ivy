
consumeTasks = (tasks) ->
  #FIXME: dependency smell, refactor
  ivy = require './index'

  for task in tasks
    result = ivy.callTask task.name, task.args


module.exports = {
  consumeTasks
}
