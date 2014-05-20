#
# This file is part of Mozart
# (c) Spokela 2014
#
net = require 'net'
{EventEmitter} = require 'events'
ZMQManager = require './zmq-manager'

class Mozart extends EventEmitter
  constructor: (@config, @adapter) ->
    @socket
    @zmq = new ZMQManager config.zmq
    self = @
    adapter.on 'zmq', (eventName, args) ->
      self.zmq.broadcast eventName, args

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
    @zmq.init()

  connect: ->
    self = @
    @socket = net.connect {port: self.config.irc.port, host: self.config.irc.hostname}, () ->
      self.adapter.init self.socket

module.exports = Mozart