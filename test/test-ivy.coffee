{assert}    = require 'chai'

ivy         = require '../src'

{queue}     = require '../src/queues'
{notifier}  = require '../src/notifiers'

describe 'Register Task', ->

  describe 'When I set up queue with non-existing function', ->

    before (done) ->
      queue.clear -> notifier.clear done

    after ->
      ivy.clearTasks()

    it 'Try registerTask', ->
      try
        ivy.registerTask null, null, name: 'factorial'
      catch e
        assert.equal "First parameter 'func' isn't function is null", e.message
