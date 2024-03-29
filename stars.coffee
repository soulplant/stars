WIDTH = 640
HEIGHT = 480
BOARD_Y = 240
BOARD_HEIGHT = 240

VK_LEFT=37
VK_UP=38
VK_RIGHT=39
VK_DOWN=40

VK_H = 72
VK_J = 74
VK_K = 75
VK_L = 76

VK_Z = 90

keyState = {}

randInt = (n) -> Math.floor(Math.random() * n)
randArray = (arr) -> arr[randInt(arr.length)]

class Point
  constructor: (@x, @y) ->

  scale: (x, y=x) -> new Point @x * x, @y * y
  sub: (pt) -> new Point @x - pt.x, @y - pt.y

  magnitude: -> Math.sqrt(@x * @x + @y * @y)

  distance: (pt) -> @sub(pt).magnitude()

  toUnit: ->
    h = @magnitude()
    return new Point(0, 0) if h == 0
    new Point(@x/h, @y/h).offset()

  isEmpty: -> @x == 0 && @y == 0

  offset: ->
    h = @magnitude()
    if h == 0
      return new Point 0, 0
    new Point Math.abs(@x) * @x/h, Math.abs(@y) * @y/h

class Controller
  constructor: ->
    @keyState = {}

  down: -> !!@keyState[VK_J] || !!@keyState[VK_DOWN]
  up: -> !!@keyState[VK_K] || !!@keyState[VK_UP]
  left: -> !!@keyState[VK_H] || !!@keyState[VK_LEFT]
  right: -> !!@keyState[VK_L] || !!@keyState[VK_RIGHT]
  shoot: -> !!@keyState[VK_Z]

  offset: ->
    x = y = 0
    x += 1 if @right()
    x -= 1 if @left()
    y += 1 if @down()
    y -= 1 if @up()
    new Point x, y

controller = new Controller

document.body.addEventListener 'keydown', (e) ->
  controller.keyState[e.keyCode] = true
  console.log e.keyCode, 'down'

document.body.addEventListener 'keyup', (e) ->
  delete controller.keyState[e.keyCode]

class Entities
  constructor: ->
    @entities = []

  draw: (ctx, percent=1) ->
    for e in @entities
      e.draw ctx, percent

  tick: ->
    for e in @entities
      e.tick()
    @entities = @entities.filter (e) -> e.alive()

  add: (e) ->
    @entities.push e

  getCollisionsFor: (entity) ->
    result = []
    for e in @entities
      unless e == entity
        result.push e if entity.overlaps e
    result

class Entity
  constructor: (@x, @y, @width, @height) ->
  draw: (ctx, percent) ->
    p = @getDrawingPos percent
    ctx.fillStyle = @color
    ctx.fillRect p.x, p.y, @width, @height

  getDrawingPos: (percent) ->
    return new Point @x, @y unless @lastPos
    x = @x * percent + @lastPos.x * (1 - percent)
    y = @y * percent + @lastPos.y * (1 - percent)
    new Point x, y

  tick: ->
    @lastPos = new Point @x, @y

  alive: -> true

  overlaps: (e) ->
    x = @overlap2d @x, @width, e.x, e.width
    y = @overlap2d @y, @height, e.y, e.height
    x && y

  overlap2d: (x1, w1, x2, w2) ->
    x1e = x1 + w1
    x2e = x2 + w2
    return (x2 <= x1 <= x2e) || (x2 <= x1e <= x2e) ||
        (x1 <= x2 <= x1e) || (x1 <= x2e <= x1e)

class LoopingTimer
  constructor: (@duration) ->
    @left = @duration

  tick: ->
    @left-- if @left > 0
    if @left == 0
      @left = @duration
      return true
    false

# Calls |fn| every |ticks| ticks.
class Generator extends Entity
  constructor: (@ticks, @fn) ->
    super 0, 0, 0, 0
    @timer = new LoopingTimer @ticks

  tick: ->
    if @timer.tick()
      @fn()

class Particles
  constructor: ->
    @particles = []

  tick: ->
    for p in @particles
      p.tick()
    @particles = @particles.filter (p) ->
      p.alive()

  draw: (ctx) ->
    for p in @particles
      p.draw ctx

  add: (p) ->
    @particles.push p

  size: -> @particles.length

class Particle
  constructor: (@x, @y, @color, @speed=1, @size=1) ->

  tick: -> @x-= @speed
  alive: -> @x + @size >= 0

  draw: (ctx) ->
    ctx.fillStyle = @color
    ctx.fillRect @x, @y, @size, 1

class GameWindow
  constructor: (@x, @y, @width, @height) ->
    @entities = new Entities
  draw: (ctx, percent) ->
  add: (entity) -> @entities.add entity
  tick: -> @entities.tick()

class Shooter
  constructor: (@cooldown) -> @left = 0
  tick: -> @left-- if @left > 0
  canShoot: -> @left == 0
  shoot: ->
    return false unless @canShoot()
    @left = @cooldown
    true

class Player extends Entity
  constructor: ->
    super
    @shooter = new Shooter 10
    @color = 'red'

  tick: ->
    super()
    @shooter.tick()
    delta = controller.offset().toUnit().scale(2)
    @x += delta.x
    @y += delta.y
    if controller.shoot()
      if @shooter.shoot()
        b = new Bullet @x + @width, @y + @height / 2 - 1, 4, 0
        starsWindow.entities.add b

class StarsWindow extends GameWindow
  constructor: ->
    super 0, 0, WIDTH, HEIGHT/2
    @particles = new Particles
    for x in [0..@width]
      @particles.add @generateParticle(x, 2)

    for x in [0..Math.floor(@width/2)]
      @particles.add @generateParticle(x * 2, 3, '#aaa')

    @init()

  generateParticle: (x, speed=1, color='#ddd') ->
    y = randInt @height
    size = 1
    new Particle x, y, color, speed, size

  draw: (ctx, percent) ->
    ctx.fillStyle = 'black'
    ctx.fillRect @x, @y, @width, @height
    @particles.draw ctx
    starsWindow.entities.draw ctx, percent

  addNewParticles: ->
    @particles.add @generateParticle(@width, 2)
    @particles.add @generateParticle(@width, 3, '#aaa')
    if @particles.size() < @width
      @particles.add @generateParticle(@width, 2)

  tick: ->
    super
    @particles.tick()

  init: ->
    player = new Player 20, (@height - 10) / 2, 10, 10
    @entities.add player
    @entities.add new Generator 60, =>
      bg = new BadGuy @width, randInt(@height - 10), 10, 10
      bg.color = randArray ['green', 'gray', 'blue', 'cyan']
      bg.target = player
      bg.addScript new GoToScript bg, new Point(@width - 50, @height / 2)
      bg.addScript new GoToScript bg, new Point(@width - 50, @height / 2 - 30)
      bg.addScript new GoToScript bg, new Point(@width - 80, @height / 2 + 30)
      @entities.add bg

class PuzzleWindow extends GameWindow
  TILE_WIDTH = 16
  TILE_HEIGHT = 16

  constructor: ->
    super 0, 240, WIDTH, 240
    @tilesWide = 8
    @tilesHigh = 10
    @colors = []

  addPiece: (color) ->
    console.log 'color = ', color
    @colors.push color

  draw: (ctx, percent) ->
    ctx.fillStyle = 'orange'
    ctx.fillRect @x, @y, @width, @height
    ctx.strokeStyle = 'white'
    towerWidth = @tilesWide * TILE_WIDTH
    towerX = @x + (@width - towerWidth) / 2
    for y in [0...@tilesHigh]
      for x in [0...@tilesWide]
        colorI = x + y * @tilesWide
        px = towerX + x * TILE_WIDTH
        py = @y + @height - (y + 1) * TILE_HEIGHT
        if colorI < @colors.length
          ctx.fillStyle = @colors[colorI]
          ctx.fillRect px, py, TILE_WIDTH, TILE_HEIGHT
        ctx.strokeRect px, py, TILE_WIDTH, TILE_HEIGHT

starsWindow = new StarsWindow
puzzleWindow = new PuzzleWindow

class FreefallScript
  constructor: (@badGuy) ->
  nextDelta: -> new Point -1, 0
  alive: -> true

class GoToScript
  constructor: (@badGuy, @goToPt) ->
  nextDelta: ->
    speed = 2
    badGuyPt = new Point @badGuy.x, @badGuy.y
    direction = @goToPt.sub badGuyPt
    if direction.magnitude() < speed
      return direction
    direction.toUnit().scale(speed)

  alive: ->
    pt = new Point @badGuy.x, @badGuy.y
    pt = @goToPt.sub pt
    !pt.isEmpty()

class CrashingBadGuy extends Entity
  constructor: (x, y, @color) ->
    super x, y, 10, 10

  alive: -> @y <= starsWindow.height

  tick: ->
    @x--
    @y++
    if !@alive()
      puzzleWindow.addPiece @color

class BadGuy extends Entity
  constructor: ->
    super
    @hp = 1
    @target = null  # Set with a setter
    @scripts = [new FreefallScript this]
    @color = 'green'

  tick: ->
    super
    return unless @target
    if @scripts.length == 0
      @x--
    else
      delta = @scripts[0].nextDelta()
      @scripts.shift() if !@scripts[0].alive()
      @x += delta.x
      @y += delta.y

  addScript: (script) ->
    @scripts.unshift script

  hitByBullet: (bullet) ->
    return unless @alive()
    @hp = 0
    starsWindow.entities.add new CrashingBadGuy @x, @y, @color
  alive: -> @hp > 0

class Bullet extends Entity
  constructor: (x, y, @dx, @dy) ->
    super x, y, 2, 2
    @hit = false
    @color = 'red'

  tick: ->
    super
    @x += @dx
    @y += @dy
    for e in starsWindow.entities.getCollisionsFor this
      if e.constructor == BadGuy
        e.hitByBullet this
        @hit = true

  alive: -> @x < WIDTH && !@hit

canvas = document.getElementById 'c'
ctx = canvas.getContext '2d'

colors = ['red', 'green', 'blue']

now = -> new Date().getTime()
lastTick = now()

TPS = 60                      # ticks per second
FPT = Math.floor 1000/TPS     # frames per tick

draw = ->
  timeNow = now()
  delta = timeNow - lastTick
  if timeNow - lastTick > 1000
    lastTick = timeNow - FPT
  while timeNow - lastTick >= FPT
    starsWindow.entities.tick()
    lastTick += FPT
  requestAnimationFrame draw
  percent = (timeNow - lastTick) / FPT
  starsWindow.tick()
  puzzleWindow.tick()
  starsWindow.addNewParticles()
  starsWindow.draw ctx, percent
  puzzleWindow.draw ctx, percent


draw()
