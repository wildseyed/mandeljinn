# Mandeljinn

A fractal music explorer for Monome Norns, combining real-time fractal visualization with algorithmic music generation inspired by the Fractal Music Generator (FMG).

## Overview

Mandeljinn bridges the gap between mathematical beauty and musical expression by providing an intuitive interface for exploring fractals while generating corresponding musical sequences. The name combines "Mandelbrot" with "jinn" (a supernatural being), reflecting the magical emergence of complex patterns from simple rules.

## Features

### Fractal Visualization
- **Multiple Fractal Types**: Mandelbrot Set, Burning Ship, Tricorn, Multibrot, Phoenix, and more
- **Interactive Navigation**: Smooth pan and zoom with encoder controls
- **Real-time Rendering**: Background incremental rendering for responsive interaction
- **Zoom-adaptive Movement**: Pan sensitivity scales with zoom level for precise navigation

### Control Interface
- **E1**: Zoom in/out
- **E2**: Pan horizontally (reversed for intuitive feel)
- **E3**: Pan vertically
- **K1**: Enter fractal selection mode
- **K2**: Enter iteration count adjustment mode
- **K1 + E1**: Select fractal type
- **K2 + E1**: Adjust iteration count (10-500)

### Technical Features
- **Queue-free Encoder Handling**: Frame-by-frame movement system prevents lag buildup
- **Coordinate Bounds Safety**: Prevents numerical instability with safe coordinate limits
- **Metro Timer Management**: Graceful fallback when system resources are exhausted
- **Generation-based Rendering**: Prevents race conditions during rapid navigation

## Installation

1. Copy `mandeljinn.lua` to your Norns `code` directory
2. Launch from the Norns SELECT menu
3. Use encoders to explore fractals

## Development Roadmap

### Phase 1: Core Fractal Explorer ✅
- [x] Multiple fractal implementations
- [x] Interactive pan/zoom navigation
- [x] Responsive encoder handling
- [x] Stable rendering system

### Phase 2: Musical Integration (In Progress)
- [ ] FMG-compatible iteration sequence mapping
- [ ] 8-patch timbre bank per fractal
- [ ] Real-time audio parameter modulation
- [ ] MIDI sequence generation

### Phase 3: Advanced Features (Planned)
- [ ] Fractal animation and morphing
- [ ] Save/load fractal locations
- [ ] Audio recording and export
- [ ] Multi-scale harmonic mapping

## Technical Notes

### Fractal Implementation
- Uses FMG-compatible Z0=C initialization for musical consistency
- Implements escape-time algorithm with configurable iteration limits
- Coordinate system optimized for Norns 128x64 screen resolution

### Performance Optimization
- Background incremental rendering (4 rows per frame at 60fps)
- Encoder event throttling to match render capacity
- Efficient pixel buffer management
- Safe coordinate bounds to prevent mathematical overflow

### Audio Architecture (Planned)
- SuperCollider Engine_Mandeljinn integration
- Real-time parameter mapping from fractal coordinates
- Multi-voice synthesis with fractal-derived timbres
- MIDI output for external synthesizers

## Inspiration

This project builds upon the pioneering work of:
- **Fractal Music Generator (FMG)**: Mathematical foundation for fractal-to-music mapping
- **Benoit Mandelbrot**: Fractal geometry and the Mandelbrot set
- **Monome Norns Community**: Hardware platform and creative coding environment

## Technical Specifications

- **Platform**: Monome Norns (Lua scripting environment)
- **Screen Resolution**: 128x64 pixels
- **Rendering**: Real-time fractal computation with escape-time algorithm
- **Audio Engine**: SuperCollider integration (planned)
- **Control**: Hardware encoders and keys

## Version History

- **v0.2-debug**: Implemented queue-free encoder handling and stable rendering
- **v0.1**: Initial fractal explorer with basic navigation

---

*"In the infinite complexity of fractals, we find the seeds of endless musical possibility."*
