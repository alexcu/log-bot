###
Config file module
###
nconf = require 'nconf'
fs    = require 'fs'

try
  nconf.file { file: 'config.json', readOnly: true }
catch e
  throw Error "Error when loading `config.json`: #{e.message}"

module.exports = nconf.stores.file.store
