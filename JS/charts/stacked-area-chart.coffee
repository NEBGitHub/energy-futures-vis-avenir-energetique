d3 = require 'd3'
_ = require 'lodash'

stackedBarChart = require './stacked-bar-chart.coffee'
Tr = require '../TranslationTable.coffee'

class stackedAreaChart extends stackedBarChart
  stackedAreaDefaults:
    strokeWidth: 1

  constructor: (@app, parent, x, y, options = {}) ->

    @options = _.extend {}, @stackedAreaDefaults, options
    @_strokeWidth = @options.strokeWidth
    super(@app, parent, x, y, @options)
    @redraw()

    @tooltip = @app.window.document.getElementById 'tooltip'
    @tooltipParent = @app.window.document.getElementById 'wideVisualizationPanel'
    @graphPanel = @app.window.document.getElementById 'graphPanel'

  # When dragging we want a shorter duration
  dragStart: ->
    @_duration = 500

  dragEnd: ->
    @_duration = @options.duration

  redraw: ->
    if (@_y != undefined) and (@_x != undefined)
      grads = @_parent.select("defs").selectAll(".vizPresentLinearGradient")
          .data(@_mapping, (d) -> d.key)
      gradsFuture = @_parent.select("defs").selectAll(".vizFutureLinearGradient")
          .data(@_mapping, (d) -> d.key)
      enterPresentGrads = grads.enter().append("linearGradient")
          .attr
            class: 'vizPresentLinearGradient'
            gradientUnits: "objectBoundingBox"
            id: (d) -> "viz2gradPresent" + d.key
      enterPresentGrads.append("stop")
          .attr
            offset: "0"
          .style
            "stop-color": (d) -> d.colour
            "stop-opacity": "0.6"

      enterPresentGrads.append('stop')
          .attr
            offset: (d) => "#{@_x(2011) / @_x(2014)}"
          .style
            "stop-color": (d) -> d.colour
            "stop-opacity": 0.6 * 0.9

      enterPresentGrads.append("stop")
          .attr
            offset: "100%"
          .style
            "stop-color": (d) -> d.colour
            "stop-opacity": 0.6 * 0.7

      enterFutureGrads = gradsFuture.enter().append("linearGradient")
          .attr
            class: 'vizFutureLinearGradient'
            gradientUnits: "objectBoundingBox"
            id: (d) -> "viz2gradFuture" + d.key

      enterFutureGrads.append("stop")
          .attr
            offset: "0%"
          .style
            "stop-color": (d) -> d.colour
            "stop-opacity": 0.6 * 0.7

      enterFutureGrads.append("stop")
          .attr
            offset: "100%"
          .style
            "stop-color": (d) -> d.colour
            "stop-opacity": 0.6 * 0.2

      grads.exit().remove()
      area = d3.svg.area()
        .x((d)  => @_x(d.x) )
        .y0((d) => @_y(d.y0))
        .y1((d) => @_y(d.y0 + d.y) )
        .defined((d) -> d.x <= 2014)

      areaFuture = d3.svg.area()
        .x((d)  => @_x(d.x) )
        .y0((d) => @_y(d.y0))
        .y1((d) => @_y(d.y0 + d.y) )
        .defined((d) -> d.x >= 2014)

      line = d3.svg.line()
        .x((d)  => @_x(d.x) )
        .y((d) => @_y(d.y0 + d.y) )
        .defined((d) -> d.x <= 2014)

      futureLineFunction = d3.svg.line()
        .x((d)  => @_x(d.x) )
        .y((d) => @_y(d.y0 + d.y) )
        .defined((d) -> d.x >= 2014)

      presentArea = @_group.selectAll(".presentArea")
          .data(@_mapping, (d) -> d.key)
          .on "mouseover", (d) =>
            coords = d3.mouse @tooltipParent # [x, y]
            @tooltip.style.visibility = "visible"
            @tooltip.style.left = "#{coords[0] + 30}px"
            @tooltip.style.top = "#{coords[1]}px"
            @displayTooltip d.key
          .on "mousemove", (d) =>
            coords = d3.mouse @tooltipParent # [x, y]
            @tooltip.style.left = "#{coords[0] + 30}px"
            @tooltip.style.top = "#{coords[1]}px"
            @displayTooltip d.key
          .on "mouseout", (d) =>
            @tooltip.style.visibility = "hidden"

      presentArea.enter().append("path")
        .attr
          class: 'presentArea'
          d: (d) =>
            area(@_stackDictionary[d.key].values.map((data) -> {x: data.x, y:0, y0:0}))
        .style  
          fill: (d) -> colour = d3.rgb(d.colour); "url(#viz2gradPresent#{d.key}) rgba(#{colour.r}, #{colour.g}, #{colour.b}, 0.6)"

      presentArea.exit().remove()

      futureArea = @_group.selectAll(".futureArea")
          .data(@_mapping, (d) -> d.key)
          .on "mouseover", (d) =>
            coords = d3.mouse @tooltipParent # [x, y]
            @tooltip.style.visibility = "visible"
            @tooltip.style.left = "#{coords[0] + 30}px"
            @tooltip.style.top = "#{coords[1]}px"
            @displayTooltip d.key
          .on "mousemove", (d) =>
            coords = d3.mouse @tooltipParent # [x, y]
            @tooltip.style.left = "#{coords[0] + 30}px"
            @tooltip.style.top = "#{coords[1]}px"
            @displayTooltip d.key
          .on "mouseout", (d) =>
            @tooltip.style.visibility = "hidden"

      futureArea.enter().append("path")
        .attr
          class: 'futureArea'
          d: (d) =>
            areaFuture(@_stackDictionary[d.key].values.map((data) -> {x: data.x, y:0, y0:0}))
        .style  
          fill: (d) -> colour = d3.rgb(d.colour); "url(#viz2gradFuture#{d.key}) rgba(#{colour.r}, #{colour.g}, #{colour.b}, 0.4)"

      futureArea.exit().remove()

      presentLine = @_group.selectAll(".presentLine")
          .data(@_mapping, (d) -> d.key)
      presentLine.enter().append("path")
        .attr(
          class: 'presentLine'
          d: (d, i, j) =>
            line(@_stackDictionary[d.key].values.map((data) -> {x: data.x, y:0, y0:0}))
          )
        .style(
          stroke: (d, i) =>
            if @_mapping then d.colour else "#333333"
          'stroke-width': @_strokeWidth
          fill: 'none'
        )
      
      futureLine = @_group.selectAll(".futureLine")
          .data(@_mapping, (d) -> d.key)
      futureLine.enter().append("path")
        .attr(
          class: 'futureLine'
          d: (d, i, j) =>
            futureLineFunction(@_stackDictionary[d.key].values.map((data) -> {x: data.x, y:0, y0:0}))
          )
        .style(
          stroke: (d, i) =>
            if @_mapping then d.colour else "#333333"
          'stroke-width': @_strokeWidth
          'stroke-opacity': 0.4
          fill: 'none'
        )
      presentArea.transition()
        .duration( =>
          if @_duration then @_duration else 0)
        .attr(
          d: (d, i) =>
            area(@_stackDictionary[d.key].values.map((d) -> {x: d.x, y:d.y, y0:d.y0}))
          )
      futureArea.transition()
        .duration( =>
          if @_duration then @_duration else 0)
        .attr(
          d: (d, i) =>
            areaFuture(@_stackDictionary[d.key].values.map((d) -> {x: d.x, y:d.y, y0:d.y0}))
          )

      presentLine.transition()
        .duration( =>
          if @_duration then @_duration else 0)
        .attr(
          d: (d, i) =>
            line(@_stackDictionary[d.key].values.map((d) -> {x: d.x, y:d.y, y0:d.y0}))
          )
      futureLine.transition()
        .duration( =>
          if @_duration then @_duration else 0)
        .attr(
          d: (d, i) =>
            futureLineFunction(@_stackDictionary[d.key].values.map((d) -> {x: d.x, y:d.y, y0:d.y0}))
          )
    this

  # Take the mouse coordinates, and invert the scale we used to draw the graph to
  # look up which year they correspond to. Combine with the name of the scenario to
  # populate the contents of the mouseover tooltip. Should work at any resolution!
  # We assume that this method is called during a d3 event handler
  displayTooltip: (powerSource) ->
    # Mouse coordinates relative to the graph panel element, should be the same
    # coordinate space that the scale is used to draw in.
    coords = d3.mouse @graphPanel # [x, y]

    # Compute the year from the scale
    year = Math.floor @_x.invert(coords[0])

    tooltipDatum = @_stackDictionary[powerSource].values.find (item) ->
      item.x == year
    return unless tooltipDatum

    @tooltip.innerHTML = "#{Tr.sourceSelector.sources[powerSource][@app.language]} (#{year}) #{tooltipDatum.y.toFixed(2)}"


module.exports = stackedAreaChart