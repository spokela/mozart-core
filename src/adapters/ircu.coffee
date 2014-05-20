#
# This file is part of Mozart
# (c) Spokela 2014
#
Adapter = require '../adapter'
{Server, User, Channel, ChannelBan} = require '../structs'

P10_TOKENS = {
  # PING? PONG!
  PING:           "G"
  PONG:           "Z",

  # SERVER TOKENS
  SERVER:         "SERVER",
  PASS:           "PASS",
  SERVER_SERVER:  "S",
  SERVER_QUIT:    "SQ",
  END_BURST:      "EB",
  END_ACK:        "EA",

  # USER TOKENS
  USER:           "N",
  MODE:           "M",
  USER_QUIT:      "Q",
  USER_AWAY:      "A",

  # CHANNEL TOKENS
  CHAN_BURST:     "B",
  CHAN_CREATE:    "C",
  CHAN_JOIN:      "J",
  CHAN_PART:      "L",
  CHAN_KICK:      "K"
}

class IRCu extends Adapter
  connect: ->
    ts = Math.round(new Date()/1000);
    @send "#{ P10_TOKENS.PASS } #{ @config.password }"
    @send "#{ P10_TOKENS.SERVER } #{ @config.serverName } 1 #{ ts } #{ ts } J10 #{ @config.numeric } +s :#{ @config.serverDesc }"
    @serverAdd @config.serverName, 0, ts, ts, @config.serverDesc, @config.numeric, false

  send: (line) ->
    console.log "> OUT: "+ line
    @socket.write line + "\n"

  serverSend: (msg) ->
    me = @findMyServer()
    @send "#{ me.numeric.substr(0,2) } #{ msg }"

  parse: (line) ->
    console.log "<  IN: "+ line
    split = line.split " "

    # AB G !1400504767.778443 services.spoke.la 1400504767.778443
    if split[1] == P10_TOKENS.PING
      @handlePing split[4]

    # SERVER Dev1.Eu.Spokela.Com 1 1400499149 1400505006 J10 ABA]] +h6 :Spokela, Dev server 1
    # This is our uplink \o/
    if split[0] == P10_TOKENS.SERVER
      s = @serverAdd split[1], split[2], split[3], split[4], @doubleDotStr(split, 8), split[6], split[5] == "J10" ? false : true
      @findMyServer().parent = s;

    # AB EB
    if split[1] == P10_TOKENS.END_BURST
      server = @findServerByNumeric split[0]
      @endOfBurst server
      @serverSend "#{ P10_TOKENS.END_ACK }"

    # AB SQ AD 12345670 :reason
    # ADAAD SQ Dev2.Eu.Spokela.Com 0 :neiluj
    if split[1] == P10_TOKENS.SERVER_QUIT
      if split[0].length > 2
        sender = @findUserByNumeric split[0]
      else
        sender = @findServerByNumeric split[0]

      if split[2].indexOf('.') != false
        server = @findServerByName split[2]
      else
        server = @findServerByNumeric split[2]

      if split.length > 3 && split[3].indexOf(':') == 0
        reason = @doubleDotStr(split, 3)
      else
        reason = undefined

      @serverQuit server, sender, reason

    # AB N neiluj 1 1400499156 ~neiluj Dev1.Eu.Spokela.Com +oiwg B]AAAB ABAAA :julien
    # AB N neiluJ 1 1400509253 ~neiluj Dev1.Eu.Spokela.Com B]AAAB ABAAA :julien
    # ABAAA N joe 1400508608
    if split[1] == P10_TOKENS.USER
      # it's a new user connected
      if split[4] != undefined
        server      = @findServerByNumeric split[0]
        modes       = split[7]
        realNameIdx = 9
        account     = ""

        if modes.substr(0,1) == '+'
          realNameIdx++
          if modes.indexOf('r') > -1
            account = split[8]
            realNameIdx++
        else
          modes     = ""

        u = @userAdd split[2], split[5], split[6], @doubleDotStr(split, realNameIdx), server, split[4], split[realNameIdx-1]
        u.changeModes "#{ modes } #{ account }"

      # it's a nickname change
      else
        @nickChange @findUserByNumeric(split[0]), split[2]

    # ABAAA M neiluJ :+ow
    if split[1] == P10_TOKENS.MODE && split[2].indexOf('#') == -1
      if split[0].length > 2
        sender = @findUserByNumeric split[0]
      else
        sender = @findServerByNumeric split[0]

      target  = @findUserByNickname split[2]
      modes   = @doubleDotStr(split, 3)
      @umodesChange sender, target, modes

    # ADAAB Q :Quit: byebye
    if split[1] == P10_TOKENS.USER_QUIT
      if split.length > 2 && split[2].indexOf(':') == 0
        reason = @doubleDotStr(split, 2)
      else
        reason = undefined

      @userQuit @findUserByNumeric split[0], reason

    # ADAAB A :brb
    if split[1] == P10_TOKENS.USER_AWAY
      if split.length > 2 && split[2].indexOf(':') == 0
        reason = @doubleDotStr(split, 2)
      else
        reason = false

      u = @findUserByNumeric split[0]
      @userAway u, reason
      console.log u

    # AB B #opers 1400499156 ABAAB,ABAAA:o
    # AB B #opers 1400499156 ABAAB,ABAAA:o :%*!*@lamer.com
    # AB B #opers 1400499156 +tn ABAAB,ABAAA:o :%*!*@lamer.com
    if split[1] == P10_TOKENS.CHAN_BURST
      chan = @getChannelByName split[2], true
      chan.timestamp = split[3]
      usersIdx = 4
      modes = null
      if split[4].indexOf('+') == 0
        usersIdx++;
        modes = split[4]
        if modes.indexOf('k') != -1
          usersIdx++
          modes += ' '+ split[5]
        if modes.indexOf('l') != -1
          usersIdx++
          modes += ' '+ split[6]

      users = split[usersIdx].split(',')
      for user in users
        if user.indexOf(':') != -1
          u = @findUserByNumeric(user.split(':')[0])
          umods = user.split(':')[1]
        else
          u = @findUserByNumeric(user)
          umods = ""
        chan.addUser u, umods, split[3]

      if split[usersIdx+1] != undefined && split[usersIdx+1].indexOf(':') == 0
        bans = @doubleDotStr(split, usersIdx+1).substr(1).split(' ')
      else
        bans = []

      for ban in bans
        chan.addBan ban

      if modes != null
        chan.changeModes modes

      @channelAdd chan, true

    # ABAAA C #powah 1400577592
    # ABAAA C #pw1,#pw2 1400577796
    if split[1] == P10_TOKENS.CHAN_CREATE
      if split[2].indexOf(',') != -1
        chans = split[2].split(',')
      else
        chans = [split[2]]

      u = @findUserByNumeric split[0]
      for chan in chans
        chan = @getChannelByName chan, true
        chan.timestamp = split[3]
        chan.creator = u
        chan.addUser u, "o", split[3]
        @channelAdd chan, false

    # ABAAB J #powah 1400577592
    # ABAAB J 0
    # ABAAB J #pw1,#pw2 1400577592
    if split[1] == P10_TOKENS.CHAN_JOIN
      u = @findUserByNumeric split[0]

      # user left all channels
      if split[2] == "0"
        for id,channel of u.channels
          @channelPart channel, u, 'Leaving all channels'
        return

      if split[2].indexOf(',') != -1
        chans = split[2].split(',')
      else
        chans = [split[2]]

      # JOINs are propagated with the CreationTS of the channel (P10 specs)
      # However we already store this value so we prefer to store when the user actually joined
      ts = Math.round(new Date()/1000);
      for chan in chans
        chan = @getChannelByName chan, false
        @channelJoin chan, u, ts

    # ABAAB L #coucou :Leaving
    # ABAAB L #powah,#coucou1 :Leaving
    if split[1] == P10_TOKENS.CHAN_PART
      u = @findUserByNumeric split[0]

      if split[2].indexOf(',') != -1
        chans = split[2].split(',')
      else
        chans = [split[2]]

      if split[3] != undefined && split[3].indexOf(':') == 0
        reason = @doubleDotStr(split, 3)
      else
        reason = undefined

      for chan in chans
        chan = @getChannelByName chan, false
        @channelPart chan, u, reason

    # ABAAA K #powah ABAAB :pwet
    if split[1] == P10_TOKENS.CHAN_KICK
      if split[4] != undefined && split[4].indexOf(':') == 0
        reason = @doubleDotStr(split, 4)
      else
        reason = undefined

      @channelKick(@findUserByNumeric(split[0]), @getChannelByName(split[2], false), @findUserByNumeric(split[3]), reason)

  serverAdd: (serverName, hops, serverTs, linkTs, description, numeric, bursted = false) ->
    server = new Server serverName, hops, serverTs, linkTs, description, bursted
    server.numeric = numeric
    super server
    return server

  userAdd: (nickname, ident, hostname, realname, server, connectionTs, numeric) ->
    user = new User nickname, ident, hostname, realname, server, connectionTs
    user.numeric = numeric
    super user
    return user

  endOfBurst: (server) ->
    super server
    return server

  handlePing: (timestamp) ->
    super timestamp

  sendPong: (timestamp) ->
    @serverSend "#{ P10_TOKENS.PONG } #{ timestamp }"

  findServerByNumeric: (shortNumeric) ->
    for id, server of @servers
      if server.numeric.substr(0,shortNumeric.length) == shortNumeric
        return server
    return false

  findUserByNumeric: (numeric) ->
    for id, user of @users
      if user.numeric == numeric
        return user
    return false

module.exports = IRCu