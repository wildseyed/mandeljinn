-- Mandeljinn - Clean Version
-- Fractal explorer with pixel-precise pan and zoom

local util = require 'util'

-- Screen dimensions
local SCREEN_W = 128
local SCREEN_H = 64

-- Fractal definitions
local fractals = {
  {id = 0, name = "Mandelbrot", short = "MAND"},
  {id = 1, name = "Burning Ship", short = "BURN"},
  {id = 2, name = "Tricorn", short = "TRIC"}
}

-- State variables
local fractal_index = 1
local center_x = -0.5
local center_y = 0.0
local zoom = 1.0
local max_iterations = 100

-- UI state
local screen_dirty = true
local hud_timeout = 0
local hud_text = ""

-- Rendering state
local render_in_progress = false
local render_row = 1
local rows_per_frame = 8
local render_needed = true

-- Pixel buffer
local pixel_buffer = {}

-- Encoder state
local encoder_dir = {0, 0, 0}
local encoder_last_time = {0, 0, 0}
local encoder_timeout = 0.1

-- Initialize pixel buffer
function init_buffer()
  for y = 1, SCREEN_H do
    pixel_buffer[y] = {}
    for x = 1, SCREEN_W do
      pixel_buffer[y][x] = 0
    end
  end
end

-- Convert screen coordinates to complex plane
function screen_to_complex(screen_x, screen_y)
  local aspect = SCREEN_W / SCREEN_H
  local scale = 4.0 / zoom
  
  local cx = center_x + (screen_x - SCREEN_W/2) * scale / SCREEN_W * aspect
  local cy = center_y + (screen_y - SCREEN_H/2) * scale / SCREEN_H
  
  return cx, cy
end

-- Fractal iteration
function iterate_fractal(cx, cy, fractal_id, max_iter)
  if math.abs(cx) > 100 or math.abs(cy) > 100 then return 0 end
  
  local zx, zy = cx, cy
  local iterations = 0
  
  for i = 1, max_iter do
    local zx2 = zx * zx
    local zy2 = zy * zy
    local mag2 = zx2 + zy2
    
    if mag2 >= 4.0 then return iterations end
    if mag2 > 1e10 then return iterations end
    
    if fractal_id == 0 then -- Mandelbrot
      local nzx = zx2 - zy2 + cx
      local nzy = 2 * zx * zy + cy
      zx, zy = nzx, nzy
    elseif fractal_id == 1 then -- Burning Ship
      local nzx = zx2 - zy2 + cx
      local nzy = math.abs(2 * zx * zy) + cy
      zx, zy = nzx, nzy
    elseif fractal_id == 2 then -- Tricorn
      local nzx = zx2 - zy2 + cx
      local nzy = -2 * zx * zy + cy
      zx, zy = nzx, nzy
    else -- Default Mandelbrot
      local nzx = zx2 - zy2 + cx
      local nzy = 2 * zx * zy + cy
      zx, zy = nzx, nzy
    end
    
    iterations = iterations + 1
  end
  
  return max_iter
end

-- Map iterations to screen level
function map_iterations(iterations, max_iter)
  if iterations >= max_iter then return 0 end
  local r = iterations / max_iter
  local level = 1 + math.floor(r * 14)
  return math.min(level, 15)
end

-- Start render if needed
function start_render_if_needed()
  if render_needed and not render_in_progress then
    render_row = 1
    render_in_progress = true
    render_needed = false
  end
end

-- Step render
function step_render()
  if not render_in_progress then return end
  
  local end_row = math.min(render_row + rows_per_frame - 1, SCREEN_H)
  
  for y = render_row, end_row do
    for x = 1, SCREEN_W do
      local cx, cy = screen_to_complex(x-1, y-1)
      local iterations = iterate_fractal(cx, cy, fractals[fractal_index].id, max_iterations)
      pixel_buffer[y][x] = map_iterations(iterations, max_iterations)
    end
  end
  
  render_row = end_row + 1
  screen_dirty = true
  
  if render_row > SCREEN_H then
    render_in_progress = false
  end
end

-- Update encoder timeouts
function update_encoder_timeouts()
  local now = util.time()
  for i = 1, 3 do
    if now - encoder_last_time[i] > encoder_timeout then
      encoder_dir[i] = 0
    end
  end
end

-- Show HUD message
function show_hud(text, timeout)
  hud_text = text
  hud_timeout = timeout or 30
end

-- Apply encoder movement
function apply_encoder_movement()
  update_encoder_timeouts()
  local changed = false
  
  -- Zoom (E1)
  if encoder_dir[1] ~= 0 then
    local scale = 4.0 / zoom
    local pixel_scale = scale / SCREEN_W
    scale = scale - encoder_dir[1] * (pixel_scale * 4)
    zoom = util.clamp(4.0 / scale, 0.1, 1e12)
    show_hud(string.format("ZOOM: %.2fx", zoom))
    changed = true
    encoder_dir[1] = 0
  end
  
  -- Pan X (E2)
  if encoder_dir[2] ~= 0 then
    local aspect = SCREEN_W / SCREEN_H
    local scale = 4.0 / zoom
    local pixel_step_x = scale / SCREEN_W * aspect
    center_x = util.clamp(center_x - encoder_dir[2] * pixel_step_x, -3.5, 3.5)
    show_hud(string.format("PAN X: %.3f", center_x))
    changed = true
    encoder_dir[2] = 0
  end
  
  -- Pan Y (E3)
  if encoder_dir[3] ~= 0 then
    local scale = 4.0 / zoom
    local pixel_step_y = scale / SCREEN_H
    center_y = util.clamp(center_y + encoder_dir[3] * pixel_step_y, -2.8, 2.8)
    show_hud(string.format("PAN Y: %.3f", center_y))
    changed = true
    encoder_dir[3] = 0
  end
  
  if changed then
    render_needed = true
  end
end

-- Main init function
function init()
  print("Mandeljinn starting...")
  
  init_buffer()
  render_needed = true
  
  -- Initial render
  start_render_if_needed()
  step_render()
  
  -- Start main timer
  local main_timer = metro.init()
  main_timer.time = 1/15
  main_timer.event = function()
    apply_encoder_movement()
    
    if hud_timeout > 0 then
      hud_timeout = hud_timeout - 1
      screen_dirty = true
    end
    
    start_render_if_needed()
    step_render()
    
    if screen_dirty then
      redraw()
    end
  end
  main_timer:start()
  
  print("Mandeljinn ready")
end

-- Encoder handler
function enc(n, delta)
  if delta == 0 then return end
  
  local dir = (delta > 0) and 1 or -1
  local now = util.time()
  
  -- Simple rate limiting
  if (now - encoder_last_time[n]) < 0.05 then
    return
  end
  
  encoder_dir[n] = dir
  encoder_last_time[n] = now
end

-- Key handler
function key(n, z)
  if n == 1 and z == 1 then
    -- Cycle fractal
    fractal_index = (fractal_index % #fractals) + 1
    show_hud("FRACTAL: " .. fractals[fractal_index].name)
    render_needed = true
  elseif n == 2 and z == 1 then
    -- Adjust iterations
    max_iterations = max_iterations == 100 and 200 or 100
    show_hud("ITER: " .. max_iterations)
    render_needed = true
  elseif n == 3 and z == 1 then
    -- Reset view
    center_x = -0.5
    center_y = 0.0
    zoom = 1.0
    show_hud("RESET")
    render_needed = true
  end
end

-- Draw function
function redraw()
  screen.clear()
  
  -- Draw fractal
  for y = 1, SCREEN_H do
    for x = 1, SCREEN_W do
      local level = pixel_buffer[y][x]
      if level > 0 then
        screen.level(level)
        screen.rect(x-1, y-1, 1, 1)
        screen.fill()
      end
    end
  end
  
  -- Draw HUD
  if hud_timeout > 0 then
    screen.level(15)
    screen.move(2, 8)
    screen.text(hud_text)
  end
  
  -- Status line
  screen.level(4)
  screen.move(2, SCREEN_H - 2)
  local progress = ""
  if render_in_progress then
    local pct = math.floor((render_row-1)/SCREEN_H*100)
    progress = string.format(" R%02d%%", pct)
  end
  screen.text(string.format("%s | %.1fx%s", 
    fractals[fractal_index].short, zoom, progress))
  
  screen.update()
  screen_dirty = false
end

function cleanup()
  -- Cleanup code here
end
