{UsersDatastore}  = require './data-store'
Roles             = require './roles'
Q                 = require 'q'
_                 = require 'underscore'

###
User class
###
module.exports = class Users
  ###
  Invokes a request to all documents in the datastore
  @returns  [promise] A promise to the documents retrieved
  ###
  @all: ->
    d = Q.defer()
    UsersDatastore.find {}, (err, docs) ->
      throw err if err?
      d.resolve docs
    d.promise
  ###
  Retrieves the profile for the given user
  @param    [string]  id  Slack user id
  @returns  [promise] A promise to the profile
  ###
  @find: (id) ->
    d = Q.defer()
    Users.all().then (users) ->
      userFound = _.find users, (user) ->
        user.id is id
      return d.reject unless userFound?
      d.resolve userFound
    d.promise
  ###
  Adds a new user
  @param  [string]  id  Slack user id
  @param  [object]  profile Slack profile object
  @param  [Role]    role  The role for this user
  ###
  @add: (id, profile, role = null) ->
    UsersDatastore.insert { id: id, profile: profile, role: role }, (err) ->
      throw err if err?
  ###
  Assigns a user with the id provided a role
  @param  [string]  id    Slack user id
  @param  [string]  role  The role to assign
  ###
  @assignRole: (id, role) ->
    d = Q.defer()
    Users.find(id)
      .then (user) =>
        Roles.all().then (roles) ->
          roleExists = role in roles
          d.reject "No role \"#{role}\" exists. Create it first." unless roleExists
          UsersDatastore.update { id: id }, { $set: { role: role } }, { multi: true }, (err) ->
            throw err if err?
          d.resolve "Assigned #{role} to #{user.profile.real_name}"
      .fail () =>
        d.reject "No user with id #{id} found"
    d.promise