# soft corporate background music -> bgm.wav (44.1 kHz, 16-bit stereo)
param([int]$Seconds = 300, [string]$Out = "$PSScriptRoot\bgm.wav")
Add-Type @"
using System; using System.IO;
public static class Bgm {
  static double Note(int midi) { return 440.0 * Math.Pow(2.0, (midi - 69) / 12.0); }
  static double Env(double t, double a, double d, double s, double r, double len) {
    if (t < 0) return 0; if (t < a) return t / a; if (t < a + d) return 1 - (1 - s) * (t - a) / d;
    if (t < len) return s; double x = t - len; return x < r ? s * (1 - x / r) : 0;
  }
  public static void Make(string path, int seconds) {
    int sr = 44100; int n = sr * seconds; double bpm = 108; double beat = 60.0 / bpm; double bar = beat * 4;
    // I - V - vi - IV  (C major), 2 bars each, with 7ths for warmth
    int[][] chords = { new[]{60,64,67,71}, new[]{55,59,62,67}, new[]{57,60,64,67}, new[]{53,57,60,64} };
    int[] bass = { 36, 43, 45, 41 };
    float[] L = new float[n], R = new float[n];
    double[] delayL = new double[(int)(sr*0.31)], delayR = new double[(int)(sr*0.23)]; int dl = 0, dr = 0;
    Random rnd = new Random(7);
    for (int i = 0; i < n; i++) {
      double t = i / (double)sr; double song = t;
      int prog = (int)Math.Floor(song / (bar * 2)) % 4; double tc = song % (bar * 2);
      int[] ch = chords[prog];
      // pad: soft detuned sines with slow swell
      double pad = 0;
      for (int k = 0; k < ch.Length; k++) { double f = Note(ch[k]); pad += Math.Sin(2*Math.PI*f*t) * 0.5 + Math.Sin(2*Math.PI*f*1.003*t) * 0.3 + Math.Sin(2*Math.PI*f*2*t) * 0.12; }
      pad *= 0.11 * Env(tc, 0.9, 0.5, 0.85, 0.8, bar*2 - 0.8);
      // pluck arpeggio on 8ths: cycles through chord tones one octave up
      double eighth = beat / 2; int step = (int)Math.Floor(song / eighth); double te = song - step * eighth;
      int[] pattern = { 0, 1, 2, 3, 2, 1, 2, 3 }; int idx = pattern[step % 8]; double fp = Note(ch[idx] + 12);
      double pl = (Math.Sin(2*Math.PI*fp*te) * 0.6 + Math.Sin(2*Math.PI*fp*2*te) * 0.25 + Math.Sin(2*Math.PI*fp*3*te) * 0.08) * Math.Exp(-te * 7.0) * 0.16;
      // bass: one note per bar, gentle
      double tb = song % bar; double fb = Note(bass[prog]);
      double bs = (Math.Sin(2*Math.PI*fb*t) + 0.3*Math.Sin(2*Math.PI*fb*2*t)) * Env(tb, 0.02, 0.3, 0.6, 0.25, bar - 0.3) * 0.13;
      // soft kick on beats 1 and 3, softer on 2 and 4
      double tk = song % beat; int bt = (int)Math.Floor(song / beat) % 4; double kAmp = (bt == 0 || bt == 2) ? 0.16 : 0.07;
      double kick = Math.Sin(2*Math.PI*(50 + 80*Math.Exp(-tk*30))*tk) * Math.Exp(-tk*14) * kAmp;
      // shaker-ish tick on off-beats
      double ts = (song + eighth) % beat; double tick = (rnd.NextDouble()*2-1) * Math.Exp(-ts*90) * 0.025;
      double dry = pad + pl + bs + kick + tick;
      // fade in/out
      double fade = Math.Min(1, t / 3.0) * Math.Min(1, (seconds - t) / 6.0);
      dry *= fade;
      // stereo widen + simple delay
      double l = dry + delayL[dl] * 0.28, r = dry + delayR[dr] * 0.28;
      delayL[dl] = l * 0.6; delayR[dr] = r * 0.6; dl = (dl + 1) % delayL.Length; dr = (dr + 1) % delayR.Length;
      L[i] = (float)l; R[i] = (float)r;
    }
    // normalize to -16 dBFS peak (quiet background)
    float peak = 0; for (int i = 0; i < n; i++) { peak = Math.Max(peak, Math.Max(Math.Abs(L[i]), Math.Abs(R[i]))); }
    float g = (float)(Math.Pow(10, -16.0/20) / Math.Max(peak, 1e-6));
    using (var fs = new FileStream(path, FileMode.Create)) using (var w = new BinaryWriter(fs)) {
      int bytes = n * 4;
      w.Write(new[]{'R','I','F','F'}); w.Write(36 + bytes); w.Write(new[]{'W','A','V','E'}); w.Write(new[]{'f','m','t',' '});
      w.Write(16); w.Write((short)1); w.Write((short)2); w.Write(sr); w.Write(sr * 4); w.Write((short)4); w.Write((short)16);
      w.Write(new[]{'d','a','t','a'}); w.Write(bytes);
      for (int i = 0; i < n; i++) { w.Write((short)(L[i] * g * 32767)); w.Write((short)(R[i] * g * 32767)); }
    }
  }
}
"@
[Bgm]::Make($Out, $Seconds)
"made $Out $((Get-Item $Out).Length) bytes"
