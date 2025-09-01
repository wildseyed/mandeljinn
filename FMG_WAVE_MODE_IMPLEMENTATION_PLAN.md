# FMG Wave Mode Implementation Plan
## Bringing Mandeljinn Audio to FMG Fidelity

**Goal**: Implement authentic FMG Wave Mode behavior in Mandeljinn, excluding MIDI functionality.

---

## **Current State Analysis**

### ❌ **Critical Issues in Our Implementation**
1. **Wrong Orbit Starting Point**: We use Z0 = 0 (canonical) instead of FMG's Z0 = C convention
2. **Missing Interpolation**: We send discrete orbit points instead of interpolated smooth trajectories  
3. **No Sine Mode**: We only have Direct Mode (zx→L, zy→R)
4. **Incorrect Parameter Scaling**: Not using FMG's exact scaling ranges and formula
5. **Missing Wave Synthesis Features**: No fade-in/out, duration control, orbit repetition
6. **Single Point Updates**: Sending individual coordinates instead of complete wave buffers

### ✅ **What's Working**
- Complete 10-fractal set with correct iteration formulas
- SuperCollider engine integration
- Direct Mode concept (zx→Left amp, zy→Right amp)
- Orbit calculation and storage
- UI integration with fractal navigation

---

## **Phase 1: Fix Orbit Generation (Z0 = C Convention)**

### **1.1 Update OrbitCalculator Function**
**File**: `mandeljinn.lua`
**Function**: `calculate_and_send_orbit(cx, cy)`

**Current Code**:
```lua
local zx, zy = 0, 0  -- Start with Z0 = 0
```

**Required Change**:
```lua
local zx, zy = cx, cy  -- FMG Convention: Z0 = C
```

**Impact**: This fundamentally changes the orbit shape and musical character to match FMG.

### **1.2 Update All Fractal Iteration Functions**
**File**: `mandeljinn.lua`
**Function**: `iterate_fractal(cx, cy, fractal_id, max_iter)`

**Current Code**:
```lua
local zx, zy = cx, cy
```

**Required Change**: 
```lua
local zx, zy = cx, cy  -- Already correct for FMG orbit starting point
```

**Note**: The iteration function is already using Z0 = C, but we need to verify this matches OrbitCalculator behavior exactly.

---

## **Phase 2: Implement FMG Wave Synthesis Parameters**

### **2.1 Add FMG Wave Parameters**
**File**: `mandeljinn.lua`
**Location**: Add after existing state variables

```lua
-- FMG Wave Mode Parameters (from mandelbrot.xml)
local wave_params = {
  -- Duration and timing
  duration_seconds = 5,           -- durationWaveSlider
  interpolation_points = 43,      -- interpolationPointsSpinner  
  keep_orbit_samples = 7,         -- keepOrbitSpinner
  sample_rate = 44100,            -- Fixed
  
  -- Volume and scaling
  volume = 6144,                  -- volumeWaveSlider (max 32767)
  
  -- Direct Mode scaling windows (from mandelbrot preset)
  direct_zx_min = -2.0,           -- minZxDirectSpinner
  direct_zx_max = 1.0,            -- maxZxDirectSpinner  
  direct_zy_min = -1.25,          -- minZyDirectSpinner
  direct_zy_max = 1.25,           -- maxZyDirectSpinner
  
  -- Sine Mode scaling windows  
  sine_zy_min = -1.25,            -- minZySineSpinner
  sine_zy_max = 1.25,             -- maxZySineSpinner
  freq_min = 25,                  -- minFreqSpinner
  freq_max = 4000,                -- maxFreqSpinner
  
  -- Mode selection
  direct_mode = true,             -- directRadioButton
  sine_mode = false,              -- sineRadioButton
  
  -- Advanced
  skip_divergent = true,          -- skipDivergentWaveCheckBox
  fade_frames = 1024,             -- Fixed fade-in/out length
}
```

### **2.2 Implement FMG Scaling Function**
**File**: `mandeljinn.lua`
**Location**: Add new function

```lua
-- FMG's exact scaling function (from Utilities.java)
function fmg_scale(value_in, base_min, base_max, limit_min, limit_max)
  return ((limit_max - limit_min) * (value_in - base_min) / (base_max - base_min)) + limit_min
end
```

**Note**: This is FMG's exact linear scaling with NO clamping.

---

## **Phase 3: Implement Wave Buffer Generation**

### **3.1 Create FMG Wave Generator Function**
**File**: `mandeljinn.lua`
**Location**: Add new function

```lua
-- Generate FMG-style wave buffer from orbit
function generate_wave_buffer(orbit_array, params)
  local sample_rate = params.sample_rate
  local duration = params.duration_seconds  
  local interpolation_points = params.interpolation_points
  local keep_orbit_samples = params.keep_orbit_samples
  local volume = params.volume
  
  -- Calculate buffer parameters
  local loops = math.floor((sample_rate * duration) / interpolation_points)
  local buffer_size = loops * interpolation_points
  local stereo_buffer = {}  -- {L, R, L, R, ...}
  
  local orbit_index = 0
  local frame_counter = 0
  
  -- Get initial orbit point
  if #orbit_array == 0 then return {} end
  local zx = orbit_array[1][1]
  local zy = orbit_array[1][2]
  
  for i = 0, loops - 1 do
    -- Advance orbit index based on keep_orbit_samples
    if i % keep_orbit_samples == 0 then
      orbit_index = orbit_index + 1
    end
    
    -- Handle orbit wraparound (FMG behavior)
    if orbit_index >= #orbit_array then
      orbit_index = 0
      print("Wave duration exceeds orbit length: repeating orbit")
    end
    
    -- Get next orbit point for interpolation
    local zx_next, zy_next
    if orbit_index + 1 < #orbit_array then
      zx_next = orbit_array[orbit_index + 2][1]  -- +2 because lua is 1-indexed
      zy_next = orbit_array[orbit_index + 2][2]
    else
      zx_next = orbit_array[1][1]  -- Wrap to beginning
      zy_next = orbit_array[1][2]
    end
    
    -- Calculate interpolation steps
    local zx_step = (zx_next - zx) / interpolation_points
    local zy_step = (zy_next - zy) / interpolation_points
    
    -- Generate interpolated samples
    for j = 0, interpolation_points - 1 do
      local zx_play = zx + (zx_step * j)
      local zy_play = zy + (zy_step * j)
      
      local sample_l, sample_r
      
      if params.direct_mode then
        -- Direct Mode: zx→Left, zy→Right
        sample_l = fmg_scale(zx_play, params.direct_zx_min, params.direct_zx_max, -volume, volume)
        sample_r = fmg_scale(zy_play, params.direct_zy_min, params.direct_zy_max, -volume, volume)
        
      elseif params.sine_mode then
        -- Sine Mode: zy→frequency, zx→pan
        local frequency = fmg_scale(zy_play, params.sine_zy_min, params.sine_zy_max, params.freq_min, params.freq_max)
        local pan = fmg_scale(zx_play, -2.0, 2.0, 0, 1)  -- Pan range 0-1
        
        -- Generate sine wave sample
        local phase = 2 * math.pi * frequency * frame_counter / sample_rate
        local sine_sample = math.sin(phase) * volume
        
        sample_l = sine_sample * (1 - pan)
        sample_r = sine_sample * pan
      end
      
      -- Apply fade-in/fade-out (FMG behavior)
      local fade_in = 1.0
      local fade_out = 1.0
      
      if frame_counter < params.fade_frames then
        fade_in = frame_counter / params.fade_frames
      end
      
      if frame_counter > (buffer_size - params.fade_frames) then
        fade_out = (buffer_size - frame_counter) / params.fade_frames
      end
      
      sample_l = sample_l * fade_in * fade_out
      sample_r = sample_r * fade_in * fade_out
      
      -- Store stereo samples
      table.insert(stereo_buffer, sample_l)
      table.insert(stereo_buffer, sample_r)
      
      frame_counter = frame_counter + 1
    end
    
    -- Update for next loop
    zx = zx_next
    zy = zy_next
  end
  
  return stereo_buffer
end
```

---

## **Phase 4: Update SuperCollider Engine**

### **4.1 Engine Requirements**
**File**: `Engine_Mandeljinn.sc`

**Required Capabilities**:
1. **Buffer Playback**: Accept complete stereo audio buffers
2. **Multiple Modes**: Support both Direct and Sine mode parameter streaming
3. **Smooth Transitions**: Handle buffer crossfades when orbit changes
4. **Real-time Updates**: Accept new buffers without audio dropouts

**Current Issues**: Our engine only accepts single coordinate pairs, not audio buffers.

### **4.2 Engine API Design**
```lua
-- Required engine methods:
engine.setWaveMode(mode)           -- "direct" or "sine"  
engine.setWaveParams(params)       -- Duration, volume, scaling windows
engine.playWaveBuffer(buffer)      -- Stereo audio buffer
engine.stopWave()                  -- Stop current playback
```

---

## **Phase 5: Integration with UI**

### **5.1 Add Wave Mode Toggle**
**Controls Needed**:
- Direct/Sine mode toggle (K2 + E2 when in hold state)
- Wave parameter adjustment (duration, volume, scaling)
- Real-time parameter updates without stopping audio

### **5.2 Update HUD Display**
**Show Current Wave Status**:
- Wave mode (Direct/Sine)
- Duration and orbit length
- Current volume level
- Scaling window parameters

---

## **Phase 6: Audio Pipeline Restructure**

### **6.1 Update calculate_and_send_orbit Function**
**File**: `mandeljinn.lua`

**Current Process**:
1. Calculate orbit points
2. Send individual coordinates to engine

**New FMG Process**:
1. Calculate complete orbit (Z0 = C)
2. Generate wave buffer from orbit
3. Send complete buffer to engine
4. Store orbit for visual display

### **6.2 Handle Divergent Orbits**
**FMG Behavior**: 
- If `skip_divergent = true` → abort wave generation
- If `skip_divergent = false` → use partial orbit

---

## **Implementation Priority Order**

### **Phase 1: Critical Fixes (Week 1)**
1. ✅ Fix Z0 = C orbit starting point
2. ✅ Implement FMG scaling function
3. ✅ Add wave parameter structure

### **Phase 2: Wave Generation (Week 2)**  
4. ✅ Implement wave buffer generation
5. ✅ Add interpolation between orbit points
6. ✅ Implement fade-in/fade-out

### **Phase 3: Engine Integration (Week 2)**
7. ✅ Update SuperCollider engine for buffer playback
8. ✅ Add Sine mode support
9. ✅ Integrate with orbit calculation pipeline

### **Phase 4: Polish (Week 3)**
10. ✅ Add UI controls for wave parameters
11. ✅ Update HUD for wave status
12. ✅ Test with all 10 fractals
13. ✅ Verify FMG preset parameter accuracy

---

## **Testing Strategy**

### **Validation Checkpoints**:
1. **Orbit Accuracy**: Compare orbit sequences with FMG using same (cx,cy) points
2. **Audio Character**: A/B test Direct mode output with FMG recordings  
3. **Parameter Fidelity**: Verify scaling ranges match Mandelbrot preset exactly
4. **Sine Mode**: Test frequency mapping and stereo panning
5. **Performance**: Ensure real-time operation on norns hardware

### **Reference Points**:
- Use FMG Mandelbrot preset as baseline
- Test specific coordinates: (-0.5, 0.0), (-0.74529, 0.11307), etc.
- Validate orbit length and divergence behavior
- Compare audio spectral content

---

## **Expected Outcomes**

After implementation, Mandeljinn Wave mode should:
- ✅ Sound authentically like FMG Direct/Sine modes
- ✅ Use identical orbit mathematics (Z0 = C)
- ✅ Generate smooth interpolated audio trajectories  
- ✅ Support both Direct and Sine synthesis modes
- ✅ Handle orbit repetition and divergence correctly
- ✅ Provide real-time parameter control
- ✅ Maintain norns performance characteristics

This will give us **100% FMG Wave Mode fidelity** while remaining practical for norns hardware constraints.
