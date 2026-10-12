// AceBridge: reads AC8 telemetry from a named pipe (written by the AceTelemetry UE4SS mod)
// and serves it to MOZA Cockpit in its DCS export format on 127.0.0.1:3476.
using System; using System.Globalization; using System.IO; using System.IO.Pipes; using System.Net; using System.Net.Sockets;
using System.Text; using System.Threading; using System.Diagnostics; using System.Collections.Generic;

class Sample { public string plane = ""; public double gun, ice, cdens; public double t, spd, vx, vy, vz, pitch, yaw, roll, health, maxHealth, missile, throttle, cloud; public bool valid; }

static class Program {
  static readonly object Gate = new();
  static Sample Latest = new();
  static long Frames;
  static string Aircraft = "FA-18C-AC8";
  static int Port = 3476;
  static readonly CultureInfo Inv = CultureInfo.InvariantCulture;

  [System.Runtime.InteropServices.DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int h);
  [System.Runtime.InteropServices.DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr h, out uint m);
  [System.Runtime.InteropServices.DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr h, uint m);
  static void DisableQuickEdit() { try { var h = GetStdHandle(-10); if (GetConsoleMode(h, out var m)) SetConsoleMode(h, (m & ~0x0040u) | 0x0080u); } catch { } }
  static Vibration Vib; static double VibScale = 1.0, StallKmh = 200; static string MapPath = null; static bool NoCockpit = false;
  [STAThread] static void Main(string[] args) {
    DisableQuickEdit();
    foreach (var a in args) {
      if (a == "--no-cockpit") NoCockpit = true;
      if (a == "--help" || a == "-h" || a == "/?") { Console.WriteLine("AceBridge [--port 3476] [--aircraft FA-18C-AC8] [--vib 1.0] [--stall-kmh 200] [--map path\\aircraft-map.json] [--no-cockpit]"); return; }
    }
    for (int i = 0; i < args.Length - 1; i++) { if (args[i] == "--port") Port = int.Parse(args[i + 1]); if (args[i] == "--aircraft") Aircraft = args[i + 1]; if (args[i] == "--vib") VibScale = double.Parse(args[i + 1], Inv); if (args[i] == "--stall-kmh") StallKmh = double.Parse(args[i + 1], Inv); if (args[i] == "--map") MapPath = args[i + 1]; }
    Console.WriteLine($"AceBridge: pipe \\\\.\\pipe\\AceTelemetry -> Cockpit DCS port {Port}, aircraft profile {Aircraft}");
    LoadMap();
    Vib = new Vibration(VibScale);
    new Thread(PipeLoop) { IsBackground = true }.Start();
    if (NoCockpit) { Console.WriteLine("[tcp] --no-cockpit: MOZA Cockpit output disabled, rumble effects only"); Serve(null); }
    else TcpLoop();
  }

  static string MapDefault = "FA-18C-AC8"; static List<(string pre, string prof)> Map = new();
  static string LastPlane = null, LastProfile = null;
  static void LoadMap() {
    try {
      // Search order: --map, next to the exe, ..\config (release zip), repo config\ (dotnet run / bin output).
      string b = AppContext.BaseDirectory;
      var candidates = new List<string>();
      if (MapPath != null) candidates.Add(MapPath);
      candidates.Add(Path.Combine(b, "aircraft-map.json"));
      candidates.Add(Path.Combine(b, "..", "config", "aircraft-map.json"));
      candidates.Add(Path.Combine(b, "..", "..", "..", "..", "..", "config", "aircraft-map.json"));
      candidates.Add(Path.Combine(Environment.CurrentDirectory, "config", "aircraft-map.json"));
      string path = candidates.Find(File.Exists) ?? candidates[0];
      using var doc = System.Text.Json.JsonDocument.Parse(File.ReadAllText(path));
      MapDefault = doc.RootElement.GetProperty("default").GetString();
      foreach (var e in doc.RootElement.GetProperty("map").EnumerateArray()) Map.Add((e[0].GetString(), e[1].GetString()));
      Console.WriteLine($"[map] {Map.Count} aircraft mappings loaded from {Path.GetFullPath(path)}");
    } catch (Exception ex) { Console.WriteLine("[map] using defaults: " + ex.Message); }
  }
  static string Normalize(string code) => System.Text.RegularExpressions.Regex.Replace(code.ToLowerInvariant(), @"(?<![0-9])0+(?=[0-9])", "");
  static string ProfileFor(string plane) {
    if (string.IsNullOrEmpty(plane)) return Aircraft;
    if (plane == LastPlane) return LastProfile;
    var m = System.Text.RegularExpressions.Regex.Match(plane, @"PP\d+_([A-Za-z0-9]+)");
    var code = Normalize(m.Success ? m.Groups[1].Value : plane);
    string prof = null; foreach (var (pre, pr) in Map) if (code.StartsWith(pre)) { prof = pr; break; }
    if (prof == null) { prof = MapDefault; Console.WriteLine($"[map] no mapping for '{code}' ({plane}); using {prof}. Add it to aircraft-map.json"); }
    else Console.WriteLine($"[map] plane {code} -> Cockpit profile {prof}");
    LastPlane = plane; LastProfile = prof; return prof;
  }

  static void PipeLoop() {
    var clock = Stopwatch.StartNew();
    while (true) {
      try {
        using var pipe = new NamedPipeServerStream("AceTelemetry", PipeDirection.In, 1, PipeTransmissionMode.Byte, PipeOptions.None);
        Console.WriteLine("[pipe] waiting for game mod...");
        pipe.WaitForConnection();
        Console.WriteLine("[pipe] game mod connected");
        using var rd = new StreamReader(pipe, Encoding.ASCII);
        string line;
        while ((line = rd.ReadLine()) != null) {
          var s = Parse(line); s.t = clock.Elapsed.TotalSeconds;
          lock (Gate) { Latest = s; Frames++; }
        }
        Console.WriteLine("[pipe] game mod disconnected");
        lock (Gate) { Latest = new Sample(); }
      } catch (Exception ex) { Console.WriteLine("[pipe] " + ex.Message); Thread.Sleep(1000); }
    }
  }

  static Sample Parse(string line) {
    var s = new Sample();
    if (line.StartsWith("none")) return s;
    foreach (var kv in line.Split(';')) {
      var p = kv.Split('='); if (p.Length != 2) continue;
      if (p[0] == "pl") { s.plane = p[1]; continue; }
      if (!double.TryParse(p[1], NumberStyles.Float, Inv, out var v)) continue;
      switch (p[0]) {
        case "spd": s.spd = v; break; case "vx": s.vx = v; break; case "vy": s.vy = v; break; case "vz": s.vz = v; break;
        case "p": s.pitch = v; break; case "y": s.yaw = v; break; case "r": s.roll = v; break;
        case "hp": s.health = v; break; case "mhp": s.maxHealth = v; break; case "ma": s.missile = v; break;
        case "thr": s.throttle = v; break; case "cl": s.cloud = v; break; case "gf": s.gun = v; break; case "ic": s.ice = v; break; case "cd": s.cdens = v; break;
      }
    }
    s.valid = true; return s;
  }

  static double D2R(double d) => d * Math.PI / 180.0;
  static (double x, double y, double z) Fwd(double p, double y) { p = D2R(p); y = D2R(y); return (Math.Cos(p) * Math.Cos(y), Math.Cos(p) * Math.Sin(y), Math.Sin(p)); }
  static (double x, double y, double z) Up(double p, double y, double r) {
    p = D2R(p); y = D2R(y); r = D2R(r);
    double cp = Math.Cos(p), sp = Math.Sin(p), cy = Math.Cos(y), sy = Math.Sin(y), cr = Math.Cos(r), sr = Math.Sin(r);
    return (-(cr * sp * cy + sr * sy), cy * sr - cr * sp * sy, cr * cp); // UE FRotationMatrix Z axis
  }
  static (double x, double y, double z) Right(double p, double y, double r) {
    p = D2R(p); y = D2R(y); r = D2R(r);
    double cp = Math.Cos(p), sp = Math.Sin(p), cy = Math.Cos(y), sy = Math.Sin(y), cr = Math.Cos(r), sr = Math.Sin(r);
    return (sr * sp * cy - cr * sy, sr * sp * sy + cr * cy, -sr * cp); // UE FRotationMatrix Y axis
  }
  static double Dot((double x, double y, double z) a, double bx, double by, double bz) => a.x * bx + a.y * by + a.z * bz;
  static double WrapDeg(double d) { while (d > 180) d -= 360; while (d < -180) d += 360; return d; }

  static void TcpLoop() {
    var listener = new TcpListener(IPAddress.Loopback, Port);
    while (true) {
      try { listener.Start(); break; } catch (Exception ex) { Console.WriteLine($"[tcp] can't listen on {Port} ({ex.Message}); is DCS in a mission? retrying"); Thread.Sleep(2000); }
    }
    while (true) {
      Console.WriteLine("[tcp] waiting for MOZA Cockpit (select DCS, Start game)...");
      using var client = listener.AcceptTcpClient();
      client.NoDelay = true;
      Console.WriteLine("[tcp] Cockpit connected");
      try { Serve(client.GetStream()); } catch (Exception ex) { Console.WriteLine("[tcp] Cockpit disconnected: " + ex.Message); }
    }
  }

  static void Serve(NetworkStream ns) {
    Sample prev = null; double gSmooth = 1, axSmooth = 0, azSmooth = 0, lastHp = -1, hpFull = 0, shells = 600; double joltAmp = 0, joltDecay = 0, joltFreq = 90; var fx = Stopwatch.StartNew(); bool iced = false, gunOn = false, boomArmed = false, airborne = false, stalling = false; double gunKick = 0; double pv = 0, yv = 0, rv = 0;
    var statusClock = Stopwatch.StartNew(); bool idleSent = false;
    while (true) {
      Sample s; long frames; lock (Gate) { s = Latest; frames = Frames; }
      if (!s.valid) {
        if (!idleSent) { idleSent = true; Vib?.Update(0, 0, 0); Console.WriteLine("[tcp] no aircraft (menu/loading) - paused output"); }
        prev = null; lastHp = -1; hpFull = 0; Thread.Sleep(50); continue;
      }
      idleSent = false;
      if (prev != null && s.t > prev.t + 1e-4) {
        double dt = s.t - prev.t;
        // acceleration in world (cm/s^2), specific force = a - gravity, gravity = (0,0,-981)
        double ax = (s.vx - prev.vx) / dt, ay = (s.vy - prev.vy) / dt, az = (s.vz - prev.vz) / dt + 981.0;
        var up = Up(s.pitch, s.yaw, s.roll); var fw = Fwd(s.pitch, s.yaw); var rt = Right(s.pitch, s.yaw, s.roll);
        double nz = Dot(up, ax, ay, az) / 981.0, nx = Dot(fw, ax, ay, az) / 981.0, ny = Dot(rt, ax, ay, az) / 981.0;
        nz = Math.Clamp(nz, -4, 12); nx = Math.Clamp(nx, -4, 4); ny = Math.Clamp(ny, -4, 4);
        double a = Math.Min(1, dt / 0.12);
        gSmooth += (nz - gSmooth) * a; axSmooth += (nx - axSmooth) * a; azSmooth += (ny - azSmooth) * a;
        double k = Math.Min(1, dt / 0.08);
        pv += (D2R(WrapDeg(s.pitch - prev.pitch)) / dt - pv) * k; yv += (D2R(WrapDeg(s.yaw - prev.yaw)) / dt - yv) * k; rv += (D2R(WrapDeg(s.roll - prev.roll)) / dt - rv) * k;
      }
      if (s.health > hpFull) hpFull = s.health;
      if (lastHp >= 0 && s.health < lastHp - 0.5 && hpFull > 0) {
        double frac = (lastHp - s.health) / hpFull;
        string tier;
        if (s.health <= 0) { Vib?.Pulse(0.85, 80, 900); tier = "DESTROYED"; }
        else if (frac >= 0.10) { Vib?.Pulse(0.65, 60, 420); tier = "heavy (missile/bump)"; }
        else { Vib?.Pulse(0.35, 35, 160); tier = "light (bullets)"; }
        Console.WriteLine($"[hit] {tier}: health {lastHp} -> {s.health} ({frac:P0} of {hpFull})");
      }
      if (s.health <= 0 && lastHp > 0) { }      lastHp = s.health;
      if (prev == null || s.t != prev.t) prev = s;

      var u = Up(s.pitch, s.yaw, s.roll); var f = Fwd(s.pitch, s.yaw); var r = Right(s.pitch, s.yaw, s.roll);
      double vF = Dot(f, s.vx, s.vy, s.vz), vU = Dot(u, s.vx, s.vy, s.vz), vR = Dot(r, s.vx, s.vy, s.vz);
      double aoa = vF > 100 ? Math.Atan2(-vU, vF) * 180 / Math.PI : 0;
      double aos = vF > 100 ? Math.Atan2(vR, vF) * 180 / Math.PI : 0;
      double tas = s.spd / 100.0; // cm/s -> m/s
      double ab = s.throttle > 0.9 ? 1 : 0;
      double jx = 0, jz = 0, ts = fx.Elapsed.TotalSeconds;
      if (joltAmp > 0) { jx = joltAmp * Math.Sin(ts * joltFreq); jz = joltAmp * 1.2 * Math.Cos(ts * joltFreq * 1.17); joltAmp = Math.Max(0, joltAmp - joltDecay); }
      if (s.gun > 0) { shells = shells <= 2 ? 600 : shells - 2; gunKick = 0; if (!gunOn) Console.WriteLine("[gun] firing"); gunOn = true; } else { gunKick = 0; if (gunOn) Console.WriteLine("[gun] stopped"); gunOn = false; }
      if (s.ice > 0) { if (!iced) Console.WriteLine("[ice] icing started"); iced = true; } else if (iced) { iced = false; Console.WriteLine("[ice] icing cleared"); }
      double machNow = s.spd / 100.0 / 340.0;
      if (machNow >= 1.0 && boomArmed) { boomArmed = false; Vib?.Pulse(0.42, 100, 280); Console.WriteLine($"[boom] sonic boom at {s.spd / 100.0 * 3.6:0} km/h"); }
      if (machNow < 0.93) boomArmed = true;
      double kmh = s.spd / 100.0 * 3.6;
      if (kmh > StallKmh + 120) airborne = true; else if (kmh < 60) airborne = false;   // landed / stopped
      double stall = airborne ? Math.Clamp((StallKmh - kmh) / 90.0 + 0.35, 0, 1) : 0;
      if (kmh >= StallKmh) stall = 0;
      if ((stall > 0) != stalling) { stalling = stall > 0; Console.WriteLine(stalling ? $"[stall] stall shake on at {kmh:0} km/h" : $"[stall] off at {kmh:0} km/h"); }
      Vib?.Update(s.gun > 0 ? 1 : 0, (s.cloud > 0 || s.cdens > 0.01) ? Math.Clamp(s.cdens, 0, 1) : 0, s.ice > 0 ? 1 : 0, stall);      string profile = ProfileFor(s.plane);      string I(double v) => v.ToString("0.####", Inv);
      var sb = new StringBuilder(512);
      sb.Append("aircraft_name,").Append(profile).Append(';');
      sb.Append("engine_rpm_left,").Append(I(70 + 30 * Math.Clamp(s.throttle, 0, 1))).Append(';');
      sb.Append("engine_rpm_right,").Append(I(70 + 30 * Math.Clamp(s.throttle, 0, 1))).Append(';');
      sb.Append("left_gear,0;nose_gear,0;right_gear,0;");
      sb.Append("acc_x,").Append(I(axSmooth + jx)).Append(';');
      sb.Append("acc_y,").Append(I(gSmooth + jz + gunKick)).Append(';');
      sb.Append("acc_z,").Append(I(azSmooth)).Append(';');
      sb.Append("wind_x,0;wind_y,0;wind_z,0;");
      sb.Append("vector_velocity_x,").Append(I(s.vx / 100)).Append(';');
      sb.Append("vector_velocity_y,").Append(I(s.vz / 100)).Append(';');
      sb.Append("vector_velocity_z,").Append(I(s.vy / 100)).Append(';');
      sb.Append("tas,").Append(I(tas)).Append(';');
      sb.Append("ias,").Append(I(tas)).Append(';');
      sb.Append("vertical_velocity_speed,").Append(I(s.vz / 100)).Append(';');
      sb.Append("aoa,").Append(I(aoa)).Append(';');
      sb.Append("heading,").Append(I(D2R(s.yaw))).Append(';');
      sb.Append("pitch,").Append(I(D2R(s.pitch))).Append(';');
      sb.Append("bank,").Append(I(D2R(s.roll))).Append(';');
      sb.Append("aos,").Append(I(aos)).Append(';');
      sb.Append("euler_vx,").Append(I(rv)).Append(';');
      sb.Append("euler_vy,").Append(I(yv)).Append(';');
      sb.Append("euler_vz,").Append(I(pv)).Append(';');
      sb.Append("canopy_pos,0;flap_pos,0;gear_value,0;speedbrake_value,0;wheelbrakesPos,0;");
      sb.Append("afterburner_1,").Append(I(ab)).Append(";afterburner_2,").Append(I(ab)).Append(';');
      sb.Append("mach,").Append(I(tas / 340.0)).Append(';');
      sb.Append("h_above_sea_level,3000;");
      sb.Append("weapon,;flare,30;chaff,30;cannon_shells,").Append((int)shells).Append(';');
      Write(ns, sb.ToString());

      if (statusClock.ElapsedMilliseconds > 2000) {
        statusClock.Restart();
        Console.WriteLine($"[live] frames={frames} tas={tas:0} m/s G={gSmooth:0.0} aoa={aoa:0.0} hp={s.health} thr={s.throttle:0.00} gun={s.gun} cloud={s.cdens:0.00} ice={s.ice} plane={profile}");
      }
      Thread.Sleep(16);
    }
  }
  static void Write(NetworkStream ns, string s) { if (ns == null) return; var b = Encoding.ASCII.GetBytes(s); ns.Write(b, 0, b.Length); }
}
