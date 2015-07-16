{LogsDatastore}   = require './data-store'
Users             = require './users'
Q                 = require 'q'
moment            = require 'moment'

###
Log class
###
module.exports = class Logs
  ###
  Inserts a new log into the log datastore
  @param  [string]  userId  The user to store for
  @param  [double]  hours   The number of hours to log
  @param  [string]  project Optional string for project
  ###
  @insert: (userId, hours = 0, project = null) ->
    time = moment().unix()
    LogsDatastore.insert { user: userId, time: time, hours: hours, project: project }, (err) ->
      throw err if err?
  ###
  Gets all logs
  @returns  [promise] A promise to the logs found
  ###
  @all: ->
    d = Q.defer()
    LogsDatastore.find({}).sort({ time: 1 }).exec (err, docs) ->
      throw err if err?
      d.resolve docs
    d.promise
  ###
  Finds all logs for a given user
  @param  [string|array]  userIds  The user(s) to find
  @returns  [promise] A promise to the logs found
  ###
  @forUsers: (userIds) ->
    d = Q.defer()
    userIds = [userIds] if typeof userIds is 'string'
    LogsDatastore.find({ user: { $in: userIds } }).sort({ time: 1 }).exec (err, logs) ->
      d.resolve logs
    d.promise
  ###
  Finds all logs for a given role
  @param  [string|array]  role  The role(s) to find
  @returns  [promise] A promise to the logs found
  ###
  @forRoles: (roles) ->
    d = Q.defer()
    roles = [roles] if typeof roles is 'string'
    logsFound = []
    for role, index in roles
      do (role, index) ->
        Users.usersForRole(role).then (users) ->
          userIds = (user.id for user in users)
          LogsDatastore.find({ user: { $in: userIds } }).sort({ time: 1 }).exec (err, logs) ->
            logsFound = logsFound.concat logs
            # Keep appending to the logs found
            if index is roles.length - 1
              d.resolve logsFound

    d.promise
  ###
  Formats log documents as CSV data
  @param  [array] logs  The logs to format
  @returns  [promise] A promise to the CSV-formatted data
  ###
  @asCSV: (logs) ->
    d = Q.defer()
    csv = "name,role,date,hours,project\n"
    for log, index in logs
      do (log, index) ->
        userId = log.user
        Users.find(userId).then (user) ->
          role  = user.role
          name  = user.profile.real_name
          date  = moment.unix(log.time).format("DD/MM/YYYY")
          hours = log.hours.toFixed(2)
          project = log.project or "n/a"
          csv += "#{name},#{role},#{date},#{hours},#{project}\n"
          # Resolve the csv if it's the last one
          d.resolve csv if index is (logs.length - 1)
    d.promise