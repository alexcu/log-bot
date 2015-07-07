###
Config file module
###
nconf = require 'nconf'
fs    = require 'fs'

nconf.file { file: 'config.json', readOnly: true }

module.exports = nconf.stores.file.store
