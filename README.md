# Mandeljinn

A fractal music explorer for Monome Norns that transforms mathematical orbits into living musical sequences through real-time fractal visualization and algorithmic composition.

## Overview

Mandeljinn bridges mathematics and music by generating melodic sequences from fractal orbit trajectories. Each point you explore creates unique musical orbits that play as sequences, with the fractal landscape serving as both visual canvas and musical instrument. The name combines "Mandelbrot" with "jinn" (a supernatural being), reflecting the magical emergence of complex melodies from simple mathematical rules.

## Features

### Musical Orbit Sequencer
- **Real-time Musical Generation**: Fractal orbit points mapped to musical scales and pitches
- **FILL Mode (Default)**: Normalizes orbits to screen bounds for maximum melodic range
- **DIRECT Mode**: Maps orbits to actual fractal coordinates for spatial accuracy  
- **Multiple Musical Scales**: Major, Minor, Pentatonic, Dorian, Whole Tone
- **5-Octave Range**: Vertical movement spans 5 octaves for dramatic pitch variation
- **Smooth Transitions**: Orbit changes queue until current sequence completes

### Fractal Visualization
- **10 Fractal Types**: Mandelbrot, Burning Ship, Tricorn, Rectangle, Klingon, Crown, Frog, Mandelship, Frankenstein, Logistic
- **Interactive Navigation**: Real-time pan, zoom with encoder controls
- **Progressive Orbit Display**: Visual playback shows current sequence position
- **Dual Display Modes**: Toggle between fractal-accurate and screen-normalized views

### Control Interface

#### Normal State
- **K1**: Menu access
- **K2**: Add current location to sequence list  
- **K3**: Delete last sequence entry
- **E1**: Zoom in/out
- **E2**: Pan horizontally  
- **E3**: Pan vertically

#### Hold Combinations
- **K1 Hold + E1**: Change musical scale (Major→Minor→Pentatonic→Dorian→Whole Tone)
- **K2 Hold + E1**: Select fractal type
- **K2 Hold + E2**: Adjust loop length (1-64 steps)
- **K2 Hold + E3**: Adjust iteration count (8-2000)
- **K3 Hold + E1**: Adjust tempo (60-200 BPM)
- **K3 Hold + E2**: Toggle display mode (FILL/DIRECT)
- **K3 Hold + E3**: Change color palette

### Sequence Management
- **K2 Long Press**: Open hierarchical sequence menu with full-screen interface
- **K3 Long Press**: Toggle auto-playback through stored sequence locations
- **Menu Navigation**: E1 scrolls, K3 selects, K2 goes back
- **View Sequences**: Browse stored orbits with fractal details and coordinates
- **Orbit Operations**: Copy, insert, and delete specific sequence locations
- **Auto-Playback**: Timer-based cycling through sequences with visual feedback
- **Save/Load Lists**: File I/O pending text entry method implementation

### Audio Engine
- **PolyPerc Integration**: Built-in polyphonic percussion synthesizer
- **Dynamic Note Generation**: MIDI notes converted to frequencies with velocity/pan
- **Tempo Control**: Adjustable BPM for sequence playback
- **Loop Length**: Configurable sequence length (1-64 orbit points)

## Installation

1. Copy `mandeljinn.lua` to your Norns `code/` directory
2. Restart Norns or refresh SLEEP
3. Launch "mandeljinn" from SELECT > code
4. Use encoders to explore and K2 to add musical locations

## Musical Workflow

1. **Explore**: Navigate fractals with encoders to find interesting orbit patterns
2. **Sample**: Press K2 to add current location to your sequence collection
3. **Compose**: Build a library of fractal locations with unique musical characteristics
4. **Play**: Each location generates real-time musical sequences from its orbit
5. **Refine**: Adjust scales, tempo, and display modes to perfect your composition

## Technical Features

### Performance Optimization
- **Anti-Queueing Encoder System**: Prevents input lag with controlled sampling
- **Background Rendering**: Non-blocking fractal computation (8 rows per 60fps frame)
- **Metro Timer Management**: Graceful resource handling with auto-recovery
- **Coordinate Safety**: Bounded mathematics prevent numerical overflow

### Musical Algorithm
- **Screen-to-Music Mapping**: X-axis→scale degrees, Y-axis→octaves
- **Orbit Normalization**: FILL mode maximizes musical range from tight orbits  
- **Velocity from Distance**: Movement speed affects note intensity
- **Stereo Panning**: Horizontal position controls stereo field

### Display Modes
- **FILL Mode**: Orbit normalized to screen extents for full musical range utilization
- **DIRECT Mode**: Orbit displayed at actual fractal coordinates for spatial accuracy

## Version History

### v1.3 (Current) - Hierarchical Sequence Management & Project Cleanup
- **Hierarchical Menu System**: Full-screen sequence management interface replacing fractal display
- **Sequence Browser**: View stored orbits with fractal type, coordinates, and zoom details
- **Auto-Playback System**: K3 long press toggles timer-based cycling through sequences
- **Menu Navigation**: E1 scrolls, K3 selects, K2 navigates back through menu levels  
- **Orbit Operations**: Copy, insert, and delete specific sequence locations via sub-menus
- **Simplified Controls**: K2 long = menu, K3 long = auto-play (removed complex combinations)
- **Project Cleanup**: Moved 21 development files to archive, clean essential-only structure
- **Pending Features**: Save/Load sequence lists awaiting text entry method implementation

### v1.2 - FILL Mode & Normalized Musical Mapping
- **FILL Mode Implementation**: Orbit display normalized to screen bounds for maximum melodic range
- **Unified Coordinate System**: Visual and musical mapping use same coordinate conversion
- **Display Mode Toggle**: K3+E2 switches between FILL (default) and DIRECT modes
- **Performance Optimization**: Orbit extent calculation with caching system
- **Enhanced Musical Range**: Tight orbits now utilize full 5-octave span

### v1.0 - HUD Polish & Musical Parameter Refinement  
- **Dark Grey Text Backgrounds**: Improved HUD readability with draw_text_with_bg()
- **Fixed Control Labels**: K1 long press shows "SH1 SCAL", K3 shows "MNU TMPO" 
- **Expanded Musical Range**: Octave range increased from 4 to 5 octaves
- **Standardized Loop Length**: Both limits set to 64 steps maximum
- **Control System Polish**: All modifier combinations working correctly

### v0.9 - Complete Musical Integration
- **Musical Orbit Sequencer**: Full implementation of fractal-to-music mapping
- **PolyPerc Audio Engine**: Polyphonic synthesis with hz/amp/pan/release
- **5 Musical Scales**: Major, Minor, Pentatonic, Dorian, Whole Tone quantization
- **Tempo & Loop Control**: Adjustable BPM (60-200) and sequence length (1-64)
- **Real-time Audio Generation**: MIDI note conversion with velocity and stereo panning

### v0.8 - Context-Aware HUD System
- **Spatial HUD Layout**: Four-quadrant status display matching physical controls
- **Dynamic Status Messages**: Real-time feedback for all operations
- **Operation Status Display**: Shows fractal types, iteration counts, coordinate changes
- **Immediate HUD Updates**: Status changes on key press, not just release
- **Debug Integration**: Comprehensive logging for troubleshooting

### v0.7 - Control System Overhaul
- **Fixed Modifier System**: Proper K1/K2/K3 long press handling
- **Canonical Control Mapping**: K2+K3 reset, K3 delete only, no unauthorized resets
- **Hold-Based Modifiers**: All secondary functions require key holds
- **Iteration Control**: Precise single-digit increments (8-2000 range)
- **Text Formatting**: Screen-optimized control descriptions and story

### v0.6 - Digital Encoder Revolution
- **True Digital Encoding**: Boolean state tracking eliminates lag completely
- **Move-Render-Wait Cycle**: One pixel movement per render completion
- **No Event Queuing**: Direct encoder state reading prevents accumulation
- **Timeout Detection**: 100ms automatic stop detection
- **Pixel-Perfect Movement**: 1.0/zoom pixel precision, 1.02x zoom steps

### v0.1 - Initial Fractal Explorer
- **10 Fractal Types**: Mandelbrot, Burning Ship, Tricorn, Rectangle, Klingon, Crown, Frog, Mandelship, Frankenstein, Logistic
- **Queue-Free Encoder Handling**: Revolutionary anti-lag encoder system
- **Interactive Navigation**: Real-time pan/zoom with coordinate bounds safety
- **Background Rendering**: 8 rows per 60fps frame for responsive interaction
- **Metro Timer Management**: Graceful resource handling with auto-recovery
- **FMG Research Foundation**: Mathematical basis for future musical integration

## Technical Specifications

- **Platform**: Monome Norns (Lua + SuperCollider)
- **Audio Engine**: PolyPerc (polyphonic synthesizer)
- **Screen Resolution**: 128x64 pixels with orbit visualization
- **Musical Range**: 5 octaves (C4-C9) across multiple scales
- **Fractal Types**: 10 different mathematical functions
- **Sequence Length**: 1-64 orbit points with looping

---

*"Where mathematics becomes music, where iteration becomes rhythm, where chaos becomes art."*
