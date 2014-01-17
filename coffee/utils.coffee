window.Tether ?= {}

getScrollParent = (el) ->
  position = getComputedStyle(el).position

  if position is 'fixed'
    return el

  scrollParent = undefined

  parent = el
  while parent = parent.parentNode
    unless style = getComputedStyle parent
      return parent

    if /(auto|scroll)/.test(style['overflow'] + style['overflow-y'] + style['overflow-x'])
      if position isnt 'absolute' or style['position'] in ['relative', 'absolute', 'fixed']
        return parent

  return document.body

uniqueId = do ->
  id = 0
  ->
    id++

zeroPosCache = {}
getOrigin = (doc) ->
  # getBoundingClientRect is unfortunately too accurate.  It introduces a pixel or two of
  # jitter as the user scrolls that messes with our ability to detect if two positions
  # are equivilant or not.  We place an element at the top left of the page that will
  # get the same jitter, so we can cancel the two out.
  node = doc._tetherZeroElement
  if not node?
    node = doc.createElement 'div'
    node.setAttribute 'data-tether-id', uniqueId()
    extend node.style,
      top: 0
      left: 0
      position: 'absolute'

    doc.body.appendChild node

    doc._tetherZeroElement = node

  id = node.getAttribute 'data-tether-id'
  if not zeroPosCache[id]?
    zeroPosCache[id] = extend {}, node.getBoundingClientRect()

    defer ->
      zeroPosCache[id] = undefined

  return zeroPosCache[id]

node = null
getBounds = (el) ->
  if el is document
    doc = document
    el = document.documentElement
  else
    doc = el.ownerDocument

  docEl = doc.documentElement

  box = extend {}, el.getBoundingClientRect()

  origin = getOrigin doc

  box.top -= origin.top
  box.left -= origin.left

  box.top = box.top - docEl.clientTop
  box.left = box.left - docEl.clientLeft
  box.right = doc.body.clientWidth - box.width - box.left
  box.bottom = doc.body.clientHeight - box.height - box.top

  box

getOffsetParent = (el) ->
  el.offsetParent or document.documentElement

extend = (out={}) ->
  args = []
  Array::push.apply(args, arguments)

  for obj in args[1..] when obj
    for own key, val of obj
      out[key] = val

  out

removeClass = (el, name) ->
  if el.classList?
    el.classList.remove(cls) for cls in name.split(' ')
  else
    el.className = el.className.replace new RegExp("(^| )#{ name.split(' ').join('|') }( |$)", 'gi'), ' '

addClass = (el, name) ->
  if el.classList?
    el.classList.add(cls) for cls in name.split(' ')
  else
    removeClass el, name
    el.className += " #{ name }"

hasClass = (el, name) ->
  if el.classList?
    el.classList.contains(name)
  else
    new RegExp("(^| )#{ name }( |$)", 'gi').test(el.className)

updateClasses = (el, add, all) ->
  # Of the set of 'all' classes, we need the 'add' classes, and only the
  # 'add' classes to be set.
  for cls in all when cls not in add
    if hasClass(el, cls)
      removeClass el, cls

  for cls in add
    if not hasClass(el, cls)
      addClass el, cls

deferred = []

defer = (fn) ->
  deferred.push fn

flush = ->
  fn() while fn = deferred.pop()
    
class Evented
  on: (event, handler, ctx, once=false) ->
    @bindings ?= {}
    @bindings[event] ?= []
    @bindings[event].push {handler, ctx, once}

  once: (event, handler, ctx) ->
    @on(event, handler, ctx, true)

  off: (event, handler) ->
    return unless @bindings?[event]?

    if not handler?
      delete @bindings[event]
    else
      i = 0
      while i < @bindings[event].length
        if @bindings[event][i].handler is handler
          @bindings[event].splice i, 1
        else
          i++

  trigger: (event, args...) ->
    if @bindings?[event]
      i = 0
      while i < @bindings[event].length
        {handler, ctx, once} = @bindings[event][i]

        handler.apply(ctx ? @, args)

        if once
          @bindings[event].splice i, 1
        else
          i++

Tether.Utils = {getScrollParent, getBounds, getOffsetParent, extend, addClass, removeClass, hasClass, updateClasses, defer, flush, uniqueId, Evented}
