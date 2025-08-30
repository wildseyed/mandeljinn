# Fractal Music Generator (FMG) – Research Notes (Survey)

Purpose: Technical survey of FMG to guide Mandeljinn feature parity & selective adaptation to monome norns constraints.

---
## 1. Supported Fractals (Orbit Iteration Functions)
Source: `OrbitCalculator.java` (audio orbits) & `AKernel.java` (image rendering + smoothing/histogram).

Fractal index mapping (AKernel.fractalIndex):
0 Mandelbrot  Zn+1 = Zn^2 + C (classic; smoothing formula uses CON1/CON2)
1 Burning Ship  zx' = zx^2 - zy^2 + cx ; zy' = |2*zx*zy| + cy
2 Tricorn (Conjugate / Mandelbar)  zx' = zx^2 - zy^2 + cx ; zy' = -2*zx*zy + cy
3 Rectangle (custom)  Polynomial form derived from Zn * (|Z|^2) - (Zn * C^2)
4 Klingon (abs + cubic)  zx' = |zx^3| - 3*zy^2*|zx| + cx ; zy' = 3*zx^2*|zy| - |zy^3| + cy
5 Crown  zx' = zx^3 - 3*zx*zy^2 + cx ; zy' = |3*zx^2*zy - zy^3| + cy
6 Frog  zx' = |zx^3 - 3*zx*zy^2| + cx ; zy' = |3*zx^2*zy - zy^3| + cy
7 Mandelship (hybrid)  Higher-order polynomial mix (see code) combining quartic & cross terms
8 Frankenstein  zx' = tanh(zx^3 - 3*zx*zy^2) + cx ; zy' = |3*zx^2*zy - zy^3| + cy
9 Logistic  zx' = -cx*zx^2 + cx*zx + 2*cy*zx*zy + cx*zy^2 - cy*zy ; zy' = cx*zy + cy*zx - cy*zx^2 + cy*zy^2 - 2*cx*zx*zy

Notes:
- Orbit calculation (audio) and iteration (image) formulas are analogous except for smoothing constants.
- Bailout radius default is 2 (squared modulus < 4) but bailout can vary; smoothing branch early-exits if bailout == 4 (no smoothing math needed).
- Some fractals change smoothing denominator (CON2/CON3/CON4) to adjust fractional iteration scaling due to growth rate differences.

## 2. Image Rendering Pipeline (AKernel + RenderManager)
- Aperture: Kernel run across width*height.
- Maps pixel (px, py) to complex plane: zx in [minA,maxA], zy in [maxB,minB] (vertical inverted).
- Chooses iteration function by fractalIndex (0–9).
- Three rendering modes:
  1. Smooth only (smooth==1, histogram==0): linear interpolation of palette colors by fractional iteration (countD).
  2. Histogram + (optionally) smoothing (histogram==1): stores iteration counts into iterCountArray for post-pass color normalization.
  3. Plain cycling: color = palette[count % 100], interior color index 100.
- Smoothing fractional formula: count + 1 - fraction where fraction = (log(0.5*log(|Z|^2)) - CONk)/CONm with caps to [0,1].
- Histogram not fully visible here; frequency accumulation occurs outside GPU due to Aparapi limits.

## 3. Orbit Extraction for Audio/MIDI
Class: `OrbitCalculator`
- Builds an array ComplexNumber[maxAudioIterations].
- Starting Z0 = C (cx, cy) (Note: not classic Mandelbrot starting at 0; here Z0 begins at C; this changes early orbit shape – design decision to replicate or adjust?).
- Stores successive Zn until divergence (|Z|^2 >= 4) or maxAudioIterations reached.
- Provides separate calculateXOrbits methods per fractal (same formulas as AKernel but without smoothing; stops at bailout=2^2).

Implication for Mandeljinn: Decide whether to mimic this Z0=C start or use canonical Z0=0 for Mandelbrot and variants. Using Z0=0 yields traditional exterior structure; using Z0=C produces different early transient values influencing mapped music.

## 4. Audio Wave Synthesis Mode (`playWave`)
Parameters pulled from GUI (sliders/spinners):
- sampleRate = 44100; bufferSize; durationSeconds; interpolationPoints; keepOrbitForTotSamples; volume.
- Scaling windows: zx->direct stereo amplitude (minZxDirect, maxZxDirect), zy likewise OR alternative sine synthesis mapping.
Two synthesis strategies:
1. Direct Mode: zx -> Left amplitude, zy -> Right amplitude (after scaling). Interpolates between successive orbit points to create smooth audio trajectory; fade-in/out over 1024 frames.
2. Sine Mode: zy mapped to frequency; zx mapped to stereo pan; amplitude global volume. xValue accumulates phase.
Edge Cases:
- If divergent orbit earlier than max iterations and skip divergence enabled, abort.
- Repeats orbit sequence if duration longer than collected orbits (index wraps to 0) with verbose warning.
- Interpolation ensures continuous audio rather than discrete steps.

Potential norns adaptation:
- Replace direct PCM generation with softcut voices or supercollider engine using parameter streams (e.g., map zx/zy to frequency, pan, filter). Interpolation can be handled via line segments or clock.

## 5. MIDI Melody Mapping (`playMelody`)
Per orbit point i:
- zy -> Note number scaled to [minNote, maxNote].
- zx -> Either Program Change (instrument) and/or Control Change 10 (pan) when enabled.
- Each point generates NOTE_ON at tick (i*4+2), NOTE_OFF at (i*4 + 3 + (4*noteDuration)). tick resolution is PPQ=sequenceSpeed.
- Optional: Program Change at (i*4) and Pan CC at (i*4+1). Thus ordering per orbit: program change, pan, noteOn, noteOff.
- Divergence handling: if array has null earlier than max length -> either break and keep partial (preventInterruptions) or abort sequence.
- Range validation for zy, zx similarly uses preventInterruptions to clamp or abort.
- Channel cycling: sequentially increments channel (skips 9 for drums). Maintains map sequencer->channel; sends All Notes Off (CC 123) when reassigning.
- Effects: Sends reverb (CC 91) and chorus (CC 93) initial values per sequence.
- Extends sequence artificially with hidden Note On removal (keepAndEnlargeSequence) to prevent premature STOP events when preventInterruptions selected.

Design takeaways:
- Program Change per orbit (when enabled) is canonical FMG behavior; replicate unthrottled instrument changes exactly.
- NOTE timing fixed stride: one orbit == constant rhythmic subdivision. (No duration variation except global noteDuration.)
- Potential enhancements for Mandeljinn: variable rhythmic density based on iteration delta, escape velocity, or fractional iteration part.

## 6. MIDI Drums Mapping (`playDrums`)
Nearly identical to melody but fixed to channel 10 (index 9). zy -> drum note, zx -> drumkit change (Program) and/or pan CC10; independent parameter ranges and durations.

## 7. Scaling Function (`Utilities.scale`)
Standard linear mapping: out = ((limitMax-limitMin)*(valueIn-baseMin)/(baseMax-baseMin))+limitMin.
No clamping; upstream ensures in-range or branches on out-of-range conditions.

## 8. Performance / Concurrency
- Uses arrays of Sequencers / SourceDataLines with resource capping (maxSDL, maxSequencers, drumsMaxSequencers).
- When requesting new resources, recycles oldest if caps reached (FIFO rotation).
- Audio writing manually manages buffering; fade exit applied on preemption.
- GPU acceleration attempt with Aparapi; gracefully falls back based on execution mode tests.

## 9. Presets & Assets
Preset images & XML (`resources/.../presets/01_mandelbrot.xml` etc.) correlate to fractalIndex ordering.
Presets likely include plane bounds (minA,maxA,minB,maxB), iteration caps, palette, smoothing/histogram flags (not yet parsed here).

## 10. Key Divergences / Decisions for Mandeljinn
Decision points to document before implementation:
- Starting Z for orbit audio: replicate FMG (Z0=C) or canonical (Z0=0)?
- Which fractals subset fit norns CPU budget? (Start with Mandelbrot, Tricorn, Burning Ship, Crown maybe.)
- Musical mapping simplification: limit per-step Program Change; maybe map zx to pan, zy to pitch, iteration count/fraction to velocity or probability.
- Introduce variable rhythm: derive gate or subdivision from delta|Z| or escape iteration gradient.
- HUD: show current fractal, zoom, center, max iterations, tempo.
- Sequence capture: store (cx, cy, fractal, zoom, iterationDepth) per orbit origin; iterate through list under tempo clock.

## 11. Minimal Data Structures Candidate (Mandeljinn)
FractalDef { id, name, func(cx,cy,maxIter)->orbitArray }.
OrbitPoint { zx, zy }.
OrbitOrigin { cx, cy, fractalId, maxIter, zoom, extraParams }.
Sequence list: [OrbitOrigin].
MappingConfig { pitchSource: zy|zx|modulus|angle, ampSource: zx|zy|constant, panSource: zx|angle|none }.

## 12. Open Questions / TODO
- Extract preset XML parameters (future) to understand default ranges.
- Confirm smoothing necessity on norns (cost vs benefit). Could precompute fractional iteration with simple log operations for modest resolution.
- Determine iteration cap vs zoom auto-adjust (e.g., increase maxIter when zoom crosses thresholds).
- Consider caching orbit arrays for sequence origins to avoid recomputation every cycle.

---
Revision: v0.1 (initial survey)
Next: Parse one preset XML to confirm stored fields if needed.

## 13. Canonical Fidelity Decisions (User Preference: "stay true to FMG")
User intent: replicate FMG musical feel before introducing novel mappings. Therefore initial Mandeljinn should:
1. Use FMG's orbit start convention Z0 = C (NOT classic Z0 = 0) for all fractals, to preserve early orbit shapes influencing pitch/program/pan streams.
2. Maintain separate fractal formulas exactly as in `OrbitCalculator` for audio (no smoothing math in orbit phase; smoothing is image-only).
3. Provide two base synthesis/mapping modes analogous to FMG:
   - Direct (zx->L amp, zy->R amp) with adjustable min/max scaling windows.
   - Sine (zy->frequency, zx->pan) with same parameter names (min/max zy for freq, global min/max freq, volume) though realized through norns engine.
4. Replicate linear scaling function precisely (no clamping) so out-of-range handling occurs at higher layer (abort or clamp policy flags later).
5. Implement melody mapping: zy -> note, zx -> (optional) instrument change OR pan. Keep unthrottled per-orbit Program Change exactly as FMG when the option is enabled.
6. Implement drums mapping on dedicated channel 10 mirroring melody logic for zx/zy scaling with independent ranges.
7. Preserve divergence policies: options skipDivergent (abort) vs reuse partial (preventInterruptions). Expose as params.
8. Keep global uniform note duration & tick spacing first; advanced rhythmic variation deferred.
9. Channel cycling for melody sequences replicates FMG order (skip channel 10). Limit total concurrent sequences to param (default 16 from Mandelbrot preset).
10. Image iteration smoothing/histogram optional; audio unaffected but iteration count influences potential future mappings (e.g., velocity) — record raw integer count only initially.

## 14. Preset Parameter Snapshot (Canonical Baseline)
Extracted from `01_mandelbrot.xml` and `02_tricorn.xml` (differences illustrate per-fractal defaults):
- Shared core: zoom, minA, maxB, fractalIndex, maxAudioIterationsSlider (100), maxImageIterationsSlider (100), autoImageIterationsCheckBox true.
- Audio orbit generation: maxAudioIterations=100 baseline; Direct vs Sine mode differs per preset (Mandelbrot: direct; Tricorn: sine).
- Wave synthesis: interpolationPoints (43 vs 100), keepOrbit (7 vs 25) controlling temporal smoothing density; durationWave (5 vs 10 seconds).
- Scaling windows: Direct mode windows tailored (Mandelbrot asymmetric zx window). Sine mode zy window (0 to 1.5) for Tricorn suggests emphasizing positive imaginary values for frequency mapping.
- Melody MIDI: sequenceSpeed (3 vs 11), maxSequencers (16 vs 11), noteVelocity (30 vs 43), noteDuration (100 both), instrument change effect toggled (on for Mandelbrot, off for Tricorn) while pan effect on for both.
- MIDI scaling ranges: Mandelbrot narrower zx range (-2.25..0.75) than Tricorn (-2..2). zy ranges widen for Tricorn (-1.5..1.5) vs Mandelbrot (-1.25..1.25).
- Drums: Lower maxSequencers (2 vs 1), varied ranges; pan enabled; changeEffect off.
- Rendering: smoothing true/histogram false (Mandelbrot) vs smoothing false/histogram true (Tricorn). Outline speeds and randomness differ (723 w/ randomness 250 vs 78 randomness 1) indicating stylistic visual pacing.

Implications for Mandeljinn defaults:
- Provide fractal-specific default parameter sets (subset) loaded when fractal changes while allowing current session overrides.
- Start with Mandelbrot defaults for global init; switching to Tricorn should load its sine mode config if user has not manually overridden core synthesis mode.

## 15. Implementation Planning Notes (Next Coding Phase)
Minimal param table example (Lua pseudocode):
```
local fractal_defaults = {
  mandelbrot = {
    mode = "direct", max_audio_iter=100,
    direct = { zx_min=-2.0, zx_max=1.0, zy_min=-1.25, zy_max=1.25 },
    sine = { zy_min=-1.25, zy_max=1.25, freq_min=25, freq_max=4000 },
    melody = { zx_min=-2.25, zx_max=0.75, zy_min=-1.25, zy_max=1.25, note_min=24, note_max=100 },
    drums  = { zx_min=-2.25, zx_max=0.75, zy_min=-1.25, zy_max=1.25, note_min=24, note_max=70 },
  },
  tricorn = {
    mode = "sine", max_audio_iter=100,
    direct = { zx_min=-1.25, zx_max=1.25, zy_min=-1.25, zy_max=1.25 },
    sine = { zy_min=0.0, zy_max=1.5, freq_min=25, freq_max=4000 },
    melody = { zx_min=-2.0, zx_max=2.0, zy_min=-1.5, zy_max=1.5, note_min=24, note_max=100 },
    drums  = { zx_min=-2.25, zx_max=0.75, zy_min=-1.25, zy_max=1.25, note_min=0,  note_max=100 },
  },
}
```
Will expand with remaining fractals as needed. Values retain FMG semantics; naming mirrors XML tags for traceability.

## 16. Remaining Fidelity Gaps / Questions
1. Need to inspect additional presets to confirm parameter variability (especially exotic fractals with different smoothing constants).
2. Confirm bailout adjustments (XML currently does not expose; may be GUI-driven elsewhere or fixed at 4).
3. Determine whether FMG autoImageIterations heuristic influences audio (likely not); optional adaptive maxAudioIterations on zoom for depth parity.
4. How FMG chooses zoom step and outline speed interplay with orbit selection for audio triggering (outline render timing influences user interaction rhythm). For norns, replace with deterministic user encoder cadence.
5. Decide if sequence capture should store explicit scaling windows per origin to truly reproduce sounds when revisiting.

---
Revision: v0.3 (added Orbit List / Autonomous Playback design)

## 17. Orbit Lists & Autonomous Playback (New Requirement)
Goal: Allow performer to capture interesting orbit origins (with all necessary params) into an ordered list, then play them back hands‑free while still being able to adjust global tempo (and possibly mix parameters) live. While each orbit plays, its fractal view is redrawn and the orbit path is progressively rendered (point-by-point) exactly as audio/MIDI events are generated.

### 17.1 Capturable Snapshot (OrbitOrigin+Context)
To guarantee sonic & visual reproducibility, each list entry must store:
1. fractal_id (0–9) – iteration function selector.
2. cx, cy – complex plane center/origin used for orbit generation.
3. plane window (minA, maxA, minB, maxB) OR (zoom factor + center) (pick one canonical representation; recommend storing explicit bounds to avoid float drift on recompute).
4. max_audio_iterations (and policy flags: skipDivergent, preventInterruptions) – ensures identical length / early exit behavior.
5. synthesis_mode (direct|sine) and its scaling windows (direct: zx_min, zx_max, zy_min, zy_max; sine: zy_min, zy_max, freq_min, freq_max, volume).
6. melody mapping config (note_min, note_max, zx_pan_min/max, zy_note_min/max if distinct, program_change_enabled, pan_enabled, note_duration, sequence_speed, channel_cycle_state snapshot optional).
7. drums mapping config (if enabled) similar fields + enable flag.
8. global fx & CC defaults (reverb CC91, chorus CC93 values) if diverging from global session defaults.
9. image render prefs (smoothing flag, histogram flag, palette id) for visual fidelity (optional for v1: palette id only).
10. timestamp or user label (label preferred for UI list identification).
11. optional cached_orbit hash or metrics (length, diverged_at iteration) to inform prefetch heuristics.

Assumption: We recompute orbits live using stored parameters (cache optional). This prevents stale format issues if internal representation evolves; a version field per entry can manage migrations.

### 17.2 Data Structures (Lua Pseudocode)
```
OrbitSnapshot = {
  version = 1,
  label = "string",
  fractal_id = 0,
  cx = 0.0, cy = 0.0,
  minA=..., maxA=..., minB=..., maxB=..., -- OR zoom, center
  max_audio_iter = 100,
  policies = { skip_divergent=false, reuse_partial=true },
  synthesis = { mode='direct', direct={zx_min=..., zx_max=..., zy_min=..., zy_max=...}, sine={zy_min=..., zy_max=..., freq_min=..., freq_max=..., volume=...}},
  melody = { enabled=true, note_min=24, note_max=100, program_change=true, pan=true, note_duration=100, sequence_speed=3, zx_min=..., zx_max=..., zy_min=..., zy_max=... },
  drums  = { enabled=false, ... },
  fx = { reverb=40, chorus=0 },
  render = { palette=0, smoothing=true, histogram=false },
  meta = { created=os.time(), user="" }
}

OrbitList = { tempo_bpm=90, entries = { OrbitSnapshot, ... }, current_index=1, loop=true }
```

### 17.3 Persistence Format
- JSON file per list: `lists/<slug>.json`.
- Top-level keys: version, name, tempo_bpm, entries[].
- Keep floats as numbers (no string formatting) to minimize parse overhead; if precision matters for extremely deep zooms later, add scientific notation strings in parallel.
- Provide export/import (same structure) to enable sharing.

### 17.4 Playback State Machine
States: idle -> preparing -> playing_orbit -> advancing -> (end or loop).

Transitions:
1. idle -> preparing: user presses PLAY LIST (key combo) OR list auto-start on load (configurable).
2. preparing: recompute orbit for current entry (in coroutine) while UI shows "loading" spinner if > threshold ms.
3. On orbit ready: switch to playing_orbit (start audio/midi scheduler; begin visual draw).
4. playing_orbit completes when all events for orbit consumed (MIDI: last scheduled noteOff sent; audio: buffer duration elapsed) OR early abort (user stop).
5. advancing: increment index; if beyond list length and loop=true -> wrap; else -> idle.

Stop semantics: STOP resets to idle immediately (cease audio, send All Notes Off to active channels, flush drawing). PAUSE (optional future) would freeze timers & current sample index — defer implementation to retain simplicity.

### 17.5 Timing & Tempo Control
- Global tempo affects only MIDI rhythmic scheduling (sequence_speed scaling) and any envelope/LFO durations if later introduced. Direct PCM (wave) playback durations are parameter-defined; for cohesion we can optionally quantize start of each orbit to next beat boundary derived from tempo (configurable quantization: off, 1 beat, 1 bar).
- Live tempo change: adjusting tempo updates internal clock divisor; future events (not yet emitted) shift accordingly. Already sent NOTE_ON durations remain fixed unless we implement real-time duration scaling (defer).

Formula reference (MIDI mode):
- Ticks per orbit step = fixed 4 (FMG). If we keep PPQ = sequence_speed (like FMG), step_duration_seconds = (60 / tempo_bpm) * (4 / PPQ). Provide derived display: steps/sec.

### 17.6 Visual Synchronization
While playing_orbit, each orbit point i:
1. Add point to orbit path overlay (progressive polyline or dots) — draw only new segment to minimize CPU.
2. Optionally highlight current point (blink or inverse pixel) for last N frames.
3. After orbit completes, optionally fade path (alpha decay) before clearing when next orbit begins (config flag fade_orbit_paths).

Orbit recomputation vs precomputation: For long lists, precompute next entry asynchronously during current orbit's playback (look-ahead=1). Shared thread/coroutine must not block audio; yield every n iterations.

### 17.7 UI Integration (Performance Surface Constraints)
Live screen (non-modal) shows when list playback active:
- Row 1: LIST name, index/total, loop flag.
- Row 2: Current fractal short name, tempo BPM (encoder 1 adjust), playback status symbol (▶, ■), maybe progress bar (percent of orbit points consumed).
- Row 3: cx, cy (condensed), zoom / maxIter.
- HUD overlay: small orbit progress gauge (e.g., mini arc) optional.

Controls (proposed):
- K1 long-press: toggle list playback (start/stop) if list non-empty.
- E1: tempo (coarse when unmodified, fine with K1 held).
- K2: next orbit (skip) when playing_orbit; when idle, steps selection cursor in list manager (if on list UI page).
- K3: prev orbit while playing (optional; if invoked mid-play, stops current and immediately loads previous).

Deep Dive / List Manager Page (entered via existing double-click or long-press gesture decision):
- Add current origin (captures snapshot & prompts label defaulting to fractal + index).
- Delete / reorder (encoder navigation + K2/K3 to move; or hold+turn for reorder).
- Save list, Load list, New list, Toggle loop.

### 17.8 Audio/MIDI Coordination & Edge Cases
Edge Cases & Policies:
1. Divergent orbit early: If policies.skip_divergent -> orbit aborted; treat as zero-length -> advance automatically (log). If reuse_partial -> play partial; visual shows truncated path.
2. Empty list start attempt: ignore with brief HUD message.
3. Tempo change extreme (e.g., <20 BPM or >300 BPM): enforce safe clamping; show warning if user exceeds recommended range.
4. Channel exhaustion: If multiple simultaneous list playback not allowed (v1 single active orbit), simpler; if later layering added, must ensure channel cycling state per layer.
5. Program Change spam: List entries with program_change_enabled true will produce unthrottled changes per orbit point — faithful; global toggle can suppress across entire list if user wants consistency (feature flag list_pc_override=false by default).
6. Visualization backpressure: If drawing cannot keep up (frame skip), keep audio authoritative; accumulate orbit points and flush in batches; track dropped frames metric for tuning.

### 17.9 Performance Considerations (norns)
- Orbit length (<= max_audio_iter=100 initially) is modest; recompute cost trivial. Future deeper zoom may require adaptive iteration scheduling (yield every 8 iterations to scheduler).
- JSON load/save small (<10 KB typical); use norns util.json safely on main thread when idle; save deferred until no playback to avoid disk jitter.
- Precompute sine frequency scaling tables (zy->freq) once per list start to avoid per-step recalculation if heavy.

### 17.10 Minimal Implementation Phases
Phase A (MVP): capture current origin, append, save/load, sequential playback (no prefetch), tempo adjust, loop, progressive orbit draw (no fade), skip/stop controls.
Phase B: asynchronous prefetch, orbit path fade, reorder UI, list-level overrides (e.g., global suppression of program changes), quantized start.
Phase C: multi-list playlist chaining, randomized order modes, conditional branching based on orbit metrics.

### 17.11 Open Questions
1. Do we guarantee atomic visual switch between entries (fade out previous path vs immediate clear)?
2. Should list tempo override individual snapshot sequence_speed or combine (e.g., effective PPQ = snapshot.sequence_speed scaled by global tempo)?
3. Provide per-entry repeat count before advance? (Not in FMG; optional extension.)
4. Save per-entry color palette or unify list palette? (Suggest saving palette for fidelity; allow global override.)

Decision placeholders: Will confirm with user before coding; defaults lean toward maximum fidelity (respect per-entry settings) with global tempo as multiplicative layer.

---
## 18. SuperCollider Engine Capability Survey (Community Reuse vs Custom)
Scope: Rapid scan of representative community engines to gauge feasibility of FMG feature fidelity on norns and identify reusable design patterns. Focus: polyphony management, fast per-event timbral change ("program change" analog), real-time continuous parameter streaming (direct stereo orbit), lightweight sine mapping, and sample / physical / FM diversity.

### 18.1 Representative Engines Inspected
1. MollyThePoly (subtractive poly) – Rich voice architecture (VarSaw/Saw/Pulse + sub/noise, dual ADSRs, LFO, ring mod, chorus). Voice allocation with per-voice SynthDef and global param broadcast via Group. Patch randomization at Lua level. Suitable for sustained poly pads/leads; heavier CPU per voice.
2. FM7 (6‑op FM) – Complex param space (carrier/modulator matrix) with dynamic Bus mapping for control values; up to 16 voices. Good for wide timbral variety; per-voice reconfiguration expensive if done every orbit step.
3. Sines (simple 16-voice sine/FM-ish) – Extremely light voices; per-voice frequency/amp/pan updates cheap. Ideal base for Sine Mode (zy->freq, zx->pan) with continuous updates.
4. KarplusRings (pluck synthesis, event-triggered) – One-shot per trigger; fits mapping orbit points to plucked events (note on + auto decay) if we want per-iteration transient timbres.
5. MxSamples (multi-sample playback, pedal logic, FX bus) – High voice count (40), sample management, sustain/sostenuto states. Useful for mapping orbit program changes to instrument (buffer) selection; heavy disk/RAM if many instruments.
6. Additional patterns: Granular (Graintopia), Physical modeling / resonators (ResonatorBank), FM hybrids (faeng), Sample FX chains (Pedalboard), simple pluck/resonator variants.

### 18.2 Capability Mapping to FMG Requirements
Requirement | Needed Mechanism | Existing Pattern | Feasibility
------------|------------------|------------------|------------
Direct Mode (zx->L, zy->R continuous wave) | Continuous stereo amplitude trajectory | Custom lightweight SynthDef fed by control bus or buffer | HIGH (custom engine simpler than adapting heavy poly engines)
Sine Mode (zy->freq, zx->pan) | Fast per-step freq & pan updates | Sines engine voice parameter set | HIGH (reuse pattern / wrap minimal subset)
Unthrottled Program Change per orbit point (MIDI) | Instrument switch every iteration | External MIDI PC messages OR internal patch index cycling | HIGH (external); MED (internal heavy engines)
Per-iteration pan CC + note scheduling | Event-based voice triggers | Any poly engine with noteOn/noteOff (Molly/Sines/FM7) | HIGH
Wave interpolation / repeated orbit playback | Precompute orbit into buffer | Custom engine using Buffer + Phasor / BufRd | HIGH
Large patch diversity (subtractive/FM/sample) | Multiple synthesis families | Combine lightweight custom + optional external MIDI synths; later integrate selected engines | PHASED (start small)
Fast patch morphing (pseudo Program Change) | Parameter snapshot sets | Molly randomization & bus broadcast approach | MED (limit snapshot count to avoid CPU spikes)
Drums channel (channel 10) | Dedicated percussion timbres | External MIDI drum module OR sample engine voices (MxSamples subset) | HIGH (external), MED (internal sample mgmt)

### 18.3 Proposed Audio Strategy (Phased)
Phase 1 (Fidelity Core):
- Implement custom Engine_Mandeljinn with two SynthDefs:
  a. orbit_direct: Reads from two control busses (ampL, ampR) updated each orbit step (or small segment interpolation with Line.kr) producing raw stereo.
  b. orbit_sine: Either a single dynamic sine (continuous Line.kr freq & pan) OR allocate small pool (N voices) for legato overlap; map zy->freq, zx->pan.
- MIDI: Send unthrottled Program Change + Note/CC out (external gear handles instrument variety). Audio engine provides local monitoring for Direct/Sine modes independent of MIDI program churn.

Phase 2 (Internal Timbre Diversity):
- Add optional "instrument banks" inside Engine_Mandeljinn: lightweight variants (saw, pulse, noise mix) selected by integer program index; switching sets global wave select & mix levels (cheap) instead of spawning complex new voices.
- Add per-orbit patch morph: program index drives crossfade weights (avoid full param randomization cost).
- Optional integration: embed a trimmed Molly voice for richer mode; limit program change frequency when that mode active (documented fidelity exception) or only allow patch changes on divergence boundary (config flag) while still sending external PC unthrottled.

Phase 3 (Advanced):
- Incorporate a simple FM pair (2‑op) to diversify internal program set without full FM7 overhead.
- Introduce sample percussion via a mini sample player (subset of MxSamples concept) for drums mapping if external MIDI drums not used.

### 18.4 Feasibility Risks & Mitigations
Risk: CPU spikes if heavy poly engine params mutated every orbit step (100 PCs).
Mitigation: For fidelity, keep unthrottled PCs only in outbound MIDI; internal engine uses light program index toggles (constant-time param set). Provide transparency in UI.

Risk: Control rate zipper noise for rapid amplitude updates in Direct Mode.
Mitigation: Use Lag.kr or short Line.kr segments between successive orbit points (interpolation akin to FMG). Batch orbit points into small scheduler intervals (e.g., 4 ms) to reduce set commands.

Risk: Orbit recompute + audio scheduling contention.
Mitigation: Compute orbit fully before playback (Phase 1) for wave & melody; stream later if needed with yield strategy.

Risk: Internal patch scarcity reducing FMG "instrument churn" feel if user lacks external MIDI.
Mitigation: Provide a curated bank (8–16 lightweight timbre presets) covering wide spectral space (sine, bright saw, pulse, noise, pluck-like filtered, formant, ring mod approximation) with near-zero cost switching.

### 18.5 Features to Potentially Cull or Defer (Technical Cost vs Benefit)
Candidate | Reason to Defer | Replacement / Future Path
----------|-----------------|--------------------------
Full internal complex subtractive (Molly-level) patch randomization per orbit step | Heavy CPU & param flood; not needed for core mapping | External MIDI PC + lightweight internal bank; manual randomize in deep menu
6-op FM instrument switching each iteration | Excessive parameter set overhead | 2-op mini FM variant for Phase 3
Sample-based instrument per-step change (MxSamples) | Buffer loads & voice mgmt overhead, disk IO | External sampler via MIDI; later: preloaded small sample set for drums
Simultaneous Direct + Sine mixed rendering | Doubles engine complexity; not canonical FMG | Keep modes mutually exclusive (toggle)
Realtime orbit streaming (before full compute) | Increases risk of divergence handling race | Precompute entire orbit (<=100 points) first

### 18.6 Internal Engine Minimal Spec (Phase 1 Draft)
SynthDef orbit_direct(out, ampL=0, ampR=0, glide=0.01, vol=0.8) { Out.ar(out, [Lag.kr(ampL, glide), Lag.kr(ampR, glide)]) }
SynthDef orbit_sine(out, freq=220, pan=0, vol=0.5) { Out.ar(out, Pan2.ar(SinOsc.ar(Lag.kr(freq,0.01)), Lag.kr(pan,0.01), vol)) }
Control Paths: per orbit point schedule engine.ampL/ampR or engine.freq/pan updates at fixed tick (derived from PPQ & tempo) + linear interpolation.

### 18.7 Program Change Handling Plan
Outbound MIDI: Always send PCs per orbit step when user enables (pure fidelity).
Internal Audio: Map program index = orbit_step % bank_size; bank defines static param sets (waveform, filter tilt, noise mix). Provide user option: internal_pc_follow (on/off). When off, internal sound stable while external churn occurs.

### 18.8 Next Actions (Post Confirmation)
1. Lock Phase 1 spec: confirm acceptance of internal vs external PC split.
2. Define lightweight timbre bank (list of 8 entries) & add to research doc (Section 19 future).
3. Implement Engine_Mandeljinn (SC) + Lua wrapper param registration.
4. Integrate with Orbit List playback scheduler (Sections 17 & 5 logic alignment).
5. Add performance telemetry (avg engine param set time) to ensure headroom.

Open Confirmation Points:
Decision Outcomes (2025-08-29):
- MIDI Entirely Deferred: Phase 1 will NOT send or rely on MIDI (melody, program change, drums). Focus shifts to internal audio reproduction of FMG feel. Program Change concept repurposed as internal patch index churn.
- Internal Timbre Bank: Proceed with 8 patches (baseline) BUT not "lightweight placeholder"—they must be musically distinct enough to emulate FMG's instrument variability without external MIDI.
- Drums Deferred: No internal drum synthesis in Phase 1; rhythmic percussion mapping postponed to later (could be MIDI or internal sample engine in a future phase).

Implications:
1. Orbit step -> internal patch index (optional) becomes core fidelity analog; unthrottled like FMG PC. Mapping: zx scaled to [0,7] integer when patch_change_enabled.
2. Melody note & pan mapping replaced (temporarily) by timbre evolution + continuous Direct/Sine parameter audio. (Future: reinstate melodic events via internal poly voices or MIDI.)
3. Research document will introduce Section 19 defining patch architecture & Engine_Mandeljinn spec for audio-only Phase 1.

Next: Section 19 (timbre bank & engine scaffolding) appended below.

---
## 19. Internal Timbre Bank & Engine_Mandeljinn (Audio-Only Phase 1)
Goal: Provide internal sonic diversity (analog to FMG Program Change churn) without MIDI. Eight distinct low-CPU patches selectable per orbit point (optional) or fixed when patch_change disabled.

### 19.1 Patch Design Principles
- Low CPU: Single Synth voice (monophonic continuous) for Direct Mode; Sine Mode already simple. Timbre bank changes avoid re-instantiating Synth; they adjust control-rate parameters.
- Distinct Spectral Profiles: Cover pure, bright, hollow, noisy, transient-rich, metallic, vocal/formant, and evolving/ring-mod textures.
- Deterministic: Each patch = fixed param set (no randomness at switch) to ensure reproducibility of orbit timbre sequences.
- Instant Switching: Patch change applies within <1 orbit tick (control bus set) with gentle 5–10 ms crossfade to prevent clicks.

### 19.2 Unified SynthDef Concept
One SynthDef (orbit_voice) with a patch_index control driving branch-select signal chain:
Components per patch (enabled via patch_index case):
1. PureSine: single SinOsc.
2. BrightSaw: VarSaw + subtle high shelf tilt.
3. PulseHollow: Pulse (PWM fixed width=0.35) plus mild notch (BRF) to hollow out mids.
4. NoiseCloud: PinkNoise -> gentle LPF + slow amplitude wobble (internal LFO).
5. Pluckish: Decay2 * Saw passed through resonant LPF (short envelope shaping). (Amplitude envelope re-triggered on patch change if coming into this patch.)
6. RingPair: Two detuned sines * amplitude ring (multiplication) -> metallic partials.
7. SimpleFM: Two-op FM (carrier sine + mod sine) with fixed index & ratio.
8. FormantAir: Saw -> two BPF formant peaks + subtle noise layer.

Signal Path Skeleton:
```
freq_base (for Sine Mode) OR amplitude pair (for Direct Mode) -> timbre block (selected) -> optional low shelving (compensation) -> Pan2 (pan from zx or derived) -> Out
```
Direct Mode: patch block receives amplitude scaling left/right externally; timbre block acts as waveshaper on unity signal per channel (apply after amplitude mapping?). Simpler: For Direct Mode we synthesize stereo in engine (two parallel timbre generators) each scaled by ampL/ampR (cost x2). Since amp arrays small (<=100 updates), acceptable.
Sine Mode: ignore patch bank (OR allow patch bank to apply waveshaping to sine output; configurable). For Phase 1 Sine Mode uses only PureSine or SimpleFM if user toggles "sine_fm_variant".

### 19.3 Control Interface (Engine Parameters)
engine.patch(index)              -- 0..7
engine.mode(value)               -- 0=direct, 1=sine
engine.ampL(value), ampR(value)  -- Direct Mode continuous
engine.freq(value)               -- Sine Mode continuous (Hz)
engine.pan(value)                -- Sine Mode pan (-1..1) if not deriving from zx
engine.masterAmp(value)          -- Global volume
engine.glide(value)              -- (optional) smoothing for freq / amp transitions
engine.patchChangeXfade(ms)      -- Crossfade duration (default 0.01)

### 19.4 Orbit Mapping Adjustments (Audio-Only)
Per orbit point i:
If patch_change_enabled: patch_index = floor( scale(zx, zx_min, zx_max, 0, 7) + 0.5 ) clamped 0..7; send engine.patch(patch_index) first.
Direct Mode: ampL = scale(zx, direct.zx_min, zx_max, -1, 1) * masterAmp ; ampR = scale(zy, direct.zy_min, zy_max, -1, 1) * masterAmp.
Sine Mode: freq = scale(zy, sine.zy_min, zy_max, freq_min, freq_max); pan = scale(zx, sine.zx_min or reuse melody.zx_min?, zx_max, -1, 1).
Timing: Maintain fixed tick stride as earlier (sequence_speed & tempo) to preserve FMG rhythmic regularity (even though no MIDI message output), used solely to schedule parameter updates.

### 19.5 Patch Parameter Table (Initial Values)
| Index | Name         | Core Params |
|-------|--------------|-------------|
| 0 | PureSine    | sine only (baseline) |
| 1 | BrightSaw   | VarSaw, slight high shelf (+3 dB @ 4kHz) |
| 2 | PulseHollow | Pulse 0.35 width, BRF @ 1.2kHz Q=3 |
| 3 | NoiseCloud  | PinkNoise -> LPF 2.5kHz; slow LFO (0.1Hz) depth 0.2 amp |
| 4 | Pluckish    | Saw * Decay2(0.005,0.15) -> LPF 3kHz, resonance 0.4 (envelope retrigger on patch enter) |
| 5 | RingPair    | Sin(freq) * Sin(freq*1.618) (scaled) |
| 6 | SimpleFM    | Carrier Sin; Mod Sin ratio 2.0; index 1.2 |
| 7 | FormantAir  | Saw + Pink 0.05 -> BPF 800Hz Q=5 + BPF 1800Hz Q=5 |

Crossfade: On patch change ramp old block gain down & new block up over patchChangeXfade.

### 19.6 SynthDef Pseudocode Outline
```
SynthDef(\orbit_voice, { |out, mode=0, patch=0, ampL=0, ampR=0, freq=220, pan=0, masterAmp=0.5, glide=0.01, xfade=0.01|
  var sigL, sigR, baseSig, blocks, sel, envSwitch;
  // Build blocks array (8 variants producing mono signal at unity amplitude)
  blocks = [
    SinOsc.ar(freq),
    VarSaw.ar(freq, 0, 0.5) * 0.8,
    BRF.ar(Pulse.ar(freq, 0.35), 1200, 0.003) * 0.9,
    LPF.ar(PinkNoise.ar(0.5 + LFNoise1.kr(0.1)*0.2), 2500),
    LPF.ar(Decay2.ar(Impulse.kr(0), 0.005, 0.15) * Saw.ar(freq), 3000, 0.4),
    (SinOsc.ar(freq) * SinOsc.ar(freq*1.618)) * 1.5,
    SinOsc.ar(freq + SinOsc.ar(freq*2, 0, freq*1.2)),
    (BPF.ar(Saw.ar(freq), 800, 0.2) + BPF.ar(Saw.ar(freq), 1800, 0.2) + PinkNoise.ar(0.02))
  ];
  sel = SelectX.ar(patch, blocks); // patch assumed 0..7 integer; fractional -> interpolate
  if(mode == 1, { // Sine Mode
     baseSig = sel; // freq driven externally
     sigL = Pan2.ar(baseSig, pan).at(0);
     sigR = Pan2.ar(baseSig, pan).at(1);
  }, {          // Direct Mode
     // use ampL/ampR (scaled -1..1) controlling amplitude of single mono timbre? Or dual generation.
     sigL = sel * Lag.kr(ampL, glide);
     sigR = sel * Lag.kr(ampR, glide);
  });
  Out.ar(out, [sigL, sigR] * masterAmp);
});
```
Note: Need additional logic to handle Pluckish trigger envelope on patch enter (store last patch index via LocalIn/LocalOut or control bus). May split Pluckish into self-contained excitation always on patch boundary; acceptable simplification for Phase 1.

### 19.7 Scheduler Integration
Orbit playback loop drives engine parameter sets at each tick. Provide small debounce: if computed patch index unchanged, skip patch() call. Batch ampL/ampR (Direct) or freq/pan (Sine) updates into a single OSC bundle for jitter minimization.

### 19.8 Risk / Mitigation (Audio-Only Shift)
Loss of pitched melodic contour (no note mapping): Accept for Phase 1; rely on timbral rhythm & amplitude/frequency trajectories. Future Phase adds internal poly melodic mode using subset of voices from multi-osc bank.
CPU spikes from patch crossfade: Keep crossfade <= 10 ms and avoid allocating new UGens per change (pre-built blocks inside single SynthDef). SelectX interpolates; only amplitude weighting cost.

### 19.9 Next Implementation Steps
1. Implement Engine_Mandeljinn SC file with SynthDef above + command handlers.
2. Lua wrapper: params (mode, patch_change_enabled, master_amp, glide, xfade_ms) + orbit playback scheduling code.
3. Update orbit mapping functions to compute patch index & amplitude/freq values.
4. Basic profiling (average SC command latency) to ensure <1ms average.
5. Add test harness script to cycle patches at 100Hz for 1 second verifying absence of clicks.

---
