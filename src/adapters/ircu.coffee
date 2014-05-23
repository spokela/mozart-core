#
# This file is part of Mozart
# (c) Spokela 2014
#
Adapter = require '../adapter'
{Server, User} = require '../structs'

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
  RPING:          "RI",
  RPONG:          "RO"

  # USER TOKENS
  USER:           "N",
  USER_QUIT:      "Q",
  USER_KILL:      "D",
  USER_AWAY:      "A",
  USER_ACCOUNT:   "AC",

  MODE:           "M",

  # CHANNEL TOKENS
  CHAN_BURST:     "B",
  CHAN_CREATE:    "C",
  CHAN_JOIN:      "J",
  CHAN_PART:      "L",
  CHAN_KICK:      "K",
  CHAN_TOPIC:     "T",
  # add support for some popular forks of ircu (nefarious/asuka)
  CHAN_TBURST:    "TB",

  PRIVMSG:        "P",
  NOTICE:         "O"
}

class IRCu extends Adapter
  connect: ->
    ts = Math.round(new Date()/1000);
    @send "#{ P10_TOKENS.PASS } #{ @config.password }"
    @send "#{ P10_TOKENS.SERVER } #{ @config.serverName } 1 #{ ts } #{ ts } J10 #{ @config.numeric } +h6s :#{ @config.serverDesc }"
    @serverAdd @config.serverName, 0, ts, ts, @config.serverDesc, @config.numeric, false
    @serverSend "#{ P10_TOKENS.END_BURST }"

  send: (line) ->
    console.log "> OUT: "+ line
    @socket.write line + "\n"

  serverSend: (msg) ->
    me = @findMyServer()
    @send "#{ me.numeric.substr(0,2) } #{ msg }"

  parse: (line) ->
    console.log "<  IN: "+ line
    split = line.split " "
    for idx, spl of split
      if spl.indexOf("\r") != -1
        split[idx] = spl.trim()

    # AB G !1400504767.778443 services.spoke.la 1400504767.778443
    if split[1] == P10_TOKENS.PING
      @handlePing split[4]

    # AD RI 5A SPAAE 1400788900 8610 :RP
    if split[1] == P10_TOKENS.RPING
      if split[0].length == 2
        sender = @findServerByNumeric(split[0])
      else
        sender = @findUserByNumeric(split[0])

      target = @findServerByNumeric(split[2])
      oper = @findUserByNumeric(split[3])
      ts = split[4]
      ms = split[5]
      msg = @doubleDotStr(split, 6)
      me = @findMyServer()

      # i'm not the target
      if target.id != me.id
        @serverSend("#{ P10_TOKENS.RPING } #{ target.numeric } #{ oper.numeric } #{ ts } #{ ms } :#{ msg }")
      else
        myTs = Math.round(new Date()/1000)
        @serverSend("#{ P10_TOKENS.RPONG } #{ oper.numeric } #{ me.name } 0 :#{ msg }")

    # SERVER Dev1.Eu.Spokela.Com 1 1400499149 1400505006 J10 ABA]] +h6 :Spokela, Dev server 1
    # This is our uplink \o/
    if split[0] == P10_TOKENS.SERVER
      s = @serverAdd split[1], split[2], split[3], split[4], @doubleDotStr(split, 8), split[6], split[5] == "J10" ? false : true
      @findMyServer().parent = s;

    # AB S newserv.spoke.la 2 0 1400598331 J10 SPP]] +hs6 :my newserv instance
    if split[1] == P10_TOKENS.SERVER_SERVER
      s = @serverAdd(split[2], split[3], split[4], split[5], (split[6] == "J10" ? false : true), split[7], @doubleDotStr(split, 8))
      s.parent = @findServerByNumeric split[0];

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

      if split.length > 3 && split[4].indexOf(':') == 0
        reason = @doubleDotStr(split, 4)
      else
        reason = undefined

      @serverQuit server, sender, reason

    # AB N neiluj 1 1400499156 ~neiluj Dev1.Eu.Spokela.Com +oiwg B]AAAB ABAAA :julien
    # AB N neiluJ 1 1400509253 ~neiluj Dev1.Eu.Spokela.Com B]AAAB ABAAA :julien
    # ABAAA N joe 1400508608
    if split[1] == P10_TOKENS.USER
      # it's a new user connected
      if split[4] != undefined
        server      = @findServerByNumeric(split[0])
        modes       = split[7]
        realNameIdx = 9
        account     = ""

        if modes.substr(0,1) == '+'
          realNameIdx++
          if modes.indexOf('r') > -1
            account = split[8].trim()
            # ircu sends an AccountTs now (since ??)
            if account.indexOf(':') != -1
              account = account.split(':')[0]

            realNameIdx++
        else
          modes     = ""

        u = new User(split[2], split[5], split[6], @doubleDotStr(split, realNameIdx), server, split[4])
        u.numeric = split[realNameIdx-1]
        @userAdd(u, false)
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

    # AB AC AZAAA neiluJ 123456789
    # AB AC ABAAA neiluJ:123456789 12345789
    if split[1] == P10_TOKENS.USER_ACCOUNT
      sender = @findServerByNumeric split[0]
      target  = @findUserByNumeric split[2]
      account = split[3]
      # ircu sends an AccountTs now (since ??)
      if account.indexOf(':') != -1
        account = split[3].split(':')[0].trim()

      @userAuth sender, target, account

    # ADAAB Q :Quit: byebye
    if split[1] == P10_TOKENS.USER_QUIT
      if split.length > 2 && split[2].indexOf(':') == 0
        reason = @doubleDotStr(split, 2)
      else
        reason = undefined

      @userQuit @findUserByNumeric split[0], reason

    # SP D ADAAB :newserv.spoke.la!newserv.spoke.la (humpf)
    if split[1] == P10_TOKENS.USER_KILL
      if split.length > 3 && split[3].indexOf(':') == 0
        reason = @doubleDotStr(split, 3)
      else
        reason = undefined

      @userQuit @findUserByNumeric split[2], "Killed: #{ reason }"

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
      umods = ""
      for idx, user of users
        if user.indexOf(':') != -1
          u = @findUserByNumeric(user.split(':')[0].trim())
          umods = user.split(':')[1]
        else
          u = @findUserByNumeric(user.trim())
        chan.addUser u, umods.trim(), split[3].trim()

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
      if split[2].toString().trim() == "0"
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

    # ABAAA M #pwet +v ABAAC 1400587586
    # ABAAA M #opers +bvv *!*@lamer.com ABAAA ABAAC 1400587572
    if split[1] == P10_TOKENS.MODE && split[2].indexOf('#') == 0
      if split[0].length > 2
        sender = @findUserByNumeric split[0]
      else
        sender = @findServerByNumeric split[0]

      channel = @getChannelByName(split[2], false)
      modes   = split[3]
      operator = ""
      argsIdx = 4
      i = 0
      while i <= modes.length
        curr = modes.charAt(i)
        if curr == '+' || curr == '-'
          operator = curr
          i++
          continue

        else if curr == 'k' && operator == '+'
          channel.key = split[argsIdx]
          argsIdx++
        else if curr == 'k' && operator == '-'
          channel.key = null
          argsIdx++
        else if curr == 'l' && operator == '+'
          channel.limit = split[argsIdx]
          argsIdx++
        else if curr == 'l' && operator == '-'
          channel.limit = null
        # halfops is not supported by IRCu but may be on some forks so lets handle it anyway
        else if curr == 'o' || curr == 'v' || curr == 'h'
          u = @findUserByNumeric(split[argsIdx])
          argsIdx++
          @channelUsermodeChange(sender, channel, u, "#{ operator.toString() + curr.toString() }")
        else if curr == 'b'
          mask = split[argsIdx]
          argsIdx++
          if operator == '+'
            @channelAddBan sender, channel, mask, Math.round(new Date()/1000)
          else
            @channelRemoveBan sender, channel, mask
        else if operator == '+'
          channel.modes += curr
        else
          channel.modes = channel.modes.replace curr, ''
        i++
      @channelModesChange sender, channel, modes, split[argsIdx]

    # ABAAA T #opers 1400587572 1400592155 :topic !!!
    if split[1] == P10_TOKENS.CHAN_TOPIC
      if split[0].length > 2
        sender = @findUserByNumeric split[0]
      else
        sender = @findServerByNumeric split[0]

      channel = @getChannelByName split[2], false
      ts = split[4]
      topic = @doubleDotStr(split, 5).trim()
      @channelTopicChange sender, channel, topic, ts

    if split[1] == P10_TOKENS.CHAN_TBURST
      sender = @findServerByNumeric split[0]
      channel = @getChannelByName split[2], false
      ts = split[4]
      topic = @doubleDotStr(split, 5).trim()
      channel.topic = topic
      channel.topicTs = ts

    # ABAAE P 5ASQN :yo
    if split[1] == P10_TOKENS.PRIVMSG
      sender = @findUserByNumeric(split[0])

      if split[2].indexOf('#') == -1
        target = @findUserByNumeric(split[2])
      else
        target = @getChannelByName(split[2], false)

      msg = @doubleDotStr(split, 3)
      @privmsg sender, target, msg

    if split[1] == P10_TOKENS.NOTICE
      sender = @findUserByNumeric(split[0])
      if split[2].indexOf('#') == -1
        target = @findUserByNumeric(split[2])
      else
        target = @getChannelByName(split[2], false)

      msg = @doubleDotStr(split, 3)
      @notice sender, target, msg

  serverAdd: (serverName, hops, serverTs, linkTs, description, numeric, bursted = false) ->
    server = new Server serverName, hops, serverTs, linkTs, description, bursted
    server.numeric = numeric
    super server
    return server

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

  # COMMANDS
  createFakeUser: (user) ->
    user.numeric = @generateUserNumeric()
    @serverSend("#{ P10_TOKENS.USER } #{ user.nickname } 1 #{ user.connectionTs } #{ user.ident } #{ user.hostname } #{ user.modes } B]AAAB #{ user.numeric } :#{ user.realname }")

    return super user

  fakeUserQuit: (user, reason) ->
    if user == false
      throw new Error 'invalid user'

    if !reason
      @send("#{ user.numeric } #{ P10_TOKENS.USER_QUIT }")
    else
      @send("#{ user.numeric } #{ P10_TOKENS.USER_QUIT } :#{ reason }")

    return super user, reason

  doUmodesChange: (sender, user, modes) ->
    if !user || !sender
      throw new Error 'invalid user'

    # not ircu compilant when sender != target but some forks support it
    # @todo SVSMODE / SAMODE check ?
    @send("#{ sender.numeric } #{ P10_TOKENS.MODE } #{ user.nickname } :#{ modes }")

    return super sender, user, modes

  fakeNicknameChange: (user, newnick) ->
    if user == false
      throw new Error 'invalid user'

    @send("#{ user.numeric } #{ P10_TOKENS.USER } #{ newnick } #{ Math.round(new Date()/1000) }")

    return super user, newnick

  fakeAway: (user, reason) ->
    if !user
      throw new Error 'invalid user'
    if !reason || reason.trim().length == 0
      reason = false

    if !reason
      @send("#{ user.numeric } #{ P10_TOKENS.USER_AWAY }")
    else
      @send("#{ user.numeric } #{ P10_TOKENS.USER_AWAY } :#{ reason }")

    return super user, reason

  fakeChannelJoin: (user, channel) ->
    if !user || !channel
      throw new Error 'invalid user or channel'

    if channel.isEmpty()
      @send("#{ user.numeric } #{ P10_TOKENS.CHAN_CREATE } #{ channel.name } #{ Math.round(new Date()/1000) }")
    else
      @send("#{ user.numeric } #{ P10_TOKENS.CHAN_JOIN } #{ channel.name } #{ Math.round(new Date()/1000) }")

    return super user, channel, channel.isEmpty()

  fakeChannelPart: (user, channel, reason) ->
    if !user || !channel
      throw new Error 'invalid user or channel'

    if !reason || reason.trim().length == 0
      reason = false

    if !reason
      @send("#{ user.numeric } #{ P10_TOKENS.CHAN_PART } #{ channel.name }")
    else
      @send("#{ user.numeric } #{ P10_TOKENS.CHAN_PART } #{ channel.name } :#{ reason }")

    return super user, channel, reason

  # @todo Try to make a transaction before applying changes to database because a desync is easy
  doChannelModeChange: (sender, channel, modes) ->
    if !sender || !channel
      throw new Error 'invalid sender or channel'

    unum = sender.numeric
    if sender instanceof Server
      unum = unum.substr(0,2)

    finalArgs = []
    if modes.indexOf(' ') != -1
      mds = modes.substr(0, modes.indexOf(' '))
      args = modes.substr(modes.indexOf(' ')+1).split(' ')
    else
      mds = modes
      args = []

    operator = ""
    argsIdx = 0
    i = 0
    while i <= mds.length
      curr = mds.charAt(i)
      if curr == '+' || curr == '-'
        operator = curr
        i++
        continue

      else if curr == 'k' && operator == '+'
        channel.key = args[argsIdx]
        finalArgs.push args[argsIdx]
        argsIdx++
      else if curr == 'k' && operator == '-'
        channel.key = null
        finalArgs.push args[argsIdx]
        argsIdx++
      else if curr == 'l' && operator == '+'
        channel.limit = args[argsIdx]
        finalArgs.push args[argsIdx]
        argsIdx++
      else if curr == 'l' && operator == '-'
        channel.limit = null
      else if curr == 'b'
        mask = args[argsIdx]
        finalArgs.push args[argsIdx]
        argsIdx++
        if operator == '+'
          @channelAddBan sender, channel, mask, Math.round(new Date()/1000)
        else
          @channelRemoveBan sender, channel, mask
      else if curr == 'o' || curr == 'v'
        unick = @findUserByNickname(args[argsIdx])
        if !unick
          return 'user not found'
        else if !channel.isUser(unick)
          return 'user not on channel'

        channel.users[unick.id].changeModes("#{ operator }#{ curr }")
        finalArgs.push(unick.numeric)
        argsIdx++
      else if operator == '+'
        channel.modes += curr
      else
        channel.modes = channel.modes.replace curr, ''
      i++

    @send("#{ unum } #{ P10_TOKENS.MODE } #{ channel.name } #{ mds } #{ finalArgs.join(' ') } #{ channel.timestamp }")

    return super sender, channel, modes

  fakeChannelTopicChange: (sender, channel, topic) ->
    if !sender || !channel
      throw new Error 'invalid sender or channel'

    unum = sender.numeric
    if sender instanceof Server
      unum = unum.substr(0,2)

    @send("#{ unum } #{ P10_TOKENS.CHAN_TOPIC } #{ channel.name } #{ channel.timestamp } #{ Math.round(new Date()/1000) } :#{ topic }")

    return super sender, channel, topic

  fakePrivmsg: (sender, target, msg, silent = true) ->
    if !sender || !target
      throw new Error 'invalid user or target'

    unum = sender.numeric
    if sender instanceof Server
      unum = unum.substr(0,2)

    if target instanceof User
      dest = target.numeric
    else
      dest = target.name

    @send("#{ unum } #{ P10_TOKENS.PRIVMSG } #{ dest } :#{ msg }")

    return super sender, target, msg, silent

  fakeNotice: (sender, target, msg, silent = true) ->
    if !sender || !target
      throw new Error 'invalid sender or target'

    unum = sender.numeric
    if sender instanceof Server
      unum = unum.substr(0,2)

    if target instanceof User
      dest = target.numeric
    else
      dest = target.name

    @send("#{ unum } #{ P10_TOKENS.NOTICE } #{ dest } :#{ msg }")

    return super sender, target, msg, silent

  generateUserNumeric: ->
    s = @findMyServer().numeric.substr(0, 2)
    generator = (prefix) ->
      chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
      txt = prefix
      i = 0
      while i < 3
        txt += chars.charAt(Math.floor(Math.random() * chars.length));
        i++
      return txt

    num = generator(s)
    while @findUserByNumeric(num) != false
      num = generator(s)

    return num

module.exports = IRCu