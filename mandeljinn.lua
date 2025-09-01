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
engine.name = 'PolyPerc'

-- Screen dimensions
local SCREEN_W = 128
local SCREEN_H = 64

-- Fractal definitions (complete FMG set)
local fractals = {
  {id = 0, name = "Mandelbrot", short = "MAND"},
  {id = 1, name = "Burning Ship", short = "BURN"},
  {id = 2, name = "Tricorn", short = "TRIC"},
  {id = 3, name = "Rectangle", short = "RECT"},
  {id = 4, name = "Klingon", short = "KLIN"},
  {id = 5, name = "Crown", short = "CRWN"},
  {id = 6, name = "Frog", short = "FROG"},
  {id = 7, name = "Mandelship", short = "SHIP"},
  {id = 8, name = "Frankenstein", short = "FRNK"},
  {id = 9, name = "Logistic", short = "LOGI"}
}

-- State variables
local fractal_index = 1
local center_x = -0.5
local center_y = 0.0
local zoom = 1.0
local max_iterations = 100

-- UI state
local screen_dirty = true
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

-- Encoder state tracking (paradigm implementation)
local encoder_accumulated = {0, 0, 0}  -- Accumulated deltas since last sampling
local last_encoder_sample_time = 0
local encoder_sample_rate = 0.1  -- Sample every 100ms (reduced from 200ms)
local system_busy = false  -- Block ALL input when true

-- Threshold accumulators for deliberate actions (anti-sensitivity)
local fractal_delta_accumulator = 0
local palette_delta_accumulator = 0
local DELIBERATE_THRESHOLD = 3  -- Require 3+ detents for fractal/palette changes

-- Key state for hold detection
local k1_press_time = 0
local k2_press_time = 0
local k3_press_time = 0
local k1_still_down = false
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

-- Musical Orbit Sequencer Parameters
local music_params = {
  -- Timing
  tempo = 120,                    -- BPM for orbit playback
  loop_length = 8,                -- Max orbit points before repeat
  
  -- Musical mapping
  scale_steps = 8,                -- Number of scale degrees across screen width
  octave_range = 5,               -- Number of octaves across screen height
  base_octave = 4,                -- Starting octave (C4 = 60)
  scale_type = "major",           -- Scale type for quantization
  
  -- Audio parameters
  note_length = 0.5,              -- Note duration as fraction of beat
  velocity_min = 20,              -- Minimum velocity
  velocity_max = 127,             -- Maximum velocity
  velocity_scale = 10,            -- Distance to velocity multiplier
  
  -- Visual
  progressive_draw = true,        -- Draw orbit points as they play
  wrap_display = true,            -- Wrap lines that go off-screen
  current_point = 0,              -- Currently playing point index
}

-- Musical scales for quantization
local scales = {
  major = {0, 2, 4, 5, 7, 9, 11, 12},
  minor = {0, 2, 3, 5, 7, 8, 10, 12},
  pentatonic = {0, 2, 4, 7, 9, 12, 14, 16},
  dorian = {0, 2, 3, 5, 7, 9, 10, 12},
  whole_tone = {0, 2, 4, 6, 8, 10, 12, 14},
}

-- Sequencer state
local sequence_timer = nil
local is_playing = false
local orbit_sequence = {}        -- Processed musical data for current orbit
local audio_engine_started = false

-- Pending orbit change system (to avoid interrupting current sequence)
local pending_orbit_change = false
local pending_center_x = 0
local pending_center_y = 0
local pending_zoom = 1
local pending_fractal_index = 1

-- 4x4 Bayer matrix for dithering
local bayer4 = {
  { 0,  8,  2, 10},
  {12,  4, 14,  6},
  { 3, 11,  1,  9},
  {15,  7, 13,  5},
}

-- Convert complex coordinates to screen coordinates for orbit display
function complex_to_screen(zx, zy)
  local aspect = SCREEN_W / SCREEN_H
  local range = 3.0 / zoom
  local screen_x = ((zx - center_x) / (range * aspect) + 0.5) * SCREEN_W
  local screen_y = ((zy - center_y) / range + 0.5) * SCREEN_H
  return screen_x, screen_y
end

-- Convert screen coordinates to musical parameters
function screen_to_music(screen_x, screen_y, prev_x, prev_y)
  local params = music_params
  
  -- Wrap coordinates to screen bounds for consistent mapping
  local x = ((screen_x % SCREEN_W) + SCREEN_W) % SCREEN_W
  local y = ((screen_y % SCREEN_H) + SCREEN_H) % SCREEN_H
  
  -- Map X to scale degree (quantized to musical scale)
  local scale = scales[params.scale_type] or scales.major
  local scale_position = (x / SCREEN_W) * (#scale - 1)
  local scale_index = math.floor(scale_position) + 1
  local scale_degree = scale[util.clamp(scale_index, 1, #scale)]
  
  -- Map Y to octave
  local octave_offset = math.floor((1 - y / SCREEN_H) * params.octave_range)
  local midi_note = (params.base_octave + octave_offset) * 12 + scale_degree
  
  -- Stereo pan from X position
  local pan = (x / SCREEN_W) * 2 - 1  -- -1 (left) to 1 (right)
  
  -- Velocity from distance to previous point
  local velocity = params.velocity_min
  if prev_x and prev_y then
    local distance = math.sqrt((screen_x - prev_x)^2 + (screen_y - prev_y)^2)
    velocity = util.clamp(
      params.velocity_min + distance * params.velocity_scale, 
      params.velocity_min, 
      params.velocity_max
    )
  end
  
  return {
    note = util.clamp(midi_note, 0, 127),
    pan = pan,
    velocity = velocity,
    screen_x = x,
    screen_y = y
  }
end

-- Convert orbit points to musical sequence
function process_orbit_to_music(orbit_points)
  local sequence = {}
  local prev_screen_x, prev_screen_y
  
  for i, point in ipairs(orbit_points) do
    local screen_x, screen_y = complex_to_screen(point[1], point[2])
    local music_data = screen_to_music(screen_x, screen_y, prev_screen_x, prev_screen_y)
    
    music_data.point_index = i
    music_data.complex_x = point[1]
    music_data.complex_y = point[2]
    
    table.insert(sequence, music_data)
    prev_screen_x, prev_screen_y = screen_x, screen_y
  end
  
  return sequence
end

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

-- Fractal iteration (complete FMG set)
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
    elseif fractal_id == 3 then -- Rectangle
      -- Zn * (|Z|^2) - (Zn * C^2)
      local zmag2 = zx2 + zy2
      local c2x = cx * cx - cy * cy
      local c2y = 2 * cx * cy
      local nzx = zx * zmag2 - (zx * c2x - zy * c2y)
      local nzy = zy * zmag2 - (zx * c2y + zy * c2x)
      zx, zy = nzx, nzy
    elseif fractal_id == 4 then -- Klingon
      -- zx' = |zx^3| - 3*zy^2*|zx| + cx; zy' = 3*zx^2*|zy| - |zy^3| + cy
      local zx3 = zx * zx * zx
      local zy3 = zy * zy * zy
      local nzx = math.abs(zx3) - 3 * zy2 * math.abs(zx) + cx
      local nzy = 3 * zx2 * math.abs(zy) - math.abs(zy3) + cy
      zx, zy = nzx, nzy
    elseif fractal_id == 5 then -- Crown
      -- zx' = zx^3 - 3*zx*zy^2 + cx; zy' = |3*zx^2*zy - zy^3| + cy
      local zx3 = zx * zx * zx
      local zy3 = zy * zy * zy
      local nzx = zx3 - 3 * zx * zy2 + cx
      local nzy = math.abs(3 * zx2 * zy - zy3) + cy
      zx, zy = nzx, nzy
    elseif fractal_id == 6 then -- Frog
      -- zx' = |zx^3 - 3*zx*zy^2| + cx; zy' = |3*zx^2*zy - zy^3| + cy
      local zx3 = zx * zx * zx
      local zy3 = zy * zy * zy
      local nzx = math.abs(zx3 - 3 * zx * zy2) + cx
      local nzy = math.abs(3 * zx2 * zy - zy3) + cy
      zx, zy = nzx, nzy
    elseif fractal_id == 7 then -- Mandelship (simplified quartic approximation)
      -- Higher-order polynomial mix with quartic & cross terms
      local zx4 = zx2 * zx2
      local zy4 = zy2 * zy2
      local nzx = zx4 - 6 * zx2 * zy2 + zy4 + cx
      local nzy = 4 * zx * zy * (zx2 - zy2) + cy
      zx, zy = nzx, nzy
    elseif fractal_id == 8 then -- Frankenstein
      -- zx' = tanh(zx^3 - 3*zx*zy^2) + cx; zy' = |3*zx^2*zy - zy^3| + cy
      local zx3 = zx * zx * zx
      local zy3 = zy * zy * zy
      local nzx = math.tanh(zx3 - 3 * zx * zy2) + cx
      local nzy = math.abs(3 * zx2 * zy - zy3) + cy
      zx, zy = nzx, nzy
    elseif fractal_id == 9 then -- Logistic
      -- zx' = -cx*zx^2 + cx*zx + 2*cy*zx*zy + cx*zy^2 - cy*zy
      -- zy' = cx*zy + cy*zx - cy*zx^2 + cy*zy^2 - 2*cx*zx*zy
      local nzx = -cx * zx2 + cx * zx + 2 * cy * zx * zy + cx * zy2 - cy * zy
      local nzy = cx * zy + cy * zx - cy * zx2 + cy * zy2 - 2 * cx * zx * zy
      zx, zy = nzx, nzy
    else -- Default to Mandelbrot
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

-- Show HUD message (no timeout - stays until next parameter change)
function show_hud(text)
  print("DEBUG: show_hud() called with text: '" .. text .. "'")
  hud_text = text
  screen_dirty = true
end

-- Sequence management functions
function add_current_state_to_sequence()
  print("DEBUG: add_current_state_to_sequence() called")
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
  print("DEBUG: Added state to sequence, total count: " .. #sequence_list)
  return #sequence_list
end

function delete_last_sequence_entry()
  print("DEBUG: delete_last_sequence_entry() called, current count: " .. #sequence_list)
  if #sequence_list > 0 then
    table.remove(sequence_list, #sequence_list)
    print("DEBUG: Deleted from sequence, new count: " .. #sequence_list)
    return true
  end
  print("DEBUG: Sequence was empty, nothing to delete")
  return false
end

-- Apply pending orbit changes when current sequence completes
function apply_pending_orbit_change()
  if pending_orbit_change then
    print("Applying pending orbit change...")
    center_x = pending_center_x
    center_y = pending_center_y
    zoom = pending_zoom
    fractal_index = pending_fractal_index
    
    -- Reset pending flag
    pending_orbit_change = false
    
    -- Trigger render and new orbit calculation
    render_needed = true
    calculate_and_send_orbit(center_x, center_y)
    
    print("Pending orbit change applied")
  end
end

-- Store orbit changes as pending when sequencer is playing
function set_pending_orbit_change()
  pending_center_x = center_x
  pending_center_y = center_y
  pending_zoom = zoom
  pending_fractal_index = fractal_index
  pending_orbit_change = true
  print("Orbit change stored as pending - will apply when sequence completes")
end

-- Calculate orbit for a specific point and send to engine
function calculate_and_send_orbit(cx, cy)
  print("Calculating orbit for point: cx=" .. cx .. ", cy=" .. cy)
  
  -- Store the point we're calculating orbit for
  orbit_cx = cx
  orbit_cy = cy
  
  -- Clear previous orbit points
  orbit_points = {}
  
  local zx, zy = cx, cy  -- FMG Convention: Z0 = C (not Z0 = 0!)
  
  -- Store Z0 (initial point)
  table.insert(orbit_points, {zx, zy})
  
  -- Send initial Z0 to engine
  if engine and engine.updateOrbit then
    engine.updateOrbit(zx, zy)
    print("Sent Z0 to engine: zx=" .. zx .. ", zy=" .. zy)
  else
    print("Engine updateOrbit not available")
  end
  
  -- Calculate orbit using the current fractal
  local fractal_id = fractals[fractal_index].id
  
  -- Calculate a few iterations and send the orbit progression
  for i = 1, 16 do  -- Increased from 8 to get more orbit points for wave generation
    -- Use fractal iteration (same formulas as image iteration)
    local temp_zx, temp_zy
    
    if fractal_id == 0 then -- Mandelbrot
      temp_zx = zx * zx - zy * zy + cx
      temp_zy = 2 * zx * zy + cy
    elseif fractal_id == 1 then -- Burning Ship
      temp_zx = zx * zx - zy * zy + cx
      temp_zy = math.abs(2 * zx * zy) + cy
    elseif fractal_id == 2 then -- Tricorn
      temp_zx = zx * zx - zy * zy + cx
      temp_zy = -2 * zx * zy + cy
    else
      -- Use same iteration as image for other fractals
      local iter_result = iterate_fractal(cx, cy, fractal_id, i)
      if iter_result >= i then
        -- Still iterating, use Mandelbrot as fallback
        temp_zx = zx * zx - zy * zy + cx
        temp_zy = 2 * zx * zy + cy
      else
        break -- Escaped
      end
    end
    
    zx, zy = temp_zx, temp_zy
    
    -- Store orbit point
    table.insert(orbit_points, {zx, zy})
    
    print("Orbit iteration " .. i .. ": zx=" .. string.format("%.4f", zx) .. ", zy=" .. string.format("%.4f", zy))
    
    -- Send current orbit point to engine (legacy compatibility)
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
  
  -- Convert orbit to musical sequence
  print("Converting orbit to musical sequence...")
  orbit_sequence = process_orbit_to_music(orbit_points)
  print("Generated musical sequence with " .. #orbit_sequence .. " notes")
  
  -- Start the musical sequencer
  start_orbit_sequencer()
  
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
  -- Only start if not already started
  if not audio_engine_started then
    if engine and engine.startAudio then
      engine.startAudio()
      audio_engine_started = true
      print("Audio engine started")
      show_hud("AUDIO ENGINE ON")
    else
      print("Engine startAudio not available")
    end
  end
end

function stop_audio()
  stop_orbit_sequencer()  -- Stop sequencer
  
  if audio_engine_started then
    if engine and engine.stopAudio then
      engine.stopAudio()
      audio_engine_started = false
      print("Audio engine stopped")
      show_hud("AUDIO ENGINE OFF")
    else
      print("Engine stopAudio not available")
    end
  end
end

-- Start musical orbit sequencer
function start_orbit_sequencer()
  stop_orbit_sequencer()  -- Stop any existing sequencer
  
  if #orbit_sequence == 0 then
    print("No orbit sequence to play")
    return
  end
  
  print("Starting orbit sequencer with " .. #orbit_sequence .. " points")
  music_params.current_point = 0
  is_playing = true
  
  -- Try to create metro timer with error handling
  if sequence_timer == nil then
    sequence_timer = metro.init()
    if sequence_timer == nil then
      print("ERROR: Could not create metro timer - metro pool exhausted")
      is_playing = false
      return
    end
  end
  
  sequence_timer.time = 60 / music_params.tempo  -- Beat duration in seconds
  sequence_timer.event = function()
    play_next_orbit_point()
  end
  
  if sequence_timer.start then
    sequence_timer:start()
    show_hud("SEQUENCER: " .. music_params.tempo .. " BPM")
  else
    print("ERROR: Metro timer invalid")
    sequence_timer = nil
    is_playing = false
  end
end

-- Stop musical orbit sequencer
function stop_orbit_sequencer()
  if sequence_timer and sequence_timer.stop then
    sequence_timer:stop()
    -- Don't set to nil here - reuse the timer
  end
  is_playing = false
  music_params.current_point = 0
  
  -- Send all notes off
  if engine and engine.allNotesOff then
    engine.allNotesOff()
  end
  
  print("Orbit sequencer stopped")
end

-- Play next point in orbit sequence
function play_next_orbit_point()
  if #orbit_sequence == 0 then return end
  
  music_params.current_point = music_params.current_point + 1
  
  -- Loop back if we've reached the end or loop length
  if music_params.current_point > #orbit_sequence or 
     music_params.current_point > music_params.loop_length then
    music_params.current_point = 1
    
    -- Check for pending orbit changes when loop completes
    if pending_orbit_change then
      print("Sequence loop completed - applying pending orbit change")
      apply_pending_orbit_change()
      return  -- Exit here as apply_pending_orbit_change will generate new sequence
    end
  end
  
  local point = orbit_sequence[music_params.current_point]
  if point then
    -- Convert MIDI note to frequency
    local hz = 440 * math.pow(2, (point.note - 69) / 12)
    
    -- Trigger note using PolyPerc engine
    if engine and engine.hz then
      engine.hz(hz)
      engine.amp(point.velocity / 127.0)
      engine.pan(point.pan)
      engine.release(music_params.note_length)
      print("Playing note: " .. point.note .. " hz:" .. string.format("%.1f", hz) .. " vel:" .. point.velocity .. " pan:" .. string.format("%.2f", point.pan))
    else
      print("Engine hz method not available")
    end
    
    -- Update visual
    screen_dirty = true
  end
end

-- Draw orbit with progressive playback visualization
function draw_orbit_with_playback()
  if #orbit_points == 0 then return end
  
  screen.level(15)  -- Bright white for orbit
  screen.line_width(1)
  
  -- Draw all orbit lines (with wrapping support)
  for i = 1, #orbit_points - 1 do
    local zx1, zy1 = orbit_points[i][1], orbit_points[i][2]
    local zx2, zy2 = orbit_points[i+1][1], orbit_points[i+1][2]
    
    local sx1, sy1 = complex_to_screen(zx1, zy1)
    local sx2, sy2 = complex_to_screen(zx2, zy2)
    
    -- Draw line with wrapping
    draw_wrapped_line(sx1, sy1, sx2, sy2)
  end
  
  -- Highlight currently playing point
  if is_playing and music_params.current_point > 0 and 
     music_params.current_point <= #orbit_points then
    local current_orbit_point = orbit_points[music_params.current_point]
    local zx, zy = current_orbit_point[1], current_orbit_point[2]
    local sx, sy = complex_to_screen(zx, zy)
    
    -- Wrap screen coordinates
    sx = ((sx % SCREEN_W) + SCREEN_W) % SCREEN_W
    sy = ((sy % SCREEN_H) + SCREEN_H) % SCREEN_H
    
    -- Draw highlighted current point
    screen.level(8)  -- Dimmer for highlight background
    screen.circle(sx, sy, 4)
    screen.fill()
    screen.level(15)  -- Bright for center
    screen.circle(sx, sy, 2)
    screen.fill()
  end
  
  -- Draw starting point (Z0)
  if #orbit_points > 0 then
    local zx0, zy0 = orbit_points[1][1], orbit_points[1][2]
    local sx0, sy0 = complex_to_screen(zx0, zy0)
    sx0 = ((sx0 % SCREEN_W) + SCREEN_W) % SCREEN_W
    sy0 = ((sy0 % SCREEN_H) + SCREEN_H) % SCREEN_H
    
    screen.level(10)
    screen.circle(sx0, sy0, 3)
    screen.stroke()
  end
end

-- Draw line with screen wrapping
function draw_wrapped_line(x1, y1, x2, y2)
  -- Simple approach: draw the line even if it goes off screen
  -- The screen clipping will handle it naturally
  screen.move(x1, y1)
  screen.line(x2, y2)
  screen.stroke()
end

-- Sample and process encoder states (called by controlled timer)
function sample_and_process_encoders()
  -- Don't process if system is busy
  if system_busy then
    return
  end
  
  local now = util.time()
  
  -- Only sample at controlled intervals
  if (now - last_encoder_sample_time) < encoder_sample_rate then
    return
  end
  
  last_encoder_sample_time = now
  
  -- Check if any encoders have accumulated deltas
  local e1_delta = encoder_accumulated[1]
  local e2_delta = encoder_accumulated[2] 
  local e3_delta = encoder_accumulated[3]
  
  -- Reset accumulated values immediately (anti-queueing)
  encoder_accumulated[1] = 0
  encoder_accumulated[2] = 0
  encoder_accumulated[3] = 0
  
  -- If no input, nothing to do
  if e1_delta == 0 and e2_delta == 0 and e3_delta == 0 then
    return
  end
  
  -- Set system busy to block all further input
  system_busy = true
  
  print("Processing encoder input: E1=" .. e1_delta .. " E2=" .. e2_delta .. " E3=" .. e3_delta)
  
  -- Check hold modifiers
  local k1_held = k1_still_down and (now - k1_press_time) > HOLD_THRESHOLD
  local k2_held = k2_still_down and (now - k2_press_time) > HOLD_THRESHOLD
  local k3_held = k3_still_down and (now - k3_press_time) > HOLD_THRESHOLD
  
  -- SINGLE ACTION: Process only the encoder with the largest delta
  local max_delta = 0
  local active_encoder = 0
  
  if math.abs(e1_delta) > max_delta then
    max_delta = math.abs(e1_delta)
    active_encoder = 1
  end
  if math.abs(e2_delta) > max_delta then
    max_delta = math.abs(e2_delta)
    active_encoder = 2
  end
  if math.abs(e3_delta) > max_delta then
    max_delta = math.abs(e3_delta)
    active_encoder = 3
  end
  
  if active_encoder == 0 then
    system_busy = false
    return
  end
  
  local delta = 0
  if active_encoder == 1 then delta = e1_delta
  elseif active_encoder == 2 then delta = e2_delta  
  elseif active_encoder == 3 then delta = e3_delta
  end
  
  local dir = (delta > 0) and 1 or -1
  
  -- Process the single action
  local action_taken = false
  
  if k1_held then
    if active_encoder == 1 then
      -- K1 Hold + E1: Scale type selection (DELIBERATE - requires threshold)
      palette_delta_accumulator = palette_delta_accumulator + delta  -- Reuse accumulator
      
      if math.abs(palette_delta_accumulator) >= DELIBERATE_THRESHOLD then
        -- Cycle through scale types
        local scale_names = {"major", "minor", "pentatonic", "dorian", "whole_tone"}
        local current_index = 1
        for i, name in ipairs(scale_names) do
          if name == music_params.scale_type then
            current_index = i
            break
          end
        end
        
        local next_index = (current_index % #scale_names) + 1
        music_params.scale_type = scale_names[next_index]
        
        show_hud("SCALE: " .. music_params.scale_type:upper())
        action_taken = true
        palette_delta_accumulator = 0  -- Reset after action
        
        -- Regenerate musical sequence if we have orbit points
        if #orbit_points > 0 then
          orbit_sequence = process_orbit_to_music(orbit_points)
        end
      end
    end
  elseif k2_held then
    if active_encoder == 1 then
      -- K2 Hold + E1: Fractal selection (DELIBERATE - requires threshold)
      fractal_delta_accumulator = fractal_delta_accumulator + delta
      
      if math.abs(fractal_delta_accumulator) >= DELIBERATE_THRESHOLD then
        local dir = (fractal_delta_accumulator > 0) and 1 or -1
        fractal_index = fractal_index + dir
        if fractal_index < 1 then fractal_index = #fractals end
        if fractal_index > #fractals then fractal_index = 1 end
        show_hud("FRACTAL: " .. fractals[fractal_index].name)
        render_needed = true
        action_taken = true
        fractal_delta_accumulator = 0  -- Reset after action
      end
    elseif active_encoder == 2 then
      -- K2 Hold + E2: Loop length control (RESPONSIVE - immediate)
      local new_loop_length = music_params.loop_length + dir
      new_loop_length = util.clamp(new_loop_length, 1, 64)
      if new_loop_length ~= music_params.loop_length then
        music_params.loop_length = new_loop_length
        show_hud("LOOP LENGTH: " .. music_params.loop_length)
        action_taken = true
      end
    elseif active_encoder == 3 then
      -- K2 Hold + E3: Iteration selection (RESPONSIVE - immediate)
      local new_iterations = max_iterations + dir
      new_iterations = util.clamp(new_iterations, 8, 2000)
      if new_iterations ~= max_iterations then
        max_iterations = new_iterations
        show_hud("ITERATIONS: " .. max_iterations)
        render_needed = true
        action_taken = true
      end
    end
  elseif k3_held then
    if active_encoder == 1 then
      -- K3 Hold + E1: Tempo control (RESPONSIVE - immediate)
      music_params.tempo = util.clamp(music_params.tempo + dir * 5, 20, 300)
      show_hud("TEMPO: " .. music_params.tempo .. " BPM")
      
      -- Update running sequencer tempo
      if sequence_timer then
        sequence_timer.time = 60 / music_params.tempo
      end
      action_taken = true
    elseif active_encoder == 2 then
      -- K3 Hold + E2: Loop length control (RESPONSIVE - immediate)
      music_params.loop_length = util.clamp(music_params.loop_length + dir, 1, 64)
      show_hud("LOOP LENGTH: " .. music_params.loop_length)
      action_taken = true
    elseif active_encoder == 3 then
      -- K3 Hold + E3: Palette cycling (DELIBERATE - requires threshold)
      palette_delta_accumulator = palette_delta_accumulator + delta
      
      if math.abs(palette_delta_accumulator) >= DELIBERATE_THRESHOLD then
        local dir = (palette_delta_accumulator > 0) and 1 or -1
        palette_index = (palette_index + dir - 1) % #palettes + 1
        if palette_index < 1 then palette_index = #palettes end
        show_hud("PALETTE: " .. palettes[palette_index].name)
        render_needed = true
        action_taken = true
        palette_delta_accumulator = 0  -- Reset after action
      end
    end
  else
    -- Base navigation
    if active_encoder == 1 then
      -- Zoom
      local scale = 4.0 / zoom
      local pixel_scale = scale / SCREEN_W
      scale = scale - dir * (pixel_scale * 4)
      zoom = util.clamp(4.0 / scale, 0.1, 1e12)
      show_hud(string.format("ZOOM: %.2fx", zoom))
      render_needed = true
      action_taken = true
    elseif active_encoder == 2 then
      -- Pan X
      local aspect = SCREEN_W / SCREEN_H
      local scale = 4.0 / zoom
      local pixel_step_x = scale / SCREEN_W * aspect
      center_x = util.clamp(center_x - dir * pixel_step_x, -3.5, 3.5)
      show_hud(string.format("PAN X: %.3f", center_x))
      render_needed = true
      action_taken = true
    elseif active_encoder == 3 then
      -- Pan Y
      local scale = 4.0 / zoom
      local pixel_step_y = scale / SCREEN_H
      center_y = util.clamp(center_y + dir * pixel_step_y, -2.8, 2.8)
      show_hud(string.format("PAN Y: %.3f", center_y))
      render_needed = true
      action_taken = true
    end
  end
  
  -- BLOCKING EXECUTION: Complete entire pipeline before accepting new input
  if action_taken and render_needed then
    print("Executing complete blocking pipeline...")
    
    -- Complete render
    start_render_if_needed()
    while render_in_progress do
      step_render()
    end
    
    -- Check if sequencer is playing - if so, store changes as pending
    if is_playing then
      print("Sequencer is playing - storing orbit change as pending")
      set_pending_orbit_change()
    else
      -- Calculate orbit and update audio immediately if not playing
      calculate_and_send_orbit(center_x, center_y)
    end
    
    -- Update display
    redraw()
    
    print("Pipeline complete - system ready")
  end
  
  -- Clear system busy flag
  system_busy = false
end

-- Main init function
function init()
  print("Mandeljinn starting...")
  
  init_buffer()
  render_needed = true
  
  -- Complete initial render (pipeline: render until done)
  start_render_if_needed()
  while render_in_progress do
    step_render()
  end
  
  -- Calculate initial orbit and start musical sequencer
  print("Testing orbit calculation...")
  calculate_and_send_orbit(center_x, center_y)
  
  print("Testing musical sequencer...")
  start_audio()
  
  print("Starting controlled encoder sampling...")
  
  -- Start the controlled sampling timer
  local sampling_timer = metro.init()
  sampling_timer.time = 1/15  -- 15 FPS sampling rate (reduced from 60)
  sampling_timer.event = function()
    sample_and_process_encoders()
    
    -- Continue any pending render (when not busy)
    if not system_busy then
      start_render_if_needed()
      step_render()
    end
    
    -- Check for hold state changes and force redraw when they occur
    local now = util.time()
    local k2_held_now = k2_still_down and (now - k2_press_time) > HOLD_THRESHOLD
    local k3_held_now = k3_still_down and (now - k3_press_time) > HOLD_THRESHOLD
    
    -- Initialize previous states if not set
    if k2_held_prev == nil then k2_held_prev = false end
    if k3_held_prev == nil then k3_held_prev = false end
    
    -- If hold state changed, force screen update
    if k2_held_now ~= k2_held_prev or k3_held_now ~= k3_held_prev then
      print("DEBUG: Hold state changed - K2_held: " .. tostring(k2_held_prev) .. " -> " .. tostring(k2_held_now) .. ", K3_held: " .. tostring(k3_held_prev) .. " -> " .. tostring(k3_held_now))
      screen_dirty = true
      k2_held_prev = k2_held_now
      k3_held_prev = k3_held_now
    end
    
    if screen_dirty and not system_busy then
      redraw()
      screen_dirty = false
    end
  end
  sampling_timer:start()
  
  print("Mandeljinn ready")
end

-- Encoder state accumulator (PARADIGM: not event-driven!)
function enc(n, delta)
  if delta == 0 then return end
  
  -- Only accumulate deltas - NO processing here
  encoder_accumulated[n] = encoder_accumulated[n] + delta
  
  -- The main_loop will sample these accumulated values at controlled moments
end

-- Key handler
function key(n, z)
  local now = util.time()
  
  -- Debug: Track all key events
  print("KEY EVENT: K" .. n .. " " .. (z == 1 and "PRESS" or "RELEASE") .. " at time " .. string.format("%.3f", now))
  
  if z == 1 then  -- Key press
    if n == 1 then
      print("DEBUG: K1 pressed - setting down state")
      k1_press_time = now
      k1_still_down = true
    elseif n == 2 then
      print("DEBUG: K2 pressed - setting down state")
      k2_press_time = now
      k2_still_down = true
    elseif n == 3 then
      print("DEBUG: K3 pressed - setting down state")
      k3_press_time = now
      k3_still_down = true
    end
  else  -- Key release
    if n == 1 then
      print("DEBUG: K1 released")
      k1_still_down = false
      local hold_duration = now - k1_press_time
      print("DEBUG: K1 hold duration: " .. string.format("%.3f", hold_duration) .. "s (threshold: " .. HOLD_THRESHOLD .. "s)")
      
      if hold_duration < HOLD_THRESHOLD then
        -- K1 short press: Toggle to norns menu (original spec)
        print("DEBUG: K1 short press - opening norns menu")
        norns.menu.init()
      end
      -- Long press handled by encoder logic when K1 held
    elseif n == 2 then
      print("DEBUG: K2 released")
      k2_still_down = false
      local hold_duration = now - k2_press_time
      print("DEBUG: K2 hold duration: " .. string.format("%.3f", hold_duration) .. "s (threshold: " .. HOLD_THRESHOLD .. "s)")
      
      -- Check if K3 is held (K2 becomes RST when K3 held)
      if k3_still_down and hold_duration >= HOLD_THRESHOLD then
        -- Reset view to origin
        print("DEBUG: K2+K3 reset triggered")
        center_x = -0.5
        center_y = 0.0
        zoom = 1.0
        show_hud("VIEW RESET")
        render_needed = true
      elseif hold_duration < HOLD_THRESHOLD then
        -- K2 short press: Add current state to saved sequence list
        print("DEBUG: K2 short press - adding current state to sequence list")
        local count = add_current_state_to_sequence()
        show_hud("ADDED TO SEQUENCE (" .. count .. ")")
      end
      
    elseif n == 3 then
      print("DEBUG: K3 released")
      k3_still_down = false
      local hold_duration = now - k3_press_time
      print("DEBUG: K3 hold duration: " .. string.format("%.3f", hold_duration) .. "s (threshold: " .. HOLD_THRESHOLD .. "s)")
      
      -- Check if K2 is held (K3 becomes RST when K2 held)
      if k2_still_down and hold_duration >= HOLD_THRESHOLD then
        -- Reset view to origin
        print("DEBUG: K3+K2 reset triggered")
        center_x = -0.5
        center_y = 0.0
        zoom = 1.0
        show_hud("VIEW RESET")
        render_needed = true
      elseif hold_duration < HOLD_THRESHOLD then
        -- K3 short press: Delete from sequence
        print("DEBUG: K3 short press - deleting from sequence")
        if delete_last_sequence_entry() then
          show_hud("DELETED FROM SEQUENCE (" .. #sequence_list .. ")")
        else
          show_hud("SEQUENCE EMPTY")
        end
      end
    end
  end
  
  print("DEBUG: Calling redraw()")
  redraw()
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
  
  -- Draw orbit visualization with musical playback
  if show_orbit and #orbit_points > 0 then
    draw_orbit_with_playback()
  end
  
  -- Draw context-aware HUD
  draw_context_hud()
  
  screen.update()
  screen_dirty = false
end

-- Draw context-aware HUD with spatial mapping
function draw_context_hud()
  local now = util.time()
  
  -- Helper function to draw text with dark grey background
  local function draw_text_with_bg(x, y, text, text_level)
    -- Calculate text dimensions (rough estimate)
    local text_width = #text * 4  -- Approximate width
    local text_height = 6
    
    -- Draw dark grey background rectangle
    screen.level(2)  -- Dark grey background
    screen.rect(x-1, y-text_height, text_width+2, text_height+2)
    screen.fill()
    
    -- Draw text
    screen.level(text_level or 10)
    screen.move(x, y)
    screen.text(text)
  end
  
  -- Check hold states
  local k1_held = k1_still_down and (now - k1_press_time) > HOLD_THRESHOLD
  local k2_held = k2_still_down and (now - k2_press_time) > HOLD_THRESHOLD
  local k3_held = k3_still_down and (now - k3_press_time) > HOLD_THRESHOLD
  
  -- Debug: Track HUD state
  if k2_still_down or k3_still_down then
    local k2_time = k2_still_down and (now - k2_press_time) or 0
    local k3_time = k3_still_down and (now - k3_press_time) or 0
    print("DEBUG HUD: K2_down=" .. tostring(k2_still_down) .. " (" .. string.format("%.3f", k2_time) .. "s) K3_down=" .. tostring(k3_still_down) .. " (" .. string.format("%.3f", k3_time) .. "s)")
    print("DEBUG HUD: K2_held=" .. tostring(k2_held) .. " K3_held=" .. tostring(k3_held))
  end
  
  print("DEBUG HUD: Current hud_text = '" .. hud_text .. "'")
  
  -- Top Left: Show HUD text if available, otherwise show coordinates
  if hud_text ~= "" then
    draw_text_with_bg(2, 8, hud_text, 8)
    print("DEBUG HUD: Displaying hud_text: '" .. hud_text .. "'")
  else
    draw_text_with_bg(2, 8, string.format("X:%.3f Y:%.3f", center_x, center_y), 8)
    print("DEBUG HUD: Displaying coordinates")
  end
  
  if k1_held then
    -- K1 Hold State: --- --- | SH1 SCAL | --- ---
    draw_text_with_bg(90, 8, "SH1 SCAL", 10)
    
  elseif k2_held then
    -- K2 Hold State: SH1 RST | --- FRAC | LOOP ITER
    draw_text_with_bg(2, 64, "SH1 RST", 12)
    draw_text_with_bg(90, 8, "--- FRAC", 10)
    draw_text_with_bg(90, 64, "LOOP ITER", 10)
    
  elseif k3_held then
    -- K3 Hold State: RST SH3 | MNU TMPO | --- PAL
    draw_text_with_bg(2, 64, "RST SH3", 12)
    draw_text_with_bg(90, 8, "MNU TMPO", 10)
    draw_text_with_bg(90, 64, "--- PAL", 10)
    
  else
    -- Normal State: ADD DEL | MNU ZOOM | PNH PNV
    draw_text_with_bg(2, 64, "ADD DEL", 10)
    draw_text_with_bg(90, 8, "MNU ZOOM", 10)
    draw_text_with_bg(90, 64, "PNH PNV", 10)
  end
end

function cleanup()
  -- Cleanup code here
end
