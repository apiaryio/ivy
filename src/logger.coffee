winston        = require 'winston'

LOG_LEVEL = process.env.LOG_LEVEL or 'info'

oldLog = winston.transports.Console.prototype.log

winston.transports.Console.prototype.log = (level, msg, meta, callback) ->
  if meta and (meta instanceof Error) and (stack = meta.stack)
    meta = stack
  oldLog.call @, level, msg, meta, callback

logger = new (winston.Logger)(transports: [
  new (winston.transports.Console)(
    level: LOG_LEVEL
    colorize: true
  )
])

module.exports = logger
