# Execution Plan: Specification Violation Repairs
## Implementation Strategy Using Established Encoder Paradigm

**Date:** August 30, 2025  
**Goal:** Fix specification violations while maintaining proven encoder event handling  
**Paradigm:** Direction-based encoders, immediate action, no accumulation, mode-aware dispatch

---

## 🎯 ESTABLISHED ENCODER PARADIGM ANALYSIS

### Current Working Pattern
```lua
-- Proven encoder dispatch pattern:
function enc(n, delta)
  local dir = (delta > 0) and 1 or -1
  
  -- Rate limiting (50ms)
  if (now - encoder_last_time[n]) < 0.05 then return end
  
  -- Mode-specific immediate actions (no accumulation)
  if mode_active and n == target_encoder then
    -- Immediate parameter change
    -- Clear state, return early
    return
  end
  
  -- Base navigation (accumulates for smooth movement)
  if not in_any_mode then
    encoder_dir[n] = dir  -- Only base nav accumulates
  end
end
```

### Key Principles to Preserve
1. **Rate limiting prevents event spam**
2. **Mode-specific actions are immediate** (no accumulation)
3. **Base navigation accumulates** for smooth pan/zoom
4. **Mode transitions clear encoder state**
5. **Selection modes block base navigation**

---

## 🔧 VIOLATION REPAIR PLAN

### Phase 1: Core Key Function Restoration

#### 1.1 Remove Unauthorized K3 Reset
**Current Violation:**
```lua
-- K3 alone: Reset view [UNAUTHORIZED]
center_x = -0.5; center_y = 0.0; zoom = 1.0
```
**Action:** Remove entirely, implement sequence delete

#### 1.2 Restore K1 Menu Toggle Function  
**Original Spec:** "Toggle between NORNS SELECT/SYSTEM/SLEEP Menu Screen and Patch Canvas"
**Implementation Strategy:**
```lua
-- K1 standalone press/release
if n == 1 and z == 1 then
  -- Navigate to norns menu (pause playback)
  norns.menu.init()  -- or appropriate norns menu call
end
```
**Impact:** Removes K1 as hold modifier - need new modifier strategy

#### 1.3 Restore K2 Sequence Add Function
**Original Spec:** "Add current Orbit Origin Point and its Parameters to Play Sequence List"  
**Implementation Strategy:**
```lua
-- K2 standalone press/release
if n == 2 and z == 1 then
  add_current_state_to_sequence()
  show_hud("ADDED TO SEQUENCE (" .. #sequence_list .. ")")
end
```

#### 1.4 Implement K3 Sequence Delete Function
**Original Spec:** "Delete most recently added Origin Point Entry from Play Sequence List"
**Implementation Strategy:**
```lua  
-- K3 standalone press/release
if n == 3 and z == 1 then
  if #sequence_list > 0 then
    table.remove(sequence_list, #sequence_list)
    show_hud("DELETED FROM SEQUENCE (" .. #sequence_list .. ")")
  else
    show_hud("SEQUENCE EMPTY")
  end
end
```

### Phase 2: Modifier Strategy Redesign

#### Problem: K1 No Longer Available as Modifier
**Current Dependencies:**
- K1+K2: Iteration selection mode
- K1+K3: Palette cycling  
- K1+E1: Fractal selection (from original spec)

**Solution Options:**

##### Option A: Hold-Based Modifiers (Recommended)
Use K2/K3 long-press as modifiers:
```lua
local k2_hold_time = 0
local k3_hold_time = 0
local HOLD_THRESHOLD = 0.5  -- 500ms

-- In key function:
if n == 2 then
  if z == 1 then  
    k2_press_time = util.time()
  else -- z == 0 (release)
    local hold_duration = util.time() - k2_press_time
    if hold_duration < HOLD_THRESHOLD then
      -- Short press: Add to sequence
      add_current_state_to_sequence()
    end
    -- Long press modifier actions handled in enc()
  end
end
```

##### Option B: Double-Tap Modifiers
```lua
-- Track double-tap state
local last_k2_time = 0
local DOUBLE_TAP_WINDOW = 0.3

if n == 2 and z == 1 then
  local now = util.time()
  if (now - last_k2_time) < DOUBLE_TAP_WINDOW then
    -- Double-tap: Enter modifier mode
    k2_modifier_mode = true
    show_hud("K2 MODIFIER MODE")
  else
    -- Single tap: Add to sequence (delayed to detect double-tap)
    clock.run(function()
      clock.sleep(DOUBLE_TAP_WINDOW)
      if not k2_modifier_mode then
        add_current_state_to_sequence()
      end
    end)
  end
  last_k2_time = now
end
```

#### Recommended: Option A (Hold-Based)
- More intuitive than double-tap
- Maintains immediate feedback
- Preserves encoder paradigm

### Phase 3: Required K+E Combinations Implementation

#### 3.1 K1+E1: Fractal Selection (Original Spec)
**Challenge:** K1 now menu toggle, need new approach
**Solution:** Use K2 long-hold + E1
```lua
-- In enc() function:
local k2_held = (util.time() - k2_press_time) > HOLD_THRESHOLD and k2_still_down

if k2_held and n == 1 then
  -- Immediate fractal cycling
  fractal_index = fractal_index + dir
  if fractal_index < 1 then fractal_index = #fractals end
  if fractal_index > #fractals then fractal_index = 1 end
  show_hud("FRACTAL: " .. fractals[fractal_index].name)
  render_needed = true
  return  -- Immediate action, no accumulation
end
```

#### 3.2 K2+E1: Tempo Control (Missing from Current)
**Original Spec:** "Increase/Decrease (CW/CCW) Orbit Position Note Execution Tempo"
**Implementation:** Use K3 long-hold + E1
```lua
if k3_held and n == 1 then
  -- Immediate tempo adjustment
  global_tempo = math.max(20, math.min(300, global_tempo + dir * 5))
  show_hud("TEMPO: " .. global_tempo .. " BPM")
  return
end
```

#### 3.3 K2+E2: Loop Length Control (Missing from Current)  
**Original Spec:** "Increase/Decrease (CW/CCW) Number of Orbit Positions to Play in Loop"
**Implementation:** Use K3 long-hold + E2
```lua
if k3_held and n == 2 then
  -- Immediate loop length adjustment
  loop_length = math.max(1, math.min(32, loop_length + dir))
  show_hud("LOOP LENGTH: " .. loop_length)
  return
end
```

#### 3.4 Iteration Control (User's "Familiar" Operation)
**Need Clarification:** What was the familiar method?
**Proposed:** K2 long-hold + E3 (immediate iteration cycling)
```lua
if k2_held and n == 3 then
  -- Immediate iteration count cycling
  local iter_options = {50, 100, 200, 500, 1000, 2000}
  local current_idx = find_iteration_index(max_iterations)
  current_idx = current_idx + dir
  if current_idx < 1 then current_idx = #iter_options end
  if current_idx > #iter_options then current_idx = 1 end
  max_iterations = iter_options[current_idx]
  show_hud("ITERATIONS: " .. max_iterations)
  render_needed = true
  return
end
```

### Phase 4: Palette System Integration

#### 4.1 Palette Control Method
**Current:** K1+K3 (no longer available)
**Proposed:** K3 long-hold + E3
```lua
if k3_held and n == 3 then
  -- Immediate palette cycling  
  palette_index = (palette_index % #palettes) + 1
  show_hud("PALETTE: " .. palettes[palette_index].name)
  render_needed = true
  return
end
```

---

## 📊 NEW CONTROL MAPPING SUMMARY

### Single Key Operations
```
K1: Toggle to norns menu (pause playback)
K2: Add current state to sequence list  
K3: Delete last entry from sequence list
```

### Hold + Encoder Operations  
```
K2 Hold + E1: Fractal selection (immediate)
K2 Hold + E2: [Reserved for future] 
K2 Hold + E3: Iteration count selection (immediate)

K3 Hold + E1: Tempo control (immediate)
K3 Hold + E2: Loop length control (immediate)  
K3 Hold + E3: Palette cycling (immediate)
```

### Base Navigation (No Modifiers)
```
E1: Zoom (accumulates for smooth movement)
E2: Pan X (accumulates for smooth movement)  
E3: Pan Y (accumulates for smooth movement)
```

---

## 🔄 IMPLEMENTATION SEQUENCE

### Step 1: Data Structures
```lua
-- Sequence management
local sequence_list = {}
local global_tempo = 120
local loop_length = 4

-- Hold state tracking
local k2_press_time = 0
local k3_press_time = 0  
local k2_still_down = false
local k3_still_down = false
local HOLD_THRESHOLD = 0.5
```

### Step 2: Sequence Management Functions
```lua
function add_current_state_to_sequence()
  local state = {
    fractal_index = fractal_index,
    center_x = center_x,
    center_y = center_y, 
    zoom = zoom,
    max_iterations = max_iterations,
    palette_index = palette_index
  }
  table.insert(sequence_list, state)
end

function delete_last_sequence_entry()
  if #sequence_list > 0 then
    table.remove(sequence_list, #sequence_list)
    return true
  end
  return false
end
```

### Step 3: Key Handler Rewrite
```lua
function key(n, z)
  local now = util.time()
  
  if z == 1 then  -- Press
    if n == 1 then
      -- K1: Menu toggle
      norns.menu.init()  -- or appropriate menu call
    elseif n == 2 then
      k2_press_time = now
      k2_still_down = true
    elseif n == 3 then  
      k3_press_time = now
      k3_still_down = true
    end
  else  -- Release
    if n == 2 then
      k2_still_down = false
      local hold_duration = now - k2_press_time
      if hold_duration < HOLD_THRESHOLD then
        -- Short press: Add to sequence
        add_current_state_to_sequence()
        show_hud("ADDED TO SEQUENCE (" .. #sequence_list .. ")")
      end
    elseif n == 3 then
      k3_still_down = false  
      local hold_duration = now - k3_press_time
      if hold_duration < HOLD_THRESHOLD then
        -- Short press: Delete from sequence
        if delete_last_sequence_entry() then
          show_hud("DELETED FROM SEQUENCE (" .. #sequence_list .. ")")
        else
          show_hud("SEQUENCE EMPTY")
        end
      end
    end
  end
end
```

### Step 4: Encoder Handler Enhancement
```lua
function enc(n, delta)
  if delta == 0 then return end
  
  local dir = (delta > 0) and 1 or -1
  local now = util.time()
  
  -- Rate limiting
  if (now - encoder_last_time[n]) < 0.05 then return end
  
  -- Check hold modifiers
  local k2_held = k2_still_down and (now - k2_press_time) > HOLD_THRESHOLD
  local k3_held = k3_still_down and (now - k3_press_time) > HOLD_THRESHOLD
  
  -- Hold + Encoder combinations (immediate actions)
  if k2_held then
    if n == 1 then
      -- Fractal selection
      fractal_index = fractal_index + dir
      if fractal_index < 1 then fractal_index = #fractals end
      if fractal_index > #fractals then fractal_index = 1 end
      show_hud("FRACTAL: " .. fractals[fractal_index].name)
      render_needed = true
    elseif n == 3 then
      -- Iteration selection
      local iter_options = {50, 100, 200, 500, 1000, 2000}
      local current_idx = find_iteration_index(max_iterations)
      current_idx = current_idx + dir
      if current_idx < 1 then current_idx = #iter_options end
      if current_idx > #iter_options then current_idx = 1 end
      max_iterations = iter_options[current_idx]
      show_hud("ITERATIONS: " .. max_iterations)
      render_needed = true
    end
    encoder_last_time[n] = now
    return
  end
  
  if k3_held then
    if n == 1 then
      -- Tempo control
      global_tempo = math.max(20, math.min(300, global_tempo + dir * 5))
      show_hud("TEMPO: " .. global_tempo .. " BPM")
    elseif n == 2 then
      -- Loop length
      loop_length = math.max(1, math.min(32, loop_length + dir))
      show_hud("LOOP LENGTH: " .. loop_length)
    elseif n == 3 then
      -- Palette cycling
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
```

---

## ⚠️ RISKS AND MITIGATIONS

### Risk 1: Hold Timing Conflicts
**Issue:** User might accidentally trigger hold mode during quick operations
**Mitigation:** 
- 500ms hold threshold (tested comfortable)
- Clear visual feedback when entering hold mode
- Short press actions only on release within threshold

### Risk 2: Menu Toggle Interruption
**Issue:** K1 menu toggle might interrupt critical operations
**Mitigation:**
- Only allow menu toggle when not in active playback
- Add confirmation for menu exit during sequence playback

### Risk 3: Sequence Management Complexity
**Issue:** Sequence data structure needs to capture full state
**Mitigation:**
- Start with minimal state capture
- Add versioning for future expansion
- Provide clear feedback on add/delete operations

---

## 🎯 SUCCESS CRITERIA

### Functional Requirements
- ✅ All original spec operations implemented
- ✅ No unauthorized functions remain
- ✅ Encoder paradigm preserved
- ✅ Smooth base navigation maintained
- ✅ Immediate action for mode-specific operations

### User Experience Requirements  
- ✅ Intuitive hold-based modifiers
- ✅ Clear HUD feedback for all operations
- ✅ No accidental state changes
- ✅ Familiar navigation feel preserved

### Performance Requirements
- ✅ <50ms response time for all operations
- ✅ No encoder event accumulation issues
- ✅ Smooth fractal rendering maintained

---

## 📅 IMPLEMENTATION TIMELINE

1. **Day 1:** Remove violations, implement sequence data structures
2. **Day 2:** Implement hold-based key system, test timing
3. **Day 3:** Implement K+E combinations with encoder paradigm
4. **Day 4:** Integration testing, performance verification
5. **Day 5:** User acceptance testing, refinements

**Ready to proceed with Step 1?**
