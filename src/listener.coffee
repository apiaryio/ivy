
consumeTasks = (tasks) ->
  #FIXME: dependency smell, refactor
  ivy = require './index'

  for task in tasks
    result = ivy.callTask task.name, task.args
    console.error 'result is', result


module.exports = {
  consumeTasks
}
