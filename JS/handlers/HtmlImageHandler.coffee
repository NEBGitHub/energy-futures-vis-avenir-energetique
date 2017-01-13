jsdom = require 'jsdom'
fs = require 'fs'
Promise = require 'bluebird'
url = require 'url'
queryString = require 'query-string'
Request = require 'request-promise'


PrepareQueryParams = require '../PrepareQueryParams.coffee'
readFile = Promise.promisify fs.readFile
writeFile = Promise.promisify fs.writeFile

open = Promise.promisify fs.open
write = Promise.promisify fs.write
close = Promise.promisify fs.close


ApplicationRoot = require '../../ApplicationRoot.coffee'
Logger = require '../Logger.coffee'

# Visualization classes

ServerApp = require './ServerApp.coffee'
Visualization1 = require '../views/visualization1.coffee'
Visualization2 = require '../views/visualization2.coffee'
Visualization3 = require '../views/visualization3.coffee'
Visualization4 = require '../views/visualization4.coffee'

Visualization1Configuration = require '../VisualizationConfigurations/visualization1Configuration.coffee'
Visualization2Configuration = require '../VisualizationConfigurations/visualization2Configuration.coffee'
Visualization3Configuration = require '../VisualizationConfigurations/visualization3Configuration.coffee'
Visualization4Configuration = require '../VisualizationConfigurations/visualization4Configuration.coffee'

ServerData = require '../server/ServerData.coffee'
Constants = require '../Constants.coffee'

htmlFilePromise = readFile "#{ApplicationRoot}/JS/handlers/image.html" 
htmlPromise = htmlFilePromise.then (data) ->
  data.toString()




Vis1TemplatePromise = readFile("#{ApplicationRoot}/JS/templates/Visualization1Server.mustache")
Vis2TemplatePromise = readFile("#{ApplicationRoot}/JS/templates/Visualization2Server.mustache")
Vis3TemplatePromise = readFile("#{ApplicationRoot}/JS/templates/Visualization3Server.mustache")
Vis4TemplatePromise = readFile("#{ApplicationRoot}/JS/templates/Visualization4Server.mustache")
SvgStylesheetPromise = readFile("#{ApplicationRoot}/JS/templates/SvgStylesheet.css")


templatesPromise = Promise.join Vis1TemplatePromise, Vis2TemplatePromise, Vis3TemplatePromise, Vis4TemplatePromise, SvgStylesheetPromise, (vis1Template, vis2Template, vis3Template, vis4Template, svgTemplate) ->

  return {
    vis1Template: vis1Template.toString()
    vis2Template: vis2Template.toString()
    vis3Template: vis3Template.toString()
    vis4Template: vis4Template.toString()
    svgTemplate: svgTemplate.toString()
  }



requestCounter = 0

# HtmlImageHandler = (req, res) ->

# TODO: rename me! 
HtmlImageHandler = (query, filename) ->

  time = Date.now()

  # query = url.parse(req.url).search
  requestCounter++
  counter = requestCounter
  Logger.info "html_image (request H#{counter}): #{query}"

  if process.env.BITLY_API_KEY? and process.env.BITLY_USERNAME?
    shortenUrl = "#{Constants.appHost}/#{query}"
    requestUrl = "https://api-ssl.bitly.com/v3/shorten?login=#{process.env.BITLY_USERNAME}&apiKey=#{process.env.BITLY_API_KEY}&format=json&longUrl=#{encodeURIComponent(shortenUrl)}"

    shortUrlPromise = Request({uri: requestUrl, json: true})
    .then (response) ->
      if response.status_code == 200
        return response.data.url
      else
        return Constants.appHost
    .catch (error) ->
      return Constants.appHost
  else
    shortUrlPromise = new Promise (resolve, reject) ->
      resolve Constants.appHost


  dataLoadPromise = Promise.all ServerData.loadPromises

  return Promise.join shortUrlPromise, htmlPromise, templatesPromise, dataLoadPromise, (shortUrl, html, templates) ->
    return new Promise (resolve, reject) ->

      try
        jsdom.env html, [], (error, window) -> 

          if error?
            # errorHandler req, res, error, 500
            console.log "TODO: handle this error appropriately"
            return

          params = PrepareQueryParams queryString.parse(query)
          # console.log params

          providers = {}
          for dataset in Constants.datasets
            # TODO: the 'dataset' objects on ServerData have a lot more than just
            # providers. This is fine for now, but a little messy.
            providers[dataset] = ServerData[dataset]

          serverApp = new ServerApp window, providers
          serverApp.bitlyLink = shortUrl
          serverApp.setLanguage params.language

          # Parse the parameters with a configuration object, and then hand them off to a
          # visualization object. The visualizations render the graphs in their constructors.
          switch params.page
            when 'viz1'
              config = new Visualization1Configuration(serverApp, params)
              viz = new Visualization1 serverApp, config,
                template: templates.vis1Template
                svgTemplate: templates.svgTemplate

            when 'viz2'
              config = new Visualization2Configuration(serverApp, params)
              viz = new Visualization2 serverApp, config,
                template: templates.vis2Template
                svgTemplate: templates.svgTemplate

            when 'viz3'
              config = new Visualization3Configuration(serverApp, params)
              viz = new Visualization3 serverApp, config,
                template: templates.vis3Template
                svgTemplate: templates.svgTemplate

            when 'viz4'
              config = new Visualization4Configuration(serverApp, params)
              viz = new Visualization4 serverApp, config,
                template: templates.vis4Template
                svgTemplate: templates.svgTemplate

            else 
              console.log "TODO: handle this error too"
              console.log params
              console.log params.page
              # errorHandler req, res, new Error("Visualization 'page' parameter not specified or not recognized."), 400, counter
              return

          body = window.document.querySelector('body')
            

          # we need to wait a tick for the zero duration animations to be scheduled and run          
          setTimeout ->

            source = window.document.querySelector('html').outerHTML
            # res.write source
            # res.end()

            Logger.debug "html_image (request H#{counter}) Time: #{Date.now() - time}"

            # We originally used the higher level fs.writeFile API here, but as we read immediately after writing it, it's necessary to wait for the 'close' event. The lower level fs API lets us do this.

            openPromise = open filename, "w+"
            writePromise = openPromise.then (fileDescriptor) ->
              write fileDescriptor, source

            writePromise.catch (error) ->
              console.log "file writing error"
              console.log error
 
            closePromise = Promise.join openPromise, writePromise, (fileDescriptor) ->
              Logger.verbose "This is the write file promise callback"
              return close fileDescriptor

            resolve closePromise
            # return writeFile filename, source



      catch error
        console.log 'erroorrr'
        console.log error
        console.log error.error
        # errorHandler req, res, error, 500, counter

    .catch (error) ->
        console.log 'erroorrr'
        console.log error
        console.log error.error
      # errorHandler req, res, error, 500, counter
      


errorHandler = (req, res, error, code, counter) ->

  Logger.error "html_image (request H#{counter}) error: #{error.message}"
  Logger.error error.stack

  res.writeHead code
  res.end "HTTP #{code} #{error.message}"


module.exports = HtmlImageHandler

