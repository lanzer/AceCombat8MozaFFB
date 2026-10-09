-- AceTelemetry v2: streams the player aircraft's state to AceBridge over \\.\pipe\AceTelemetry.
-- Crash-safety: never scans the object array while loading; it finds the plane through possession hooks
-- and only falls back to a slow (every 3 s) lookup after the world has been stable.
local PIPE = "\\\\.\\pipe\\AceTelemetry"
local pipe, nextOpenTry, tick = nil, 0, 0
local pawn = nil
local lastNone = false
local stableSince = nil   -- tick when the current map finished loading
local nextScan = 0
local lastErrTime, errCount = 0, 0
local okSent = 0
local planeCode = ""
-- Gun detection: the game spawns a BP_plwp_gun_* actor when the player fires the gun.
-- Firing = a NEW round appeared within the last GUN_WINDOW seconds (wall clock), so the
-- rumble stops as soon as the trigger is released, even while old rounds are still on screen.
local GUN_WINDOW = 0.14
local gunActors = {}
local lastGunShot = -1000
local shotCount, burstStart = 0, 0
local function gunShot()
  local now = os.clock()
  if now - lastGunShot > GUN_WINDOW then shotCount, burstStart = 0, now end
  shotCount = shotCount + 1
  lastGunShot = now
end
pcall(function()
  NotifyOnNewObject("/Script/Engine.Actor", function(o)
    pcall(function()
      local cn = o:GetClass():GetFName():ToString()
      if cn:find("plwp_gun", 1, true) then gunActors[#gunActors + 1] = { obj = o, born = os.clock(), d2 = nil }; gunShot() end
    end)
  end)
end)
local lastFiring = false
local function gunFiring()
  -- Prune dead rounds. If the game recycles a pooled round (it jumps from far away back to
  -- the muzzle), count that as a new shot too; otherwise existing rounds are ignored.
  local px, py, pz = nil, nil, nil
  pcall(function() local l = pawn:K2_GetActorLocation(); px, py, pz = l.X, l.Y, l.Z end)
  for i = #gunActors, 1, -1 do
    local g = gunActors[i]
    local alive = false
    pcall(function() alive = g.obj:IsValid() end)
    if not alive then table.remove(gunActors, i)
    elseif px then
      pcall(function()
        local l = g.obj:K2_GetActorLocation()
        local dx, dy, dz = l.X - px, l.Y - py, l.Z - pz
        local d2 = dx * dx + dy * dy + dz * dz
        if g.d2 and g.d2 > 9e8 and d2 < 2.5e7 then gunShot() end   -- was >300 m, now <50 m: re-fired
        g.d2 = d2
      end)
    end
  end
  local firing = (os.clock() - lastGunShot) < GUN_WINDOW
  if firing ~= lastFiring then
    if firing then print("[AceTelemetry] gun firing (pool " .. #gunActors .. ")\n")
    else
      local dur = lastGunShot - burstStart
      local rate = (dur > 0 and shotCount > 1) and string.format("%.1f rounds/s", (shotCount - 1) / dur) or "single"
      print(string.format("[AceTelemetry] gun stopped (%d rounds in %.2fs, %s, pool %d)\n", shotCount, dur, rate, #gunActors))
    end
  end
  lastFiring = firing
  return firing and 1 or 0
end

local function log(s) print("[AceTelemetry] " .. tostring(s) .. "\n") end
local function valid(o) return o ~= nil and o.IsValid ~= nil and o:IsValid() end
local function closePipe() if pipe then pcall(function() pipe:close() end) end pipe = nil end

local function send(line)
  if not pipe then
    if tick < nextOpenTry then return end
    nextOpenTry = tick + 120
    local f = io.open(PIPE, "wb"); if not f then return end
    f:setvbuf("no"); pipe = f; log("connected to AceBridge")
  end
  if not pcall(function() assert(pipe:write(line, "\n")) end) then log("AceBridge pipe closed"); closePipe() end
end

local function adopt(p, why)
  if not valid(p) then return end
  local ok, name = pcall(function() return p:GetFullName() end)
  if ok and name and name:find("PlayerPlane", 1, true) then
    if p ~= pawn then log("tracking (" .. why .. ") " .. name) end
    planeCode = name:match("BP_PlayerPlane_(PP%d+_[%w_]-)_C ") or name:match("(PP%d+_[%w]+)") or ""
    pawn = p
  end
end

-- Possession hooks: fire when the player gets a new pawn (mission start, respawn).
pcall(function()
  RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(self, newPawn)
    pcall(function() adopt(newPawn:get(), "ClientRestart") end)
  end)
end)
-- Map loads: drop the old plane and wait before any lookup.
pcall(function()
  RegisterLoadMapPreHook(function() pawn = nil; stableSince = nil end)
  RegisterLoadMapPostHook(function() stableSince = tick end)
end)
pcall(function()
  RegisterBeginPlayPostHook(function(actor)
    pcall(function()
      local a = actor:get()
      if valid(a) and a:GetClass():GetFName():ToString():find("PlayerPlane", 1, true) then
        stableSince = stableSince or tick
      end
    end)
  end)
end)

local function sample()
  tick = tick + 1
  local ok, err = pcall(function()
    if pawn and not valid(pawn) then pawn = nil end
    if not pawn then
      -- slow fallback lookup only once the world has been stable for 5 s
      if stableSince and tick - stableSince > 300 and tick >= nextScan then
        nextScan = tick + 180
        local pc = FindFirstOf("LivePlayerController")
        if valid(pc) then adopt(pc.Pawn, "scan") end
      end
      if not pawn then
        if not lastNone then send("none"); lastNone = true end
        return
      end
    end
    lastNone = false
    local function n(x) return tonumber(x) or 0 end
    local v = pawn:GetVelocity()
    local f = pawn:GetActorForwardVector()
    local rt = pawn:GetActorRightVector()
    local up = pawn:GetActorUpVector()
    local fz = math.max(-1, math.min(1, n(f.Z)))
    local pitch = math.deg(math.asin(fz))
    local yaw = math.deg(math.atan(n(f.Y), n(f.X)))
    local roll = math.deg(math.atan(-n(rt.Z), n(up.Z)))
    send(string.format("spd=%.1f;vx=%.1f;vy=%.1f;vz=%.1f;p=%.3f;y=%.3f;r=%.3f;hp=%d;mhp=%.1f;ma=%d;thr=%.3f;cl=%d",
      n(pawn.Speed), n(v.X), n(v.Y), n(v.Z), pitch, yaw, roll,
      math.floor(n(pawn.HealthInternal)), n(pawn.MaxHealth), math.floor(n(pawn.MissileAlert)), n(pawn.InputThrottle),
      pawn.bIsInCloud and 1 or 0) .. string.format(";ic=%d;cd=%.3f", pawn.bIsInIce and 1 or 0, n(pawn.CurrentCloudDensity)) .. ";gf=" .. gunFiring() .. ";pl=" .. planeCode)
    okSent = okSent + 1; if okSent == 1 or okSent % 3000 == 0 then log("sent frame #" .. okSent) end
  end)
  if not ok then pawn = nil; errCount = errCount + 1; if os.time() - lastErrTime >= 2 then lastErrTime = os.time(); log("sample error (x" .. errCount .. "): " .. tostring(err)) end end
end

-- One persistent game-thread loop (no per-frame callback allocation).
local okLoop = pcall(function()
  LoopInGameThreadAfterFrames(2, function() sample(); return false end)
end)
if not okLoop then
  log("LoopInGameThreadAfterFrames unavailable, using LoopAsync")
  LoopAsync(33, function() ExecuteInGameThread(sample); return false end)
end
stableSince = 0 -- mod may load after the first map; allow the fallback after 5 s
log("loaded v2")








