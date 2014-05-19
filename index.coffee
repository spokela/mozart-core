#
# This file is part of Mozart
# (c) Spokela 2014
#
Mozart = require './src/mozart'
config = require './mozart.json'
IRCu = require './src/adapters/ircu'

bot = new Mozart config, new IRCu config.irc

bot.start()