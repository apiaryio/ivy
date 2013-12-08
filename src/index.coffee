config = require './config'

main   = require './ivy'
ivy = new main.Ivy config: config

module.exports = ivy

