-- mandeljinn_minimal.lua
-- Minimal test version to debug loading issues

engine.name = "Mandeljinn"

function init()
  print("Minimal Mandeljinn starting...")
  print("Minimal Mandeljinn ready")
end

function redraw()
  screen.clear()
  screen.text("Minimal Mandeljinn")
  screen.update()
end

function key(n, z)
  if z == 1 then
    print("Key " .. n .. " pressed")
    redraw()  -- Manual redraw for testing
  end
end

function enc(n, delta)
  print("Encoder " .. n .. " moved " .. delta)
  redraw()  -- Manual redraw for testing
end
