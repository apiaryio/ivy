config = require './config'

main   = require './ivy'

ivy = new main.Ivy config: config
ivy.setupMain()

module.exports = ivy

