
root = exports ? this

dispatch = d3.dispatch("yearchange", "animation", "filter")

Bubbles = () ->
  # standard variables accessible to
  # the rest of the functions inside Bubbles
  width = 980
  height = 510
  allData = []
  data = []
  nodes = null
  node = null
  labels = null
  label = null
  margin = {top: 5, right: 0, bottom: 0, left: 0}
  # largest size for our bubbles
  maxRadius = 60
  currentYear = '1880'
  currentFilter = null
  currentNode = null

  # this scale will be used to size our bubbles
  rScale = d3.scale.sqrt().range([0,maxRadius])
  
  # I've abstracted the data value used to size each
  # into its own function. This should make it easy
  # to switch out the underlying dataset
  rValue = (d) -> d.n

  # function to define the 'id' of a data element
  #  - used to bind the data uniquely to the force nodes
  #   and for url creation
  #  - should make it easier to switch out dataset
  #   for your own
  idValue = (d) -> d.name

  # function to define what to display in each bubble
  #  again, abstracted to ease migration to 
  #  a different dataset if desired
  textValue = (d) -> d.name

  # function to define what attribute to 
  # use for the node's class
  classValue = (d) -> d.sex

  # constants to control how
  # collision look and act
  collisionPadding = 4
  minCollisionRadius = 12

  # variables that can be changed
  # to tweak how the force layout
  # acts
  # - jitter controls the 'jumpiness'
  #  of the collisions
  jitter = 0.4

  # ---
  # tick callback function will be executed for every
  # iteration of the force simulation
  # - moves force nodes towards their destinations
  # - deals with collisions of force nodes
  # - updates visual bubbles to reflect new force node locations
  # ---
  tick = (e) ->
    dampenedAlpha = e.alpha * 0.1
    
    # Most of the work is done by the gravity and collide
    # functions.
    node
      .each(gravity(dampenedAlpha))
      .each(collide(jitter))
      .attr("transform", (d) -> "translate(#{d.x},#{d.y})")

    # As the labels are created in raw html and not svg, we need
    # to ensure we specify the 'px' for moving based on pixels
    label
      .style("left", (d) -> ((margin.left + d.x) - d.dx / 2) + "px")
      .style("top", (d) -> ((margin.top + d.y) - d.dy / 2) + "px")

  # The force variable is the force layout controlling the bubbles
  # here we disable gravity and charge as we implement custom versions
  # of gravity and collisions for this visualization
  force = d3.layout.force()
    .gravity(0)
    .charge(0)
    .size([width, height])
    .on("tick", tick)

  # ---
  # Creates new chart function. This is the 'constructor' of our
  #  visualization
  # Check out http://bost.ocks.org/mike/chart/ 
  #  for a explanation and rational behind this function design
  # ---
  chart = (selection) ->
    selection.each (inputData) ->

      # first, get the data in the right format
      # data = transformData(inputData)
      allData = inputData
      # setup the radius scale's domain now that
      # we have some data
      maxDomainValue = d3.max(allData, (n) -> d3.max(n.values, (d) -> rValue(d)))
      rScale.domain([0, maxDomainValue])

      data = getYearData(currentYear)

      # a fancy way to setup svg element
      svg = d3.select(this).selectAll("svg").data([data])
      svgEnter = svg.enter().append("svg")
      svg.attr("width", width + margin.left + margin.right )
      svg.attr("height", height + margin.top + margin.bottom )
      
      # node will be used to group the bubbles
      nodes = svgEnter.append("g").attr("id", "bubble-nodes")
        .attr("transform", "translate(#{margin.left},#{margin.top})")

      # clickable background rect to clear the current selection
      nodes.append("rect")
        .attr("id", "bubble-background")
        .attr("width", width)
        .attr("height", height)
        .on("click", clear)

      # labels is the container div for all the labels that sit on top of 
      # the bubbles
      # - remember that we are keeping the labels in plain html and 
      #  the bubbles in svg
      labels = d3.select(this).selectAll("#bubble-labels").data([data])
        .enter()
        .append("div")
        .attr("id", "bubble-labels")

      update()

      # year needs to be a string. We can convert it here
      dispatch.on "yearchange.bubble", (year) ->
        updateData('' + year, currentFilter)

      dispatch.on "filter.bubble", (filter) ->
        updateData(currentYear, filter)

  # ---
  # update starts up the force directed layout and then
  # updates the nodes and labels
  # ---
  update = () ->
    # add a radius to our data nodes that will serve to determine
    # when a collision has occurred. This uses the same scale as
    # the one used to size our bubbles, but it kicks up the minimum
    # size to make it so smaller bubbles have a slightly larger 
    # collision 'sphere'
    data.forEach (d,i) ->
      d.forceR = Math.max(minCollisionRadius, rScale(rValue(d)))


    # call our update methods to do the creation and layout work
    updateNodes()
    updateLabels()
    # start up the force layout
    force.nodes(data, (d) -> idValue(d)).start()

  # ---
  # updateNodes creates a new bubble for each node in our dataset
  # ---
  updateNodes = () ->
    # here we are using the idValue function to uniquely bind our
    # data to the (currently) empty 'bubble-node selection'.
    # if you want to use your own data, you just need to modify what
    # idValue returns
    node = nodes.selectAll(".bubble-node").data(data, (d) -> idValue(d))

    # we don't actually remove any nodes from our data in this example 
    # but if we did, this line of code would remove them from the
    # visualization as well
    node.exit()
      .remove()

    # nodes are just links with circles inside.
    # the styling comes from the css
    node.enter()
      .append("a")
      .attr("class", (d) -> "bubble-node #{classValue(d)}")
      # .attr("xlink:href", (d) -> "##{encodeURIComponent(idValue(d))}")
      .append("circle")
      .attr("r", 0)

    node.select("circle").transition()
      .duration(500)
      .attr("r", (d) -> rScale(rValue(d)))

  # ---
  # updateLabels is more involved as we need to deal with getting the sizing
  # to work well with the font size
  # ---
  updateLabels = () ->
    # as in updateNodes, we use idValue to define what the unique id for each data 
    # point is
    label = labels.selectAll(".bubble-label").data(data, (d) -> idValue(d))

    label.exit().remove()

    # labels are anchors with div's inside them
    # labelEnter holds our enter selection so it 
    # is easier to append multiple elements to this selection
    labelEnter = label.enter().append("a")
      .attr("class", "bubble-label")
      # .attr("href", (d) -> "##{encodeURIComponent(idValue(d))}")
      .call(force.drag)
      .call(connectEvents)

    labelEnter.append("div")
      .attr("class", "bubble-label-name")
      .text((d) -> textValue(d))

    # labelEnter.append("div")
    #   .attr("class", "bubble-label-value")
    #   .text((d) -> rValue(d))

    # label font size is determined based on the size of the bubble
    # this sizing allows for a bit of overhang outside of the bubble
    # - remember to add the 'px' at the end as we are dealing with 
    #  styling divs
    label
      .style("font-size", (d) -> Math.max(8, rScale(rValue(d) / 2)) + "px")
      .style("width", (d) -> 2.5 * rScale(rValue(d)) + "px")

    # interesting hack to get the 'true' text width
    # - create a span inside the label
    # - add the text to this span
    # - use the span to compute the nodes 'dx' value
    #  which is how much to adjust the label by when
    #  positioning it
    # - remove the extra span
    label.append("span")
      .text((d) -> textValue(d))
      .each((d) -> d.dx = Math.max(2.5 * rScale(rValue(d)), this.getBoundingClientRect().width))
      .remove()

    # reset the width of the label to the actual width
    label
      .style("width", (d) -> d.dx + "px")
  
    # compute and store each nodes 'dy' value - the 
    # amount to shift the label down
    # 'this' inside of D3's each refers to the actual DOM element
    # connected to the data node
    label.each((d) -> d.dy = this.getBoundingClientRect().height)

  # ---
  # custom gravity to skew the bubble placement
  # ---
  gravity = (alpha) ->
    # start with the center of the display
    cx = width / 2
    cy = height / 2
    # use alpha to affect how much to push
    # towards the horizontal or vertical
    ax = alpha / 8
    ay = alpha

    # return a function that will modify the
    # node's x and y values
    (d) ->
      d.x += (cx - d.x) * ax
      d.y += (cy - d.y) * ay

  # ---
  # custom collision function to prevent
  # nodes from touching
  # This version is brute force
  # we could use quadtree to speed up implementation
  # (which is what Mike's original version does)
  # ---
  collide = (jitter) ->
    # return a function that modifies
    # the x and y of a node
    (d) ->
      data.forEach (d2) ->
        # check that we aren't comparing a node
        # with itself
        if d != d2
          # use distance formula to find distance
          # between two nodes
          x = d.x - d2.x
          y = d.y - d2.y
          distance = Math.sqrt(x * x + y * y)
          # find current minimum space between two nodes
          # using the forceR that was set to match the 
          # visible radius of the nodes
          minDistance = d.forceR + d2.forceR + collisionPadding

          # if the current distance is less then the minimum
          # allowed then we need to push both nodes away from one another
          if distance < minDistance
            # scale the distance based on the jitter variable
            distance = (distance - minDistance) / distance * jitter
            # move our two nodes
            moveX = x * distance
            moveY = y * distance
            d.x -= moveX
            d.y -= moveY
            d2.x += moveX
            d2.y += moveY

  # ---
  # adds mouse events to element
  # ---
  connectEvents = (d) ->
    d.on("click", click)
    d.on("mouseover", mouseover)
    d.on("mouseout", mouseout)

  # ---
  # clears currently selected bubble
  # ---
  clear = () ->
    updateActive(null)

  # ---
  # changes clicked bubble by modifying url
  # ---
  click = (d) ->
    updateActive(idValue(d))

  # ---
  # called when url after the # changes
  # ---
  # hashchange = () ->
  #   id = decodeURIComponent(location.hash.substring(1)).trim()

  # -
  # activates new node
  # ---
  updateActive = (id) ->
    node.classed("bubble-selected", (d) -> id == idValue(d))
    # if no node is selected, id will be empty
    # if id.length > 0
      # d3.select("#status").html("<h3>The word <span class=\"active\">#{id}</span> is now active</h3>")
    # else
      # d3.select("#status").html("<h3>No word is active</h3>")

  # ---
  # ---
  # updateFilter = (newFilter) ->

  # ---
  # ---
  copyLocations = (oldData, newData) ->
    oldLocs = d3.map()
    oldData.forEach (d) ->
      oldLocs.set(idValue(d), {"x": d.x, "y": d.y, "px": d.px, "py": d.py})
    newData.forEach (d) ->
      if oldLocs.has(idValue(d))
        oldLoc = oldLocs.get(idValue(d))
        d.x = oldLoc.x
        d.y = oldLoc.y
        d.px = oldLoc.px
        d.py = oldLoc.py

  # ---
  # ---
  updateData = (newYear, newFilter) ->
    currentYear = newYear
    currentFilter = newFilter
    oldData = data
    data = getYearData(currentYear)
    data = getFilterData(data, currentFilter)
    copyLocations(oldData, data)
    update()

  # ---
  # ---
  getYearData = (year) ->
    data = allData.filter((y) -> y.key == year)[0].values
    data

  # ---
  # ---
  getFilterData = (data, filter) ->
    data = data.filter (d) ->
      if filter == "male"
        classValue(d) == "M"
      else if filter == "female"
        classValue(d) == "F"
      else
        true
    data

  # ---
  # hover event
  # ---
  mouseover = (d) ->
    node.classed("bubble-hover", (p) -> p == d)

  # ---
  # remove hover class
  # ---
  mouseout = (d) ->
    node.classed("bubble-hover", false)

  # ---
  # public getter/setter for currentYear variable
  # ---
  chart.year = (_) ->
    if !arguments.length
      return currentYear
    currentYear = _
    chart

  # ---
  # public getter/setter for jitter variable
  # ---
  chart.jitter = (_) ->
    if !arguments.length
      return jitter
    jitter = _
    force.start()
    chart

  # ---
  # public getter/setter for height variable
  # ---
  chart.height = (_) ->
    if !arguments.length
      return height
    height = _
    chart

  # ---
  # public getter/setter for width variable
  # ---
  chart.width = (_) ->
    if !arguments.length
      return width
    width = _
    chart

  # ---
  # public getter/setter for radius function
  # ---
  chart.r = (_) ->
    if !arguments.length
      return rValue
    rValue = _
    chart
  
  # final act of our main function is to
  # return the chart function we have created
  return chart


Slider = () ->
  margin = {top: 0, right: 20, bottom: 10, left: 20}
  width = 850 - margin.left - margin.right
  height = 75 - margin.top - margin.bottom
  data = []
  handle = null
  slider = null

  addYears = 1
  curYear = null
  yearExtent = []
  timer = null
  
  xScale = d3.scale.linear().range([0, width])
    .clamp(true)

  xAxis = d3.svg.axis()
    .scale(xScale)
    .orient("bottom")
    .tickSize(0)
    .tickPadding(12)
    .tickFormat((d) -> d)

  format = d3.time.format("%Y")

  brushed = () ->
    value = brush.extent()[0]
    if d3.event.sourceEvent
      if d3.mouse(this)[0] > 0
        value = Math.round(xScale.invert(d3.mouse(this)[0]))
        brush.extent([value,value])
        curYear = value
    else
      value = curYear
    handle.attr("cx", xScale(value))
    dispatch.yearchange(value)

  brush = d3.svg.brush()
    .x(xScale)
    .extent([0,0])
    .on("brush", brushed)

  transformData = (rawData) ->
    data = []
    rawData.forEach (d) ->
      data.push({"year":+d, "date":format.parse(d)})
    data

  chart = (selection) ->
    selection.each (inputData) ->
      data = transformData(inputData)

      yearExtent = d3.extent(data, (d) -> d.year)
      curYear = yearExtent[0]
      xScale.domain(yearExtent)

      svg = d3.select(this).selectAll("svg").data([data])
      svgEnter = svg.enter().append("svg")
      svg.attr("width", width + margin.left + margin.right )
      svg.attr("height", height + margin.top + margin.bottom )
      
      g = svgEnter.append("g")
        .attr("transform", "translate(#{margin.left},#{margin.top})")

      axis = g.append("g")
        .attr("class", "x axis")
        .attr("transform", "translate(0,#{height / 2})")
        .call(xAxis)

      slider = g.append("g")
        .attr("class", "slider")
        .call(brush)

      slider.selectAll(".extent,.resize").remove()

      slider.select(".background")
        .attr("height", height)

      handle = slider.append("circle")
        .attr("class", "handle")
        .attr("transform", "translate(0," + height / 2 + ")")
        .attr("r", 9)

      # dispatch.on "yearstart.slider", (year) ->
      #   curYear = +year
      #   brush.extent([+year, +year])
      #   brush.event(slider)

      dispatch.on("animation.slider", handleAnimation)

  play = () ->
    if curYear <= yearExtent[1]
      brush.extent([+curYear, +curYear])
      brush.event(slider)
      curYear = curYear + 1
    else
      curYear = yearExtent[0]
      handleAnimation("stop")
      dispatch.animation("stop")

  handleAnimation = (action) ->
    console.log(action)
    if action == "start"
      play()
      timer = setInterval(play, 700)
    if action == "stop"
      clearInterval(timer)

  return chart

# ---
# Helper function that simplifies the calling
# of our chart with it's data and div selector
# specified
# ---
root.plotData = (selector, data, plot) ->
  d3.select(selector)
    .datum(data)
    .call(plot)

# ---
# ---
transformData = (rawData) ->
  nest = d3.nest()
    .key((d) -> d.year)
    .rollup (n) ->
      # rollup gives us access to each sub array
      # so let's clean up the data a bit
      n.forEach (d,i) ->
        d.n = +d.n
        d.prop = +d.prop
        d.index = i
      n
    .entries(rawData)
  nest

# ---
# ---
updateTitle = (newYear) ->
  d3.select("#dynamic-title").html(newYear)


# ---
# Activate selector button
# ---
activateLink = (group, link) ->
  d3.selectAll("##{group} a").classed("active", false)
  d3.select("##{group} ##{link}").classed("active", true)


# ---
# jQuery document ready.
# ---
$ ->
  # create a new Bubbles chart
  plot = Bubbles()
  slider = Slider()


  # ---
  # function that is called when
  # data is loaded
  # ---
  display = (error, rawData) ->
    data = transformData(rawData)
    years = data.map((d) -> d.key)

    plotData("#vis", data, plot)
    plotData("#slider", years, slider)
    dispatch.yearchange(years[0])
    # dispatch.yearstart(year)


  # bind change in drop down to change the
  # search url and reset the hash url
  # d3.select("#text-select")
  #   .on "change", (e) ->
  #     key = $(this).val()
  #     location.replace("#")
  #     location.search = encodeURIComponent(key)


  # load our data
  d3.tsv("data/top_baby_names.tsv", display)

  d3.select("#play").on "click", () ->
    dispatch.animation("start")

  d3.select("#pause").on "click", () ->
    dispatch.animation("stop")

  dispatch.on "animation.buttons", (action) ->
    shown = if (action == "start") then "#pause" else "#play"
    hidden = if (action == "start") then "#play" else "#pause"
    d3.select(hidden).classed("hidden", true)
    d3.select(shown).classed("hidden", false)

  dispatch.on "yearchange.title", (year) ->
    updateTitle('' + year)

  d3.selectAll("#filter a").on "click", (d) ->
    newFilter = d3.select(this).attr("id")
    activateLink("filter", newFilter)
    dispatch.filter(newFilter)
  

