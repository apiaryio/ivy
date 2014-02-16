helpers = require './helpers'

if process.env.REDIS_URL
  require './integration/notifiers/redis'
else
  describe.skip 'Redis Test Suite', -> it 'Dummy it'
