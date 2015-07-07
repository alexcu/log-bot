###
This class is responsible for handling bot admin commands
###
class CommandProcessor
  ###
  RegExp's for the kinds of parameters accepted in the processor
  ###
  PARAMS =
    USER: /<@([A-Z0-9]+)>/g # A slack user
    ROLE: /[A-Z\_]+/g       # A role

  ###
  Command replacement matches. Plurals must come first such that
  they will reduce down to their singular equivalents.
  ###
  MATCH_REPLACEMENTS =
    '[USERS]': /([USER],?\s?)+/
    '[USER]' : PARAMS.USER
    '[ROLES]': /([ROLE],?\s?)+/
    '[ROLE]' : PARAMS.ROLE

  ###
  Commands mapped to their functions
  Where [USER] is present, a slack user will be matched
  Where [ROLE] is present, a user role will be matched
  ###
  COMMANDS =
    # Role-based commands
    'ASSIGN [USER] ROLE [ROLE]' : 'assignUserRole'
    'ADD ROLE [ROLES]'          : 'addRole'
    'DROP ROLE [ROLES]'         : 'dropRole'
    'GET ROLES FOR [USERS]'     : 'getRolesForUsers'
    'GET ROLES'                 : 'getAllRoles'
    # Log-based commands
    'GET LOGS FOR [USERS]'      : 'getLogsForUsers'
    'GET LOGS'                  : 'getAllLogs'

  # TODO: Implement the commands
  __assignUserRole: (args) ->
    "TODO: Implement __assignUserRole\t args = (#{JSON.stringify args})"
  __addRole: (args) ->
    "TODO: Implement __addRole\t args = (#{JSON.stringify args})"
  __dropRole: (args) ->
    "TODO: Implement __dropRole\t args = (#{JSON.stringify args})"
  __getAllRoles: (args) ->
    "TODO: Implement __getAllRoles\t args = (#{JSON.stringify args})"
  __getRolesForUsers: (args) ->
    "TODO: Implement __getRolesForUsers\t args = (#{JSON.stringify args})"
  __getLogsForUsers: (args) ->
    "TODO: Implement __getLogsForUsers\t args = (#{JSON.stringify args})"
  __getAllLogs: (args) ->
    "TODO: Implement __getAllLogs\t args = (#{JSON.stringify args})"

  ###
  Generates a Regular Expression for the given command by converting its
  matched replacements with the replacements to match
  @param  [string]  command The input command
  @returns  [RegExp]  A regular expression representing the command
  ###
  _regExpForCommand: (command) ->
    # Replace param match replacements with actual RegEx
    for match, regExp of MATCH_REPLACEMENTS
      # Replace each match with it's matched RegExp
      command = command.replace match, regExp.source
    # Return the command as a RegExp
    RegExp(command)

  ###
  Checks for a match between the input and the command provided
  @param  [string]  input Input string
  @param  [string]  command Regular Expression command
  @returns  [boolean] True on match, false otherwise
  ###
  _match: (input, command) =>
    matches = input.match(@_regExpForCommand command)
    matches? and matches.length > 0

  ###
  Strips a parameter list out of the command from all possible parameters
  @param  [string]  input Input string to parse
  @returns  [array] An array of user ids stripped
  ###
  _stripParams: (input) ->
    stripped = {}
    for paramType, regExp of PARAMS
      while (match = regExp.exec(input))
        value = match[1]
        continue unless value?
        stripped[paramType] = [] unless stripped[paramType]?
        stripped[paramType].push value
    stripped

  ###
  Returns a humanised list of available commands
  @returns  [array]  A list of each possible command
  ###
  humanisedCommands: ->
    (key.toString().slice(1,-1) for key of COMMANDS)

  ###
  Parses the input string for a command
  @param  [string]  input Input string
  @returns  [string]  A result string
  ###
  parse: (input) =>
    input = input.toUpperCase()
    for command, func of COMMANDS
      if @_match input, command
        params = @_stripParams input
        return @['__' + func](params)
    "Invalid admin command!"

  # Singleton CommandProcessor
  module.exports = new CommandProcessor