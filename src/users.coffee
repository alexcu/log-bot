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
  Retrieves the user for the given userId
  @param    [string]  id  Slack user id
  @returns  [promise] A promise to the user
  ###
  @find: (id) ->
    d = Q.defer()
    UsersDatastore.findOne { id: id }, (err, user) ->
      return d.reject unless user?
      d.resolve user
    d.promise
  ###
  Retrieves the users with the given role
  @param    [string]  role  The role
  @returns  [promise] A promise to the users
  ###
  @usersForRole: (role) ->
    d = Q.defer()
    UsersDatastore.find { role: role }, (err, users) ->
      d.resolve users
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