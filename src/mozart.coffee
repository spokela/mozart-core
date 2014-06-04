#
# This file is part of Mozart
# (c) Spokela 2014
#
net = require 'net'
{EventEmitter} = require 'events'
ZMQManager = require './zmq-manager'
Dispatcher = require './dispatcher'

class Mozart extends EventEmitter
  constructor: (@config, @adapter) ->
    @socket
    @zmq = new ZMQManager config.zmq
    self = @
    adapter.on 'zmq', (eventName, args) ->
      self.zmq.broadcast eventName, args

    @registerExitHandlers()

  start: ->
    console.log "                                 _   "
    console.log "                                | |  "
    console.log "    _ __ ___   ___ ______ _ _ __| |_ "
    console.log "   | '_ ` _ \\ / _ \\_  / _` | '__| __|"
    console.log "   | | | | | | (_) / / (_| | |  | |_ "
    console.log "   |_| |_| |_|\\___/___\\__,_|_|   \\__|"
    console.log "                          -core        "

    self = @
    # wait until all zmq slots are ready
    @zmq.on 'ready', ->
      console.log '---------------------------------------------'
      console.log 'ZMQ bindings now ready. Connecting to IRC ...'
      self.connect()
    @zmq.init(@adapter)

  connect: ->
    self = @
    @socket = net.connect {port: self.config.irc.port, host: self.config.irc.hostname}, () ->
      self.adapter.init self.socket

  registerExitHandlers: ->
    # prevent the program to exit instantly
    process.stdin.resume();

    self = @
    exitHandler = (cleanup = false, exit = true, err = null) ->
      console.log "\n---------------------------------------------"

      self.zmq.end('process exit')

      if cleanup == true
        require('util').print("\u001b[2J\u001b[0;0H");

      if err != null
        console.log err.stack

      console.log '---------------------------------------------'

      if exit == true
        process.exit()

    # register handlers
    process.on('SIGINT', exitHandler.bind(null, false, true));
    process.on('uncaughtException', exitHandler.bind(null, false, true));

module.exports = Mozart