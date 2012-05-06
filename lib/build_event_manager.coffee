_               = require('underscore')
{join, resolve} = require('path')
EventEmitter2   = require('eventemitter2').EventEmitter2

# Running this emits all steps in order
class BuildEventManager extends EventEmitter2
  
  constructor: (pluginManager)->
    #@events = ['clean', 'documents', 'scripts', 'styles', 'merge', 'compress', 'publish']
    @events = ['documents', 'scripts', 'styles', 'merge', 'compress', 'publish']
    @userConfig = require(resolve(join('.', 'config.json')))
    @sanitizeConfig @userConfig
    
    @pluginManager = pluginManager
    @pluginManager.getPlugins().forEach (plugin)=>
      @register plugin


  sanitizeConfig: (config)->
    sourceDir = config.sourceDir || 'src'
    sourceDir = resolve(sourceDir)
    config.sourceDir = sourceDir
    
    buildDir = config.buildDir || 'build'
    buildDir = resolve(buildDir)
    config.buildDir = buildDir

    config.stylesheets ||= {}
    stylesSourceDir = config.stylesheets.sourceDir || 'stylesheets'
    config.stylesheets.sourceDir = resolve(join(sourceDir, stylesSourceDir))
    config.stylesheets.buildDir = resolve(join(buildDir, stylesSourceDir))

    config.javascripts ||= {}
    scriptsSourceDir = config.javascripts.sourceDir || 'javascripts'
    config.javascripts.sourceDir = resolve(join(sourceDir, scriptsSourceDir))
    config.javascripts.buildDir = resolve(join(buildDir, scriptsSourceDir))


  register: (plugin)->
    return false unless plugin.defaultEvent?
    if plugin.defaultEvent == 'all'
      # register for every event
      @on event, plugin.build for event in @events
    else if plugin.defaultEvent == 'all:pre'
      @on "#{event}:pre", plugin.build for event in @events
    else if plugin.defaultEvent == 'all:pre'
      @on "#{event}:post", plugin.build for event in @events
    else
      events = null
      if typeof(plugin.defaultEvent) == 'string'
        events = [plugin.defaultEvent]
      else
        events = plugin.defaultEvent
      for event in events
        @on event, ()->
          console.log "  [#{plugin.name}]"
          plugin.build(arguments...)


  # loop through event list and emits
  # each step must fully execute before completion
  # registered events manage their own execution
  start: (toEvent)->
    return false unless _.include(@events, toEvent)

    phaseData =
      lastEvent     : toEvent
      pluginManager : @pluginManager
      upToPhase : (phaseName)=>
        for e in @events
          return true if e == phaseName
          break if e == toEvent
        false

    #process.nextTick ()=> @emit('setup', @userConfig)
    phaseData.event = 'setup'
    @emit('setup', @userConfig, phaseData)

    for event in @events
      #process.nextTick ()=> @emit(event, @userConfig)
      # phaseData.event = event
      phaseData.event = "#{event}:pre"
      @emit(phaseData.event, @userConfig, phaseData)
      phaseData.event = event
      @emit(phaseData.event, @userConfig, phaseData)
      phaseData.event = "#{event}:post"
      @emit(phaseData.event, @userConfig, phaseData)
      return true if toEvent == event
    
    return true


module.exports = BuildEventManager
