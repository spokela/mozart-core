#
# This file is part of Mozart
# (c) Spokela 2014

BOT_COMMANDS = {
  CONNECT:              'bot:connect',
  DISCONNECT:           'bot:disconnect',
  UMODE:                'bot:umode',
  NICKNAME:             'bot:nickname',

  AWAY:                 'bot:away',

  CHANNEL_JOIN:         'bot:chan-join',
  CHANNEL_PART:         'bot:chan-part',
  CHANNEL_MODE:         'bot:chan-mode',
  CHANNEL_UMODE:        'bot:chan-umode',
  CHANNEL_TOPIC:        'bot:chan-topic',
  CHANNEL_KICK:         'bot:chan-kick',
  CHANNEL_PRIVMSG:      'bot:chan-privmsg',
  CHANNEL_NOTICE:       'bot:chan-notice',
  CHANNEL_CTCP:         'bot:chan-ctcp',
  CHANNEL_INVITE:       'bot:chan-invite',

  USER_PRIVMSG:         'bot:user-privmsg',
  USER_NOTICE:          'bot:user-notice',
  USER_CTCP:            'bot:user-ctcp',
  USER_KILL:            'bot:user-kill',

  SERVER_QUIT:          'bot:squit',
  SERVER_WALLOPS:       'bot:wallops'
}

SERVER_COMMANDS = {
  CHANNEL_MODE:         'server:chan-mode',
  CHANNEL_UMODE:        'server:chan-umode',
  CHANNEL_TOPIC:        'server:chan-topic',
  CHANNEL_KICK:         'server:chan-kick',
  CHANNEL_PRIVMSG:      'server:chan-privmsg',
  CHANNEL_NOTICE:       'server:chan-notice',
  CHANNEL_CTCP:         'server:chan-ctcp',
  CHANNEL_INVITE:       'server:chan-invite',

  USER_PRIVMSG:         'server:user-privmsg',
  USER_NOTICE:          'server:user-notice',
  USER_CTCP:            'server:user-ctcp',
  USER_KILL:            'server:user-kill',
  USER_AUTH:            'server:user-auth',
  USER_DEAUTH:          'server:user-deauth',
  USER_NICKNAME:        'server:user-nickname',
  USER_HOSTNAME:        'server:user-hostname',

  SERVER_QUIT:          'server:squit',
  SERVER_WALLOPS:       'server:wallops',
  SERVER_NOTICE:        'server:squit',
  SERVER_JUPE_ADD:      'server:jupe-add',
  SERVER_JUPE_REMOVE:   'server:jupe-remove'
}

MOZART_COMMANDS = {
  DB_GETINFOS:          'mz:db:getinfos',

  DB_UPDATE_USER:       'mz:db:user-update',
  DB_UPDATE_SERVER:     'mz:db:server-update',
  DB_UPDATE_CHANNEL:    'mz:db:channel-update',
  DB_UPDATE_CHAN_USER:  'mz:db:chan-user-update',
  DB_UPDATE_CHAN_BAN:   'mz:db:chan-ban-update'
}

module.exports = {BOT_COMMANDS, SERVER_COMMANDS, MOZART_COMMANDS}