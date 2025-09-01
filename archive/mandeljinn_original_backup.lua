-- Mandeljinn by Wildseyed
-- vibin' with Claude
--
-- Deep in the mathematical
-- realm where infinite
-- complexity emerges from
-- simple rules, the Mandeljinn
-- dwells. Ancient folklore
-- speaks of genies trapped in
-- lamps, but this Jinn inhabits
-- the fractal landscape itself -
-- a spirit of pure mathematics
-- that transforms the eternal
-- dance of complex numbers
-- into living sound and vision.
--
-- As you navigate these
-- infinite shores, the
-- Mandeljinn whispers the
-- secret songs hidden within
-- each point of the fractal
-- plane. Every zoom reveals
-- new mysteries, every orbit
-- traces melodies that have
-- waited eons to be heard.
-- This is where mathematics
-- becomes music, where
-- iteration becomes rhythm,
-- where chaos becomes art.
--
-- CONTROLS:
-- K1: Toggle menu / back
-- K2: Add current location to
-- sequence
-- K3: Delete last sequence
-- entry
-- E1: Pan left/right (hold K2:
-- zoom out/in)
-- E2: Pan up/down (hold K2:
-- change fractal)
-- E3: Zoom in/out (hold K3:
-- palette cycling)
--
-- HOLD COMBINATIONS:
-- K2 + E1: Zoom out/in
-- K2 + E2: Change fractal type
-- K3 + E3: Cycle color palette
-- K2 + K3 (long press): Reset
-- view to default
--
-- github.com/wildseyed/mandeljinn

local util = require 'util'

-- Engine registration
engine.name = "Mandeljinn"

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

-- Orbit visualization
local orbit_points = {}
local orbit_cx = 0
local orbit_cy = 0
local show_orbit = true

-- Encoder state
local encoder_dir = {0, 0, 0}
local encoder_last_time = {0, 0, 0}
local encoder_timeout = 0.1

-- Key state for hold detection
local k2_press_time = 0
local k3_press_time = 0
local k2_still_down = false
local k3_still_down = false
local HOLD_THRESHOLD = 0.5

-- Sequence management
local sequence_list = {}
local global_tempo = 120
local loop_length = 4

-- Palette system
local palette_index = 1
local palettes = {
  {name="linear", fn=function(r) return r end},
  {name="gamma√", fn=function(r) return math.sqrt(r) end},
  {name="gamma¼", fn=function(r) return r^(0.25) end},
  {name="cosine", fn=function(r) return 0.5 - 0.5*math.cos(r*math.pi) end},
  {name="edge", fn=function(r) return (r < 0.85) and (r*0.6) or (0.6 + (r-0.85)/0.15*0.4) end},
  {name="smooth", fn="dither"},
}

-- 4x4 Bayer matrix for dithering
local bayer4 = {
  { 0,  8,  2, 10},
  {12,  4, 14,  6},
  { 3, 11,  1,  9},
  {15,  7, 13,  5},
}

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

-- Map iterations to screen level with palette support
function map_iterations(iterations, max_iter)
  if iterations >= max_iter then return 0 end
  
  local r = iterations / max_iter
  local current_palette = palettes[palette_index]
  
  if current_palette.fn == "dither" then
    -- Smooth coloring with Bayer dithering - simplified for compatibility
    local level_base = math.floor(r * 14) + 1
    local level_next = math.min(level_base + 1, 15)
    local fraction = (r * 14) % 1
    
    -- Use a simple threshold for dithering
    if fraction > 0.5 then
      return level_next
    else
      return level_base
    end
  else
    -- Apply palette function
    r = current_palette.fn(r)
    local level = 1 + math.floor(r * 14)
    return math.min(level, 15)
  end
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

-- Sequence management functions
function add_current_state_to_sequence()
  local state = {
    fractal_index = fractal_index,
    center_x = center_x,
    center_y = center_y,
    zoom = zoom,
    max_iterations = max_iterations,
    palette_index = palette_index,
    timestamp = util.time()
  }
  table.insert(sequence_list, state)
  return #sequence_list
end

function delete_last_sequence_entry()
  if #sequence_list > 0 then
    table.remove(sequence_list, #sequence_list)
    return true
  end
  return false
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

-- Calculate orbit for a specific point and send to engine
function calculate_and_send_orbit(cx, cy)
  print("Calculating orbit for point: cx=" .. cx .. ", cy=" .. cy)
  
  -- Store the point we're calculating orbit for
  orbit_cx = cx
  orbit_cy = cy
  
  -- Clear previous orbit points
  orbit_points = {}
  
  local zx, zy = 0, 0  -- Start with Z0 = 0
  
  -- Store Z0
  table.insert(orbit_points, {zx, zy})
  
  -- Send initial Z0 to engine
  if engine and engine.updateOrbit then
    engine.updateOrbit(zx, zy)
    print("Sent Z0 to engine: zx=" .. zx .. ", zy=" .. zy)
  else
    print("Engine updateOrbit not available")
  end
  
  -- Calculate a few iterations and send the orbit progression
  for i = 1, 8 do  -- Send first 8 orbit points
    -- Mandelbrot iteration: z = z^2 + c
    local temp = zx * zx - zy * zy + cx
    zy = 2 * zx * zy + cy
    zx = temp
    
    -- Store orbit point
    table.insert(orbit_points, {zx, zy})
    
    print("Orbit iteration " .. i .. ": zx=" .. string.format("%.4f", zx) .. ", zy=" .. string.format("%.4f", zy))
    
    -- Send current orbit point to engine
    if engine and engine.updateOrbit then
      engine.updateOrbit(zx, zy)
      print("  -> Sent to engine")
    end
    
    -- Break if orbit escapes
    if zx * zx + zy * zy > 4 then
      print("  -> Orbit escaped at iteration " .. i)
      break
    end
  end
  
  print("Orbit calculation complete, stored " .. #orbit_points .. " points")
  screen_dirty = true  -- Trigger redraw to show orbit
end

-- Convert complex coordinates to screen coordinates for orbit display
function complex_to_screen(zx, zy)
  local aspect = SCREEN_W / SCREEN_H
  local range = 3.0 / zoom
  local screen_x = ((zx - center_x) / (range * aspect) + 0.5) * SCREEN_W
  local screen_y = ((zy - center_y) / range + 0.5) * SCREEN_H
  return screen_x, screen_y
end

-- Audio control functions
function start_audio()
  if engine and engine.startAudio then
    engine.startAudio()
    print("Audio started - Direct Mode")
    show_hud("AUDIO ON - Direct Mode")
  else
    print("Engine startAudio not available")
  end
end

function stop_audio()
  if engine and engine.stopAudio then
    engine.stopAudio()
    print("Audio stopped")
    show_hud("AUDIO OFF")
  else
    print("Engine stopAudio not available")
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
  
  -- Test orbit calculation with center point
  print("Testing orbit calculation...")
  calculate_and_send_orbit(center_x, center_y)
  
  -- Test audio after a brief delay
  print("Testing Direct Mode audio...")
  start_audio()
  
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
  
  -- Check hold modifiers
  local k2_held = k2_still_down and (now - k2_press_time) > HOLD_THRESHOLD
  local k3_held = k3_still_down and (now - k3_press_time) > HOLD_THRESHOLD
  
  -- K2 Hold + Encoder combinations (immediate actions)
  if k2_held then
    if n == 1 then
      -- K2 Hold + E1: Fractal selection (immediate)
      fractal_index = fractal_index + dir
      if fractal_index < 1 then fractal_index = #fractals end
      if fractal_index > #fractals then fractal_index = 1 end
      show_hud("FRACTAL: " .. fractals[fractal_index].name)
      render_needed = true
    elseif n == 3 then
      -- K2 Hold + E3: Iteration selection (immediate)
      -- Single digit increments with hard limits (8 min, 2000 max for now)
      local new_iterations = max_iterations + dir
      new_iterations = util.clamp(new_iterations, 8, 2000)
      
      if new_iterations ~= max_iterations then
        max_iterations = new_iterations
        show_hud("ITERATIONS: " .. max_iterations)
        render_needed = true
      end
    end
    encoder_last_time[n] = now
    return
  end
  
  -- K3 Hold + Encoder combinations (immediate actions)
  if k3_held then
    if n == 1 then
      -- K3 Hold + E1: Tempo control (immediate)
      global_tempo = util.clamp(global_tempo + dir * 5, 20, 300)
      show_hud("TEMPO: " .. global_tempo .. " BPM")
    elseif n == 2 then
      -- K3 Hold + E2: Loop length control (immediate)
      loop_length = util.clamp(loop_length + dir, 1, 32)
      show_hud("LOOP LENGTH: " .. loop_length)
    elseif n == 3 then
      -- K3 Hold + E3: Palette cycling (immediate)
      palette_index = (palette_index % #palettes) + 1
      show_hud("PALETTE: " .. palettes[palette_index].name)
      render_needed = true
    end
    encoder_last_time[n] = now
    return
  end
  
  -- Base navigation (accumulates for smooth movement)
  encoder_dir[n] = dir
  encoder_last_time[n] = now
end

-- Key handler
function key(n, z)
  local now = util.time()
  
  if z == 1 then  -- Key press
    if n == 1 then
      -- K1: Toggle to norns menu (original spec)
      norns.menu.init()
    elseif n == 2 then
      k2_press_time = now
      k2_still_down = true
    elseif n == 3 then
      k3_press_time = now
      k3_still_down = true
    end
  else  -- Key release
    if n == 2 then
      k2_still_down = false
      local hold_duration = now - k2_press_time
      if hold_duration < HOLD_THRESHOLD then
        -- K2 short press: Add current state to sequence (original spec)
        local count = add_current_state_to_sequence()
        show_hud("ADDED TO SEQUENCE (" .. count .. ")")
      end
    elseif n == 3 then
      k3_still_down = false
      local hold_duration = now - k3_press_time
      
      -- Check for K2+K3 combination (both keys held together)
      if k2_still_down and hold_duration >= HOLD_THRESHOLD then
        -- K2+K3 long press: Reset view
        center_x = -0.5
        center_y = 0.0
        zoom = 1.0
        fractal_index = 1
        show_hud("VIEW RESET")
        render_needed = true
      elseif hold_duration < HOLD_THRESHOLD then
        -- K3 short press: Delete from sequence (original spec)
        if delete_last_sequence_entry() then
          show_hud("DELETED FROM SEQUENCE (" .. #sequence_list .. ")")
        else
          show_hud("SEQUENCE EMPTY")
        end
      end
    end
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
  
  -- Draw orbit visualization
  if show_orbit and #orbit_points > 1 then
    screen.level(15)  -- Bright white for orbit
    screen.line_width(1)
    
    -- Draw lines connecting orbit points
    for i = 1, #orbit_points - 1 do
      local zx1, zy1 = orbit_points[i][1], orbit_points[i][2]
      local zx2, zy2 = orbit_points[i+1][1], orbit_points[i+1][2]
      
      local sx1, sy1 = complex_to_screen(zx1, zy1)
      local sx2, sy2 = complex_to_screen(zx2, zy2)
      
      -- Only draw if both points are on screen
      if sx1 >= 0 and sx1 <= SCREEN_W and sy1 >= 0 and sy1 <= SCREEN_H and
         sx2 >= 0 and sx2 <= SCREEN_W and sy2 >= 0 and sy2 <= SCREEN_H then
        screen.move(sx1, sy1)
        screen.line(sx2, sy2)
        screen.stroke()
      end
    end
    
    -- Draw starting point (Z0) as a small circle
    if #orbit_points > 0 then
      local zx0, zy0 = orbit_points[1][1], orbit_points[1][2]
      local sx0, sy0 = complex_to_screen(zx0, zy0)
      if sx0 >= 0 and sx0 <= SCREEN_W and sy0 >= 0 and sy0 <= SCREEN_H then
        screen.circle(sx0, sy0, 2)
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
