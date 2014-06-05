#
# This file is part of Mozart
# (c) Spokela 2014
#
net = require 'net'
{EventEmitter} = require 'events'
ZMQManager = require './zmq-manager'
Dispatcher = require './dispatcher'
IRC_EVENTS = require './events'

class Mozart extends EventEmitter
  constructor: (@config, @adapter) ->
    @socket
    @zmq = new ZMQManager config.zmq
    @retryTimer = null
    @connected = false
    self = @
    adapter.on 'zmq', (eventName, args) ->
      self.zmq.broadcast eventName, args

    @registerExitHandlers()
    process.title = 'mozart-core'

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
      self.connected = true
      self.adapter.init self.socket
      if self.retryTimer != null
        clearTimeout(self.retryTimer)
        self.retryTimer = null


    @socket.on 'error', (err) ->
      self.disconnect err

    @socket.on 'end', () ->
      self.connected = false

    @socket.on 'close', (hadError) ->
      if hadError
        self.disconnect "socket error"
      else
        self.disconnect "remote closed connection"

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

  disconnect: (reason = null, retry = true) ->
    if @socket != null
      if @connected
        @adapter.disconnect(reason)
        @socket.end()

      @socket.destroy()
      @socket = null

    console.log "IRC Connection closed: #{ reason }"
    @adapter.emit IRC_EVENTS.UPLINK_DISCONNECTED
    @adapter.cleanup()

    if @noRetry != undefined
      retry = !@noRetry
    else if !retry
      @noRetry = true

    if retry
      @noRetry = undefined
      @retry(0)

  retry: (step) ->
    if !@config.socket.retry
      @zmq.end 'IRC Connection lost'
      process.exit(0)
      return

    if @retryTimer != null
      if @connected
        clearTimeout(@retryTimer)
        @retryTimer = null
        return

      if @config.socket.maxRetries == 0
        max = "unlimited"
      else
        max = @config.socket.maxRetries

      console.log("Connecting to IRC... (retry #{ step }/#{ max })")
      @connect()
      return

    if @config.socket.maxRetries > 0 && step > @config.socket.maxRetries
      if !@connected
        @zmq.end 'IRC Connection lost'
        process.exit(1)
        return
      clearTimeout(@retryTimer)
      @retryTimer = null
      return

    self = @
    func = ->
      self.retry(step+1)

    console.log("Reconnection attempt in #{ @config.socket.retryDelay } seconds...")
    @retryTimer = setTimeout(func, @config.socket.retryDelay*1000)


module.exports = Mozart