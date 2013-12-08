{assert}    = require 'chai'

{factorial} = require './testfunc'

ivy         = require '../src'

# internal
{queue}     = require '../src/queues'


describe 'Passing info through queue', ->
  describe 'When I call delayed function on paused queue', ->
    before ->
      queue.pause()

      ivy.registerTask ivy

      ivy.delayedCall factorial, 5


    after ->
      queue.resume()


    describe 'and inspect paused queue', ->
      tasks = undefined

      before (done) ->
        queue.getQueueContent (err, queueTasks) ->
          tasks = queueTasks

          done err

      it 'I should see function there', ->
        assert.equal 1, tasks.length


