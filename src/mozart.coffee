#
# This file is part of Mozart
# (c) Spokela 2014
#
net = require 'net'
{EventEmitter} = require 'events'

class Mozart extends EventEmitter
  @config
  @adapter
  @socket
  @zmq

  constructor: (@config, @adapter) ->
    console.log "starting mozart-core ..."

  start: ->
    self = @
    @socket = net.connect {port: @config.irc.port, host: @config.irc.hostname}, () ->
      self.adapter.init self.socket

module.exports = Mozart