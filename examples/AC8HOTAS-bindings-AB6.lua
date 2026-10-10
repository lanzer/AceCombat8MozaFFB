-- Example AC8HOTAS bindings for a MOZA AB6 FFB base (from the AceFFB project).
-- Copy this over Mods\AC8HOTAS\bindings.lua, then press F5 in the game.
--
-- IMPORTANT: the device GUID below ({A4E48D70-...}) is from the author's PC. DirectInput instance
-- GUIDs differ per machine, so you MUST replace every occurrence with your own AB6 GUID:
--   1. Start AC8 once with the AC8HOTAS mod enabled and your AB6 plugged in.
--   2. Open Mods\AC8HOTAS\bindings.lua. At the bottom, between "BEGIN DETECTED DEVICES" and
--      "END DETECTED DEVICES", the mod lists each controller, e.g.
--        -- MOZA AB6 FFB Base | 0x1002346E
--        -- device = "{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}"
--   3. Search/replace {A4E48D70-C29A-11F1-8001-444553540000} with that GUID, save, press F5 in game.
--
-- Button numbers are 1-based (same numbers as Windows "Game Controllers" / MOZA Cockpit).
-- Pitch is inverted (invert = true) and yaw is on the AB6 Rz axis ("Z Rotation") on the author's setup.
-- Start/Menu is the mod's "Pause" action (AB6 Button49 here).
-- Camera look (Xbox right stick) is CameraYaw/CameraPitch on the grip thumbstick (AB6 Rx/Ry); flip invert if reversed.
-- Throttle is bound to the AB6 base slider (Slider2, labelled "Slider" in the detected list) for players
-- without a separate throttle. COMMENT IT OUT if you use a throttle the game supports natively
-- (e.g. a T.Flight HOTAS 4), otherwise both may feed throttle at the same time.
-- Note: per a comment in the AC8HOTAS mapper, the game's throttle input accumulates (value - 0.5), so
-- 0.5 (slider centre) is neutral; it may act as "faster/slower around centre" rather than an absolute
-- throttle position. This has not been verified in game.
-- Weapon/Target are single "cycle" actions (no prev/next in the mod).
-- Air brake / speed control button = AccelDecel (Button3); level flight (auto-level, LT+RT on a pad) = AutoPilot
-- (Button52). Both are listed as untested by AC8HOTAS; if F5 rejects one, the newest HOTAS-*.log names it.

-- AC8HOTAS: edit your bindings, save this file, then press F5 in the game.

-- nil means unbound. Copy a device GUID and input token from the detected list.

-- Axis example: Roll = { device="{detected GUID}", input="X", invert=false },
-- Button example: Gun = { device="{detected GUID}", input="Button1" },
-- Hat example: HatUp = { device="{detected GUID}", input="POV1_Up" },
-- Button numbers start at 1. Hats use POV1_Up/Down/Left/Right; only POV1 is supported.

-- Pitch/Roll/Yaw/Throttle/CameraPitch/CameraYaw require axes; other actions require buttons/hats.

-- Axis invert=true reverses direction; buttons/hats do not use invert or mode.
-- Axis mode="minus_one_to_one": -1 / 0 / +1; mode="zero_to_one": 0 / 0.5 / 1.
-- Mode defaults to minus_one_to_one except Throttle, which defaults to zero_to_one.

-- Not every game profile has slots for every action. Unsupported slots are rejected.
-- Existing device assignments may still require a USB reconnect when adding a new device.

return {
    version = 1,
    bindings = {
        -- Button Controls
        -- Replace nil with a button or hat binding from the examples above.
        Gun = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button1" },  -- MOZA AB6
        Missile = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button2" },  -- MOZA AB6
        -- Weapon/Target are single cycle actions in AC8HOTAS (no prev/next): using Button10 and Button7.
        Weapon = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button10" },  -- MOZA AB6
        Target = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button7" },  -- MOZA AB6
        Radar = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button4" },  -- MOZA AB6
        Flare = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button11" },  -- MOZA AB6
        View = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button16" },  -- MOZA AB6
        Gear = nil,
        
        HatUp = nil,
        HatRight = nil,
        HatDown = nil,
        HatLeft = nil,
        
        DPadUp = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button12" },  -- MOZA AB6
        DPadRight = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button13" },  -- MOZA AB6
        DPadDown = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button14" },  -- MOZA AB6
        DPadLeft = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button15" },  -- MOZA AB6

        -- Menu navigation (if you want to use your HOTAS in menus)
        FaceButtonTop = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button17" },  -- MOZA AB6
        FaceButtonRight = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button18" },  -- MOZA AB6
        FaceButtonBottom = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button19" },  -- MOZA AB6
        FaceButtonLeft = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button20" },  -- MOZA AB6

        Pause = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button49" },  -- MOZA AB6 Start/Menu
        Platform = nil,

        -- Axis Controls
        -- nil means unbound. Replace nil with a binding from the device list.
        -- Example: Yaw = { device = "{detected GUID}", input = "X", invert = false },
        Pitch = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Y", invert = true },  -- MOZA AB6 stick Y
        Roll = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "X", invert = false },  -- MOZA AB6 stick X
        -- AB6-only setups: base slider as throttle. Comment out if your throttle is natively supported (e.g. HOTAS 4).
        Throttle = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Slider2", invert = false, mode = "zero_to_one" },  -- MOZA AB6 base slider
        CameraPitch = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Ry", invert = false, mode = "minus_one_to_one" },  -- MOZA AB6 thumbstick Y (camera look)
        CameraYaw = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Rx", invert = false, mode = "minus_one_to_one" },  -- MOZA AB6 thumbstick X (camera look)
        Yaw = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Rz", invert = false },  -- MOZA AB6 Rz (Z Rotation); flip invert if left/right reversed

        -- Optional & Untested Controls
        AutoPilot = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button52" },  -- MOZA AB6 level flight (auto-level)
        AccelDecel = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button3" },  -- MOZA AB6 accelerate/decelerate (air brake)
        LeftShoulder = nil,
        RightShoulder = nil,
        LeftTrigger = nil,
        RightTrigger = nil,
        LeftThumbstick = nil,
        RightThumbstick = nil,
        SpecialRight = nil,
        SpecialLeft = nil,
        TouchPad = nil,
        ExtraButton_01 = nil,
        ExtraButton_02 = nil,
        ExtraButton_03 = nil,
        ExtraButton_04 = nil,
        ExtraButton_05 = nil,
        ExtraButton_06 = nil,
        ExtraButton_07 = nil,
        ExtraButton_08 = nil,
        OnlineLobbyAvatarDash = nil,
        OnlineLobbyAvatarJump = nil,
    },
}
