WIDTH = 640
HEIGHT = 240

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

class Point
  constructor: (@x, @y) ->

  scale: (x, y=x) -> new Point @x * x, @y * y
  offset: ->
    h = Math.sqrt(@x*@x + @y*@y)
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

class BadGuy extends Entity
  constructor: ->
    super
    @hp = 1
    @target = null  # Set with a setter

  draw: (ctx, percent) ->
    ctx.fillStyle = 'green'
    ctx.fillRect @x, @y, @width, @height

  tick: ->
    return unless @target
    if @target.y > @y
      @y += 1
    else if @target.y < @y
      @y -= 1
    @x--

  hitByBullet: (bullet) -> @hp = 0
  alive: -> @hp > 0


class Shooter
  constructor: (@cooldown) -> @left = 0
  tick: -> @left-- if @left > 0
  canShoot: -> @left == 0
  shoot: ->
    return false unless @canShoot()
    @left = @cooldown
    true

entities = new Entities()

class Bullet extends Entity
  constructor: (x, y, @dx, @dy) ->
    super x, y, 2, 2
    @hit = false

  tick: ->
    super
    @x += @dx
    @y += @dy
    for e in entities.getCollisionsFor this
      if e.constructor == BadGuy
        e.hitByBullet this
        @hit = true

  alive: -> @x < WIDTH && !@hit

  draw: (ctx, percent) ->
    p = @getDrawingPos percent
    ctx.fillStyle = 'red'
    ctx.fillRect p.x, p.y, @width, @height

class Player extends Entity
  constructor: ->
    super
    @shooter = new Shooter 10

  tick: ->
    super()
    @shooter.tick()
    delta = controller.offset().scale(2).offset()
    @x += delta.x
    @y += delta.y
    if controller.shoot()
      if @shooter.shoot()
        entities.add new Bullet @x, @y + @height / 2 - 1, 4, 0

  draw: (ctx, percent) ->
    p = @getDrawingPos percent
    ctx.fillStyle = 'red'
    ctx.fillRect p.x, p.y, @width, @height

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

player = new Player 20, (HEIGHT - 10) / 2, 10, 10
entities.add player
entities.add new Generator 60, ->
  bg = new BadGuy WIDTH, randInt(HEIGHT - 10), 10, 10
  bg.target = player
  entities.add bg

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

canvas = document.getElementById 'c'
ctx = canvas.getContext '2d'

randInt = (n) -> Math.floor(Math.random() * n)
randArray = (arr) -> arr[randInt(arr.length)]

colors = ['red', 'green', 'blue']

generateParticle = ->
  y = randInt HEIGHT
  size = 1
  speed = 2
  new Particle x, y, '#ddd', speed, size

ps = new Particles()
for x in [0..WIDTH]
  ps.add generateParticle()

now = -> new Date().getTime()
lastTick = now()

TPS = 60                      # ticks per second
FPT = Math.floor 1000/TPS     # frames per tick

draw = ->
  timeNow = now()
  delta = timeNow - lastTick
  while timeNow - lastTick > FPT
    entities.tick()
    lastTick += FPT
  requestAnimationFrame draw
  ctx.fillStyle = 'black'
  ctx.fillRect 0, 0, WIDTH, HEIGHT
  ps.tick()
  ps.draw ctx
  entities.draw ctx, (timeNow - lastTick) / FPT

  y = randInt HEIGHT
  ps.add generateParticle()
  if ps.size() < WIDTH
    ps.add generateParticle()

draw()
