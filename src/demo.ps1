# Autodesk 설치 자동화 — 홍보 영상용 자동 시연 + OBS 녹화
# 사용: demo.cmd (관리자로 뜸)  ·  시험: powershell -File demo.ps1 -Test [-NoObs]   (비승격, RUN 생략)
param(
  [switch]$Test,        # 비승격 시험: 앱을 RunAsInvoker 로 띄우고 RUN 은 생략
  [switch]$NoObs,       # 녹화 없이
  [switch]$SnapAll,     # 본 실행에서도 화면을 파일로 남긴다(진행 연출 확인용)
  [int]$RunSeconds = 95 # RUN 뒤 지켜보는 시간
)
$ErrorActionPreference = 'Continue'
$root = $PSScriptRoot
Start-Transcript -Path "$root\demo-transcript.txt" -Force | Out-Null
[Console]::OutputEncoding = [Text.Encoding]::UTF8
function Log($m) { Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $m) }
function Snap([string]$name) { if (-not ($Test -or $SnapAll)) { return }; $b = New-Object System.Drawing.Bitmap 1920, 1080; $g = [System.Drawing.Graphics]::FromImage($b); $g.CopyFromScreen(0, 0, 0, 0, $b.Size); $g.Dispose(); $b.Save("$root\snap_$name.png"); $b.Dispose() }

Add-Type -AssemblyName System.Windows.Forms, System.Drawing, UIAutomationClient, UIAutomationTypes
Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing @"
using System; using System.Drawing; using System.Drawing.Drawing2D; using System.Runtime.InteropServices; using System.Windows.Forms;
public static class N {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  public static readonly IntPtr TOPMOST = new IntPtr(-1), NOTOPMOST = new IntPtr(-2);
  // 이미 TOPMOST 인 창에 HWND_TOPMOST 를 다시 주면 자리가 안 바뀐다 — HWND_TOP 이라야 최상위 무리 안에서 맨 위로 간다(실기 2026-09-22)
  public static void Top(IntPtr h) { SetWindowPos(h, IntPtr.Zero, 0, 0, 0, 0, 0x0013); } // HWND_TOP · NOSIZE|NOMOVE|NOACTIVATE
  public static void Under(IntPtr h, IntPtr above) { SetWindowPos(h, above, 0, 0, 0, 0, 0x0013); }
}
// 공통: 활성화 없이 뜨고(포커스 안 뺏음), 클릭은 통과
public class Overlay : Form {
  public Overlay() { FormBorderStyle = FormBorderStyle.None; StartPosition = FormStartPosition.Manual; TopMost = true; ShowInTaskbar = false; }
  protected override bool ShowWithoutActivation { get { return true; } }
  protected override CreateParams CreateParams { get { var p = base.CreateParams; p.ExStyle |= 0x08000000 | 0x00000020 | 0x00000080; return p; } }
  public void Raise() { N.Top(Handle); }
}
// 배경 디자인 — 짙은 남색 그라데이션 + 브랜드색 빛 + 점 격자. 한 번 그려 두고 창마다 제 자리만 오려 그린다(이음매 없음)
public static class Bg {
  static Bitmap cache;
  public static Bitmap Cache() {
    if (cache != null) return cache;
    var scr = Screen.PrimaryScreen.Bounds; var b = new Bitmap(scr.Width, scr.Height);
    using (var g = Graphics.FromImage(b)) {
      g.SmoothingMode = SmoothingMode.AntiAlias;
      using (var lg = new LinearGradientBrush(new Rectangle(0, 0, scr.Width, scr.Height), Color.FromArgb(16, 26, 66), Color.FromArgb(7, 11, 32), LinearGradientMode.Vertical)) g.FillRectangle(lg, 0, 0, scr.Width, scr.Height);
      Glow(g, 1500, 80, 950, Color.FromArgb(80, 47, 128, 237));
      Glow(g, 200, 1000, 850, Color.FromArgb(60, 30, 190, 170));
      Glow(g, 1800, 950, 650, Color.FromArgb(45, 255, 150, 60));
      Glow(g, 900, 540, 700, Color.FromArgb(28, 120, 160, 255));
      using (var d = new SolidBrush(Color.FromArgb(26, 255, 255, 255))) for (int y = 24; y < scr.Height; y += 48) for (int x = 24; x < scr.Width; x += 48) g.FillEllipse(d, x - 1.5f, y - 1.5f, 3f, 3f);
      using (var lb = new LinearGradientBrush(new Point(0, 0), new Point(scr.Width, scr.Height), Color.FromArgb(0, 255, 255, 255), Color.FromArgb(16, 255, 255, 255))) g.FillRectangle(lb, 0, 0, scr.Width, scr.Height);
    }
    cache = b; return b;
  }
  static void Glow(Graphics g, float cx, float cy, float r, Color c) {
    using (var p = new GraphicsPath()) { p.AddEllipse(cx - r, cy - r, 2 * r, 2 * r); using (var b = new PathGradientBrush(p)) { b.CenterColor = c; b.SurroundColors = new[] { Color.FromArgb(0, c) }; g.FillPath(b, p); } }
  }
  public static void Paint(Graphics g, Rectangle formBounds) {
    var st = g.Save(); g.InterpolationMode = InterpolationMode.NearestNeighbor; g.CompositingMode = CompositingMode.SourceCopy;
    g.DrawImage(Cache(), new Rectangle(0, 0, formBounds.Width, formBounds.Height), formBounds, GraphicsUnit.Pixel);
    g.Restore(st);
  }
}
public class Backdrop : Overlay {
  // 배경은 TopMost 가 아니다 — 앱(TopMost) 바로 아래에 둔다. 그래야 어떤 순서 꼬임에도 앱을 덮지 못한다
  public Backdrop() { BackColor = Color.Black; Bounds = Screen.PrimaryScreen.Bounds; TopMost = false; SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint, true); }
  protected override void OnPaint(PaintEventArgs e) { Bg.Paint(e.Graphics, Bounds); }
}
// 어둡게 + 구멍(스포트라이트)
public class Spot : Overlay {
  Rectangle hole = Rectangle.Empty;
  public Spot() { BackColor = Color.Black; Opacity = 0.62; TransparencyKey = Color.Magenta; Bounds = Screen.PrimaryScreen.Bounds; }
  public void ShowHole(Rectangle r) { hole = r; if (!Visible) Show(); Raise(); Invalidate(); Update(); Application.DoEvents(); }
  public void HideAll() { if (Visible) Hide(); Application.DoEvents(); }
  protected override void OnPaint(PaintEventArgs e) {
    e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
    if (hole.IsEmpty) return;
    using (var path = Round(hole, 14)) using (var b = new SolidBrush(Color.Magenta)) e.Graphics.FillPath(b, path);
  }
  public static GraphicsPath Round(Rectangle r, int rad) {
    var p = new GraphicsPath(); int d = rad * 2;
    p.AddArc(r.X, r.Y, d, d, 180, 90); p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
    p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90); p.AddArc(r.X, r.Bottom - d, d, d, 90, 90); p.CloseFigure(); return p;
  }
}
// 클릭 지점 링
public class Ring : Overlay {
  int size = 110; Color col;
  public Ring(Color c) { col = c; BackColor = Color.Magenta; TransparencyKey = Color.Magenta; Size = new Size(size, size); }
  public void Pulse(int cx, int cy, int ms) {
    Bounds = new Rectangle(cx - size / 2, cy - size / 2, size, size); Show(); Raise(); Application.DoEvents();
    var sw = System.Diagnostics.Stopwatch.StartNew();
    while (sw.ElapsedMilliseconds < ms) {
      double t = sw.ElapsedMilliseconds / (double)ms; int s = (int)(size * (1.0 - 0.5 * t)); if (s < 24) s = 24;
      Bounds = new Rectangle(cx - s / 2, cy - s / 2, s, s); Invalidate(); Application.DoEvents(); System.Threading.Thread.Sleep(12);
    }
    Hide(); Application.DoEvents();
  }
  protected override void OnPaint(PaintEventArgs e) {
    e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
    using (var pen = new Pen(col, 6)) e.Graphics.DrawEllipse(pen, 4, 4, Width - 9, Height - 9);
    using (var b = new SolidBrush(col)) e.Graphics.FillEllipse(b, Width / 2 - 5, Height / 2 - 5, 10, 10);
  }
}
// 클릭 지점 옆 툴팁
public class Tip : Overlay {
  string text = ""; Font font = new Font("Malgun Gothic", 15f, FontStyle.Bold);
  public Tip() { BackColor = Color.Magenta; TransparencyKey = Color.Magenta; }
  public void ShowAt(int x, int y, string t) {
    text = t; var sz = TextRenderer.MeasureText(text, font); int w = sz.Width + 34, h = sz.Height + 22;
    int px = x + 28, py = y + 26; var scr = Screen.PrimaryScreen.Bounds;
    if (px + w > scr.Right - 10) px = x - w - 28; if (py + h > scr.Bottom - 120) py = y - h - 26;
    Bounds = new Rectangle(px, py, w, h); if (!Visible) Show(); Raise(); Invalidate(); Update(); Application.DoEvents();
  }
  public void HideAll() { if (Visible) Hide(); Application.DoEvents(); }
  protected override void OnPaint(PaintEventArgs e) {
    e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
    var r = new Rectangle(1, 1, Width - 3, Height - 3);
    using (var p = Spot.Round(r, 10)) { using (var b = new SolidBrush(Color.FromArgb(28, 28, 30))) e.Graphics.FillPath(b, p); using (var pen = new Pen(Color.FromArgb(255, 196, 0), 2.5f)) e.Graphics.DrawPath(pen, p); }
    TextRenderer.DrawText(e.Graphics, text, font, new Rectangle(0, 0, Width, Height), Color.White, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);
  }
}
// 인트로 — 캐릭터 · 제목 · 태그라인을 검정 위에 애니메이션으로
public class Intro : Overlay {
  Image[] imgs; string[] words; string[] lines; double t, dur;
  Font fTitle = new Font("Malgun Gothic", 74f, FontStyle.Bold), fSub = new Font("Malgun Gothic", 30f, FontStyle.Bold),
       fSmall = new Font("Malgun Gothic", 22f, FontStyle.Bold), fWord = new Font("Malgun Gothic", 24f, FontStyle.Bold);
  Image[] flips;
  public Intro(Image[] imgs, string[] words, string[] lines) {
    this.imgs = imgs; this.words = words; this.lines = lines; BackColor = Color.Black; Bounds = Screen.PrimaryScreen.Bounds;
    SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint, true);
    flips = new Image[imgs.Length];
    for (int i = 0; i < imgs.Length; i++) { var f = (Image)imgs[i].Clone(); f.RotateFlip(RotateFlipType.RotateNoneFlipY); flips[i] = f; }
  }
  // JPG 의 "검정" 은 압축 잡음이 섞여 순검정 위에서 네모가 비친다 — 거의 검은 픽셀을 투명하게 뺀다(가장자리는 부드럽게)
  public static Bitmap KeyBlack(Image src) {
    var b = new Bitmap(src.Width, src.Height, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(b)) g.DrawImage(src, 0, 0, src.Width, src.Height);
    var rect = new Rectangle(0, 0, b.Width, b.Height);
    var d = b.LockBits(rect, System.Drawing.Imaging.ImageLockMode.ReadWrite, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
    int n = d.Stride * b.Height; var buf = new byte[n]; System.Runtime.InteropServices.Marshal.Copy(d.Scan0, buf, 0, n);
    for (int y = 0; y < b.Height; y++) { int o = y * d.Stride;
      for (int x = 0; x < b.Width; x++) { int i = o + x * 4; int m = Math.Max(buf[i + 2], Math.Max(buf[i + 1], buf[i]));
        if (m < 30) buf[i + 3] = 0; else if (m < 70) buf[i + 3] = (byte)((m - 30) * 255 / 40); } }
    System.Runtime.InteropServices.Marshal.Copy(buf, 0, d.Scan0, n);
    b.UnlockBits(d); return b;
  }
  // 3D 느낌: 바닥 그림자(부드러운 타원) + 바닥 반사(뒤집어 흐리게) + 살짝 떠 있는 움직임
  // 흰 바탕에 검정 로고(PNG) → 투명 바탕에 흰 로고. 어두운 만큼 불투명하게
  public static Bitmap WhiteFromDark(Image src) {
    var b = new Bitmap(src.Width, src.Height, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(b)) { g.Clear(Color.White); g.DrawImage(src, 0, 0, src.Width, src.Height); }
    var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), System.Drawing.Imaging.ImageLockMode.ReadWrite, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
    int n = d.Stride * b.Height; var buf = new byte[n]; System.Runtime.InteropServices.Marshal.Copy(d.Scan0, buf, 0, n);
    for (int y = 0; y < b.Height; y++) { int o = y * d.Stride;
      for (int x = 0; x < b.Width; x++) { int i = o + x * 4; int lum = (buf[i] + buf[i + 1] + buf[i + 2]) / 3;
        buf[i] = 255; buf[i + 1] = 255; buf[i + 2] = 255; buf[i + 3] = (byte)(255 - lum); } }
    System.Runtime.InteropServices.Marshal.Copy(buf, 0, d.Scan0, n); b.UnlockBits(d); return b;
  }
  public static void DrawFit(Graphics g, Image im, float cx, float cy, float w, float alpha) {
    if (im == null || alpha <= 0) return; if (alpha > 1) alpha = 1; float h = w * im.Height / im.Width;
    using (var ia = new System.Drawing.Imaging.ImageAttributes()) { var cm = new System.Drawing.Imaging.ColorMatrix(); cm.Matrix33 = alpha; ia.SetColorMatrix(cm);
      g.DrawImage(im, new Rectangle((int)(cx - w / 2), (int)(cy - h / 2), (int)w, (int)h), 0, 0, im.Width, im.Height, GraphicsUnit.Pixel, ia); }
  }
  public static Image Logo, Badge;   // 상상진화 로고 · Autodesk Gold Partner (흰색판) — 스크립트가 넣어 준다
  public static void DrawShadow(Graphics g, float cx, float cy, float w, float h, float alpha) {
    if (alpha <= 0) return; if (alpha > 1) alpha = 1;
    using (var p = new GraphicsPath()) {
      p.AddEllipse(cx - w / 2, cy - h / 2, w, h);
      // 배경이 검정이라 검은 그림자는 안 보인다 — 바닥에 푸르스름한 빛 웅덩이를 깔아 "서 있는 면" 을 만든다
      using (var b = new PathGradientBrush(p)) { b.CenterColor = Color.FromArgb((int)(130 * alpha), 90, 120, 180); b.SurroundColors = new[] { Color.FromArgb(0, 90, 120, 180) }; g.FillPath(b, p); }
    }
  }
  public static void DrawReflection(Graphics g, Image flip, float cx, float top, float size, float alpha) {
    if (alpha <= 0 || size <= 2) return;
    float h = size * 0.38f;
    using (var ia = new System.Drawing.Imaging.ImageAttributes()) {
      var cm = new System.Drawing.Imaging.ColorMatrix(); cm.Matrix33 = 0.12f * alpha; ia.SetColorMatrix(cm);
      var r = new Rectangle((int)(cx - size / 2), (int)top, (int)size, (int)h);
      g.DrawImage(flip, r, 0, 0, flip.Width, (int)(flip.Height * 0.38f), GraphicsUnit.Pixel, ia);
      // (배경이 남색 그라데이션이라 검정 페이드는 안 쓴다 — 반사는 얇고 흐리게만)
    }
  }
  public void RenderFrame(double tt, double d, string path) { t = tt; dur = d; using (var b = new Bitmap(Width, Height)) { DrawToBitmap(b, ClientRectangle); b.Save(path); } }
  const float TX = 1290f;   // 제목 블록 가운데 x — 오른쪽으로 치우치지 않게
  static Font FitFont(Graphics g, string s, Font f, float maxW) { var cur = f; float w = g.MeasureString(s, cur).Width; float fs = f.Size; while (w > maxW && fs > 14f) { fs -= 1f; cur = new Font(f.FontFamily, fs, f.Style); w = g.MeasureString(s, cur).Width; } return cur == f ? (Font)f.Clone() : cur; }
  public string Twinkle;                                   // 글자 등장 때 울릴 별빛 소리(wav). 없으면 조용히
  static readonly double[] cues = { 1.0, 2.2, 2.9, 6.5, 8.8, 11.1 };   // 제목 · 부제 · 로고 · 태그라인 셋
  public void Play(double seconds) {
    dur = seconds; t = 0; Show(); Raise(); Application.DoEvents();
    var sw = System.Diagnostics.Stopwatch.StartNew(); int next = 0;
    while (sw.Elapsed.TotalSeconds < seconds) {
      t = sw.Elapsed.TotalSeconds;
      if (Twinkle != null && next < cues.Length && t >= cues[next]) { try { new System.Media.SoundPlayer(Twinkle).Play(); } catch {} next++; }
      Invalidate(); Application.DoEvents(); System.Threading.Thread.Sleep(14);
    }
    Hide(); Application.DoEvents();
  }
  static double Ease(double x) { if (x <= 0) return 0; if (x >= 1) return 1; return 1 - Math.Pow(1 - x, 3); }
  static double Back(double x) { if (x <= 0) return 0; if (x >= 1) return 1; double c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.Pow(x - 1, 3) + c1 * Math.Pow(x - 1, 2); }
  public static void DrawImg(Graphics g, Image im, float cx, float cy, float size, float alpha) {
    if (alpha <= 0 || size <= 2) return; if (alpha > 1) alpha = 1;
    using (var ia = new System.Drawing.Imaging.ImageAttributes()) {
      var cm = new System.Drawing.Imaging.ColorMatrix(); cm.Matrix33 = alpha; ia.SetColorMatrix(cm);
      var r = new Rectangle((int)(cx - size / 2), (int)(cy - size / 2), (int)size, (int)size);
      g.DrawImage(im, r, 0, 0, im.Width, im.Height, GraphicsUnit.Pixel, ia);
    }
  }
  public static void DrawText(Graphics g, string s, Font f, float cx, float cy, Color c, float alpha) {
    if (alpha <= 0) return; if (alpha > 1) alpha = 1;
    var sz = g.MeasureString(s, f);
    using (var b = new SolidBrush(Color.FromArgb((int)(255 * alpha), c))) g.DrawString(s, f, b, cx - sz.Width / 2, cy - sz.Height / 2);
  }
  // 글자가 왼쪽부터 하나씩 커졌다 제자리로 내려앉으며 나타난다 (progress 0~1)
  public static void DrawTextChars(Graphics g, string s, Font f, float cx, float cy, Color c, double progress) {
    if (progress <= 0) return; var fmt = StringFormat.GenericTypographic; fmt.FormatFlags |= StringFormatFlags.MeasureTrailingSpaces;
    float total = g.MeasureString(s, f, 9999, fmt).Width; float x = cx - total / 2; int n = s.Length; double spread = 3.0;
    for (int i = 0; i < n; i++) {
      string ch = s[i].ToString(); float w = g.MeasureString(ch, f, 9999, fmt).Width;
      double pi = (progress * (n + spread) - i) / spread; pi = pi < 0 ? 0 : (pi > 1 ? 1 : pi); double e = 1 - Math.Pow(1 - pi, 3);
      if (e > 0) {
        float sc = (float)(1.7 - 0.7 * e); float dy = (float)(-28 * (1 - e)); float h = f.GetHeight(g);
        var st = g.Save(); g.TranslateTransform(x + w / 2, cy + dy); g.ScaleTransform(sc, sc);
        using (var b = new SolidBrush(Color.FromArgb((int)(255 * e), c))) g.DrawString(ch, f, b, -w / 2, -h / 2, fmt);
        g.Restore(st);
      }
      x += w;
    }
  }
  protected override void OnPaint(PaintEventArgs e) {
    var g = e.Graphics; Bg.Paint(g, Bounds);
    g.SmoothingMode = SmoothingMode.AntiAlias; g.InterpolationMode = InterpolationMode.HighQualityBicubic;
    g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAlias;
    // A. 도시 장면이 왼쪽에 서서히 — 살짝 떠서 흔들리고, 바닥 빛 + 반사로 입체감
    double a = Ease(t / 1.6); float sceneSize = (float)(500 + 60 * a); float sx = (float)(410 + 8 * Math.Sin(t * 0.7)), sy = (float)(395 + 6 * Math.Sin(t * 1.1));
    DrawShadow(g, sx, sy + sceneSize / 2 + 10, sceneSize * 0.9f, 60, (float)a);
    DrawImg(g, imgs[0], sx, sy, sceneSize, (float)a);
    DrawReflection(g, flips[0], sx, sy + sceneSize / 2, sceneSize, (float)a * 0.5f);
    // B. 제목 · 부제 · 회사
    double b = Ease((t - 1.0) / 1.6); DrawTextChars(g, "Autodesk 설치 자동화", fTitle, TX, 225, Color.White, b);
    double b2 = Ease((t - 2.2) / 0.9); DrawText(g, "클릭 몇 번이면 끝나는 무인 설치", fSub, (float)(TX + 90 * (1 - b2)), 355, Color.FromArgb(255, 196, 0), (float)b2);   // 오른쪽에서 밀려 들어옴
    double b3 = Back((t - 2.9) / 0.7); DrawFit(g, Logo, TX, 480, (float)(300 * b3), (float)Ease((t - 2.9) / 0.4));                 // 상상진화 로고 — 튕기며 커짐
    DrawFit(g, Badge, 1720, 70, 230, 0.85f * (float)Ease((t - 3.0) / 1.0));                          // Autodesk Gold Partner — 오른쪽 아래
    // C. 캐릭터 넷 — 통통 튀며 등장한 뒤 계속 활동: 뛰어오르기(착지 때 눌림) · 좌우 갸웃 · 살짝 이동
    for (int i = 0; i < 4 && i + 1 < imgs.Length; i++) {
      double s = Back((t - 3.6 - i * 0.5) / 0.6); if (s <= 0) continue;
      double life = t - 3.6 - i * 0.5;
      double hop = Math.Abs(Math.Sin(life * 3.1 + i * 0.9));           // 0(착지)~1(꼭대기)
      float jump = (float)(hop * hop * 46);                              // 뛰는 높이
      float squash = (float)(1 - hop);                                   // 착지 근처에서 눌림
      float qx = 1f + 0.10f * squash, qy = 1f - 0.10f * squash;
      float rot = (float)(7 * Math.Sin(life * 2.3 + i * 1.7));
      float cx = 330 + i * 420 + (float)(22 * Math.Sin(life * 0.8 + i)); float size = (float)(230 * s); float cy = 845 - jump;
      DrawShadow(g, cx, 845 + size / 2 + 8, size * (0.78f - 0.25f * (float)hop), 28, (float)s * (1f - 0.4f * (float)hop));
      var st = g.Save(); g.TranslateTransform(cx, cy); g.RotateTransform(rot); g.ScaleTransform(qx, qy);
      DrawImg(g, imgs[1 + i], 0, 0, size, 1f);
      g.Restore(st);
      DrawReflection(g, flips[1 + i], cx, 845 + size / 2, size, (float)s * (1f - 0.5f * (float)hop));
      if (i < words.Length) { double we = Ease((t - 3.9 - i * 0.5) / 0.4); DrawText(g, words[i], fWord, cx, (float)(1005 + 18 * (1 - we)), Color.White, (float)we); }
    }
    // D. 태그라인이 오른쪽에서 번갈아
    if (t > 6.5 && t < dur - 1.2 && lines.Length > 0) {
      double ph = (t - 6.5) % 2.3; int k = (int)((t - 6.5) / 2.3) % lines.Length;
      double al = Math.Min(Ease(ph / 0.4), Ease((2.3 - ph) / 0.4));
      float ty = (float)(612 + 26 * (1 - Ease(ph / 0.4))); using (var ff = FitFont(g, lines[k], fSub, 1000f)) DrawText(g, lines[k], ff, TX, ty, Color.White, (float)al);        // 아래에서 떠오르며
    }
    // E. 마지막 1.2초 검정으로
    if (t > dur - 1.2) { double f = Math.Min(1, (t - (dur - 1.2)) / 1.2); using (var br = new SolidBrush(Color.FromArgb((int)(255 * f), 0, 0, 0))) g.FillRectangle(br, ClientRectangle); }
  }
}
// 화면 왼쪽 안내 캐릭터 — 떠 있고, 말할 때 입이 움직이고, 말풍선에 툴팁과 같은 문구
public class Guide : Overlay {
  Image im, flip; string text = ""; System.Diagnostics.Stopwatch sw = System.Diagnostics.Stopwatch.StartNew();
  double speakUntil = 0; Color skin; Random rnd = new Random(3);
  Font f = new Font("Malgun Gothic", 16f, FontStyle.Bold);
  const float SIZE = 270f; const float MX = 158f, MY = 152f;   // 그림(320px) 안의 입 위치
  public Guide(Image im) {
    this.im = im; flip = (Image)im.Clone(); flip.RotateFlip(RotateFlipType.RotateNoneFlipY);
    try { var bm = im as Bitmap; skin = bm != null ? bm.GetPixel((int)MX, (int)(MY - 16)) : Color.FromArgb(250, 240, 235); if (skin.A < 200) skin = Color.FromArgb(250, 240, 235); } catch { skin = Color.FromArgb(250, 240, 235); }
    BackColor = Color.Black; Bounds = new Rectangle(20, 180, 540, 790);
    SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint, true);
  }
  public bool Dimmed;   // 스포트라이트가 켜진 동안 배경을 함께 어둡게 (캐릭터 · 말풍선은 밝게)
  public void Say(string s) { text = s; speakUntil = sw.Elapsed.TotalSeconds + Math.Max(1.3, Math.Min(4.0, 0.11 * s.Length)); if (!Visible) { Show(); } Raise(); Invalidate(); Update(); Application.DoEvents(); }
  public void RenderFrame(string s, string path) { text = s; speakUntil = sw.Elapsed.TotalSeconds + 5; using (var b = new Bitmap(Width, Height)) { DrawToBitmap(b, ClientRectangle); b.Save(path); } }
  public void Tick() { if (Visible) { Invalidate(); Update(); } }
  protected override void OnPaint(PaintEventArgs e) {
    var g = e.Graphics; Bg.Paint(g, Bounds);
    g.SmoothingMode = SmoothingMode.AntiAlias; g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAlias;

    double t = sw.Elapsed.TotalSeconds; float bob = (float)(7 * Math.Sin(t * 2.2)); float size = SIZE; float cx = Width / 2f, cy = 560 + bob;
    Intro.DrawShadow(g, cx, 560 + size / 2 + 8, size * 0.7f - bob * 2, 30, 1f);
    Intro.DrawImg(g, im, cx, cy, size, 1f);
    // 입: 말하는 동안 닫힘·반쯤·활짝을 오간다. 원래 입은 살색으로 덮고 위에 그린다
    float sc = size / 320f; float mx = cx - size / 2 + MX * sc, my = cy - size / 2 + MY * sc;
    bool speaking = t < speakUntil;
    int phase = speaking ? (int)(t * 9) % 4 : 0;   // 0 닫힘 1 반 2 활짝 3 반
    using (var b = new SolidBrush(skin)) g.FillEllipse(b, mx - 15 * sc, my - 12 * sc, 30 * sc, 22 * sc);
    float open = phase == 0 ? 0f : (phase == 2 ? 1f : 0.5f);
    if (open == 0f) { using (var pen = new Pen(Color.FromArgb(120, 40, 40), 2.2f * sc)) g.DrawArc(pen, mx - 9 * sc, my - 7 * sc, 18 * sc, 12 * sc, 15, 150); }
    else {
      float w = (14 + 8 * open) * sc, h = (5 + 11 * open) * sc;
      using (var b = new SolidBrush(Color.FromArgb(150, 40, 45))) g.FillEllipse(b, mx - w / 2, my - h / 2 + 1, w, h);
      if (open >= 1f) using (var b = new SolidBrush(Color.FromArgb(235, 110, 120))) g.FillEllipse(b, mx - w * 0.3f, my + h * 0.1f, w * 0.6f, h * 0.45f);
      using (var pen = new Pen(Color.FromArgb(110, 35, 35), 1.4f * sc)) g.DrawEllipse(pen, mx - w / 2, my - h / 2 + 1, w, h);
    }
    Intro.DrawReflection(g, flip, cx, cy + size / 2, size, 1f);
    if (Dimmed) using (var db = new SolidBrush(Color.FromArgb(158, 0, 0, 0))) g.FillRectangle(db, ClientRectangle);   // 스포트라이트 중엔 캐릭터까지 어둡게, 말풍선만 밝게
    if (text.Length > 0) {
      int bw = Width - 24; var flags = TextFormatFlags.WordBreak | TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding;
      var sz = TextRenderer.MeasureText(g, text, f, new Size(bw - 40, 4000), TextFormatFlags.WordBreak | TextFormatFlags.NoPadding);
      int bh = sz.Height + 30; int bx = 12, by = (int)(cy - size / 2 - 30 - bh); if (by < 4) by = 4;
      var r = new Rectangle(bx, by, bw, bh);
      using (var p = Spot.Round(r, 16)) { using (var b = new SolidBrush(Color.FromArgb(245, 245, 247))) g.FillPath(b, p); using (var pen = new Pen(Color.FromArgb(255, 196, 0), 3f)) g.DrawPath(pen, p); }
      using (var b = new SolidBrush(Color.FromArgb(245, 245, 247))) g.FillPolygon(b, new[] { new PointF(cx - 16, by + bh - 1), new PointF(cx + 16, by + bh - 1), new PointF(cx, by + bh + 20) });
      TextRenderer.DrawText(g, text, f, new Rectangle(bx + 20, by + 15, bw - 40, bh - 30), Color.FromArgb(28, 28, 30), flags);
    }
  }
}
// 큰 붉은 커서 + 형광 후광 — 픽셀 알파(UpdateLayeredWindow)로 그려 가장자리가 깨끗하다. 실제 커서는 OBS 가 안 찍는다(capture_cursor=false)
public class CursorFx : Form {
  [DllImport("user32.dll", SetLastError = true)] static extern bool UpdateLayeredWindow(IntPtr hwnd, IntPtr hdcDst, ref N.POINT pptDst, ref SIZE psize, IntPtr hdcSrc, ref N.POINT pptSrc, int crKey, ref BLENDFUNCTION pblend, int dwFlags);
  [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr h); [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr h, IntPtr dc);
  [DllImport("gdi32.dll")] static extern IntPtr CreateCompatibleDC(IntPtr dc); [DllImport("gdi32.dll")] static extern IntPtr SelectObject(IntPtr dc, IntPtr o);
  [DllImport("gdi32.dll")] static extern bool DeleteDC(IntPtr dc); [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr o);
  [StructLayout(LayoutKind.Sequential)] struct SIZE { public int cx, cy; }
  [StructLayout(LayoutKind.Sequential)] struct BLENDFUNCTION { public byte op, flags, alpha, fmt; }
  const int W = 130, HOT = 40; Bitmap bmp;
  public CursorFx() { FormBorderStyle = FormBorderStyle.None; ShowInTaskbar = false; TopMost = true; StartPosition = FormStartPosition.Manual; Bounds = new Rectangle(0, 0, W, W); bmp = Render(); }
  protected override bool ShowWithoutActivation { get { return true; } }
  protected override CreateParams CreateParams { get { var p = base.CreateParams; p.ExStyle |= 0x00080000 | 0x00000020 | 0x08000000 | 0x00000080; return p; } }
  static Bitmap Render() {
    var b = new Bitmap(W, W, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(b)) {
      g.SmoothingMode = SmoothingMode.AntiAlias;
      for (int i = 7; i >= 1; i--) { int r = 12 + i * 6; using (var br = new SolidBrush(Color.FromArgb(20, 160, 255, 40))) g.FillEllipse(br, HOT + 14 - r, HOT + 18 - r, 2 * r, 2 * r); }
      float s = 2.3f; float ox = HOT, oy = HOT;
      PointF[] pts = { new PointF(0, 0), new PointF(0, 16.5f), new PointF(4.3f, 12.8f), new PointF(7.4f, 19.8f), new PointF(10.2f, 18.6f), new PointF(7.1f, 11.7f), new PointF(12.6f, 11.7f) };
      for (int i = 0; i < pts.Length; i++) pts[i] = new PointF(ox + pts[i].X * s, oy + pts[i].Y * s);
      using (var pen = new Pen(Color.FromArgb(200, 255, 255, 255), 6f) { LineJoin = LineJoin.Round }) g.DrawPolygon(pen, pts);
      using (var br = new SolidBrush(Color.FromArgb(236, 48, 44))) g.FillPolygon(br, pts);
      using (var pen = new Pen(Color.FromArgb(120, 0, 0), 1.6f) { LineJoin = LineJoin.Round }) g.DrawPolygon(pen, pts);
    }
    return b;
  }
  public void SetPos(int x, int y) {
    if (!Visible) Show();
    IntPtr scr = GetDC(IntPtr.Zero), mem = CreateCompatibleDC(scr); IntPtr hb = bmp.GetHbitmap(Color.FromArgb(0)); IntPtr old = SelectObject(mem, hb);
    var dst = new N.POINT { X = x - HOT, Y = y - HOT }; var sz = new SIZE { cx = W, cy = W }; var src = new N.POINT { X = 0, Y = 0 };
    var bf = new BLENDFUNCTION { op = 0, flags = 0, alpha = 255, fmt = 1 };
    UpdateLayeredWindow(Handle, scr, ref dst, ref sz, mem, ref src, 0, ref bf, 2);
    SelectObject(mem, old); DeleteObject(hb); DeleteDC(mem); ReleaseDC(IntPtr.Zero, scr);
    N.Top(Handle);
  }
}
// 진행 시뮬레이션 — 실제 배치는 뒤에서 돌고, 앞에는 RUN 직전 화면을 그대로 떠 놓은 그림 위에
// 진행값만 바꿔 그린다(영상용 연출). 제품명·순번·부제는 캡처한 그대로 두고, 퍼센트·상태 칩·세부 문구·막대와
// 상단 상태 줄·전체 막대·통계 타일만 **실제 자리에** 다시 그린다 — 실기 6차에서 제목이 '1 2 3' 으로 바뀌고
// 막대가 제자리를 벗어난 것을 고친 판(2026-09-22).
public class SimRow { public Rectangle Row, Pct, Glyph, Label, Bar; public string Title = ""; }
public class Sim : Overlay {
  public bool StatusMode; SimRow[] rows; Bitmap baseImg; double t; int n;
  public Color Fill = Color.White;
  public Rectangle StText, StPct, StBar; public Rectangle[] StNums = new Rectangle[0], StLabs = new Rectangle[0];
  const double DL = 1.5, EX = 2.5, IN = 5.0, GAP = 0.5; public double Total { get { return n * (DL + EX + IN + GAP) + 1.0; } }   // 줄당 9.5초 — 압축 해제 7초는 10% 가 7초 동안 기어가서 지루했다(실기 7차 피드백)
  static Font Px(float px, FontStyle st) { return new Font("Malgun Gothic", px, st, GraphicsUnit.Pixel); }
  Font fPct = Px(22, FontStyle.Bold), fChip = Px(11, FontStyle.Bold), fSmall = Px(11, FontStyle.Regular), fMuted = Px(13, FontStyle.Regular), fBig = Px(15, FontStyle.Bold), fNum = Px(20, FontStyle.Bold);
  static readonly double[] totalGb = { 2.34, 4.15, 1.62 };
  public Sim(Rectangle area, SimRow[] rows, bool status) {
    StatusMode = status; this.rows = rows; n = rows.Length; Bounds = area; BackColor = Color.White;
    SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint, true);
    baseImg = new Bitmap(area.Width, area.Height);
    using (var g = Graphics.FromImage(baseImg)) g.CopyFromScreen(area.X, area.Y, 0, 0, area.Size);
  }
  // 시험용: 화면 대신 주어진 그림(전체 화면 캡처)에서 오려 온다
  public Sim(Rectangle area, SimRow[] rows, bool status, Bitmap screen) : this(area, rows, status) {
    using (var g = Graphics.FromImage(baseImg)) g.DrawImage(screen, new Rectangle(0, 0, area.Width, area.Height), area, GraphicsUnit.Pixel);
  }
  public void SampleFill(int x, int y) { try { Fill = baseImg.GetPixel(x - Left, y - Top); } catch { } }
  public void Set(double tt) { t = tt; if (!Visible) Show(); Raise(); Invalidate(); Update(); }   // 매 틱 맨 위로 — 앱이 실행 중 스스로 앞으로 나와 연출 창을 덮었다(실기 7차)
  public void Save(string path) { using (var b = new Bitmap(Width, Height)) { DrawToBitmap(b, ClientRectangle); b.Save(path); } }
  // 줄 i 의 상태: 0 대기 1 다운로드 2 압축해제 3 설치 4 완료, 구간 진행률 0~1
  void State(int i, out int st, out double pr) {
    double s = t - i * (DL + EX + IN + GAP); st = 0; pr = 0; if (s < 0) return;
    if (s < DL) { st = 1; pr = s / DL; return; } s -= DL; if (s < EX) { st = 2; pr = s / EX; return; } s -= EX; if (s < IN) { st = 3; pr = s / IN; return; } st = 4; pr = 1;
  }
  // 앱과 같은 가중치: 다운로드 40 · 압축 해제 10 · 설치 50
  static double Prog(int st, double pr) { switch (st) { case 1: return 40 * pr; case 2: return 40 + 10 * pr; case 3: return 50 + 50 * pr; case 4: return 100; default: return 0; } }
  static Color Hex(string h) { return ColorTranslator.FromHtml(h); }
  static Color Fore(int st) { switch (st) { case 1: return Hex("#0B6FD1"); case 2: return Hex("#5B58D6"); case 3: return Hex("#7A44C4"); case 4: return Hex("#1B9E5A"); default: return Hex("#6B7684"); } }
  static Color Back(int st) { switch (st) { case 1: return Hex("#E4F0FC"); case 2: return Hex("#ECEBFB"); case 3: return Hex("#F1E9FB"); case 4: return Hex("#E3F5EB"); default: return Hex("#EEF1F4"); } }
  static string Glyph(int st) { switch (st) { case 1: return "▼"; case 2: return "◆"; case 3: return "▲"; case 4: return "✔"; default: return "○"; } }
  static string StName(int st) { switch (st) { case 1: return "다운로드"; case 2: return "압축 해제"; case 3: return "설치"; case 4: return "완료"; default: return "대기"; } }
  string Detail(int i, int st, double pr) {
    switch (st) {
      case 1: { double tot = totalGb[i % totalGb.Length]; return string.Format("파트 {0}/2  {1:0.00} GB / {2:0.00} GB  (받아 둔 파일 재사용)", pr < 0.5 ? 1 : 2, tot * pr, tot); }
      case 2: return "압축 해제 중...";
      case 3: { int sec = (int)(pr * 372); return string.Format("설치 중 {0}분 {1:00}초 · 구성요소 {2}/12개", sec / 60, sec % 60, (int)(pr * 12)); }
      case 4: return "설치 완료";
      default: return "";
    }
  }
  static Rectangle Off(Rectangle r, int dx, int dy) { r.Offset(dx, dy); return r; }
  protected override void OnPaint(PaintEventArgs e) {
    var g = e.Graphics; g.DrawImageUnscaled(baseImg, 0, 0);
    g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
    if (StatusMode) { PaintStatus(g); return; }
    var muted = Hex("#6B7684"); var track = Hex("#E7EBF0");
    for (int i = 0; i < n; i++) {
      var r = rows[i]; int st; double pr; State(i, out st, out pr); double prog = Prog(st, pr); var fc = Fore(st);
      var row = Off(r.Row, -Left, -Top); var pct = Off(r.Pct, -Left, -Top); var gl = Off(r.Glyph, -Left, -Top); var lb = Off(r.Label, -Left, -Top); var bar = Off(r.Bar, -Left, -Top);
      int right = bar.Right; int inner0 = gl.Width + 5 + lb.Width; int chipX = gl.X - (Math.Max(86, inner0 + 20) - inner0) / 2;
      // 바뀌는 칸만 지운다 — 퍼센트 글자 자리, 그리고 칩부터 막대 끝까지의 띠. 줄 전체를 지우면 카드 테두리와 줄 사이 배경까지 하얗게 먹는다(실기 8차 지적)
      using (var b = new SolidBrush(Fill)) {
        g.FillRectangle(b, pct.X - 3, pct.Y - 1, pct.Width + 6, pct.Height + 2);
        int wy0 = Math.Min(lb.Y - 4, bar.Y - 22), wy1 = Math.Max(lb.Bottom + 4, bar.Bottom + 2);
        g.FillRectangle(b, chipX - 2, wy0, right + 2 - (chipX - 2), wy1 - wy0);
      }
      TextRenderer.DrawText(g, ((int)prog) + "%", fPct, pct, fc, TextFormatFlags.Right | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
      // 상태 칩: 기호 + 이름, 최소 폭 86, 모서리 11, 안쪽 여백 10,3 — 이름이 길어지면 칩이 넓어지고 오른쪽 칸이 밀린다(앱과 같다)
      var gs = TextRenderer.MeasureText(g, Glyph(st), fSmall, Size.Empty, TextFormatFlags.NoPadding); var ls = TextRenderer.MeasureText(g, StName(st), fChip, Size.Empty, TextFormatFlags.NoPadding);
      int inner = gs.Width + 5 + ls.Width; int chipW = Math.Max(86, inner + 20); int chipH = lb.Height + 6; int chipY = lb.Y - 3;
      var chip = new Rectangle(chipX, chipY, chipW, chipH);
      using (var cp = Spot.Round(chip, 11)) using (var b = new SolidBrush(Back(st))) g.FillPath(b, cp);
      int ix = chipX + (chipW - inner) / 2;
      TextRenderer.DrawText(g, Glyph(st), fSmall, new Rectangle(ix, chipY, gs.Width, chipH), fc, TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
      TextRenderer.DrawText(g, StName(st), fChip, new Rectangle(ix + gs.Width + 5, chipY, ls.Width, chipH), fc, TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
      // 세부 문구 + 얇은 막대: 칩 오른쪽 12px 부터 줄 끝까지
      int dx = chip.Right + 12; int dw = Math.Max(20, right - dx);
      string dt = Detail(i, st, pr);
      if (dt.Length > 0) TextRenderer.DrawText(g, dt, fSmall, new Rectangle(dx, bar.Y - 4 - 16, dw, 16), muted, TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPadding);
      var br = new Rectangle(dx, bar.Y, dw, Math.Max(6, bar.Height));
      using (var bp = Spot.Round(br, 3)) using (var b = new SolidBrush(track)) g.FillPath(b, bp);
      int fw = (int)(br.Width * prog / 100.0);
      if (fw > 0) { var fr = new Rectangle(br.X, br.Y, Math.Max(6, fw), br.Height); using (var fp = Spot.Round(fr, 3)) using (var b = new SolidBrush(fc)) g.FillPath(b, fp); }
    }
  }
  void PaintStatus(Graphics g) {
    int done = 0, cur = -1; double overall = 0;
    for (int i = 0; i < n; i++) { int st; double pr; State(i, out st, out pr); if (st == 4) done++; else if (st > 0 && cur < 0) cur = i; overall += Prog(st, pr); }
    overall /= Math.Max(1, n); bool fin = done == n;
    var accent = Hex("#0B6FD1"); var muted = Hex("#6B7684"); var track = Hex("#E7EBF0");
    var stT = Off(StText, -Left, -Top); var stP = Off(StPct, -Left, -Top); var stB = Off(StBar, -Left, -Top);
    // 상태 줄 전체(문구 · 남은 시간 · 퍼센트)를 지우고 다시 그린다
    int top = Math.Min(stT.Y, stP.Y) - 2, bot = Math.Max(stT.Bottom, stP.Bottom) + 2;
    using (var b = new SolidBrush(Fill)) g.FillRectangle(b, stB.X, top, stB.Width, bot - top);
    string label = fin ? "완료 " + n + " / 실패 0" : (cur < 0 ? "설치 프레임워크 확인 중..." : "#" + (cur + 1) + " " + rows[cur].Title);
    TextRenderer.DrawText(g, label, fMuted, new Rectangle(stT.X, top, Math.Max(40, stP.X - 240 - stT.X), bot - top), muted, TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPadding);
    string pctS = overall.ToString("0.0") + "%"; var ps = TextRenderer.MeasureText(g, pctS, fBig, Size.Empty, TextFormatFlags.NoPadding);
    TextRenderer.DrawText(g, pctS, fBig, new Rectangle(stP.Right - ps.Width, top, ps.Width, bot - top), accent, TextFormatFlags.Right | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
    if (!fin) {
      int remMin = (int)Math.Round((1 - overall / 100.0) * 21); string eta = remMin < 1 ? "1분 미만 남음" : "약 " + remMin + "분 남음";
      var es = TextRenderer.MeasureText(g, eta, fBig, Size.Empty, TextFormatFlags.NoPadding);
      TextRenderer.DrawText(g, eta, fBig, new Rectangle(stP.Right - ps.Width - 12 - es.Width, top, es.Width, bot - top), accent, TextFormatFlags.Right | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
    }
    // 전체 막대: 앱의 ThickBar 와 같은 자리 · 같은 모양(높이 26, 모서리 13)
    using (var bp = Spot.Round(stB, 13)) using (var b = new SolidBrush(track)) g.FillPath(b, bp);
    int fw = (int)(stB.Width * overall / 100.0);
    if (fw > 0) { var fr = new Rectangle(stB.X, stB.Y, Math.Max(26, fw), stB.Height); using (var fp = Spot.Round(fr, 13)) using (var b = new SolidBrush(fin ? Hex("#1B9E5A") : accent)) g.FillPath(b, fp); }
    // 통계 타일: 완료 · 실패 · 건너뜀 · 남음 — 0 이면 흐리게(앱의 ZeroDim 0.35)
    int[] val = { done, 0, 0, n - done }; Color[] col = { Hex("#1B9E5A"), Hex("#D93B3B"), Hex("#E08700"), Hex("#6B7684") };
    for (int k = 0; k < StNums.Length && k < 4; k++) {
      var nr = Off(StNums[k], -Left, -Top); int a = val[k] > 0 ? 255 : 89;
      using (var b = new SolidBrush(Fill)) g.FillRectangle(b, nr.X - 2, nr.Y - 1, nr.Width + 4, nr.Height + 2);
      TextRenderer.DrawText(g, val[k].ToString(), fNum, nr, Color.FromArgb(a, col[k]), TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
      if (k < StLabs.Length) { var lr = Off(StLabs[k], -Left, -Top); using (var b = new SolidBrush(Fill)) g.FillRectangle(b, lr.X - 1, lr.Y - 1, lr.Width + 2, lr.Height + 2);
        TextRenderer.DrawText(g, StLabs[k] == Rectangle.Empty ? "" : (k == 0 ? "완료" : k == 1 ? "실패" : k == 2 ? "건너뜀" : "남음"), fMuted, lr, Color.FromArgb(a, muted), TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding); }
    }
  }
}
// 하단 자막
public class Caption : Overlay {
  string text = ""; Font font = new Font("Malgun Gothic", 26f, FontStyle.Bold);
  public Caption() { BackColor = Color.Black; SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint, true); var s = Screen.PrimaryScreen.Bounds; Bounds = new Rectangle(0, s.Bottom - 104, s.Width, 104); }
  public void SetText(string t) { text = t; if (!Visible) Show(); Raise(); Invalidate(); Update(); Application.DoEvents(); }
  protected override void OnPaint(PaintEventArgs e) {
    Bg.Paint(e.Graphics, Bounds); e.Graphics.SmoothingMode = SmoothingMode.AntiAlias; e.Graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
    // 자막 바 양끝 브랜딩 — 왼쪽 상상진화 로고, 오른쪽 Autodesk Gold Partner
    Intro.DrawFit(e.Graphics, Intro.Logo, 130, Height / 2f, 190, 0.95f);
    Intro.DrawFit(e.Graphics, Intro.Badge, Width - 150, Height / 2f, 200, 0.9f);
    if (text.Length == 0) return;
    var font = this.font; var sz = TextRenderer.MeasureText(text, font);
    for (float fs = 26f; sz.Width + 60 > Width - 640 && fs > 16f; fs -= 1f) { font = new Font("Malgun Gothic", fs, FontStyle.Bold); sz = TextRenderer.MeasureText(text, font); }
    int w = sz.Width + 60, h = sz.Height + 22;
    var r = new Rectangle((Width - w) / 2, (Height - h) / 2, w, h);
    using (var p = Spot.Round(r, 12)) using (var b = new SolidBrush(Color.FromArgb(215, 20, 20, 24))) e.Graphics.FillPath(b, p);
    TextRenderer.DrawText(e.Graphics, text, font, r, Color.White, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter);



  }
}
// 엔딩(약 5초) — 상상진화 로고를 가운데 두고 3D 느낌으로: 두께(어두운 판을 겹쳐 밀어냄) · 옆으로 돌며 등장 ·
// 빛줄기가 로고 획 위만 훑고 지나감 · 바닥 빛 웅덩이와 반사 · 별빛 입자. 끝은 검정으로 잠긴다.
public class Outro : Overlay {
  double t, dur; Image logo, flip, dark, white, badge; string[] lines; float[] px = new float[70], py = new float[70], ps = new float[70], pp = new float[70];
  Font fLine = new Font("Malgun Gothic", 30f, FontStyle.Bold), fSmall = new Font("Malgun Gothic", 20f, FontStyle.Bold);
  public string Twinkle; static readonly double[] cues = { 0.5, 1.7, 2.6 };
  public Outro(Image logo, Image badge, string[] lines) {
    this.logo = logo; this.badge = badge; this.lines = lines; BackColor = Color.Black; Bounds = Screen.PrimaryScreen.Bounds;
    SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint, true);
    if (logo != null) { flip = (Image)logo.Clone(); flip.RotateFlip(RotateFlipType.RotateNoneFlipY); dark = Tint(logo, Color.FromArgb(14, 26, 56)); white = Tint(logo, Color.White); }
    var rnd = new Random(3); for (int i = 0; i < px.Length; i++) { px[i] = (float)(rnd.NextDouble() * 1920); py[i] = (float)(rnd.NextDouble() * 1080); ps[i] = (float)(1.5 + rnd.NextDouble() * 3); pp[i] = (float)(rnd.NextDouble() * 6.28); }
  }
  // 원본의 알파는 두고 색만 한 가지로 — 두께 판(어두운색) · 빛줄기(흰색)에 쓴다
  public static Bitmap Tint(Image src, Color c) {
    var b = new Bitmap(src.Width, src.Height, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(b)) g.DrawImage(src, 0, 0, src.Width, src.Height);
    var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), System.Drawing.Imaging.ImageLockMode.ReadWrite, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
    int n = d.Stride * b.Height; var buf = new byte[n]; System.Runtime.InteropServices.Marshal.Copy(d.Scan0, buf, 0, n);
    for (int y = 0; y < b.Height; y++) { int o = y * d.Stride; for (int x = 0; x < b.Width; x++) { int i = o + x * 4; buf[i] = c.B; buf[i + 1] = c.G; buf[i + 2] = c.R; } }
    System.Runtime.InteropServices.Marshal.Copy(buf, 0, d.Scan0, n); b.UnlockBits(d); return b;
  }
  static double Ease(double x) { if (x <= 0) return 0; if (x >= 1) return 1; return 1 - Math.Pow(1 - x, 3); }
  static double Back(double x) { if (x <= 0) return 0; if (x >= 1) return 1; double c1 = 1.70158, c3 = c1 + 1; return 1 + c3 * Math.Pow(x - 1, 3) + c1 * Math.Pow(x - 1, 2); }
  public void Play(double seconds) {
    dur = seconds; t = 0; Show(); Raise(); Application.DoEvents();
    var sw = System.Diagnostics.Stopwatch.StartNew(); int next = 0;
    while (sw.Elapsed.TotalSeconds < seconds) {
      t = sw.Elapsed.TotalSeconds;
      if (Twinkle != null && next < cues.Length && t >= cues[next]) { try { new System.Media.SoundPlayer(Twinkle).Play(); } catch {} next++; }
      Invalidate(); Application.DoEvents(); System.Threading.Thread.Sleep(14);
    }
  }
  public void RenderFrame(double tt, double d, string path) { t = tt; dur = d; using (var b = new Bitmap(Width, Height)) { DrawToBitmap(b, ClientRectangle); b.Save(path); } }
  protected override void OnPaint(PaintEventArgs e) {
    var g = e.Graphics; Bg.Paint(g, Bounds);
    g.SmoothingMode = SmoothingMode.AntiAlias; g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.AntiAlias;
    // 별빛 입자 — 천천히 떠오르며 깜빡인다
    for (int i = 0; i < px.Length; i++) {
      float y = (py[i] - (float)(t * 18 * ps[i]) % 1080 + 1080) % 1080; double tw = 0.5 + 0.5 * Math.Sin(t * 3 + pp[i]);
      using (var b = new SolidBrush(Color.FromArgb((int)(150 * tw * Ease(t / 1.0)), 255, 255, 255))) g.FillEllipse(b, px[i], y, ps[i], ps[i]);
    }
    if (logo != null) {
      // 로고: 옆으로 돌아 나오며(가로 폭 0 → 1) 튕겨 자리 잡고, 그 뒤엔 살짝 떠서 흔들린다
      double a = Back((t - 0.3) / 0.9); double al = Ease((t - 0.3) / 0.4);
      float w = 760f, h = w * logo.Height / logo.Width; float cx = 960, cy = (float)(430 + 7 * Math.Sin(t * 1.3));
      float sx = (float)Math.Max(0.02, a); float tilt = (float)(-(1 - Math.Min(1, a)) * 22 + 2.5 * Math.Sin(t * 0.9));
      var st = g.Save(); g.TranslateTransform(cx, cy); g.RotateTransform(tilt); g.ScaleTransform(sx, 1f);
      // 두께: 어두운 판을 오른쪽 아래로 밀어 겹친다 → 글자에 두께가 생긴다
      for (int k = 12; k >= 1; k--) Intro.DrawFit(g, dark, k * 1.1f, k * 1.1f, w, (float)al * (0.55f + 0.45f * k / 12f));
      Intro.DrawFit(g, logo, 0, 0, w, (float)al);
      // 빛줄기: 로고 획 위만 흰 띠가 왼쪽에서 오른쪽으로 훑는다(t 1.4~2.4), 뒤에 한 번 더 약하게
      double s1 = (t - 1.4) / 1.0, s2 = (t - 3.6) / 1.0; double s = s1 >= 0 && s1 <= 1 ? s1 : (s2 >= 0 && s2 <= 1 ? s2 : -1);
      if (s >= 0) { float band = 170; float bx = (float)(-w / 2 - band + (w + 2 * band) * s); var clip = g.Clip; g.SetClip(new RectangleF(bx - band / 2, -h, band, h * 2), CombineMode.Intersect);
        Intro.DrawFit(g, white, 0, 0, w, (float)(0.9 * Math.Sin(s * Math.PI))); g.Clip = clip; }
      g.Restore(st);
      // 바닥 빛 웅덩이와 반사
      Intro.DrawShadow(g, cx, cy + h / 2 + 34, w * 0.95f, 70, (float)al);
      // 반사: 로고 아래로 뒤집어 얇게, 아래로 갈수록 옅게(세 띠). Intro.DrawReflection 은 정사각 그림용이라 가로로 긴 로고를 세로로 늘인다
      if (a > 0.95) { float rh = h * 0.42f; int bands = 3; for (int k = 0; k < bands; k++) {
        using (var ia = new System.Drawing.Imaging.ImageAttributes()) { var cm = new System.Drawing.Imaging.ColorMatrix(); cm.Matrix33 = (float)al * (0.16f - 0.05f * k); ia.SetColorMatrix(cm);
          var dst = new Rectangle((int)(cx - w / 2), (int)(cy + h / 2 + 10 + rh * k / bands), (int)w, (int)(rh / bands) + 1);
          g.DrawImage(flip, dst, 0, (int)(flip.Height * 0.42f * k / bands), flip.Width, (int)(flip.Height * 0.42f / bands) + 1, GraphicsUnit.Pixel, ia); } } }
    }
    // 문구: 한 줄씩 글자가 내려앉으며
    if (lines.Length > 0) Intro.DrawTextChars(g, lines[0], fLine, 960, 725, Color.White, Ease((t - 1.6) / 1.3));
    if (lines.Length > 1) Intro.DrawText(g, lines[1], fSmall, 960, (float)(805 + 16 * (1 - Ease((t - 2.5) / 0.6))), Color.FromArgb(255, 196, 0), (float)Ease((t - 2.5) / 0.6));
    Intro.DrawFit(g, badge, 960, 930, 240, 0.9f * (float)Ease((t - 3.0) / 0.8));
    // 들어올 때 검정에서, 나갈 때 검정으로
    double fi = 1 - Ease(t / 0.5), fo = t > dur - 0.9 ? Math.Min(1, (t - (dur - 0.9)) / 0.9) : 0; double f = Math.Max(fi, fo);
    if (f > 0) using (var br = new SolidBrush(Color.FromArgb((int)(255 * f), 0, 0, 0))) g.FillRectangle(br, ClientRectangle);
  }
}
"@

# ---------- 마우스 · 연출 ----------
function Move-To([int]$x, [int]$y, [int]$ms = 500) {
  $p = New-Object N+POINT; [void][N]::GetCursorPos([ref]$p)
  $n = [Math]::Max(12, [int]($ms / 15))
  for ($i = 1; $i -le $n; $i++) { $t = $i / $n; $e = 1 - [Math]::Pow(1 - $t, 3)
    [void][N]::SetCursorPos([int]($p.X + ($x - $p.X) * $e), [int]($p.Y + ($y - $p.Y) * $e)); Tick 15 }
}
# 쉬는 동안에도 안내 캐릭터가 떠서 움직이도록 메시지를 돌린다
function Tick([int]$ms) { $sw = [System.Diagnostics.Stopwatch]::StartNew(); do { if ($script:guide) { $script:guide.Tick() }; if ($script:cur) { $cp = New-Object N+POINT; [void][N]::GetCursorPos([ref]$cp); $script:cur.SetPos($cp.X, $cp.Y) }; [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 15 } while ($sw.ElapsedMilliseconds -lt $ms) }
function Pause([double]$sec) { Tick ([int]($sec * 1000)) }
function Sub([string]$text) { $script:cap.SetText($text); Log "자막  $text" }
# 클릭 연출: 이동 → 주변 어둡게(대상만 밝게) + 툴팁 → 클릭 → 링 → 어둠 걷기 (툴팁은 다음 클릭까지)
function Click-Rect($rect, [string]$label, [string]$tip, [switch]$Quick) {
  $x = [int]($rect.X + $rect.Width / 2); $y = [int]($rect.Y + $rect.Height / 2)
  $script:tip.HideAll()
  if ($Quick) {
    # 빠른 클릭 — 스포트라이트·툴팁 없이 이동 → 클릭 → 짧은 링 (같은 절차를 되풀이할 때)
    Move-To $x $y 260; Pause 0.12
    [N]::mouse_event(2, 0, 0, 0, [IntPtr]0); Start-Sleep -Milliseconds 60; [N]::mouse_event(4, 0, 0, 0, [IntPtr]0)
    Log "click(q) $label  @($x,$y)"; $script:ring.Pulse($x, $y, 220); return
  }
  Move-To $x $y
  $hole = New-Object System.Drawing.Rectangle ([int]$rect.X - 14), ([int]$rect.Y - 10), ([int]$rect.Width + 28), ([int]$rect.Height + 20)
  if ($script:guide) { $script:guide.Dimmed = $true }
  $script:spot.ShowHole($hole)
  if ($tip) { $script:tip.ShowAt($x, $y, $tip); if ($script:guide) { $script:guide.Say($tip) } }
  Pause 0.9
  [N]::mouse_event(2, 0, 0, 0, [IntPtr]0); Start-Sleep -Milliseconds 70; [N]::mouse_event(4, 0, 0, 0, [IntPtr]0)
  Log "click  $label  @($x,$y)"
  $script:ring.Pulse($x, $y, 500)
  $script:spot.HideAll()
  if ($script:guide) { $script:guide.Dimmed = $false; $script:guide.Tick() }
  if ($tip) { $script:tip.Raise() }
}
function Click-El($el, [string]$label, [string]$tip = '', [switch]$Quick) {
  if (-not $el) { Log "!! 못 찾음: $label"; return $false }
  if ($Quick) { Click-Rect $el.Current.BoundingRectangle $label $tip -Quick } else { Click-Rect $el.Current.BoundingRectangle $label $tip }; return $true
}

# ---------- UIA ----------
$AE = [System.Windows.Automation.AutomationElement]; $TS = [System.Windows.Automation.TreeScope]; $CT = [System.Windows.Automation.ControlType]
function Cond($prop, $val) { New-Object System.Windows.Automation.PropertyCondition($prop, $val) }
function AndC { param($a, $b) New-Object System.Windows.Automation.AndCondition($a, $b) }
function Find-Window([string]$name, [int]$waitSec = 20, [int]$procId = 0) {
  $t = Get-Date
  while (((Get-Date) - $t).TotalSeconds -lt $waitSec) {
    $cnd = Cond $AE::NameProperty $name; if ($procId -gt 0) { $cnd = AndC $cnd (Cond $AE::ProcessIdProperty $procId) }
    $w = $AE::RootElement.FindFirst($TS::Children, $cnd); if ($w) { return $w }
    # WPF 의 모달(ShowDialog) 창과 MessageBox 는 UIA 트리에서 본 창의 자식으로 나온다(실측 2026-09-22)
    if ($script:win) { $w = $script:win.FindFirst($TS::Children, (AndC (Cond $AE::ControlTypeProperty $CT::Window) (Cond $AE::NameProperty $name))); if ($w) { return $w } }
    Start-Sleep -Milliseconds 300 }
  return $null
}
function Find-Text($root, [string]$name) { $root.FindFirst($TS::Descendants, (AndC (Cond $AE::ControlTypeProperty $CT::Text) (Cond $AE::NameProperty $name))) }
function Find-Button($root, [string]$name) { $root.FindFirst($TS::Descendants, (AndC (Cond $AE::ControlTypeProperty $CT::Button) (Cond $AE::NameProperty $name))) }
function Find-Radio($root, [string]$name) { $root.FindFirst($TS::Descendants, (AndC (Cond $AE::ControlTypeProperty $CT::RadioButton) (Cond $AE::NameProperty $name))) }
function R2($r) { if ($null -eq $r -or $r.IsEmpty) { return [System.Drawing.Rectangle]::Empty }; New-Object System.Drawing.Rectangle ([int]$r.X), ([int]$r.Y), ([int]$r.Width), ([int]$r.Height) }
function Lists($root) { @($root.FindAll($TS::Descendants, (Cond $AE::ControlTypeProperty $CT::List))) }
function List-Item($list, [string]$name) {
  # 버전을 바꾸면 언어 목록이 통째로 다시 채워진다 — 그 순간엔 옛 항목만 보이므로 2.5초까지 다시 찾는다(실기 2026-09-22 Revit '공용')
  $it = $null; $t0 = Get-Date
  while (-not $it -and ((Get-Date) - $t0).TotalSeconds -lt 2.5) {
    $it = $list.FindFirst($TS::Descendants, (AndC (Cond $AE::ControlTypeProperty $CT::ListItem) (Cond $AE::NameProperty $name)))
    if (-not $it) { try { $icp = $list.GetCurrentPattern([System.Windows.Automation.ItemContainerPattern]::Pattern); $it = $icp.FindItemByProperty($null, $AE::NameProperty, $name) } catch {} }
    if (-not $it) { Tick 250 }
  }
  if ($it) { try { $it.GetCurrentPattern([System.Windows.Automation.ScrollItemPattern]::Pattern).ScrollIntoView(); Start-Sleep -Milliseconds 250 } catch {} }
  return $it
}
function List-ItemAt($list, [int]$index) {
  # 큐 목록은 가상화라 보이는 줄만 자식으로 나온다 — ItemContainerPattern 으로 n 번째를 찾아 실체화한다(실측 2026-09-22)
  try {
    $icp = $list.GetCurrentPattern([System.Windows.Automation.ItemContainerPattern]::Pattern)
    $it = $null; for ($i = 0; $i -le $index; $i++) { $it = $icp.FindItemByProperty($it, $null, $null); if (-not $it) { break } }
    if ($it) {
      try { $it.GetCurrentPattern([System.Windows.Automation.VirtualizedItemPattern]::Pattern).Realize() } catch {}
      try { $it.GetCurrentPattern([System.Windows.Automation.ScrollItemPattern]::Pattern).ScrollIntoView() } catch {}
      Start-Sleep -Milliseconds 350; return $it
    }
  } catch {}
  $all = @($list.FindAll($TS::Children, (Cond $AE::ControlTypeProperty $CT::ListItem))); Log "  (목록 자식 $($all.Count)개 · ItemContainer 경로 실패 · 요청 $index)"; if ($index -lt $all.Count) { return $all[$index] }; return $null
}
# 버튼 안의 글자(TextBlock)로 찾았을 때는 그 글자를 품은 버튼 전체 사각형을 쓴다
function Button-Rect-ByText($root, [string]$text) {
  $t = Find-Text $root $text; if (-not $t) { return $null }
  $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker; $p = $walker.GetParent($t)
  for ($i = 0; $i -lt 4 -and $p; $i++) { if ($p.Current.ControlType -eq $CT::Button) { return $p }; $p = $walker.GetParent($p) }
  return $t
}
# 단계 번호 — 툴팁 머리에 붙는다. 같은 절차(제품 담기)는 같은 번호를 다시 쓴다.
$script:circled = @('①','②','③','④','⑤','⑥','⑦','⑧','⑨','⑩','⑪','⑫','⑬','⑭','⑮')
function Tip([int]$n, [string]$text) { "$($script:circled[$n-1])  $text" }
# 제품 하나 담기 — 클릭마다 자막이 바뀐다 (마케팅 문체)
function Pick([string]$product, [string]$version, [string]$lang, [string[]]$subs) {
  # $subs 는 1~5개 — 부족하면 앞 자막을 그대로 둔다(자막을 합친다)
  $L = Lists $script:win
  if ($subs.Count -gt 0 -and $subs[0]) { Sub $subs[0] }
  $el = List-Item $L[0] $product; if (-not (Click-El $el "제품군 $product" (Tip 1 "제품군 선택: $product"))) { return }; Pause 0.5
  $L = Lists $script:win
  if ($subs.Count -gt 1 -and $subs[1]) { Sub $subs[1] }
  $el = List-Item $L[1] $version; if (-not (Click-El $el "버전 $version" (Tip 2 "버전 선택: $version"))) { return }; Pause 0.5
  $L = Lists $script:win
  if ($subs.Count -gt 2 -and $subs[2]) { Sub $subs[2] }
  $el = List-Item $L[2] $lang;    if (-not (Click-El $el "언어 $lang" (Tip 3 "언어 선택: $lang"))) { return }; Pause 0.5
  $L = Lists $script:win
  if ($subs.Count -gt 3 -and $subs[3]) { Sub $subs[3] }
  $el = List-ItemAt $L[3] 0;      if (-not (Click-El $el "설치 항목 첫째" (Tip 4 "설치 항목 확인: 파트 수 · 무인설치 인수"))) { return }; Pause 0.9
  if ($subs.Count -gt 4 -and $subs[4]) { Sub $subs[4] }
  Click-El (Button-Rect-ByText $script:win '배치에 추가') '배치에 추가' (Tip 5 '배치에 추가') | Out-Null; Pause 1.1
}
# 같은 절차를 빠르게 — 제품군 · 버전 · 언어 · 항목 · 추가 를 툴팁 없이 잇달아 (2번째 제품부터)
function Pick-Quick([string]$product, [string]$version, [string]$lang) {
  $L = Lists $script:win; $el = List-Item $L[0] $product; if (-not (Click-El $el "제품군 $product" '' -Quick)) { return }; Pause 0.25
  $L = Lists $script:win; $el = List-Item $L[1] $version; if (-not (Click-El $el "버전 $version" '' -Quick)) { return }; Pause 0.25
  $L = Lists $script:win; $el = List-Item $L[2] $lang;    if (-not (Click-El $el "언어 $lang" '' -Quick)) { return }; Pause 0.25
  $L = Lists $script:win; $el = List-ItemAt $L[3] 0;      if (-not (Click-El $el "설치 항목 첫째" '' -Quick)) { return }; Pause 0.3
  Click-El (Button-Rect-ByText $script:win '배치에 추가') '배치에 추가' '' -Quick | Out-Null; Pause 0.6
}

# ---------- OBS ----------
$obs = $null
if (-not $NoObs) {
  . "$root\obs.ps1"
  $cfg = "$env:APPDATA\obs-studio\plugin_config\obs-websocket\config.json"
  $c = Get-Content $cfg -Raw | ConvertFrom-Json
  if (-not (Test-Path "$cfg.bak")) { Copy-Item $cfg "$cfg.bak" }
  if (-not $c.server_enabled) { $c.server_enabled = $true; ($c | ConvertTo-Json) | Set-Content $cfg -Encoding UTF8; Log "obs-websocket 켬" }
  function Start-Obs { Start-Process 'C:\Program Files\obs-studio\bin\64bit\obs64.exe' -WorkingDirectory 'C:\Program Files\obs-studio\bin\64bit' -ArgumentList '--minimize-to-tray','--disable-updater','--disable-shutdown-check','--multi'; Log "OBS 띄움" }
  $wasRunning = [bool](Get-Process obs64 -EA SilentlyContinue)
  if (-not $wasRunning) { Start-Obs }
  $t = Get-Date; $restarted = $false
  while ($true) {
    try { $obs = Obs-Connect $c.server_port $c.server_password; break }
    catch {
      $el = ((Get-Date) - $t).TotalSeconds
      # 이미 떠 있던 OBS 는 websocket 설정을 안 읽었을 수 있다 — 한 번 닫고 다시 띄운다
      if ($wasRunning -and -not $restarted -and $el -gt 8) { Log "OBS 가 websocket 에 안 답함 — 다시 띄움"; Get-Process obs64 -EA SilentlyContinue | Stop-Process -Force; Start-Sleep 3; Start-Obs; $restarted = $true; $t = Get-Date; continue }
      if ($el -gt 45) { throw "OBS websocket 연결 실패: $_" }; Start-Sleep 1 }
  }
  Log "OBS 연결"
  $sc = Obs-Request $obs 'GetCurrentProgramScene' $null
  $scene = $sc.responseData.currentProgramSceneName; Log "OBS 씬: $scene"
  $items = Obs-Request $obs 'GetSceneItemList' @{ sceneName = $scene }
  $has = @($items.responseData.sceneItems | Where-Object { $_.inputKind -eq 'monitor_capture' }).Count
  if ($has -eq 0) {
    $r = Obs-Request $obs 'CreateInput' @{ sceneName = $scene; inputName = '화면 캡처(시연)'; inputKind = 'monitor_capture'; inputSettings = @{ capture_cursor = $false; method = 1 }; sceneItemEnabled = $true }
    Log "화면 캡처 소스 추가: $($r.requestStatus.result) $($r.requestStatus.comment)"
    Start-Sleep 2
  }
  # 모니터를 꼭 지정한다 — 안 하면 OBS 가 'DUMMY' 로 두고 검은 화면만 찍는다(실기 2026-09-22, 3분 18초 검은 녹화)
  $items = Obs-Request $obs 'GetSceneItemList' @{ sceneName = $scene }
  $cap = @($items.responseData.sceneItems | Where-Object { $_.inputKind -eq 'monitor_capture' }) | Select-Object -First 1
  if ($cap) {
    $mons = Obs-Request $obs 'GetInputPropertiesListPropertyItems' @{ inputName = $cap.sourceName; propertyName = 'monitor_id' }
    $pick = @($mons.responseData.propertyItems | Where-Object { $_.itemValue -and $_.itemValue -ne 'DUMMY' }) | Select-Object -First 1
    if ($pick) { $sr = Obs-Request $obs 'SetInputSettings' @{ inputName = $cap.sourceName; inputSettings = @{ monitor_id = $pick.itemValue; method = 1; capture_cursor = $false } }; Log "모니터 지정: $($pick.itemName) → $($sr.requestStatus.result)" }
    else { Log "!! 모니터 목록이 비어 있음: $($mons.requestStatus.comment)" }
    Start-Sleep 1
  } else { Log "!! 화면 캡처 소스가 없다" }
}

# ---------- 앱 ----------
$exe = 'C:\Program Files\Autodesk 설치 자동화\AutodeskInstallAutomation.exe'
$queue = 'C:\ProgramData\AutodeskInstallAutomation\queue.json'
if (Test-Path $queue) { try { Remove-Item $queue -Force; Log "큐 비움(queue.json)" } catch { Log "queue.json 못 지움: $_" } }
if (-not $Test) {
  foreach ($old in (Get-Process AutodeskInstallAutomation -EA SilentlyContinue)) {
    Log "다른 인스턴스 닫음 pid=$($old.Id)"; [void][N]::PostMessage($old.MainWindowHandle, 0x0010, [IntPtr]0, [IntPtr]0)
    if (-not $old.WaitForExit(8000)) { Log "  안 닫혀 강제 종료"; Stop-Process -Id $old.Id -Force -EA SilentlyContinue }
  }
}
if ($Test) { $env:__COMPAT_LAYER = 'RunAsInvoker' }
$app = Start-Process $exe -PassThru
if ($Test) { Remove-Item Env:\__COMPAT_LAYER -EA SilentlyContinue }
$win = Find-Window 'Autodesk 설치 자동화' 40 $app.Id
if (-not $win) { Log "!! 앱 창을 못 찾음"; Stop-Transcript | Out-Null; exit 1 }
$t0 = Get-Date; while ((Lists $win).Count -lt 5 -and ((Get-Date) - $t0).TotalSeconds -lt 30) { Start-Sleep -Milliseconds 400 }
$hwnd = [IntPtr]$win.Current.NativeWindowHandle
Log "앱 창 hwnd=$hwnd pid=$($win.Current.ProcessId)"
Pause 1.5
$dbg = Lists $win; Log "목록 $($dbg.Count)개"
for ($i = 0; $i -lt $dbg.Count; $i++) { $f = List-ItemAt $dbg[$i] 0; Log ("  목록[{0}] 항목 {1} · 첫째='{2}'" -f $i, @($dbg[$i].FindAll($TS::Children, (Cond $AE::ControlTypeProperty $CT::ListItem))).Count, $(if ($f) { $f.Current.Name } else { '' })) }

# 검정 배경 + 앱을 맨 위로 + 연출 창들
$backdrop = New-Object Backdrop; $backdrop.Show(); [System.Windows.Forms.Application]::DoEvents()
[void][N]::SetWindowPos($hwnd, [N]::TOPMOST, 580, 66, 0, 0, 0x0001)   # 오른쪽으로 (SWP_NOSIZE) — 왼쪽은 안내 캐릭터 자리
[void][N]::SetForegroundWindow($hwnd)
[N]::Under($backdrop.Handle, $hwnd)   # 배경(비-TopMost)을 앱 바로 아래로 — 어떤 순서 꼬임에도 앱을 못 덮는다
$ring = New-Object Ring ([System.Drawing.Color]::FromArgb(255, 255, 196, 0))
$spot = New-Object Spot
$tip  = New-Object Tip
$cap  = New-Object Caption
$cur  = New-Object CursorFx   # 큰 붉은 커서(형광 후광) — Tick 마다 실제 커서를 따라간다
# 캐릭터 그림 (Downloads\캐릭터) — 1: 도시 장면, 4·5·6·7: 마스코트 넷. 없으면 인트로·안내 캐릭터는 건너뛴다
$charDir = 'C:\Users\info\Downloads\캐릭터'
$guide = $null; $intro = $null; $outro = $null
try {
  $imgs = @('다운로드1.jpg','다운로드4.jpg','다운로드5.jpg','다운로드6.jpg','다운로드7.jpg') | ForEach-Object { $raw = [System.Drawing.Image]::FromFile((Join-Path $charDir $_)); $k = [Intro]::KeyBlack($raw); $raw.Dispose(); $k }
  $intro = New-Object Intro ([System.Drawing.Image[]]$imgs), ([string[]]@('고르고', '담고', '점검하고', 'RUN!')), ([string[]]@('13개 제품군 · 151개 설치본을 DB 로', '2020 ~ 2027 · 한국어 · 영어 · 다국어 매체', '사양 점검 → 다운로드 → 압축 해제 → 무인 설치 → 라이선스'))
  if (Test-Path "$root\twinkle.wav") { $intro.Twinkle = "$root\twinkle.wav" }
  $guide = New-Object Guide ($imgs[4])   # 다운로드7 — 청록 헬멧 · 안경
  Log "캐릭터 $($imgs.Count)장 읽음"
  # 로고 — 상상진화(SVG 를 Edge 헤드리스로 미리 PNG 로 만든 것) · Autodesk Gold Partner(검정→흰색판)
  if (Test-Path "$root\logo_ssjh.png") { [Intro]::Logo = [System.Drawing.Image]::FromFile("$root\logo_ssjh.png"); Log "상상진화 로고" }
  if (Test-Path "$charDir\autodesk gold partner logo.png") { $rawB = [System.Drawing.Image]::FromFile("$charDir\autodesk gold partner logo.png"); [Intro]::Badge = [Intro]::WhiteFromDark($rawB); $rawB.Dispose(); Log "Gold Partner 로고" }
  # 엔딩 — 상상진화 로고 중심. 로고가 없으면 건너뛴다
  if ([Intro]::Logo) { $outro = New-Object Outro ([Intro]::Logo), ([Intro]::Badge), ([string[]]@('설치는 프로그램에게, 시간은 사람에게', '(주)상상진화  ·  Autodesk Gold Partner')); if (Test-Path "$root\twinkle.wav") { $outro.Twinkle = "$root\twinkle.wav" }; Log "엔딩 준비" }
} catch { Log "캐릭터 못 읽음: $($_.Exception.Message)" }
Pause 0.5
$r = New-Object N+RECT; [void][N]::GetWindowRect($hwnd, [ref]$r); Log "앱 창 $($r.L),$($r.T) $($r.R-$r.L)x$($r.B-$r.T)"
Move-To ($r.L + 660) ($r.T + 470) 300

if ($obs) { $rec = Obs-Request $obs 'StartRecord' $null; Log "녹화 시작: $($rec.requestStatus.result)"; Pause 1.0 }
$bgm = $null
if ((-not $Test) -and (Test-Path "$root\bgm.wav")) { Add-Type -AssemblyName PresentationCore; $bgm = New-Object System.Windows.Media.MediaPlayer; $bgm.Open([Uri]"$root\bgm.wav"); $bgm.Volume = 0.35; $bgm.Play(); Log "배경음악 재생" }
Pause 1.5

try {
  # 0. 인트로 — 캐릭터 · 제목 · 태그라인 (14초). 끝나면 검정에서 앱이 드러난다
  if ($intro) { Log "인트로 시작"; $intro.Play(14); $intro.Close(); Log "인트로 끝" }
  if ($guide) { $guide.Say('안녕하세요! 설치, 제가 도와드릴게요'); Pause 0.3 }
  Sub 'Autodesk 설치, 이제 클릭 몇 번이면 끝납니다'
  Pause 2.6

  # 1. 제품 담기 — 첫 제품은 단계마다 짚고(①~⑤), 나머지 셋은 같은 절차를 빠르게
  Pick 'AutoCAD' '2024' '한국어' @(
    '제품군만 고르세요, 나머지는 프로그램이 알고 있습니다',
    '2020 부터 2027 까지, 원하는 버전 그대로',
    '한국어 · 영어 · 다국어, 언어를 헷갈릴 일이 없습니다',
    '파일 몇 개짜리인지, 무인설치 인수가 무엇인지까지 미리 보여 드립니다',
    '담기만 하세요, 설치는 프로그램이 합니다')
  Sub '같은 다섯 번의 클릭으로, Revit, Revit LT, Civil 3D 도'
  if ($guide) { $guide.Say('같은 절차예요, 빠르게 세 개 더 담을게요') }
  Pick-Quick 'Revit' '2025' '공용'
  Pick-Quick 'Revit LT' '2021' 'English'
  Pick-Quick 'Civil 3D' '2026' 'English'
  Sub '네 제품을 담았습니다, 담긴 순서가 곧 설치 순서입니다'
  Snap 'picks'
  Pause 1.4

  # 2. 배치 순서 · 삭제 — 눈에 보이는 마지막 줄 하나로 ▲ 한 번, ▼ 한 번, ✕ 한 번 (스크롤이 튀지 않게)
  Sub '순서 바꾸기도 클릭 한 번, 위로, 아래로'
  $q = (Lists $win)[4]
  $row = List-ItemAt $q 3; Click-El $row '배치 4번째 선택' (Tip 6 '옮길 항목 선택: Civil 3D 2026') | Out-Null; Pause 0.6
  Click-El (Find-Button $win '▲') '위로' (Tip 6 '▲ 위로: 급한 제품을 앞으로') | Out-Null; Pause 1.4
  Click-El (Find-Button $win '▼') '아래로' (Tip 6 '▼ 아래로: 다시 뒤로') | Out-Null; Pause 1.4
  Sub '설치 순서를 초기화하고 싶으시면 ✕ 한 번, 목록은 그 자리에서 정리됩니다'
  Click-El (Find-Button $win '✕') '선택 항목 삭제' (Tip 7 '✕ 선택 항목 삭제: Civil 3D 2026 빼기') | Out-Null; Pause 1.2
  Sub '세 제품, 이 순서로 설치됩니다'
  Snap 'queue'
  Pause 1.2

  # 3. 라이선스 유형
  Sub '라이선스는 한 번만, 배치 전체에 적용됩니다. 네트워크는 서버 주소만, ID 로그인은 설치 뒤 로그인만'
  $net = Find-Radio $win '네트워크 라이선스'; $aid = Find-Radio $win 'Autodesk ID 로그인'
  if ($net) { Click-El $net '네트워크 라이선스' (Tip 8 '라이선스 유형: 네트워크 라이선스') | Out-Null; Pause 1.4 }
  if ($aid) { Click-El $aid 'Autodesk ID 로그인' (Tip 8 '라이선스 유형: Autodesk ID 로그인') | Out-Null; Pause 1.0 }

  # 4. 사양 점검 — 스크롤을 내리며 무엇을 검토하는지 알린다 → 이대로 진행 → RUN 으로 이어진다
  Sub '설치 전에, 이 PC 가 준비됐는지 먼저 봅니다'
  Click-El (Button-Rect-ByText $win '사양 점검') '사양 점검' (Tip 9 '사양 점검') | Out-Null
  $hw = Find-Window '설치 가능성 점검' 30 $app.Id
  if ($hw) {
    Log "사양 점검 창"
    $script:tip.HideAll()
    Pause 1.2
    $hr = $hw.Current.BoundingRectangle
    Move-To ([int]($hr.X + $hr.Width * 0.3)) ([int]($hr.Y + 120)) 600
    Sub '이 PC: CPU · 메모리 · 그래픽 · 여유 공간을 자동으로 읽습니다'; Pause 2.0
    Move-To ([int]($hr.X + $hr.Width * 0.5)) ([int]($hr.Y + 250)) 700
    Sub '이 배치: 내려받기 · 작업 공간 · 설치 후 용량과 예상 소요 시간까지 미리 계산합니다'; Pause 2.4
    Move-To ([int]($hr.X + $hr.Width * 0.5)) ([int]($hr.Y + $hr.Height * 0.62)) 700
    Sub '아래로 내리며 보겠습니다, 항목마다 이 PC 의 값과 제품 요구 사양을 나란히, 초록 · 노랑 · 빨강으로'; Pause 1.6
    $wheel = [uint32]4294967176   # -120 (한 칸 아래) 의 부호 없는 표현. PS 는 0xFFFFFFFF 를 -1 로 읽어 -band 가 안 통한다
    for ($k = 1; $k -le 20; $k++) {
      [N]::mouse_event(0x0800, 0, 0, $wheel, [IntPtr]0); Pause 0.55
      if ($k -eq 1)  { Sub '관리자 권한 · 보안 프로그램, 설치를 막는 첫 번째 원인부터 짚습니다' }
      if ($k -eq 5)  { Sub '운영체제 · 메모리 · 디스크 · 예상 시간, 제품이 요구하는 값과 나란히' }
      if ($k -eq 9)  { Sub '프로세서 · 화면 · 그래픽, 권장 사양에 못 미치면 노랑으로 알려 줍니다' }
      if ($k -eq 13) { Sub '설치 이력: 이미 깔린 제품, 더 높은 버전이 있는지까지' }
      if ($k -eq 17) { Sub 'WebView2 · .NET · Visual C++ 같은 선행조건도 미리, 배치에 담긴 제품 전부를 봅니다' }
    }
    Pause 1.0
    $only = $hw.FindFirst($TS::Descendants, (AndC (Cond $AE::ControlTypeProperty $CT::CheckBox) (Cond $AE::NameProperty '주의·실패만 보기')))
    if ($only) {
      Sub '바쁘면 주의 · 실패 항목만 추려서 보세요, 왜 문제인지, 어떻게 하면 되는지까지 적어 드립니다'
      Click-El $only '주의·실패만 보기' (Tip 10 '주의 · 실패만 보기') | Out-Null; Pause 2.4
      Click-El $only '주의·실패만 보기(해제)' (Tip 10 '전체 보기') | Out-Null; Pause 0.7
    }
    Snap 'health'
    Sub '그대로 갈지 멈출지는 사용자 선택, 그리고 이 점검은 RUN 이 알아서 거칩니다'
    Pause 1.4
    Click-El (Find-Button $hw '이대로 진행') '이대로 진행' (Tip 11 '이대로 진행') | Out-Null
    Pause 1.2
  } else { Log "!! 사양 점검 창 못 찾음" }

  # 5. RUN — 점검에서 바로 이어진다
  if (-not $Test) {
    # RUN 직전에 큐 줄과 상태 영역의 자리를 재고 화면을 떠 둔다 — 시뮬레이션은 이 그림 위에 진행값만 바꿔 그린다.
    # 실기 6차(2026-09-22)에서 제목이 '1 2 3' 으로 바뀌고(순번 글자를 제목으로 읽음) 막대가 제자리를 벗어난 것을 고친 판.
    $script:tip.HideAll(); Move-To 1500 1010 300; Pause 0.5
    $simRows = $null; $simSt = $null; $rowsR = @()
    try {
      $q = (Lists $win)[4]
      # ✕ 뒤에 목록이 한 줄 내려가 있어 1번 줄이 화면 밖이었다(실기 7차) — 맨 위로 올리고 잰다
      try { $sp = $q.GetCurrentPattern([System.Windows.Automation.ScrollPattern]::Pattern); if ($sp.Current.VerticallyScrollable) { $sp.SetScrollPercent([System.Windows.Automation.ScrollPattern]::NoScroll, 0) } } catch { Log "  (목록 스크롤 패턴 없음: $($_.Exception.Message))" }
      $items = @($q.FindAll($TS::Children, (Cond $AE::ControlTypeProperty $CT::ListItem)))
      if ($items.Count -gt 0) { try { $items[0].GetCurrentPattern([System.Windows.Automation.ScrollItemPattern]::Pattern).ScrollIntoView() } catch {} }
      Pause 0.5; $qr = $q.Current.BoundingRectangle
      $items = @($q.FindAll($TS::Children, (Cond $AE::ControlTypeProperty $CT::ListItem)))
      foreach ($it in $items) {
        $sr = New-Object SimRow; $sr.Row = R2 $it.Current.BoundingRectangle
        $tx = @($it.FindAll($TS::Descendants, (Cond $AE::ControlTypeProperty $CT::Text))); $seen = 0
        foreach ($e in $tx) { $nm = $e.Current.Name; $rc = R2 $e.Current.BoundingRectangle
          if ($seen -eq 0 -and $nm -match '^\d+$') { $seen = 1; continue }          # 순번
          if ($seen -eq 1) { $sr.Title = $nm; $seen = 2; continue }                  # 제목 — 순번 다음 글
          if ($nm -match '%$') { $sr.Pct = $rc; continue }
          if ($nm -match '^[○▼◆▲✔✖▸■]$') { $sr.Glyph = $rc; continue }
          if ($nm -match '^(대기|다운로드|압축 해제|설치|완료|실패|건너뜀|취소)$') { $sr.Label = $rc; continue }
        }
        $pb = $it.FindFirst($TS::Descendants, (Cond $AE::ControlTypeProperty $CT::ProgressBar)); if ($pb) { $sr.Bar = R2 $pb.Current.BoundingRectangle }
        Log "  줄 '$($sr.Title)' 퍼센트=$($sr.Pct) 기호=$($sr.Glyph) 상태=$($sr.Label) 막대=$($sr.Bar)"
        if ($sr.Pct.Width -gt 0 -and $sr.Glyph.Width -gt 0 -and $sr.Label.Width -gt 0 -and $sr.Bar.Width -gt 0) { $rowsR += $sr } else { Log "  !! 줄 자리를 다 못 읽음 — 이 줄은 연출에서 뺀다" }
      }
      if ($rowsR.Count -gt 0) {
        $qa = R2 $qr; $simRows = New-Object Sim $qa, ([SimRow[]]$rowsR), $false
        $simRows.SampleFill(($rowsR[0].Pct.X - 3), ($rowsR[0].Pct.Y + [int]($rowsR[0].Pct.Height / 2)))   # 퍼센트 왼쪽 여백 = 카드 안쪽 흰색
        # 상태 영역: 문구(OverallStatusText) · 퍼센트(0.0%) · 굵은 막대(높이 26) · 통계 타일(완료·실패·건너뜀·남음)
        $stT = $win.FindFirst($TS::Descendants, (Cond $AE::AutomationIdProperty 'OverallStatusText'))
        $bars = @(@($win.FindAll($TS::Descendants, (Cond $AE::ControlTypeProperty $CT::ProgressBar))) | Where-Object { -not $_.Current.BoundingRectangle.IsEmpty -and $_.Current.BoundingRectangle.Height -ge 20 })
        $allT = @($win.FindAll($TS::Descendants, (Cond $AE::ControlTypeProperty $CT::Text)))
        $stP = $allT | Where-Object { $_.Current.Name -match '^\d+\.\d%$' } | Select-Object -First 1
        if ($stT -and $bars.Count -gt 0 -and $stP) {
          $bar = R2 $bars[0].Current.BoundingRectangle
          $band = { param($e) $b = $e.Current.BoundingRectangle; (-not $b.IsEmpty) -and $b.Y -gt $bar.Bottom -and $b.Y -lt ($bar.Bottom + 70) -and $b.X -ge ($bar.X - 4) -and $b.X -lt $bar.Right }
          $labR = @(); foreach ($nmL in @('완료', '실패', '건너뜀', '남음')) { $l = $allT | Where-Object { $_.Current.Name -eq $nmL -and (& $band $_) } | Select-Object -First 1; $labR += $(if ($l) { R2 $l.Current.BoundingRectangle } else { [System.Drawing.Rectangle]::Empty }) }
          $numR = @(); foreach ($nn in @($allT | Where-Object { $_.Current.Name -match '^\d+$' -and (& $band $_) } | Sort-Object { $_.Current.BoundingRectangle.X })) { $numR += R2 $nn.Current.BoundingRectangle }
          $top = [Math]::Min([int]$stT.Current.BoundingRectangle.Y, $bar.Y) - 4; $bottom = $bar.Bottom + 4
          foreach ($rr in ($labR + $numR)) { if ($rr.Bottom -gt $bottom) { $bottom = $rr.Bottom + 4 } }
          $sa = New-Object System.Drawing.Rectangle ($bar.X - 4), $top, ($bar.Width + 8), ($bottom - $top)
          $simSt = New-Object Sim $sa, ([SimRow[]]$rowsR), $true
          $simSt.StText = R2 $stT.Current.BoundingRectangle; $simSt.StPct = R2 $stP.Current.BoundingRectangle; $simSt.StBar = $bar
          $simSt.StNums = [System.Drawing.Rectangle[]]$numR; $simSt.StLabs = [System.Drawing.Rectangle[]]$labR
          $simSt.SampleFill(($bar.X + 2), ($bar.Bottom + 2))
          Log "  상태 영역 $sa · 문구=$($simSt.StText) 퍼센트=$($simSt.StPct) 막대=$bar 숫자=$($numR.Count) 이름=$(@($labR | Where-Object { $_.Width -gt 0 }).Count)"
        } else { Log "  !! 상태 영역 못 읽음 (문구=$([bool]$stT) 막대=$($bars.Count) 퍼센트=$([bool]$stP)) — 전체 막대 연출 생략" }
      } else { Log "!! 큐 줄을 하나도 못 읽음 — 진행 연출 생략" }
    } catch { Log "!! 시뮬레이션 준비 실패: $($_.Exception.Message) @ $($_.InvocationInfo.ScriptLineNumber)"; $simRows = $null; $simSt = $null }

    Sub 'RUN 한 번, 다운로드, 압축 해제, 무인 설치가 차례로 이어집니다'
    Click-El (Button-Rect-ByText $win 'RUN') 'RUN' (Tip 12 'RUN: 담은 순서대로 자동 설치') | Out-Null
    $mb = Find-Window '설치 전 임시파일 정리' 15 $app.Id
    if ($mb) {
      Sub '설치 전에 임시 폴더를 비울지 묻습니다, 앞선 설치의 찌꺼기가 실패 원인이 되지 않도록'
      # MessageBox 의 [예(Y)] — UIA 로 못 찾으면(실기 2026-09-22: 창은 잡혔는데 버튼이 안 나옴) 대화상자 기하로, 그래도 안 되면 키 'Y'
      $yes = @($mb.FindAll($TS::Descendants, (Cond $AE::ControlTypeProperty $CT::Button))) | Where-Object { $_.Current.Name -match '^예|^Yes' } | Select-Object -First 1
      if (-not $yes) { $yes = @($mb.FindAll($TS::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) | Where-Object { $_.Current.Name -match '^예|^Yes' } | Select-Object -First 1 }
      Pause 1.4
      if ($yes) { Click-El $yes '예' (Tip 13 '예: 임시 폴더 비우고 계속') | Out-Null }
      else {
        $mr = $mb.Current.BoundingRectangle; Log "  예 버튼 UIA 로 못 찾음 — 대화상자 $($mr.Width)x$($mr.Height) 기하로 누름"
        $guess = New-Object System.Windows.Rect ($mr.Right - 172), ($mr.Bottom - 35), 74, 24
        Click-Rect $guess '예(기하)' (Tip 13 '예: 임시 폴더 비우고 계속')
        Pause 1.0
      }
    }
    $script:tip.HideAll(); Move-To 1500 1010 350   # 붉은 커서가 목록 위에 머물지 않게
    # 진행 — 실제 배치는 뒤에서 도는 채로, 앞에 떠 둔 그림 위에서 줄 셋이 빠르게 완료까지 간다(약 50초). 영상용 연출이다.
    if ($simRows) {
      Log "시뮬레이션 줄 $($rowsR.Count) · 제목 $(@($rowsR | ForEach-Object { $_.Title }) -join ' | ')"
      $sw = [System.Diagnostics.Stopwatch]::StartNew(); $dur = $simRows.Total; $said = @{}
      while ($sw.Elapsed.TotalSeconds -lt $dur + 2.5) {
        $tt = $sw.Elapsed.TotalSeconds; $simRows.Set($tt); if ($simSt) { $simSt.Set($tt) }
        if ($tt -ge 0.3 -and -not $said[1]) { $said[1] = 1; Sub '받아 둔 파일은 다시 받지 않습니다, 캐시를 그대로 씁니다'; if ($script:guide) { $script:guide.Say('내려받기는 캐시로 바로!') } }
        if ($tt -ge 2.0 -and -not $said[2]) { $said[2] = 1; Sub '압축 해제 확인 창이 떠도 프로그램이 대신 누릅니다, 사람이 지킬 필요가 없습니다'; if ($script:guide) { $script:guide.Say('확인 창은 제가 누를게요!') } }
        if ($tt -ge 5.2 -and -not $said[3]) { $said[3] = 1; Sub '무인 설치: 진행률 · 남은 시간 · 실행 로그가 한 화면에'; if ($script:guide) { $script:guide.Say('지켜보기만 하세요') } }
        if ($tt -ge 9.8 -and -not $said[4]) { $said[4] = 1; Sub '첫 제품 완료 → 곧바로 다음 제품으로, 사람이 클릭할 필요가 없습니다'; if ($script:guide) { $script:guide.Say('하나 끝! 다음 제품은 제가 알아서 이어갈게요') } }
        if ($tt -ge 15.0 -and -not $said[5]) { $said[5] = 1; Sub '하나가 끝나면 다음이 자동으로, 라이선스까지 맞추고 이어갑니다'; if ($script:guide) { $script:guide.Say('클릭 없이 연속 설치!') } }
        if ($tt -ge 20.5 -and -not $said[7]) { $said[7] = 1; Sub '세 번째도 사람 손 없이, 자리를 비워도 설치는 계속됩니다' }
        if ($tt -ge $dur - 0.5 -and -not $said[6]) { $said[6] = 1; Sub '세 제품 설치 완료, RUN 한 번 뒤엔 클릭 한 번도 없었습니다'; if ($script:guide) { $script:guide.Say('전부 끝났어요!') } }
        if ($tt -ge 7.0 -and -not $said[91]) { $said[91] = 1; Snap 'sim07' }
        if ($tt -ge 22.0 -and -not $said[92]) { $said[92] = 1; Snap 'sim22' }
        if ($tt -ge $dur -and -not $said[93]) { $said[93] = 1; Snap 'sim_end' }
        Tick 40
      }
      Pause 2.5
      $script:simRows = $simRows; $script:simSt = $simSt
    } else { Log "!! 진행 연출 없이 20초 지켜봄"; Pause 20 }
  } else { Log "(시험) RUN 생략"; Pause 2 }
  $script:tip.HideAll()
  Sub '(주)상상진화  ·  Autodesk 설치 자동화'
  Pause 1.5
  # 6. 엔딩 — 상상진화 로고 중심 3D 연출(5.5초). 전체 화면을 덮으므로 다른 겹창은 그 뒤에 숨는다
  if ($outro) {
    $outro.Show(); $outro.Raise(); [System.Windows.Forms.Application]::DoEvents()
    $script:cap.Hide(); if ($script:guide) { $script:guide.Hide() }; if ($script:cur) { $script:cur.Hide() }
    Log "엔딩 시작"; $outro.Play(5.5); Log "엔딩 끝"
  } else { Pause 2 }
}
catch { Log "!! 오류: $($_.Exception.Message) @ $($_.InvocationInfo.ScriptLineNumber)" }

# ---------- 마무리 ----------
if ($cur) { $cur.Close(); $cur = $null; $script:cur = $null }   # 엔딩 검정 화면 위로 붉은 커서가 다시 뜨지 않게
Move-To 960 1000 500
if ($bgm) { for ($v = 0.35; $v -gt 0; $v -= 0.035) { $bgm.Volume = [Math]::Max(0, $v); Start-Sleep -Milliseconds 150 }; $bgm.Stop(); $bgm.Close() }
if ($obs) { $st = Obs-Request $obs 'StopRecord' $null; Log "녹화 끝: $($st.responseData.outputPath)"; Obs-Close $obs; Start-Sleep 2; Get-Process obs64 -EA SilentlyContinue | Stop-Process -Force }
# 녹화가 끝난 뒤 — 엔딩 창(불투명이라 클릭을 삼킨다. 실기 7차에서 ■ 중단이 안 먹었다)과 연출 줄을 걷고, 뒤에서 돌던 실제 배치를 멈춘다(영상엔 안 들어간다)
if ($outro) { $outro.Close(); $outro = $null; [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 300 }
if ($script:simRows) { $script:simRows.Close() }; if ($script:simSt) { $script:simSt.Close() }
try { $stopBtn = Find-Button $win '■ 중단'; if ($stopBtn -and $stopBtn.Current.IsEnabled) { $sr = $stopBtn.Current.BoundingRectangle; Move-To ([int]($sr.X + $sr.Width / 2)) ([int]($sr.Y + $sr.Height / 2)) 200; [N]::mouse_event(2, 0, 0, 0, [IntPtr]0); Start-Sleep -Milliseconds 60; [N]::mouse_event(4, 0, 0, 0, [IntPtr]0); Log "실제 배치 중단 클릭"; Start-Sleep 4 } } catch { Log "중단 클릭 실패: $($_.Exception.Message)" }
[void][N]::SetWindowPos($hwnd, [N]::NOTOPMOST, 0, 0, 0, 0, 0x0003)
if ($guide) { $guide.Close() }
if ($outro) { $outro.Close() }; $spot.Close(); $tip.Close(); $cap.Close(); $ring.Close(); if ($cur) { $cur.Close() }; $backdrop.Close()
if ($Test) { [void][N]::PostMessage($hwnd, 0x0010, [IntPtr]0, [IntPtr]0); Log "(시험) 앱 닫음" }
Log "끝"
Stop-Transcript | Out-Null
