# MOZA Cockpit DCS export script: port change

AceBridge pretends to be DCS. MOZA Cockpit's DCS telemetry mode talks to the DCS export
script `MOZA.lua`, which opens a TCP server on `127.0.0.1`. AceBridge listens on
`127.0.0.1:3476` and speaks the same text format, so Cockpit has to be pointed at port 3476.

`MOZA.lua` is MOZA's code, so it is **not** redistributed here. Edit your own copy instead.

## What to edit

1. In MOZA Cockpit, open the DCS game page once so Cockpit installs its export script.
   You should then have:
   - `%USERPROFILE%\Saved Games\DCS\Scripts\MOZA\MOZA.lua`
   - a line in `%USERPROFILE%\Saved Games\DCS\Scripts\Export.lua` that `dofile`s it.
   (If your DCS uses `Saved Games\DCS.openbeta`, use that folder instead.)
2. Open `Saved Games\DCS\Scripts\MOZA\MOZA.lua` in a text editor and find the
   "tcp socket" section near line 255:

   ```lua
   local tcp_host        = "127.0.0.1"
   local tcp_server_port = 1234
   ```

3. Change `1234` to `3476`:

   ```lua
   local tcp_server_port = 3476
   ```

4. Save. Nothing else in the file needs to change. Restart MOZA Cockpit so it picks up the change.

The installed template lives at `C:\Program Files (x86)\MOZA Cockpit\bin\DCS\Scripts\MOZA\MOZA.lua`
(port 1234). A MOZA Cockpit update may reinstall the script and reset the port; re-apply the edit if
"[tcp] waiting for MOZA Cockpit" never turns into "[tcp] Cockpit connected".

## Notes

- Alternative: leave the script alone and run `AceBridge --port 1234`. This was not tested;
  3476 is the tested setup.
- Don't sit in a DCS mission while using AceBridge: in a mission DCS's own export script binds the
  same port and AceBridge will log `can't listen on 3476 ... is DCS in a mission?`.
- Tested with MOZA Cockpit 1.1.4.38.
