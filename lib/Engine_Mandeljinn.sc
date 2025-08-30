// Engine_Mandeljinn.sc
// SuperCollider engine for canonical FMG audio generation
// Implements Direct and Sine modes only (no timbre bank - stay true to FMG)

Engine_Mandeljinn : CroneEngine {
    var <synth;
    var <mode = 0; // 0=direct, 1=sine
    
    *new { arg context, doneCallback;
        ^super.new(context, doneCallback);
    }
    
    alloc {
        // Define SynthDefs for FMG's canonical audio modes
        
        // Direct Mode: zx->L amp, zy->R amp (raw fractal orbit as stereo audio)
        SynthDef(\mandeljinn_direct, {
            arg out, ampL=0, ampR=0, glide=0.01;
            var sigL, sigR;
            
            // Lag for smooth interpolation between orbit points
            sigL = Lag.kr(ampL, glide);
            sigR = Lag.kr(ampR, glide);
            
            Out.ar(out, [sigL, sigR]);
        }).add;
        
        // Sine Mode: zy->freq, zx->pan (fractal-controlled sine)
        SynthDef(\mandeljinn_sine, {
            arg out, freq=220, pan=0, amp=0.5, glide=0.01;
            var sig;
            
            // Single sine oscillator with fractal parameter control
            sig = SinOsc.ar(
                Lag.kr(freq, glide),  // Smooth frequency transitions
                0,
                amp
            );
            
            Out.ar(out, Pan2.ar(sig, Lag.kr(pan, glide)));
        }).add;
        
        context.server.sync;
        
        // Start with Direct mode
        synth = Synth(\mandeljinn_direct, [out: context.out_b]);
        
        // Register engine commands
        this.addCommand("mode", "i", { arg msg;
            var newMode = msg[1];
            if (newMode != mode) {
                synth.free;
                mode = newMode;
                if (mode == 0) {
                    synth = Synth(\mandeljinn_direct, [out: context.out_b]);
                } {
                    synth = Synth(\mandeljinn_sine, [out: context.out_b]);
                };
            };
        });
        
        // Direct Mode commands
        this.addCommand("ampL", "f", { arg msg;
            if (mode == 0) { synth.set(\ampL, msg[1]) };
        });
        
        this.addCommand("ampR", "f", { arg msg;
            if (mode == 0) { synth.set(\ampR, msg[1]) };
        });
        
        // Sine Mode commands  
        this.addCommand("freq", "f", { arg msg;
            if (mode == 1) { synth.set(\freq, msg[1]) };
        });
        
        this.addCommand("pan", "f", { arg msg;
            if (mode == 1) { synth.set(\pan, msg[1]) };
        });
        
        this.addCommand("amp", "f", { arg msg;
            if (mode == 1) { synth.set(\amp, msg[1]) };
        });
        
        // Global parameter commands
        this.addCommand("glide", "f", { arg msg;
            synth.set(\glide, msg[1]);
        });
    }
    
    free {
        synth.free;
    }
}
