// Vibration.cs: plays AceBridge's own rumble on the AB6 via DirectInput (gun, hits, cloud buffet, icing, sonic boom).
// MOZA Cockpit keeps handling stick loading from the DCS-format telemetry; this only adds vibration.
using System; using System.Linq; using System.Windows.Forms; using SharpDX.DirectInput;

class Vibration {
  Joystick joy; Effect vib; int[] axes; Form form; public bool Ok; public double Scale = 1.0;
  int lastMag = -1, lastPeriod = -1; DateTime lastUpdate = DateTime.MinValue;
  // timed events
  double evMag, evPeriodMs; DateTime evUntil = DateTime.MinValue;

  public Vibration(double scale) {
    Scale = scale;
    try {
      form = new Form(); var di = new DirectInput();
      var dev = di.GetDevices(DeviceClass.GameControl, DeviceEnumerationFlags.ForceFeedback | DeviceEnumerationFlags.AttachedOnly)
                  .FirstOrDefault(x => (x.ProductName + x.InstanceName).ToUpper().Contains("MOZA"));
      if (dev == null) { Console.WriteLine("[vib] no MOZA force-feedback device found; vibration disabled"); return; }
      joy = new Joystick(di, dev.InstanceGuid);
      joy.SetCooperativeLevel(form.Handle, CooperativeLevel.Exclusive | CooperativeLevel.Background);
      joy.Acquire();
      axes = joy.GetObjects().Where(o => (o.ObjectId.Flags & DeviceObjectTypeFlags.ForceFeedbackActuator) != 0).Select(o => (int)o.ObjectId).Take(2).ToArray();
      vib = new Effect(joy, EffectGuid.Sine, Params(0, 50));
      vib.Start(1);
      Ok = true; Console.WriteLine($"[vib] vibration channel ready on {dev.ProductName} ({axes.Length} axes), scale {Scale:0.00}");
    } catch (Exception ex) { Console.WriteLine("[vib] init failed: " + ex.Message); }
  }

  EffectParameters Params(int mag, int periodMs) {
    var p = new EffectParameters { Flags = EffectFlags.Cartesian | EffectFlags.ObjectIds, Duration = -1, Gain = 10000, SamplePeriod = 0,
      StartDelay = 0, TriggerButton = -1, TriggerRepeatInterval = 0, Parameters = new PeriodicForce { Magnitude = mag, Period = periodMs * 1000, Offset = 0, Phase = 0 } };
    p.SetAxes(axes, axes.Length == 1 ? new[] { 1 } : new[] { 7000, 7000 });
    return p;
  }

  // Short event (hit, sonic boom). Stronger events override weaker ones.
  public void Pulse(double mag, double periodMs, double ms) {
    if (DateTime.Now < evUntil && mag < evMag) return;
    evMag = mag; evPeriodMs = periodMs; evUntil = DateTime.Now.AddMilliseconds(ms);
  }

  // Continuous sources, called every frame: 0..1 levels.
  public void Update(double gun, double cloud, double ice, double stall = 0) {
    if (!Ok) return;
    double mag = 0, period = 50;
    void Take(double m, double per) { if (m > mag) { mag = m; period = per; } }
    Take(gun * 0.30, 28);
    Take(cloud * 0.22, 70);
    Take(ice * 0.38, 90);
    Take(stall * 0.42, 110);
    if (DateTime.Now < evUntil) Take(evMag, evPeriodMs);
    int imag = (int)Math.Clamp(mag * Scale * 10000, 0, 10000), iper = (int)period;
    if (Math.Abs(imag - lastMag) < 150 && iper == lastPeriod) return;
    if ((DateTime.Now - lastUpdate).TotalMilliseconds < 15) return;
    try {
      var p = Params(imag, iper);
      vib.SetParameters(p, EffectParameterFlags.TypeSpecificParameters | EffectParameterFlags.NoRestart);
      lastMag = imag; lastPeriod = iper; lastUpdate = DateTime.Now;
    } catch (Exception ex) {
      Console.WriteLine("[vib] update failed (" + ex.Message + "); re-acquiring");
      try { joy.Acquire(); vib.Start(1); } catch { }
    }
  }

  public void Stop() { try { if (Ok) { vib.SetParameters(Params(0, 50), EffectParameterFlags.TypeSpecificParameters); } } catch { } }
}

