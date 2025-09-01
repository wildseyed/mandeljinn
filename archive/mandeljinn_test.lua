-- mandeljinn_test.lua
-- Absolute minimal test

engine.name = "Mandeljinn"

function init()
  print("Test init start")
  print("Test init end")
end

function redraw()
  -- Empty redraw for now
end

function key(n, z)
  print("Key " .. n .. " " .. z)
end

function enc(n, delta)
  print("Enc " .. n .. " " .. delta)
end
