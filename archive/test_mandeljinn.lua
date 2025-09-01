-- Minimal test version of mandeljinn
-- Mandeljinn debug version
local MANDELJINN_VERSION = "2025-08-30-debug-3-minimal"

local VERSION = "v0.3-dev-20250830-minimal"

local util = require 'util'
local tab = require 'tabutil'

-- Screen dimensions
local SCREEN_W = 128
local SCREEN_H = 64

-- Basic variables
local fractal_index = 1
local zoom = 1.0
local center_x = 0
local center_y = 0
local screen_dirty = false
local hud_text = ""
local hud_timeout = 0

-- Fractal types
local fractals = {
  {id = 1, name = "Mandelbrot", short = "MAND"},
  {id = 2, name = "Burning Ship", short = "SHIP"}
}

function init()
  print("MANDELJINN_VERSION: " .. MANDELJINN_VERSION)
  print("=== MANDELJINN " .. VERSION .. " STARTING ===")
  print("Init: Minimal test version loaded successfully")
end

function redraw()
  screen.clear()
  
  -- Draw simple crosshair
  screen.level(8)
  local cx_screen = SCREEN_W / 2
  local cy_screen = SCREEN_H / 2
  screen.move(cx_screen - 3, cy_screen)
  screen.line(cx_screen + 3, cy_screen)
  screen.move(cx_screen, cy_screen - 3)
  screen.line(cx_screen, cy_screen + 3)
  screen.stroke()
  
  -- Status line
  screen.level(4)
  screen.move(2, SCREEN_H - 2)
  screen.text("MINIMAL TEST")
  
  screen.update()
  screen_dirty = false
end

function enc(n, d)
  print("Encoder " .. n .. " delta: " .. d)
end

function key(n, z)
  print("Key " .. n .. " state: " .. z)
end

function cleanup()
  print("Cleanup called")
end
