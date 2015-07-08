{RolesDatastore}  = require './data-store'
{UsersDatastore}  = require './data-store'
Q                 = require 'q'
_                 = require 'underscore'

###
Role class
###
module.exports = class Roles
  ###
  Invokes a request to all documents in the datastore
  @returns  [promise] A promise to the documents retrieved
  ###
  @all: ->
    d = Q.defer()
    RolesDatastore.find {}, (err, docs) ->
      throw err if err?
      d.resolve (_.pluck docs, 'name') # Just pluck the role names
    d.promise
  ###
  Drops the role stored
  @param  [string] The name of the role to drop
  @returns  [promise] A promise to the result
  ###
  @drop: (name) ->
    d = Q.defer()
    usersAffected = 0
    # Set all users with this role name to null
    UsersDatastore.update { role: name }, { $set: { role: null } }, { multi: true }, (err, updateCount) ->
      throw err if err?
      usersAffected = updateCount
      # Now remove all roles with this name
      RolesDatastore.remove { name: name }, { multi: true }, (err) ->
        throw err if err?
        d.resolve "#{usersAffected} users have been affected by dropping \"#{name}\" and now have no role."
    d.promise
  ###
  Adds a new role
  @param  [string]  name  The name of this role
  @returns  [promise] A promise to the result
  ###
  @add: (name) ->
    d = Q.defer()
    # Make sure this role doesn't yet exist
    Roles.all().then (roles) ->
      roleAlreadyExists = name in roles
      return d.reject "Role \"#{name}\" already exists" if roleAlreadyExists
      # Now insert
      RolesDatastore.insert { name: name }, (err) ->
        throw err if err?
        d.resolve "Role \"#{name}\" was added"
    d.promise