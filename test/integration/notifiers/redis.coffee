{assert}    = require 'chai'
#{describe}  = require 'mocha'

{
  factorial
  factorialSync
  factorialFinished
  factorialFinishedCounterObject
}           = require '../../helpers'

ivy         = require '../../../src'

# internal
{notifier}  = require '../../../src/notifiers'
{queue}     = require '../../../src/queues'


describe 'Redis notifier', ->
  before (done) ->
    queue.clear -> notifier.clear done

  it 'runs', -> assert.equal false, true
