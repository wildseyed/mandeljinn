# Mandeljinn Control Operations - Forensic Review

This document captures ALL K (key) and E (encoder) operations discussed throughout the conversation, including contradictions and multiple versions. The goal is to enumerate everything considered regardless of conflicts.

## From "Mandeljinn (Agent Look Here).txt" (User's Original Spec)

### Base Operations (No Modifiers)
- **E1** - Zoom In-Out (CW/CCW)
- **E2** - Pan Left-Right (CW/CCW) (Direction Subject to Change)
- **E3** - Pan Up-Down (CW/CCW) (Direction Subject to Change)

### Modifier Operations
- **K1+E1** - Scroll Select Fractal (HUD shows current selection highlighted black text on white background, other selections above/below are white text on black background)
- **K2+E1** - Increase/Decrease (CW/CCW) Orbit Position Note Execution Tempo
- **K2+E2** - Increase/Decrease (CW/CCW) Number of Orbit Positions to Play in Loop
- **K2+E3** - Increase/Decrease (CW/CCW) [UNSPECIFIED FUNCTION]
- **K3+E1** - Increase/Decrease (CW/CCW) [UNSPECIFIED FUNCTION]
- **K3+E2** - [UNSPECIFIED FUNCTION]
- **K3+E3** - [UNSPECIFIED FUNCTION]
- **K2+K3+E1** - [UNSPECIFIED FUNCTION]
- **K2+K3+E2** - [UNSPECIFIED FUNCTION]
- **K2+K3+E3** - [UNSPECIFIED FUNCTION]

### Key Press Operations
- **K1 Short Press-Release** - Toggle between NORNS SELECT/SYSTEM/SLEEP Menu Screen and Patch Canvas. Pause Playing while viewing menu.
- **K2 Short Press-Release** - Add current Orbit Origin Point and its Parameters to Play Sequence List
- **K3 Short Press-Release** - Delete most recently added Origin Point Entry from Play Sequence List

## From Conversation Context Summary

### Early Clean Implementation (Before Issues)
The conversation mentions these operations were working:
- **K2 alone**: Enter/exit fractal select mode (use E1 to select)
- **K1+K2**: Enter/exit iteration select mode (use E1 to select)
- **K1+K3**: Cycle through palettes (linear, gamma√, gamma¼, cosine, edge, smooth)
- **K3 alone**: Reset view
- **E1/E2/E3**: Pan/zoom when not in selection modes

### Iteration Selection Details
From conversation: "K1+K2 then E1" to change iterations
Available iteration options mentioned: {50, 100, 200, 500, 1000, 2000}

### Palette System Details
Palettes mentioned:
- linear
- gamma√ 
- gamma¼
- cosine
- edge
- smooth (with dithering)

## From Current Implementation Review

Looking at the current code, these operations are implemented:

### Key Operations (Current Code)
```lua
-- K1 press/release
k1_down = true/false

-- K2 operations
if k1_down then
    -- K1+K2: Enter/exit iteration select mode
else
    -- K2 alone: Enter/exit fractal select mode
end

-- K3 operations  
if k1_down then
    -- K1+K3: Cycle palette
else
    -- K3 alone: Reset view (THIS IS THE "SUDDEN RESET" YOU MENTIONED)
end
```

### Encoder Operations (Current Code)
```lua
-- In fractal_select_mode and n == 1:
    -- Select fractal with E1

-- In iteration_select_mode and n == 1:  
    -- Select iterations with E1

-- Normal mode (not in selection):
    -- encoder_dir[n] = dir for pan/zoom
```

## Conflicts and Inconsistencies Identified

### K3 Reset Conflict
- **User's original spec**: K3 = "Delete most recently added Origin Point Entry from Play Sequence List"
- **Current implementation**: K3 = "Reset view" 
- **User complaint**: "Suddenly there is a Reset on K3. I never specified that."

### Missing Operations from Original Spec
These were specified but may not be implemented:
- K2+E1: Tempo control
- K2+E2: Loop length control  
- K2+E3: Unspecified function
- K3+E1: Unspecified function
- K3+E2: Unspecified function
- K3+E3: Unspecified function
- K2+K3+E1/E2/E3: Triple combinations

### Iteration Control Discrepancy
- **Original spec**: No explicit iteration control mentioned
- **Implementation added**: K1+K2 for iteration selection
- **User expectation**: Iteration changes should work (mentioned they're familiar with this)

## Operations That May Have Been Lost

### From Conversation References
These operations were mentioned as working at some point:
1. **Changing iteration counts** - User says they're familiar with this operation but it's not working
2. **Palette changes** - K1+K3 implemented but may have lost some functionality
3. **Fractal cycling** - May have had different control scheme originally

### Potential Missing Functions
Based on user's familiarity references:
- Direct iteration adjustment (not just selection mode)
- Simple fractal cycling (not just selection mode)
- Parameter adjustments that worked differently before

## Recommendations for Restoration

### High Priority (User Mentioned as Missing)
1. **Restore iteration count controls** - User specifically mentioned this as familiar operation that's not working
2. **Remove K3 reset function** - User never specified this, conflicts with original spec
3. **Restore K3 original function** - "Delete most recently added Origin Point Entry from Play Sequence List"

### Medium Priority (Specification Gaps)
1. **Implement K2+E1** - Tempo control as originally specified
2. **Implement K2+E2** - Loop length control as originally specified  
3. **Clarify K2+E3, K3+E1, K3+E2, K3+E3** - These were left unspecified in original

### Low Priority (Advanced Features)
1. **Triple key combinations** - K2+K3+E1/E2/E3 were mentioned but left unspecified

## Questions for Clarification

1. **Iteration control**: What was the original method for changing iterations that you were familiar with?
2. **K3 function**: Should K3 be "Delete from sequence list" (original spec) or something else?
3. **Selection modes**: Do you want to keep the fractal/iteration selection modes, or prefer direct cycling?
4. **Palette system**: Is the current K1+K3 palette cycling working as expected?
5. **Pan/zoom directions**: Are E2/E3 directions correct for your preference?

## Summary of What Needs Review

The main issues appear to be:
1. **K3 reset was added without user specification**
2. **Iteration controls may have been changed from familiar operation**
3. **Several specified operations (K2+E1, K2+E2, etc.) may not be implemented**
4. **Original K3 delete function may be missing**

This forensic review captures all mentioned operations. Please review and specify which operations you want restored or modified.
