Datastore             = require 'nedb'
{datastoreDirectory}  = require './config'

# Each datastore is defined here
module.exports.RolesDatastore =
  new Datastore({ filename: "#{datastoreDirectory}/roles.db", autoload: true })
module.exports.UsersDatastore =
  new Datastore({ filename: "#{datastoreDirectory}/users.db", autoload: true })