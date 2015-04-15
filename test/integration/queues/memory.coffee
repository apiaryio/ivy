{assert}    = require 'chai'
sinon       = require 'sinon'

{
  factorial
  factorialFinished
  sendObject
  sendObjectFinished
}           = require '../../helpers'
{
  getBaseTestSuite
}           = require './base'

ivy         = require '../../../src'

# internal
{queue}     = require '../../../src/queues'


describe 'Memory Queue Backend Test', ->

  mqOptions =
    type: 'memory'

  getBaseTestSuite mqOptions, (queue, done) ->
    ivy.setupQueue mqOptions, (err) ->
      if err then return err
      queue.clear ['ivy', 'objectSendingQueue'], (err) ->
        # err means queue does not exists and that's OK
        done null
