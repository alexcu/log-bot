express   = require 'express'
uuid      = require 'node-uuid'
{Buffer}  = require 'buffer'
{server}  = require './config'
###
An express server to handle serving of data
###
module.exports = class DataServer
  ###
  The internal express server
  ###
  @_express: express()

  ###
  Setup the /data/:id endpoint
  ###
  @_express.get '/data/:id', (req, res) =>
    id = req.params.id
    # No data exists here?
    unless @_data[id]?
      return res.sendStatus 404
    res.attachment 'data.csv'
    res.send @_data[id].toString()
    # Expire this data endpoint
    delete @_data[id]

  ###
  The actual data server
  ###
  @_server: @_express.listen server.port, =>
    console.info "Data server is up at http://%s:%s/", server.ip, server.port

  ###
  The urls hash stores data at the given /data/:id endpoint
  ###
  @_data: {}

  ###
  Adds data to the server
  @param  [string|Buffer]  data  Data to store
  @returns  [string]  A unique URI that points to the data
  ###
  @store: (data) =>
    # Convert data into a buffer if need be
    unless Buffer.isBuffer(data)
      data = new Buffer(data)
    id = uuid.v4()
    @_data[id] = data
    "http://#{server.ip}:#{server.port}/data/#{id}"