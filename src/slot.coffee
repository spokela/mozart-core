#
# This file is part of Mozart
# (c) Spokela 2014
#
zmq = require 'zmq'
{EventEmitter} = require 'events'
Dispatcher = require './dispatcher'

class Slot extends EventEmitter
  constructor: (@name, @bindAddr, adapter, @heartbeat = 30) ->
    @dispatcher = new Dispatcher adapter, @
    @connected = false

  init: ->
    if @connected
      throw new Error 'socket already initialized'

    @socket = zmq.socket 'rep'
    @connected = false
    @socket.bindSync @bindAddr
    @lastMsg = 0
    self = @
    @socket.on 'message', (data) ->
      if !self.connected
        self.startMonitor()
      else
        self.lastMsg = Math.round(new Date()/1000)

      self.handle data

    @emit 'ready'

  handle: (data) ->
    # ignore empty messages
    if data == null || data.length <= 0
      return

    data = data.toString()
    if data.indexOf('% ') == -1
      throw new Error "Invalid message recieved on Slot '#{ @name }': #{ data }"

    split = data.split('% ')
    args =JSON.parse(split[1])
    args.unshift split[0]

    rep = @dispatcher.exec.apply(@dispatcher, args)
    console.log rep
    @socket.send rep

  startMonitor: ->
    if @connected
      return

    @connected = true
    @lastMsg = Math.round(new Date()/1000)
    @monitor()
    @emit 'client'

  monitor: ->
    now = Math.round(new Date()/1000)
    if @lastMsg != 0 && now-@lastMsg > @heartbeat
      @end('heartbeat timeout', true)
      return

    self = @
    func = ->
      self.monitor()

    @hb = setTimeout(func, @heartbeat*1000)

  end: (reason = null, reopen = true) ->
    try
      @socket.close()
    catch err
      # do nothing, socket will be re-initialized
      humpf = null

    if @hb != null
      clearTimeout(@hb)
      @hb = null

    @connected = false
    @lastMsg = 0
    @emit('end', reason)

    if reopen == true
      @init()

module.exports = Slot