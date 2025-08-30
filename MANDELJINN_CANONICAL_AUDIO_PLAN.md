# Mandeljinn Canonical Audio Implementation Plan
## Stay True to FMG's Fractal-Nature Audio Generation

**Date:** August 30, 2025  
**Goal:** Implement FMG's canonical Direct and Sine audio modes only  
**Philosophy:** Audio IS the fractal - direct sonification without non-canonical synthesis

---

## 🎯 CANONICAL FIDELITY REQUIREMENTS

### Core Principle: Fractal-Native Audio
FMG's audio generation is **fractal in nature**, not conventional synthesis:
- **Direct Mode**: Raw fractal orbit coordinates become stereo audio field
- **Sine Mode**: Fractal coordinates directly control frequency and spatial position  
- **No Timbre Bank**: FMG uses external MIDI for instrument variety
- **Z0=C Convention**: Orbit starts at C (not Z0=0) for authentic FMG orbit shapes

### Confirmed Canonical Features Only
1. **Direct Mode**: zx→L amplitude, zy→R amplitude
2. **Sine Mode**: zy→frequency, zx→pan  
3. **Linear Scaling**: FMG's precise scaling function (no clamping)
4. **Orbit Interpolation**: Smooth parameter transitions between points
5. **Z0=C Start**: All fractals start orbit iteration at complex point C

### Explicitly NON-Canonical (Will NOT Implement)
- ❌ Internal timbre bank (FMG uses external MIDI Program Change)
- ❌ MIDI output (deferred - external gear not available)  
- ❌ Drums synthesis (FMG uses MIDI channel 10)
- ❌ Volume controls (norns has system volume)

---

## 🔧 SUPERCOLLIDER ENGINE SPECIFICATION

### Engine_Mandeljinn.sc Structure
```supercollider
// Two SynthDefs only - pure FMG canonical modes

SynthDef(\mandeljinn_direct, { |out, ampL=0, ampR=0, glide=0.01|
    var sig = [Lag.kr(ampL, glide), Lag.kr(ampR, glide)];
    Out.ar(out, sig);
});

SynthDef(\mandeljinn_sine, { |out, freq=220, pan=0, amp=0.5, glide=0.01|
    var sig = SinOsc.ar(Lag.kr(freq, glide), 0, amp);
    Out.ar(out, Pan2.ar(sig, Lag.kr(pan, glide)));
});
```

### Engine Commands (Minimal Interface)
```lua
-- Mode switching
engine.mode(0)  -- 0=direct, 1=sine

-- Direct Mode parameters  
engine.ampL(value)  -- -1 to 1
engine.ampR(value)  -- -1 to 1

-- Sine Mode parameters
engine.freq(value)  -- Hz (scaled from zy)
engine.pan(value)   -- -1 to 1 (scaled from zx)
engine.amp(value)   -- Global amplitude

-- Global parameters
engine.glide(value) -- Smoothing time (0.001 to 0.1)
```

---

## 🧮 ORBIT CALCULATION (CANONICAL FMG)

### Z0=C Starting Convention
```lua
-- FMG starts orbit at Z0 = C (not classic Z0 = 0)
function calculate_orbit(cx, cy, fractal_id, max_iter)
    local orbit = {}
    local zx, zy = cx, cy  -- Start at C, not at origin
    
    for i = 1, max_iter do
        orbit[i] = {zx = zx, zy = zy}
        
        -- Apply fractal iteration formula
        local new_zx, new_zy = iterate_fractal(zx, zy, cx, cy, fractal_id)
        
        -- Check divergence (|Z|^2 >= 4)
        if (new_zx * new_zx + new_zy * new_zy) >= 4 then
            break  -- Orbit diverged
        end
        
        zx, zy = new_zx, new_zy
    end
    
    return orbit
end
```

### Fractal Iteration Functions (Canonical)
```lua
function iterate_mandelbrot(zx, zy, cx, cy)
    return zx*zx - zy*zy + cx, 2*zx*zy + cy
end

function iterate_burning_ship(zx, zy, cx, cy)  
    return zx*zx - zy*zy + cx, math.abs(2*zx*zy) + cy
end

function iterate_tricorn(zx, zy, cx, cy)
    return zx*zx - zy*zy + cx, -2*zx*zy + cy
end
```

---

## 🎵 AUDIO PARAMETER MAPPING

### Direct Mode Implementation
```lua
function update_direct_mode(orbit_point, params)
    -- Linear scaling exactly as FMG
    local ampL = scale(orbit_point.zx, 
                      params.direct.zx_min, params.direct.zx_max, 
                      -1, 1)
    local ampR = scale(orbit_point.zy,
                      params.direct.zy_min, params.direct.zy_max,
                      -1, 1)
    
    engine.ampL(ampL)
    engine.ampR(ampR)
end
```

### Sine Mode Implementation  
```lua
function update_sine_mode(orbit_point, params)
    -- zy controls frequency
    local freq = scale(orbit_point.zy,
                      params.sine.zy_min, params.sine.zy_max,
                      params.sine.freq_min, params.sine.freq_max)
    
    -- zx controls pan
    local pan = scale(orbit_point.zx,
                     params.sine.zx_min, params.sine.zx_max,
                     -1, 1)
    
    engine.freq(freq)
    engine.pan(pan)
end
```

### FMG's Linear Scale Function (Exact)
```lua
function scale(value, in_min, in_max, out_min, out_max)
    -- FMG's scaling: no clamping (out-of-range handled elsewhere)
    return ((out_max - out_min) * (value - in_min) / (in_max - in_min)) + out_min
end
```

---

## 📊 CANONICAL PARAMETER DEFAULTS

### Mandelbrot Defaults (From FMG Preset)
```lua
mandelbrot_defaults = {
    mode = "direct",
    max_audio_iter = 100,
    direct = {
        zx_min = -2.0, zx_max = 1.0,
        zy_min = -1.25, zy_max = 1.25
    },
    sine = {
        zy_min = -1.25, zy_max = 1.25,
        freq_min = 25, freq_max = 4000,
        zx_min = -2.0, zx_max = 1.0
    }
}
```

### Tricorn Defaults (From FMG Preset)
```lua
tricorn_defaults = {
    mode = "sine", 
    max_audio_iter = 100,
    direct = {
        zx_min = -1.25, zx_max = 1.25,
        zy_min = -1.25, zy_max = 1.25
    },
    sine = {
        zy_min = 0.0, zy_max = 1.5,  -- Emphasizes positive imaginary
        freq_min = 25, freq_max = 4000,
        zx_min = -2.0, zx_max = 2.0
    }
}
```

---

## ⏱️ ORBIT PLAYBACK SCHEDULER

### Tempo-Controlled Parameter Updates
```lua
function start_orbit_playback(orbit, mode, params, tempo_bpm)
    local step_duration = 60 / tempo_bpm / 4  -- FMG uses 4 ticks per step
    local current_step = 1
    
    playback_clock = clock.run(function()
        while current_step <= #orbit do
            if mode == "direct" then
                update_direct_mode(orbit[current_step], params)
            else
                update_sine_mode(orbit[current_step], params)
            end
            
            clock.sleep(step_duration)
            current_step = current_step + 1
        end
    end)
end
```

### Visual Orbit Sync
```lua
function draw_orbit_progress(orbit, current_step)
    -- Draw progressive orbit path as audio plays
    screen.level(8)
    for i = 1, current_step do
        local px, py = complex_to_screen(orbit[i].zx, orbit[i].zy)
        screen.pixel(px, py)
    end
    
    -- Highlight current point
    if current_step <= #orbit then
        local px, py = complex_to_screen(orbit[current_step].zx, orbit[current_step].zy)
        screen.level(15)
        screen.circle(px, py, 2)
        screen.fill()
    end
end
```

---

## 🎛️ CONTROL INTEGRATION

### Audio Mode Selection
```lua
-- Add to existing control scheme
function switch_audio_mode()
    if audio_mode == "direct" then
        audio_mode = "sine"
        engine.mode(1)
        show_hud("SINE MODE: zy→freq, zx→pan")
    else
        audio_mode = "direct" 
        engine.mode(0)
        show_hud("DIRECT MODE: zx→L, zy→R")
    end
end

-- Bind to existing control (e.g., K2 hold + E2)
-- In enc() function:
if k2_held and n == 2 then
    switch_audio_mode()
    return
end
```

### Audio Parameter Controls
```lua
-- K3 hold + E1: Audio glide/smoothing
if k3_held and n == 1 then
    audio_glide = math.max(0.001, math.min(0.1, audio_glide + dir * 0.005))
    engine.glide(audio_glide)
    show_hud(string.format("GLIDE: %.3fs", audio_glide))
    return
end

-- K3 hold + E2: Master amplitude (Sine mode only)
if k3_held and n == 2 and audio_mode == "sine" then
    master_amp = math.max(0, math.min(1, master_amp + dir * 0.05))
    engine.amp(master_amp)
    show_hud(string.format("AMPLITUDE: %.2f", master_amp))
    return
end
```

---

## 🔄 IMPLEMENTATION PHASES

### Phase 1: Core Engine (Week 1)
- [x] Engine_Mandeljinn.sc with Direct/Sine SynthDefs
- [ ] Lua engine wrapper and parameter registration
- [ ] Basic orbit calculation with Z0=C convention
- [ ] Linear scaling function (exact FMG implementation)
- [ ] Mode switching between Direct and Sine

### Phase 2: Audio Playback (Week 2) 
- [ ] Tempo-controlled orbit parameter streaming
- [ ] Visual orbit progress synchronization
- [ ] Fractal-specific default parameter loading
- [ ] Audio glide/smoothing controls
- [ ] Performance optimization for 1020 iterations

### Phase 3: Integration (Week 3)
- [ ] Integrate with existing control scheme  
- [ ] Sequence playback with audio generation
- [ ] Audio mode selection controls
- [ ] Parameter adjustment controls (glide, amplitude)
- [ ] HUD feedback for audio parameters

### Phase 4: Optimization (Week 4)
- [ ] CPU profiling on Raspberry Pi 3
- [ ] Optimize for 1020-iteration orbits
- [ ] Smooth parameter interpolation
- [ ] Memory usage optimization
- [ ] Final performance validation

---

## 📈 PERFORMANCE TARGETS

### Raspberry Pi 3 Constraints
- **CPU Budget**: <15% for audio engine + orbit calculation
- **Memory**: <10MB for orbit storage and audio buffers  
- **Latency**: <5ms parameter update response time
- **Iterations**: Support up to 1020 iterations if CPU allows

### Scaling Strategy
```lua
-- Adaptive iteration limits based on performance
function adaptive_max_iterations()
    local base_limit = 100
    local cpu_usage = get_cpu_usage()
    
    if cpu_usage < 0.3 then
        return math.min(1020, base_limit * 4)  -- Try higher
    elseif cpu_usage > 0.7 then  
        return math.max(50, base_limit / 2)    -- Scale back
    else
        return base_limit                       -- Stay safe
    end
end
```

---

## ✅ SUCCESS CRITERIA

### Canonical Fidelity
- ✅ Direct mode produces identical audio to FMG
- ✅ Sine mode produces identical audio to FMG  
- ✅ Z0=C orbit starting convention implemented
- ✅ Linear parameter scaling matches FMG exactly
- ✅ No non-canonical synthesis features

### Performance  
- ✅ Stable operation at 100 iterations on RPi3
- ✅ Smooth parameter transitions (no audio artifacts)
- ✅ Real-time visual-audio synchronization
- ✅ Responsive control interface

### Integration
- ✅ Works with existing fractal navigation
- ✅ Integrates with sequence management
- ✅ Maintains established control paradigm
- ✅ Clear audio mode feedback in HUD

**Ready to begin Phase 1 implementation.**
