-- Example: AB6 'trigger-missile' layout (Derek's personal setup).
-- Missile is on the trigger's second stage (Button6) instead of the big red top button, and target select is on Button18,
-- so your thumb never leaves its natural spot: steadier aim while firing missiles and switching targets.
-- Face buttons 12-15, D-pad and squadron commands on 7-10, weapon change on 21.
-- Replace the device GUID with your own (see the detected list at the bottom after pressing F5).

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
        Missile = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button6" },  -- MOZA AB6
        -- Weapon/Target are single cycle actions in AC8HOTAS (no prev/next): using Button21 and Button18.
        Weapon = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button21" },  -- MOZA AB6
        Target = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button18" },  -- MOZA AB6
        Radar = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button4" },  -- MOZA AB6
        Flare = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button11" },  -- MOZA AB6
        View = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button16" },  -- MOZA AB6
        Gear = nil,
        
        HatUp = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button7" },  -- MOZA AB6 in-flight hat (squadron commands)
        HatRight = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button8" },  -- MOZA AB6 in-flight hat (squadron commands)
        HatDown = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button9" },  -- MOZA AB6 in-flight hat (squadron commands)
        HatLeft = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button10" },  -- MOZA AB6 in-flight hat (squadron commands)
        
        DPadUp = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button7" },  -- MOZA AB6
        DPadRight = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button8" },  -- MOZA AB6
        DPadDown = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button9" },  -- MOZA AB6
        DPadLeft = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button10" },  -- MOZA AB6

        -- Menu navigation (if you want to use your HOTAS in menus)
        FaceButtonTop = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button12" },  -- MOZA AB6
        FaceButtonRight = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button13" },  -- MOZA AB6
        FaceButtonBottom = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button14" },  -- MOZA AB6
        FaceButtonLeft = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button15" },  -- MOZA AB6

        Pause = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Button49" },  -- MOZA AB6 Start/Menu
        Platform = nil,

        -- Axis Controls
        -- nil means unbound. Replace nil with a binding from the device list.
        -- Example: Yaw = { device = "{detected GUID}", input = "X", invert = false },
        Pitch = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Y", invert = true },  -- MOZA AB6 stick Y
        Roll = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "X", invert = false },  -- MOZA AB6 stick X
        Throttle = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Slider2", invert = false, mode = "zero_to_one" },  -- MOZA AB6 base slider
        CameraPitch = { device = "{A4E48D70-C29A-11F1-8001-444553540000}", input = "Ry", invert = true, mode = "minus_one_to_one" },  -- MOZA AB6 thumbstick Y (camera look)
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
