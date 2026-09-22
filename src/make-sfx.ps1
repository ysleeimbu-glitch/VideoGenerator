# twinkle.wav — a short "sparkle" for text entrances (0.9 s, 44.1 kHz stereo)
param([string]$Out = "$PSScriptRoot\twinkle.wav")
Add-Type @"
using System; using System.IO;
public static class Sfx {
  public static void Make(string path) {
    int sr = 44100; double dur = 0.9; int n = (int)(sr * dur);
    double[] notes = { 1046.5, 1318.5, 1568.0, 2093.0, 2637.0 };   // C6 E6 G6 C7 E7 — rising arpeggio
    float[] L = new float[n], R = new float[n]; var rnd = new Random(11);
    for (int i = 0; i < n; i++) {
      double t = i / (double)sr; double v = 0;
      for (int k = 0; k < notes.Length; k++) {
        double ts = t - k * 0.07; if (ts < 0) continue;
        double env = Math.Exp(-ts * 9.0); double f = notes[k];
        v += (Math.Sin(2 * Math.PI * f * ts) + 0.35 * Math.Sin(2 * Math.PI * f * 2 * ts) + 0.12 * Math.Sin(2 * Math.PI * f * 3 * ts)) * env * 0.22;
      }
      // shimmer: tiny random high pings
      if (t > 0.05 && t < 0.6 && rnd.NextDouble() < 0.004) { }
      double sh = 0; for (int k = 0; k < 6; k++) { double ts = t - 0.12 - k * 0.09; if (ts >= 0) sh += Math.Sin(2 * Math.PI * (4000 + 600 * k) * ts) * Math.Exp(-ts * 30) * 0.05; }
      v += sh; double fade = Math.Min(1, (dur - t) / 0.15);
      double pan = 0.5 + 0.5 * Math.Sin(t * 8);
      L[i] = (float)(v * fade * (1.0 - 0.35 * pan)); R[i] = (float)(v * fade * (0.65 + 0.35 * pan));
    }
    float peak = 0; for (int i = 0; i < n; i++) peak = Math.Max(peak, Math.Max(Math.Abs(L[i]), Math.Abs(R[i])));
    float g = (float)(Math.Pow(10, -12.0 / 20) / Math.Max(peak, 1e-6));
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
[Sfx]::Make($Out)
"made $Out $((Get-Item $Out).Length) bytes"
