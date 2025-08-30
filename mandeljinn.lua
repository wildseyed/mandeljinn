-- Mandeljinn v0.2-debug
-- Fractal Music Generator
-- norns implementation
--
-- E1: Zoom
-- E2: Pan X  
-- E3: Pan Y
-- K1+E1: Select Fractal
-- K2+E1: Set Iterations
-- K2: Add Orbit Origin
-- K3: Remove Last Origin
--
-- Based on FMG research

local VERSION = "v0.2-debug-20250829"

local util = require 'util'
local tab = require 'tabutil'
local mu = require 'musicutil'

engine.name = 'PolyPerc'

-- Screen dimensions
local SCREEN_W = 128
local SCREEN_H = 64

-- Fractal definitions matching FMG
local fractals = {
  {id = 0, name = "Mandelbrot", short = "MAND"},
  {id = 1, name = "Burning Ship", short = "BURN"},
  {id = 2, name = "Tricorn", short = "TRIC"}, 
  {id = 3, name = "Rectangle", short = "RECT"},
  {id = 4, name = "Klingon", short = "KLIN"},
  {id = 5, name = "Crown", short = "CROW"},
  {id = 6, name = "Frog", short = "FROG"},
  {id = 7, name = "Mandelship", short = "MSHP"},
  {id = 8, name = "Frankenstein", short = "FRNK"},
  {id = 9, name = "Logistic", short = "LOGI"}
}

-- State variables
local fractal_index = 1 -- Start with Mandelbrot
local center_x = -0.5
local center_y = 0.0
local zoom = 1.0
local max_iterations = 100

-- Safe bounds to prevent numerical issues
local MAX_PAN_X = 3.5  -- Horizontal pan limit (wider range)
local MAX_PAN_Y = 2.8  -- Vertical pan limit (narrower range)
local MAX_ZOOM = 1e12 -- Maximum zoom before precision breaks
local MIN_ZOOM = 0.1  -- Minimum zoom to prevent getting lost

-- UI state
local screen_dirty = true
local fractal_select_mode = false
local iteration_select_mode = false
local hud_timeout = 0
local hud_text = ""

-- Encoder debouncing to prevent queue buildup
local encoder_timer = nil
local pending_render = false

-- Boolean encoder state tracking (digital, not analog)
local encoder_turning_cw = {false, false, false}   -- Is encoder turning clockwise?
local encoder_turning_ccw = {false, false, false}  -- Is encoder turning counter-clockwise?
local encoder_idle_time = {0, 0, 0}                -- Time since last encoder activity
local encoder_timeout = 0.1                        -- Consider encoder stopped after 100ms of no activity

-- Movement processing state
local movement_in_progress = false                  -- Are we in move->render->wait cycle?

-- Background rendering state  
local render_in_progress = false
local render_row = 1
local render_timer = nil
local pixels_per_frame = 4 -- Render 4 rows per frame for smooth updates
local render_generation = 0 -- Track render requests to prevent race conditions

-- Orbit origins list
local orbit_origins = {}

-- Rendering
local pixel_buffer = {}
local render_needed = true

function init()
  print("=== MANDELJINN " .. VERSION .. " STARTING ===")
  
  -- Initialize pixel buffer
  for y = 1, SCREEN_H do
    pixel_buffer[y] = {}
    for x = 1, SCREEN_W do
      pixel_buffer[y][x] = 0
    end
  end
  
  -- Initial render
  render_fractal()
  
  -- Screen refresh timer
  local screen_timer = metro.init()
  screen_timer.time = 1/15 -- 15 fps
  screen_timer.event = function()
    if screen_dirty then
      redraw()
    end
    -- Update HUD timeout
    if hud_timeout > 0 then
      hud_timeout = hud_timeout - 1
      screen_dirty = true
    end
  end
  screen_timer:start()
end

-- FMG-style fractal iteration functions
-- Note: Using Z0 = C convention from FMG (not classic Z0 = 0)
function iterate_fractal(cx, cy, fractal_id, max_iter)
  -- Numerical safety checks
  if math.abs(cx) > 100 or math.abs(cy) > 100 then
    return 0 -- Outside reasonable bounds
  end
  
  local zx, zy = cx, cy  -- Z0 = C (FMG convention)
  local iterations = 0
  
  for i = 1, max_iter do
    local zx2 = zx * zx
    local zy2 = zy * zy
    local magnitude_squared = zx2 + zy2
    
    -- Bailout test (|Z|^2 >= 4)
    if magnitude_squared >= 4.0 then
      return iterations
    end
    
    -- Numerical safety - prevent overflow
    if magnitude_squared > 1e10 or zx ~= zx or zy ~= zy then
      return iterations -- NaN or overflow detected
    end
    
    -- Apply fractal formula
    if fractal_id == 0 then -- Mandelbrot
      local new_zx = zx2 - zy2 + cx
      local new_zy = 2 * zx * zy + cy
      zx, zy = new_zx, new_zy
      
    elseif fractal_id == 1 then -- Burning Ship
      local new_zx = zx2 - zy2 + cx
      local new_zy = math.abs(2 * zx * zy) + cy
      zx, zy = new_zx, new_zy
      
    elseif fractal_id == 2 then -- Tricorn
      local new_zx = zx2 - zy2 + cx
      local new_zy = -2 * zx * zy + cy
      zx, zy = new_zx, new_zy
      
    elseif fractal_id == 3 then -- Rectangle (simplified)
      local mod_z2 = zx2 + zy2
      local new_zx = zx * mod_z2 - zx * cx * cx + cx
      local new_zy = zy * mod_z2 - zy * cy * cy + cy
      zx, zy = new_zx, new_zy
      
    elseif fractal_id == 4 then -- Klingon
      local new_zx = math.abs(zx * zx2) - 3 * zy2 * math.abs(zx) + cx
      local new_zy = 3 * zx2 * math.abs(zy) - math.abs(zy * zy2) + cy
      zx, zy = new_zx, new_zy
      
    elseif fractal_id == 5 then -- Crown
      local new_zx = zx * zx2 - 3 * zx * zy2 + cx
      local new_zy = math.abs(3 * zx2 * zy - zy * zy2) + cy
      zx, zy = new_zx, new_zy
      
    else -- Default to Mandelbrot for unimplemented
      local new_zx = zx2 - zy2 + cx
      local new_zy = 2 * zx * zy + cy
      zx, zy = new_zx, new_zy
    end
    
    iterations = iterations + 1
  end
  
  return max_iter -- Interior point
end

-- Compute orbit for audio (FMG-style)
function compute_orbit(cx, cy, fractal_id, max_iter)
  local orbit = {}
  local zx, zy = cx, cy  -- Z0 = C (FMG convention)
  
  table.insert(orbit, {zx = zx, zy = zy})
  
  for i = 1, max_iter do
    local zx2 = zx * zx
    local zy2 = zy * zy
    
    -- Bailout test
    if zx2 + zy2 >= 4.0 then
      break
    end
    
    -- Apply same iteration as above (could refactor)
    if fractal_id == 0 then -- Mandelbrot
      local new_zx = zx2 - zy2 + cx
      local new_zy = 2 * zx * zy + cy
      zx, zy = new_zx, new_zy
    elseif fractal_id == 1 then -- Burning Ship
      local new_zx = zx2 - zy2 + cx
      local new_zy = math.abs(2 * zx * zy) + cy
      zx, zy = new_zx, new_zy
    elseif fractal_id == 2 then -- Tricorn
      local new_zx = zx2 - zy2 + cx
      local new_zy = -2 * zx * zy + cy
      zx, zy = new_zx, new_zy
    else -- Default Mandelbrot
      local new_zx = zx2 - zy2 + cx
      local new_zy = 2 * zx * zy + cy
      zx, zy = new_zx, new_zy
    end
    
    table.insert(orbit, {zx = zx, zy = zy})
  end
  
  return orbit
end

-- Convert screen coordinates to complex plane
function screen_to_complex(screen_x, screen_y)
  local aspect = SCREEN_W / SCREEN_H
  local scale = 4.0 / zoom -- Base scale covers roughly -2 to +2
  
  local cx = center_x + (screen_x - SCREEN_W/2) * scale / SCREEN_W * aspect
  local cy = center_y + (screen_y - SCREEN_H/2) * scale / SCREEN_H
  
  return cx, cy
end

-- Convert complex plane to screen coordinates  
function complex_to_screen(cx, cy)
  local aspect = SCREEN_W / SCREEN_H
  local scale = 4.0 / zoom
  
  local screen_x = (cx - center_x) * SCREEN_W / (scale * aspect) + SCREEN_W/2
  local screen_y = (cy - center_y) * SCREEN_H / scale + SCREEN_H/2
  
  return math.floor(screen_x + 0.5), math.floor(screen_y + 0.5)
end

-- Render fractal incrementally in background
function render_fractal()
  print("RENDER_FRACTAL called, render_needed=" .. tostring(render_needed))
  if not render_needed then 
    print("RENDER_FRACTAL: early exit, not needed")
    return 
  end
  
  -- Increment generation to invalidate any pending renders
  render_generation = render_generation + 1
  local current_generation = render_generation
  print("RENDER_FRACTAL: generation=" .. current_generation)
  
  -- Stop any existing render timer
  if render_timer then
    print("RENDER_FRACTAL: stopping existing timer")
    render_timer:stop()
    render_timer = nil
  end
  
  -- Mark as not needed to prevent recursive calls
  render_needed = false
  
  -- Start background rendering
  render_in_progress = true
  render_row = 1
  print("RENDER_FRACTAL: starting background render")
  
  -- Try to start render timer for incremental updates
  render_timer = metro.init()
  
  -- Check if metro allocation succeeded
  if render_timer == nil then
    print("ERROR: render metro.init() failed - fallback to immediate render")
    -- Fallback: render everything immediately (blocking but safe)
    print("IMMEDIATE RENDER: starting full render")
    for y = 1, SCREEN_H do
      for x = 1, SCREEN_W do
        local cx, cy = screen_to_complex(x-1, y-1)
        local iterations = iterate_fractal(cx, cy, fractals[fractal_index].id, max_iterations)
        if iterations >= max_iterations then
          pixel_buffer[y][x] = 0
        else
          pixel_buffer[y][x] = math.min(15, math.floor(iterations * 15 / max_iterations) + 1)
        end
      end
      -- Update screen every 8 rows to prevent queue overflow
      if y % 8 == 0 then
        screen_dirty = true
      end
    end
    render_in_progress = false
    screen_dirty = true -- Final screen update
    print("IMMEDIATE RENDER: completed")
    
    -- Resume movement cycle if it was in progress
    if movement_in_progress then
      movement_in_progress = false
      print("MOVEMENT: render complete, checking for more movement")
      start_movement_cycle()
    end
    
    return
  end
  
  render_timer.time = 1/60 -- 60fps for smooth incremental rendering
  render_timer.event = function()
    render_incremental(current_generation)
  end
  render_timer:start()
end

-- Render a few rows at a time to prevent blocking
function render_incremental(generation)
  -- Check if this render has been superseded
  if generation ~= render_generation then
    print("RENDER_INCREMENTAL: generation mismatch, aborting " .. generation .. " vs " .. render_generation)
    if render_timer then
      render_timer:stop()
      render_timer = nil
    end
    return
  end
  
  if not render_in_progress then
    print("RENDER_INCREMENTAL: not in progress, stopping")
    if render_timer then
      render_timer:stop()
      render_timer = nil
    end
    return
  end
  
  print("RENDER_INCREMENTAL: rendering rows " .. render_row .. " to " .. math.min(render_row + pixels_per_frame - 1, SCREEN_H))
  
  -- Render a chunk of rows
  local end_row = math.min(render_row + pixels_per_frame - 1, SCREEN_H)
  
  for y = render_row, end_row do
    -- Double-check generation before expensive computation
    if generation ~= render_generation then
      print("RENDER_INCREMENTAL: generation changed mid-render, aborting")
      return
    end
    
    for x = 1, SCREEN_W do
      local cx, cy = screen_to_complex(x-1, y-1) -- Convert to 0-based
      local iterations = iterate_fractal(cx, cy, fractals[fractal_index].id, max_iterations)
      
      -- Simple grayscale mapping
      if iterations >= max_iterations then
        pixel_buffer[y][x] = 0 -- Interior = black
      else
        pixel_buffer[y][x] = math.min(15, math.floor(iterations * 15 / max_iterations) + 1)
      end
    end
  end
  
  -- Update screen as we go for progressive rendering
  screen_dirty = true
  
  -- Move to next chunk
  render_row = end_row + 1
  
  -- Check if complete
  if render_row > SCREEN_H then
    print("RENDER_INCREMENTAL: completed generation " .. generation)
    render_in_progress = false
    if render_timer then
      render_timer:stop()
      render_timer = nil
    end
    
    -- Resume movement cycle if it was in progress
    if movement_in_progress then
      movement_in_progress = false
      print("MOVEMENT: render complete, checking for more movement")
      start_movement_cycle()
    end
  end
end

-- Display HUD message
function show_hud(text, timeout)
  hud_text = text
  hud_timeout = timeout or 30 -- ~2 seconds at 15fps
  screen_dirty = true
end

-- Debounced render to prevent encoder queue buildup
function schedule_render()
  print("SCHEDULE_RENDER called [" .. VERSION .. "]")
  
  -- Stop any current rendering immediately
  render_generation = render_generation + 1
  print("RENDER_GENERATION incremented to: " .. render_generation)
  
  if render_in_progress then
    print("STOPPING current render in progress")
    render_in_progress = false
    if render_timer then
      render_timer:stop()
      render_timer = nil
    end
  end
  
  -- Cancel existing encoder timer
  if encoder_timer then
    print("STOPPING existing encoder timer")
    encoder_timer:stop()
    encoder_timer = nil
  end
  
  -- Try to create new timer for debouncing
  print("STARTING new encoder timer")
  encoder_timer = metro.init()
  
  -- Check if metro allocation succeeded
  if encoder_timer == nil then
    print("ERROR: metro.init() failed - rendering immediately without debounce")
    -- Immediate render without debouncing - no metro needed
    render_needed = true
    render_fractal()
    return
  end
  
  -- Metro available - use debounced approach
  pending_render = true
  encoder_timer.time = 0.05 -- 50ms delay
  encoder_timer.count = 1
  encoder_timer.event = function()
    print("ENCODER TIMER triggered")
    if pending_render then
      render_needed = true
      pending_render = false
      print("CALLING render_fractal()")
      render_fractal() -- Start background rendering
    end
  end
  encoder_timer:start()
end

-- Encoder boolean state tracking - digital not analog
function enc(n, delta)
  local current_time = util.time()
  
  -- Update boolean direction state based on delta (ignore magnitude)
  if delta > 0 then
    encoder_turning_cw[n] = true
    encoder_turning_ccw[n] = false
  else
    encoder_turning_cw[n] = false
    encoder_turning_ccw[n] = true
  end
  
  encoder_idle_time[n] = current_time
  
  -- Start movement processing if not already in progress
  if not movement_in_progress and not render_in_progress then
    start_movement_cycle()
  end
end

-- Process one movement cycle: move -> render -> wait -> check again
function start_movement_cycle()
  if movement_in_progress or render_in_progress then
    return  -- Already processing
  end
  
  movement_in_progress = true
  process_one_movement()
end

function process_one_movement()
  local current_time = util.time()
  local moved = false
  
  -- Check for encoder timeouts (consider stopped if no activity for timeout period)
  for i = 1, 3 do
    if current_time - encoder_idle_time[i] > encoder_timeout then
      encoder_turning_cw[i] = false
      encoder_turning_ccw[i] = false
    end
  end
  
  -- Check if any encoder is currently turning
  local any_encoder_active = false
  for i = 1, 3 do
    if encoder_turning_cw[i] or encoder_turning_ccw[i] then
      any_encoder_active = true
      break
    end
  end
  
  -- If no encoders active, stop movement cycle
  if not any_encoder_active then
    movement_in_progress = false
    print("MOVEMENT: stopped - no active encoders")
    return
  end
  
  -- Process encoder 1 (zoom or special modes)
  if fractal_select_mode and (encoder_turning_cw[1] or encoder_turning_ccw[1]) then
    local direction = encoder_turning_cw[1] and 1 or -1
    fractal_index = util.clamp(fractal_index + direction, 1, #fractals)
    render_needed = true
    print("FRACTAL CHANGE: " .. fractals[fractal_index].name)
    show_hud("FRACTAL: " .. fractals[fractal_index].name)
    moved = true
    
  elseif iteration_select_mode and (encoder_turning_cw[1] or encoder_turning_ccw[1]) then
    local direction = encoder_turning_cw[1] and 1 or -1
    local iteration_step = direction * 10
    max_iterations = util.clamp(max_iterations + iteration_step, 10, 500)
    render_needed = true
    print("ITERATION CHANGE: " .. max_iterations)
    show_hud("ITERATIONS: " .. max_iterations)
    moved = true
    
  elseif encoder_turning_cw[1] or encoder_turning_ccw[1] then
    -- Zoom - one increment per cycle
    local zoom_step = 1.02  -- 2% zoom step
    if encoder_turning_cw[1] then
      zoom = zoom * zoom_step
    else
      zoom = zoom / zoom_step
    end
    zoom = util.clamp(zoom, MIN_ZOOM, MAX_ZOOM)
    print("ZOOM: " .. zoom .. " (one increment)")
    show_hud(string.format("ZOOM: %.2fx", zoom))
    moved = true
  end
  
  -- Process encoder 2 (pan X)
  if encoder_turning_cw[2] or encoder_turning_ccw[2] then
    local direction = encoder_turning_cw[2] and 1 or -1
    local pixel_step = 1.0 / zoom  -- Exactly one pixel at current zoom
    center_x = center_x + (-direction) * pixel_step  -- Reversed direction
    center_x = util.clamp(center_x, -MAX_PAN_X, MAX_PAN_X)
    print("PAN X: " .. center_x .. " (one pixel)")
    show_hud(string.format("PAN X: %.3f", center_x))
    moved = true
  end
  
  -- Process encoder 3 (pan Y)
  if encoder_turning_cw[3] or encoder_turning_ccw[3] then
    local direction = encoder_turning_cw[3] and 1 or -1
    local pixel_step = 1.0 / zoom  -- Exactly one pixel at current zoom
    center_y = center_y + direction * pixel_step
    center_y = util.clamp(center_y, -MAX_PAN_Y, MAX_PAN_Y)
    print("PAN Y: " .. center_y .. " (one pixel)")
    show_hud(string.format("PAN Y: %.3f", center_y))
    moved = true
  end
  
  -- If we moved, start render and WAIT for completion
  if moved then
    print("MOVEMENT: moved, starting render and waiting...")
    schedule_render()
    screen_dirty = true
    -- movement_in_progress stays true - will be cleared when render completes
  else
    -- No movement needed, continue cycle
    movement_in_progress = false
    -- Check again after a short delay
    local continue_timer = metro.init()
    if continue_timer then
      continue_timer.time = 0.05  -- 50ms delay
      continue_timer.event = function()
        continue_timer:stop()
        start_movement_cycle()
      end
      continue_timer:start()
    end
  end
end

-- Key handling
function key(n, z)
  print("KEY: n=" .. n .. " z=" .. z .. " [" .. VERSION .. "]")
  
  if n == 1 then
    if z == 1 then
      fractal_select_mode = true
      iteration_select_mode = false
      print("KEY: entering fractal select mode")
      show_hud("SELECT FRACTAL (E1)")
    else
      fractal_select_mode = false
      print("KEY: exiting fractal select mode")
      show_hud("")
    end
    
  elseif n == 2 then
    if z == 1 then
      print("KEY: K2 pressed, fractal_mode=" .. tostring(fractal_select_mode))
      -- Check if not in other modes - toggle iteration mode
      if not fractal_select_mode then
        iteration_select_mode = not iteration_select_mode
        print("KEY: iteration_mode=" .. tostring(iteration_select_mode))
        if iteration_select_mode then
          show_hud("SET ITERATIONS (E1)")
        else
          -- Add orbit origin when exiting iteration mode
          print("KEY: adding orbit origin")
          local orbit = compute_orbit(center_x, center_y, fractals[fractal_index].id, max_iterations)
          table.insert(orbit_origins, {
            cx = center_x,
            cy = center_y, 
            fractal_id = fractals[fractal_index].id,
            orbit = orbit,
            label = string.format("%s_%d", fractals[fractal_index].short, #orbit_origins + 1)
          })
          show_hud(string.format("ADDED ORIGIN %d (%d pts)", #orbit_origins, #orbit))
        end
      end
    else
      print("KEY: K2 released")
      -- Key release - exit iteration mode but don't add origin on release
      if iteration_select_mode then
        iteration_select_mode = false
        print("KEY: exiting iteration mode on release")
        show_hud("")
      end
    end
    
  elseif n == 3 and z == 1 then
    print("KEY: K3 pressed - removing origin")
    -- Remove last origin
    if #orbit_origins > 0 then
      table.remove(orbit_origins)
      show_hud(string.format("REMOVED (now %d origins)", #orbit_origins))
    else
      show_hud("NO ORIGINS TO REMOVE")
    end
  end
end

-- Draw function
function redraw()
  screen.clear()
  
  -- Render fractal if needed
  render_fractal()
  
  -- Draw fractal
  for y = 1, SCREEN_H do
    for x = 1, SCREEN_W do
      local level = pixel_buffer[y][x]
      if level > 0 then
        screen.level(level)
        screen.pixel(x-1, y-1)
        screen.fill()
      end
    end
  end
  
  -- Draw orbit origins
  screen.level(15)
  for i, origin in ipairs(orbit_origins) do
    local sx, sy = complex_to_screen(origin.cx, origin.cy)
    if sx >= 0 and sx < SCREEN_W and sy >= 0 and sy < SCREEN_H then
      screen.circle(sx, sy, 2)
      screen.fill()
    end
  end
  
  -- Draw crosshair at center
  screen.level(8)
  local cx_screen, cy_screen = complex_to_screen(center_x, center_y)
  if cx_screen >= 0 and cx_screen < SCREEN_W and cy_screen >= 0 and cy_screen < SCREEN_H then
    screen.move(cx_screen - 3, cy_screen)
    screen.line(cx_screen + 3, cy_screen)
    screen.move(cx_screen, cy_screen - 3)
    screen.line(cx_screen, cy_screen + 3)
    screen.stroke()
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
  screen.text(string.format("%s | %.1fx | %d origins", 
    fractals[fractal_index].short, zoom, #orbit_origins))
  
  screen.update()
  screen_dirty = false
end

-- Cleanup
function cleanup()
  -- Stop movement cycle
  movement_in_progress = false
  
  -- Stop all timers
  if render_timer then
    render_timer:stop()
    render_timer = nil
  end
  
  if encoder_timer then
    encoder_timer:stop()
    encoder_timer = nil
  end
  
  -- Reset encoder states
  for i = 1, 3 do
    encoder_turning_cw[i] = false
    encoder_turning_ccw[i] = false
  end
  
  -- Future: stop audio engines, save state, etc.
end
