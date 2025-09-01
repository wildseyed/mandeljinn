-- mandeljinn.lua
-- Norns fractal explorer with audio (simplified working version)

engine.name = "Mandeljinn"

-- Constants
local SCREEN_W = 128
local SCREEN_H = 64

-- State
local center_x = -0.5
local center_y = 0.0
local zoom = 1.0
local max_iterations = 64
local fractal_index = 1

-- Fractals
local fractals = {
  {id = 1, name = "Mandelbrot", formula = "z = z^2 + c"},
  {id = 2, name = "Julia", formula = "z = z^2 + c"},
  {id = 3, name = "Burning Ship", formula = "z = (|Re(z)| + i|Im(z)|)^2 + c"}
}

-- Pixel buffer
local pixel_buffer = {}

-- Rendering
local render_needed = true
local render_timer

-- Simple fractal calculation
function iterate_fractal(cx, cy, fractal_id, max_iter)
  local zx, zy = 0, 0
  
  for i = 1, max_iter do
    if fractal_id == 1 then -- Mandelbrot
      local temp = zx * zx - zy * zy + cx
      zy = 2 * zx * zy + cy
      zx = temp
    elseif fractal_id == 2 then -- Julia
      local temp = zx * zx - zy * zy - 0.7269 + 0.1889
      zy = 2 * zx * zy + 0.1889
      zx = temp
    else -- Burning Ship
      zx = math.abs(zx)
      zy = math.abs(zy)
      local temp = zx * zx - zy * zy + cx
      zy = 2 * zx * zy + cy
      zx = temp
    end
    
    if zx * zx + zy * zy > 4 then
      return i
    end
  end
  return max_iter
end

-- Convert screen coordinates to complex plane
function screen_to_complex(screen_x, screen_y)
  local aspect = SCREEN_W / SCREEN_H
  local range = 3.0 / zoom
  local cx = center_x + (screen_x / SCREEN_W - 0.5) * range * aspect
  local cy = center_y + (screen_y / SCREEN_H - 0.5) * range
  return cx, cy
end

-- Map iterations to brightness
function map_iterations(iterations, max_iter)
  if iterations >= max_iter then
    return 0 -- Black for points in set
  else
    return math.floor((iterations / max_iter) * 15) -- 0-15 brightness
  end
end

-- Initialize buffer
function init_buffer()
  for y = 1, SCREEN_H do
    pixel_buffer[y] = {}
    for x = 1, SCREEN_W do
      pixel_buffer[y][x] = 0
    end
  end
end

-- Render fractal (simplified)
function render_fractal()
  for y = 1, SCREEN_H do
    for x = 1, SCREEN_W do
      local cx, cy = screen_to_complex(x-1, y-1)
      local iterations = iterate_fractal(cx, cy, fractals[fractal_index].id, max_iterations)
      pixel_buffer[y][x] = map_iterations(iterations, max_iterations)
    end
  end
  render_needed = false
end

-- Main init
function init()
  print("Mandeljinn starting...")
  
  init_buffer()
  render_fractal() -- Initial render
  
  -- Simple timer for periodic redraws (not for rendering)
  render_timer = metro.init()
  render_timer.time = 1/30 -- 30fps
  render_timer.event = function()
    if render_needed then
      render_fractal()
    end
    redraw()
  end
  render_timer:start()
  
  print("Mandeljinn ready")
end

-- Draw function
function redraw()
  screen.clear()
  
  -- Draw fractal
  for y = 1, SCREEN_H do
    for x = 1, SCREEN_W do
      local brightness = pixel_buffer[y][x]
      if brightness > 0 then
        screen.level(brightness)
        screen.pixel(x-1, y-1)
      end
    end
  end
  
  -- Draw info
  screen.level(15)
  screen.move(1, 8)
  screen.text(fractals[fractal_index].name)
  screen.move(1, 58)
  screen.text("zoom: " .. string.format("%.1f", zoom))
  
  screen.update()
end

-- Key handler
function key(n, z)
  if z == 1 then  -- Key press
    if n == 1 then
      -- K1: Toggle to norns menu
      norns.menu.init()
    elseif n == 2 then
      -- K2: Change fractal
      fractal_index = fractal_index + 1
      if fractal_index > #fractals then
        fractal_index = 1
      end
      render_needed = true
      print("Fractal: " .. fractals[fractal_index].name)
    elseif n == 3 then
      -- K3: Reset view
      center_x = -0.5
      center_y = 0.0
      zoom = 1.0
      render_needed = true
      print("View reset")
    end
  end
end

-- Encoder handler
function enc(n, delta)
  if n == 1 then
    -- E1: Change max iterations
    max_iterations = util.clamp(max_iterations + delta, 8, 256)
    render_needed = true
    print("Iterations: " .. max_iterations)
  elseif n == 2 then
    -- E2: Move horizontally
    center_x = center_x + (delta * 0.1 / zoom)
    render_needed = true
  elseif n == 3 then
    -- E3: Zoom
    if delta > 0 then
      zoom = zoom * 1.1
    else
      zoom = zoom / 1.1
    end
    zoom = util.clamp(zoom, 0.1, 1000)
    render_needed = true
    print("Zoom: " .. string.format("%.1f", zoom))
  end
end

-- Cleanup
function cleanup()
  if render_timer then
    render_timer:stop()
  end
end
