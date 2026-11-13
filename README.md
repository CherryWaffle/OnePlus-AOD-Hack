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
.\aod.ps1 off      # restore the stock timeout (rebooting also does this)
```

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
