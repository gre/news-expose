
window['console'] = {log: $.noop, debug: $.noop, error: $.noop} if !window['console']

Events = window.Events = `(function(_){return{pub:function(a,b,c,d){for(d=-1,c=[].concat(_[a]);c[++d];)c[d](b)},sub:function(a,b){(_[a]||(_[a]=[])).push(b)}}})({})`

pageTmpl = _.template('<div class="page"><img src="<%= src %>" /><a class="feedback" target="_blank" href="<%= feedbackLink %>"><%= feedbackText %></a><a href="<%= href %>" target="_blank" class="caption"><%= caption %></a></div>')

class Page
  constructor: (o) ->
    $.extend(this, o)

  insert: (container)->
    self = this
    node = @node = $(pageTmpl(this)).addClass('newNode')
    img = new Image()
    img.onload = ->
      setTimeout((-> node.removeClass('newNode')), 500)
    img.onerror = ->
      setTimeout((-> node.removeClass('newNode')), 500)
      self.loadError = true 
    img.src = @src
    @node.appendTo(container)
    @

  update: (values)->
    hasChanged = false
    if @weight isnt values.weight
      hasChanged = true
      @weight = values.weight
    if @feedbackText isnt values.feedbackText
      @node.find('.feedback').text(@feedbackText=values.feedbackText)
    hasChanged

  reload: ->
    img.src = img.src

  remove: ->
    @node.addClass('removing')
    setTimeout((=> @node.remove()), 2000)
    @

  setGridSize: (@w, @h) -> @
  setPosition: (@x, @y) -> 
    @node.css(top: @y, left: @x)
    @

  setFontSize: (fs) ->
    @node.css('font-size', fs)
    @
  setSize: (w, h) -> 
    @node.width(w).height(h)
    @

class Engine
  constructor: (@container, @unitDim = 100, @margin = 10) -> 
    @scales = [
      [1,1],
      [2,1],
      [2,2],
      [3,2],
      [4,2],
      [3,3],
      [4,3],
      [4,4]
    ]
    @pages = []
    @weightsEnabled = true
    @

  start: -> 
    @container.addClass('transitionStarted')
    @updateWidth()
    @computeWeights()
    @computeDistribution()
    lastWidth = null
    $(window).bind('resize', => 
      @updateWidth()
      if lastWidth != @width
        lastWidth = @width
        @computeDistribution()
    )
    @

  setWeightsEnabled: (@weightsEnabled) -> 
    @computeWeights()
    @computeDistribution()
    @

  updateWidth: ->
    min = _.map(@scales, (s)->s[0]).sort( (a,b) -> b-a )[0]
    units = Math.max(min, Math.floor((window.innerWidth-@margin)/@unitDim))
    @width = @unitDim*units
    @container.width(@width)

  # Compute the weight of each box and update its size
  # The weight is projected into a simplified grid
  computeWeights: ->
    n = @scales.length
    weights = _(@pages).chain().map((b) -> b.weight)
    min = weights.min().value()
    max = weights.max().value()
    if (min is max) or (@weightsEnabled is false)
      [w, h] = @scales[Math.floor (n-1)/2]
      for img in @pages
        img.setGridSize(w, h).setSize(@unitDim*w-@margin, @unitDim*h-@margin)
    else
      for img in @pages
        scaledValue = Math.floor (n-1)*(img.weight-min)/(max-min) # Scale weights to linear [0, n-1] int range
        [w, h] = @scales[scaledValue]
        img.setGridSize(w, h).setSize(@unitDim*w-@margin, @unitDim*h-@margin)
    @

  # Algorithm trying to distribute all images on the page into the best possible arrangement (fill the gaps).
  computeDistribution: -> 
    windowUnitWidth = Math.floor(@width / @unitDim)
    objs=_.map(@pages, (box) -> box: box, w: box.w, h: box.h, placed: false, position: [0,0]).sort((a, b) -> b.w*b.h-a.w*a.h)
    
    nextHeight = -> return obj.h for obj in objs when !obj.placed

    # Try to create a line of images by consuming boxes (recursive function), the max line bounds are (w, h), it starts from (x, y)
    placeLine = (x, y, w, h) ->
      # take the higher box which fits constraints
      best = obj for obj in objs when !obj.placed and obj.w <= w and obj.h <= h and (!best or obj.h > best.h)
      if best
        best.position = [x, y]
        best.placed = true
        # If it fit the height, just go right, else split into two lines
        if best.h == h
          placeLine x+best.w, y, w-best.w, h
        else
          placeLine x+best.w, y, w-best.w, best.h
          placeLine x, y+best.h, w, h-best.h

    # distribute while there are boxes
    y = 0
    while h = nextHeight()
      placeLine 0, y, windowUnitWidth, h
      y += h

    # Transform placements in positions
    for obj in objs
      obj.box.setPosition(@unitDim*obj.position[0], @unitDim*obj.position[1]).setFontSize((0.2+obj.box.w*0.6)+'em') 
    @

# Usage: setPages( [ { href: "http://greweb.fr/", weight: 0.15, img: "http://greweb.fr/image.png", caption: "my awesome blog" }, ... ] )
  setPages: (pages) ->
    currentHref = _.map(@pages, (box) -> box.href)
    pagesHref = _.map(pages, (p) -> p.href)
    commonPages = _.intersection(pagesHref, currentHref)
    newPages = _.difference(pagesHref, currentHref)
    removedPages = _.difference(currentHref, pagesHref)
    
    somethingHasChanged = newPages.length > 0 || removedPages.length > 0
    for href in newPages
      newPage = _.find(pages, (p)->p.href==href)
      page = new Page(newPage)
      page.insert(@container)
      @pages.push(page)
    
    for href in removedPages
      page = _.find(@pages, (p)->p.href==href)
      page.remove()
      @pages = _.without(@pages, page)
    
    for href in commonPages
      newPage = _.find(pages, (p)->p.href==href)
      page = _.find(@pages, (p)->p.href==href)
      if page.loadError
        page.reload()
      if page.update(newPage)
        somethingHasChanged = true
    
    if somethingHasChanged
      @computeWeights()
      @computeDistribution()
    @



$( ->
  engine = new Engine($('#pages')).start()

  body = $('body')

  toggleAction = (action) ->
    action.node.toggleClass('enabled')
    body.toggleClass(action.bodyToggle)
    Events.pub(action.bodyToggle, body.hasClass(action.bodyToggle))

  actions = $('#actions .toggler').map () ->
    self = $(this)
    node: self, keyCode: self.attr('data-keyCode'), bodyToggle: self.attr('data-bodyToggle')

  _(actions).each (action) ->
    if action.node.hasClass('enabled')
      body.addClass(action.bodyToggle)
    action.node.bind 'click', -> toggleAction(action)

  $(window).bind 'keydown', (e) ->
    action = _(actions).find( (a) -> ""+e.keyCode == a.keyCode )
    console.log action, e
    action && toggleAction(action)


  Events.sub('weightsEnabled', (enabled) ->
    engine.setWeightsEnabled(enabled)
  )

  FEEDLOOPTIME = 8000; # 8s
  feedIt = (onFeeded) ->
    $('body').addClass('feedLoading')
    $.ajax
      type: 'GET'
      url: NEWS_JSON_URI
      success: (json) ->
        pages = _.map(json, (link) ->
          href: link.url
          weight: link.weight
          src: link.image
          caption: link.title
          feedbackLink: link.feedbackLink
          feedbackText: link.feedbackText
        )
        engine.setPages(pages)
        if(pages.length == 0)
          $('body').addClass('errorLoading').removeClass('feedLoading')
        else
          $('body').removeClass('errorLoading').removeClass('feedLoading')
        onFeeded and onFeeded()
      error: ->
        $('body').addClass('errorLoading')

  feedLoop = -> setTimeout((-> feedIt(feedLoop)), FEEDLOOPTIME)
  feedIt(feedLoop)
)
