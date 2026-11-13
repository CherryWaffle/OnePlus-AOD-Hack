# OnePlus 12 all-day full-screen AOD (no root)

OnePlus ships full-screen ("panoramic") Always-On Display on the OnePlus 12, but SystemUI
hides it after a few seconds. The OnePlus 13 gets the all-day version. This repo turns the
cutoff off with one ADB command. No root, no bootloader unlock.

Tested on: OnePlus 12 `CPH2573`, build `CPH2573_17.0.0.100(EX01)` (ColorOS 17, Android 17).

## Use

1. Phone: Settings → Wallpapers & style → Always-On Display → pick the **full-screen** style.
2. Plug the phone in over USB with USB debugging on (Developer options).
3. Run (or double-click `aod.cmd`):

   ```powershell
   .\aod.ps1 on
   ```

4. **After every reboot, run it again.** The flag lives in SystemUI's memory and resets
   whenever SystemUI restarts. Unplugging the cable does not reset it.

Other commands:

```powershell
.\aod.ps1 status   # last AOD hide/keep-on log lines; "keep aod on for test!" = working
.\aod.ps1 watch    # live for 30 s (-Seconds N): light reading -> AOD nits, timeout events
.\aod.ps1 off      # restore the stock timeout (rebooting also does this)
```

`status` reads the phone's log, which only holds the last minute or so. If it finds
nothing, lock the phone and use `watch` instead:

```
23:08:23  AOD started
23:08:25  light    198 lux  ->  AOD  33.1 nits
23:08:29  timeout fired, skipped (keep_aod_on is active)
```

## Undo everything

```powershell
.\restore.ps1      # or double-click restore.cmd
```

The only thing these scripts change on the phone is SystemUI's in-memory
`keep_aod_on` flag. `restore.ps1` turns it off (a reboot does the same), then compares
AOD-related settings (keys containing `aod`, `doze`, `ambient`, `panoramic`) with the
"before" snapshot and lists any differences.

- The first `.\aod.ps1 on` saves that snapshot automatically. `.\backup.ps1` takes one
  by hand. Snapshots go in `backups\`, which is git-ignored because they hold your
  phone's own settings.
- Differences usually come from changes you made in Settings, such as switching AOD
  style, so they are only listed by default. To write the snapshot values back anyway:

  ```powershell
  .\restore.ps1 -ApplySettings -WhatIf   # preview
  .\restore.ps1 -ApplySettings
  ```

- Developer options and USB debugging are never touched. To remove a PC's access, use
  Developer options → Revoke USB debugging authorizations.

## How it works

The command is:

```
adb shell dumpsys activity service com.android.systemui/.keyguard.KeyguardService debug keep_aod_on 1
```

In this build's SystemUI (checked in the APK pulled from the phone):

- SystemUI asks the display panel whether all-day is allowed
  (`isSupportPanoramicAllDayByPanelFeature`). On the OnePlus 12 the answer is no, so a few
  seconds after full-screen AOD appears a hide timer fires (`hideByTimeoutReceiver`).
- Before hiding, `PanoramicAodController.onEnergySavingNotifyHide()` checks a debug field,
  `mKeepAodOn`. If it is set, the hide is skipped and the log says
  `onEnergySavingNotifyHide: keep aod on for test!`
- `OplusKeyguardServiceExImpl.dumpPhaseThree(debug keep_aod_on 1)` sets that field, and
  the ADB shell can reach it through `dumpsys`.

Setting `oplus_keyguard_panoramic_aod_all_day_support` by hand does not help. SystemUI
writes that value from the panel check for the Settings app to read; it doesn't control
the timer.

Verified on the phone: after `on`, the log shows the hide being skipped, and the display
stays in `DOZE_SUSPEND` (AOD lit) instead of going `OFF`.

## AOD brightness

Full-screen AOD brightness already follows the ambient light, with or without this hack.
Measured with `.\aod.ps1 watch` on a OnePlus 12:

| Ambient light | AOD brightness |
|---|---|
| ~200 lux (room light) | 33 nits |
| ~350 lux | 40 nits |
| ~850 lux | 61 nits |
| ~1100 lux (phone torch) | 70 nits |

The range is narrow, so a torch makes the AOD brighter, but not dramatically. How SystemUI
picks the value (`OplusPanoramicAODLightController.calculateBrightness`):

- A low-power AOD light sensor reports when the light band changes. SystemUI then takes one
  reading from the main light sensor, which sits under the top of the display.
- The reading is put into one of 26 bands (0, 25, 100, 200 … 2000, 2500, 3000, 3500 lux),
  looked up in a nit table (6 … 323 nits), and **divided by 1.6**.
- The band can be capped at level 18 (about 1700 lux, ~99 nits). If AOD starts right after
  the screen was on, the level is also capped at the screen brightness you had before locking.

It can't be raised without root:

- The nit table is a SystemUI resource (`config_panoramic_aod_brightness_nit`, with a
  built-in default). Shell-made overlays can't replace array resources.
- The same `dumpsys` handler has brightness overrides (`aod_brightness_debug`,
  `aod_lux_debug`). They return early unless `Build.isDebuggable()` is true, which it
  isn't on retail phones.
- So does `smt userEnablePanoramicAllDay true`, which would set the real all-day flag.

## Caveats

- **Reboot = gone.** Re-run `.\aod.ps1 on`.
- **Battery and burn-in.** The AOD now stays on whenever the phone is face-up and uncovered.
  Pocket/proximity detection and AOD burn-in protection still run, but this is
  more panel-on time than OnePlus allows on this model.
- **SuperDisplay conflict.** SuperDisplay bundles its own older adb
  (`C:\Program Files\SuperDisplay\adb\adb.exe`, v40). When it and the SDK adb (v41) both
  run, they kill each other's server, and the phone may ask for USB-debugging approval again.
  Close SuperDisplay before running the script.
- **Banking apps** sometimes refuse to run while Developer options / USB debugging are on.
  The AOD flag stays set if you turn them off after running the script.

## Without a PC

The same command can be run on the phone itself over Wireless debugging, for example
with [Astroisback/oneplus-13r-aod](https://github.com/Astroisback/oneplus-13r-aod)
(made for the 13R, same command) or Shizuku plus a shell app. These are untested here,
and Wireless debugging must be turned on again after each reboot.

## Credit

The `keep_aod_on` trick was found by
[Astroisback/oneplus-13r-aod](https://github.com/Astroisback/oneplus-13r-aod)
for the OnePlus 13R (OxygenOS 16).
