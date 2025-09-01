Engine_Mandeljinn : CroneEngine {
  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }
  
  alloc {
    // Voice management group
    ~mandeljinn_group = Group.new;
    
    // Orbit data storage
    ~current_zx = 0;
    ~current_zy = 0;
    
    // Audio mode: 0=direct, 1=sine
    ~audio_mode = 0;
    ~audio_enabled = false;
    
    // Direct mode synth
    ~direct_synth = nil;
    
    // Update orbit command - receives fractal coordinates
    this.addCommand("updateOrbit", "ff", { arg msg;
      var zx = msg[1];
      var zy = msg[2];
      
      ~current_zx = zx;
      ~current_zy = zy;
      
      // Debug output
      ("Orbit update: zx=" ++ zx ++ " zy=" ++ zy).postln;
      
      // Update audio if enabled and in direct mode
      if (~audio_enabled && (~audio_mode == 0) && ~direct_synth.notNil) {
        var ampL = (zx * 0.3).clip(-1, 1);  // Scale and clip for safety
        var ampR = (zy * 0.3).clip(-1, 1);
        ~direct_synth.set(\ampL, ampL, \ampR, ampR);
        ("Direct mode: L=" ++ ampL ++ " R=" ++ ampR).postln;
      };
    });
    
    // Start audio command
    this.addCommand("startAudio", "", { arg msg;
      ("Starting audio mode " ++ ~audio_mode).postln;
      
      if (~audio_mode == 0) {
        // Start direct mode
        ~direct_synth = Synth(\mandeljinn_direct, [\ampL, 0.1, \ampR, 0.1], ~mandeljinn_group);
        ~audio_enabled = true;
        "Direct mode synth started".postln;
      };
    });
    
    // Stop audio command
    this.addCommand("stopAudio", "", { arg msg;
      ~audio_enabled = false;
      if (~direct_synth.notNil) {
        ~direct_synth.free;
        ~direct_synth = nil;
        "Direct mode synth stopped".postln;
      };
    });
    
    // Test command (keep for now)
    this.addCommand("test", "f", { arg msg;
      var freq = msg[1];
      ("Test command received: " ++ freq).postln;
    });
    
    // Define Direct Mode synth: zx->L amp, zy->R amp
    SynthDef(\mandeljinn_direct, {
      arg ampL=0, ampR=0, freq=220;
      var sigL, sigR;
      
      // Simple sine wave, amplitude controlled by orbit coordinates
      sigL = SinOsc.ar(freq, 0, ampL);
      sigR = SinOsc.ar(freq, 0, ampR);
      
      Out.ar(0, [sigL, sigR]);
    }).add;
    
    // Define simple test synth (for future use)
    SynthDef(\mandeljinn_voice, {
      arg freq=440, amp=0.1, pan=0, duration=0.5;
      var sig, env;
      
      sig = SinOsc.ar(freq, 0, amp);
      env = EnvGen.kr(Env.perc(0.01, duration), doneAction: 2);
      sig = sig * env;
      sig = Pan2.ar(sig, pan);
      
      Out.ar(0, sig);
    }).add;
  }
  
  free {
    ~audio_enabled = false;
    if (~direct_synth.notNil) {
      ~direct_synth.free;
    };
    ~mandeljinn_group.freeAll;
  }
}
