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
    
    // Update orbit command - receives fractal coordinates
    this.addCommand("updateOrbit", "ff", { arg msg;
      var zx = msg[1];
      var zy = msg[2];
      
      ~current_zx = zx;
      ~current_zy = zy;
      
      // Debug output
      ("Orbit update: zx=" ++ zx ++ " zy=" ++ zy).postln;
    });
    
    // Test command (keep for now)
    this.addCommand("test", "f", { arg msg;
      var freq = msg[1];
      ("Test command received: " ++ freq).postln;
    });
    
    // Define simple synth (for future use)
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
    ~mandeljinn_group.freeAll;
  }
}
