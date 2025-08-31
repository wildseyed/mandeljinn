# Mandeljinn Encoder Paradigm - "The Bible"

## Core Philosophy

**Encoders are NOT event sources - they are STATE sensors.**

Traditional approaches treat each encoder detent as an event to be processed, leading to queueing problems when users turn encoders quickly. Our paradigm treats encoders as sensors that we sample at controlled moments.

## The Fundamental Principle

We only care about encoder state at the moment we choose to look at it. The WHEN is more important than the WHAT.

## Input State Model

### K Buttons (Binary + Temporal)
- **NO PRESS** - Button not currently pressed
- **SHORT PRESS** - Button pressed and released quickly (< hold threshold)
- **HOLD** - Button held down (> hold threshold)
- **RELEASE** - Button just released after hold

### Encoders (Trinary + Modified)
- **CCW** - Currently turning counter-clockwise
- **STOPPED** - Not currently turning
- **CW** - Currently turning clockwise

**Modifier Application**: K button states modify encoder interpretation
- Normal: E1=zoom, E2=pan-X, E3=pan-Y
- K2+Hold: E1=zoom-mode, E2=fractal-type, E3=iterations
- K3+Hold: E1=?, E2=?, E3=palette

## The Pipeline Loop

```
[LOOP START]
1. SAMPLE INPUT STATE
   - Read K button states (NO_PRESS|SHORT_PRESS|HOLD|RELEASE)
   - Read encoder states (CCW|STOPPED|CW)
   - Apply K button modifiers to encoder interpretation

2. DETERMINE SINGLE ACTION
   - If any input indicates change: execute ONE unit of change
   - Only one parameter change per loop iteration
   - Changes are atomic and indivisible

3. EXECUTE & BLOCK
   - Perform the single parameter change
   - Update HUD display
   - Render fractal if position/zoom changed
   - Calculate and play orbit sequence
   - NO OTHER INPUT PROCESSING during execution

4. COMPLETION CHECK
   - Only proceed to next loop iteration when current action fully complete
   - Rendering finished, audio updated, display refreshed

[LOOP END - Return to step 1]
```

## Anti-Queueing Behavior

**Example**: User spins zoom encoder rapidly (1000 detents in 30 seconds)

**Traditional Approach (WRONG)**:
- 1000 events queued
- Each event processed sequentially
- System overwhelmed, laggy, unpredictable

**Our Paradigm (CORRECT)**:
- Loop iteration 1: Sample encoder state = CW → Zoom in by 1 unit
- Execute render (takes 60 seconds for illustration)
- Loop iteration 2: Sample encoder state = STOPPED (user finished turning)
- No action taken
- Result: ONE zoom change regardless of detent count

## Implementation Strategy

### Remove Event Handlers
- Replace `function enc(n, delta)` with encoder state sampling
- Replace reactive event processing with proactive state polling

### Main Loop Structure
```lua
function main_loop()
  while true do
    local k_states = sample_k_button_states()
    local e_states = sample_encoder_states()
    local action = determine_action(k_states, e_states)
    
    if action then
      execute_action_blocking(action)
    end
    
    -- Loop continues only after action completion
  end
end
```

### State Sampling Functions
```lua
function sample_encoder_states()
  -- Return current directional state of each encoder
  -- Not accumulated deltas, just current direction
end

function sample_k_button_states()
  -- Return current state and timing info for each button
end
```

## Benefits

1. **No Queueing**: Fast encoder movement = single parameter change
2. **Predictable Behavior**: User always knows system state
3. **Responsive Feel**: Immediate feedback, no lag accumulation
4. **Deterministic**: Same input sequence always produces same result
5. **Resource Efficient**: No processing of unused intermediate events

## Key Implementation Notes

- **State over Events**: Never accumulate encoder deltas
- **Sampling Timing**: Only sample at controlled moments in pipeline
- **Atomic Actions**: Each loop iteration = one complete action
- **Blocking Execution**: No input processing during parameter changes
- **Clean State**: Each loop iteration starts with fresh input sampling

---

*This paradigm ensures that user input is always meaningful and system behavior is always predictable, regardless of input speed or complexity.*
