# OnePlus 12 all-day full-screen AOD (no root)

OnePlus ships full-screen ("panoramic") Always-On Display on the OnePlus 12, but SystemUI
hides it after a few seconds. The OnePlus 13 gets the all-day version. This repo turns the
cutoff off with one ADB command. No root, no bootloader unlock.

Two ways to use it:

- **Phone app (recommended).** Install once over USB. After that the app turns it on from
  the phone and turns it back on by itself after every restart. See [Phone app](#phone-app).
- **PC scripts.** Run `.\aod.ps1 on` over USB after every restart.

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
.\aod.ps1 status   # is it active right now? (reads SystemUI's live keepAodOn value)
.\aod.ps1 watch    # live for 30 s (-Seconds N): light reading -> AOD nits, timeout events
.\aod.ps1 off      # restore the stock timeout (rebooting also does this)
```

`watch` shows what the AOD does while the phone is locked:

```
23:08:23  AOD started
23:08:25  light    198 lux  ->  AOD  33.1 nits
23:08:29  timeout fired, skipped (keep_aod_on is active)
```

## Phone app

`app\` is a small app, **AOD Keep-On** (about 200 lines of Java, no libraries). It runs the
same `dumpsys` command itself, so no PC is needed after the one-time install.

Install it once (phone on USB debugging; needs the Android SDK and a JDK 17+, no Gradle):

```powershell
.\app\build.ps1 -Install
```

Then on the phone:

- Open **AOD Keep-On** and tap **Turn on** or **Turn off**. It shows SystemUI's live value.
- After every restart it re-applies your last choice by itself, before the first unlock.
  On the tested phone the flag was back to 1 about 9 s after boot, and the AOD held on the
  still-locked phone.

Why it works: running `dumpsys` needs `android.permission.DUMP`. ColorOS 17 blocks
`adb shell pm grant` (and no longer has *Disable permission monitoring* in Developer
options), but `adb install -g` still grants it during the install, and the build script
does that. The build creates a signing key in `app\keystore\` (git-ignored). Keep it:
updates must be signed with the same key, or you have to uninstall first.

Tested with Developer options turned off: after a restart, full-screen AOD stayed on at the
lock screen for minutes before the first unlock. The permission belongs to the installed app
rather than to ADB, so it survives Developer options being off.

## Undo everything

```powershell
.\restore.ps1      # or double-click restore.cmd
```

The scripts change two things on the phone: SystemUI's in-memory `keep_aod_on` flag, and,
if you installed it, the AOD Keep-On app. `restore.ps1` turns the flag off (a reboot does the
same) and uninstalls the app (otherwise it would turn the flag back on at the next boot).
It then compares AOD-related settings (keys containing `aod`, `doze`, `ambient`,
`panoramic`) with the "before" snapshot and lists any differences.

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
- `smt userEnablePanoramicAllDay true`, which would set the real all-day flag (the one
  the OnePlus 13 has), has the same `Build.isDebuggable()` check.

## Limitations and FAQ

**Does it survive a restart?** The flag doesn't. `keep_aod_on` is a field in SystemUI's
memory: `setKeepAodOn` only stores it there, and SystemUI sets it to 0 every time it starts.
The [phone app](#phone-app) sets it again after every restart. With the scripts only, run
`.\aod.ps1 on` again. A SystemUI crash also clears it, and the app doesn't notice that (open
it and tap Turn on). `.\aod.ps1 status` or the app shows whether it is active.

**Do I need to keep Developer options on?** With the phone app, only for the one-time
install. ColorOS 17 turns Developer options off without a restart. The flag lives in
SystemUI rather than in ADB, so it should stay set (not tested; the test phone was
restarted anyway). OxygenOS 16 restarts the phone when you turn them off, which clears the
flag, and the app sets it again after that restart. With the scripts only, you need USB
debugging to re-apply after every restart.

**Does it change the clock-only (partial) AOD?** Not its timeout. The hide that `keep_aod_on`
skips only runs when the AOD's energy-saving mode is on, and the clock-only style normally has
it off (the log says `energySaving mode is closed`). Two other places in SystemUI read the flag,
and they apply to every AOD style while it is set:

- Face-down check: it turns on SystemUI's upside-down check for AOD
  (`isNeedUpsideDown : true for aod on`), which full-screen AOD otherwise has off.
- Clock refresh: `isDisplayModeAllowUpdateClock` returns true straight away, skipping its
  *Scheduled* (time window) check. If you use a schedule, AOD may keep updating outside your
  hours. Not tested; run `.\aod.ps1 off` if you see that.

Other limitations:

- **Scripts need ADB after every reboot.** The phone app doesn't (see [Phone app](#phone-app)).
- **An update can break it.** This is a debug hook. OnePlus already blocks its neighbours
  (`aod_brightness_debug`, `smt userEnablePanoramicAllDay`) on retail builds, and could do the
  same to `keep_aod_on`. After an update, check with `.\aod.ps1 status`.
- **Not OnePlus's real all-day mode.** It skips the hide instead of switching on the all-day
  logic, so AOD stays lit whenever the phone is face-up and uncovered. Pocket/proximity
  detection and burn-in protection still run. It still means more battery use and more
  burn-in risk than OnePlus allows on this panel.
- **Brightness tops out around 70-100 nits** in bright light (see above).
- **Windows only, one phone tested.** The scripts are PowerShell. Tested on a OnePlus 12
  `CPH2573` with build `17.0.0.100`.
- **ADB approval can expire.** Android forgets a PC after 7 days without a connection, so the
  phone may ask you to Allow USB debugging again.
- **SuperDisplay conflict.** SuperDisplay bundles its own older adb
  (`C:\Program Files\SuperDisplay\adb\adb.exe`, v40). When it and the SDK adb (v41) both
  run, they kill each other's server, and the phone may ask for USB-debugging approval again.
  Close SuperDisplay before running the script.
- **Banking apps** sometimes refuse to run while Developer options / USB debugging are on.
  With the phone app installed you can turn them off. If your OS restarts the phone to do
  that, the app re-applies the flag.

## Credit

The `keep_aod_on` trick was found by
[Astroisback/oneplus-13r-aod](https://github.com/Astroisback/oneplus-13r-aod)
for the OnePlus 13R (OxygenOS 16).
