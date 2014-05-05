winston        = require 'winston'

LOG_LEVEL = process.env.LOG_LEVEL or 'info'

logger = new (winston.Logger)(transports: [
  new (winston.transports.Console)(
    level: LOG_LEVEL
    colorize: true
  )
])

module.exports = logger
