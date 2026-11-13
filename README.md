# Keep full-screen AOD on: OPPO, OnePlus, Realme (no root)

On many phones running ColorOS or a system built on it (OxygenOS, Realme UI), the
**full-screen Always-On Display** (the one that shows your wallpaper) turns itself off after
about 5 seconds, and Settings has no option to keep it on. Some models, like the OnePlus 13,
get an "all day" option; others don't.

This project keeps it on using a hidden switch that is already in the phone's SystemUI.
**No root, no unlocked bootloader, no system files changed, and fully reversible.**

- [Is this for my phone?](#is-this-for-my-phone)
- [Set it up](#set-it-up) (about 10 minutes, once)
- [Troubleshooting](#troubleshooting)
- [Undo everything](#undo-everything)
- [Things to know](#things-to-know)
- [Without the app (PC scripts)](#without-the-app-pc-scripts)
- [Build it yourself](#build-it-yourself)
- [How it works](#how-it-works)

## Is this for my phone?

It is if all of these are true:

- It's an **OPPO, OnePlus or Realme** phone on **ColorOS, OxygenOS or Realme UI**,
  Android 11 or newer.
- Its Always-On Display settings offer a **full-screen** style, and that style **turns off
  after a few seconds** with no "all day" option.

Tested:

| Phone | Software | Result |
|---|---|---|
| OnePlus 12 (CPH2573) | ColorOS 17 (17.0.0.100) | Works, app and scripts |
| OnePlus 13R | OxygenOS 16 | Works, same switch ([Astroisback/oneplus-13r-aod](https://github.com/Astroisback/oneplus-13r-aod)) |

Other OPPO/OnePlus/Realme models probably work if their SystemUI has the same switch. The
app tells you after one tap (see [Troubleshooting](#troubleshooting)). Samsung, Pixel,
Xiaomi and other brands don't have this switch, so it can't work there.

## Set it up

### What you need

- A **Windows PC** and a USB **data** cable. (On Mac or Linux, see
  [Mac or Linux](#mac-or-linux).)
- Google's **SDK Platform-Tools** (adb), a small free download. You don't need Android Studio.

### 1. Pick the full-screen AOD on the phone

Settings → **Wallpapers & style** → **Always-On Display** (or search Settings for
"Always-On Display"). Turn it on and choose a **full-screen** style.

Lock the phone. If the AOD disappears after about 5 seconds, you're in the right place.

### 2. Turn on USB debugging

1. Settings → **About device** → **Version** → tap **Build number** 7 times and enter your
   PIN (or search Settings for "Build number"). This unlocks Developer options.
2. Open **Developer options** (search Settings for it) and turn on **USB debugging**.
3. Plug the phone into the PC. On the phone, tap **Allow** on "Allow USB debugging?" and tick
   **Always allow from this computer**.

### 3. Download this project and adb

1. On GitHub: **Code → Download ZIP**, then extract it. (Or `git clone` it.)
2. Download **SDK Platform-Tools for Windows** from
   [developer.android.com/tools/releases/platform-tools](https://developer.android.com/tools/releases/platform-tools)
   and unzip it. Move the `platform-tools` folder into the project folder, next to
   `install-app.cmd`. (If adb is already on your PATH or in an Android SDK, skip this.)

### 4. Install the app

In the project folder, double-click **`install-app.cmd`** (if Windows asks whether to run a
downloaded file, choose **Run**). It installs the ready-made app from `prebuilt\` on the
phone and gives it the one permission it needs. It should end with:

```
Installed with the DUMP permission. Open "AOD Keep-On" on the phone and tap Turn on.
```

(Prefer to build the app yourself? See [Build it yourself](#build-it-yourself).)

### 5. Turn it on

On the phone, open **AOD Keep-On** and tap **Turn on**. It should say **ON**.

Lock the phone: the full-screen AOD now stays on.

### 6. Turn off USB debugging (optional)

The app doesn't need it any more. You can turn off USB debugging or Developer options. If
your phone restarts when you turn Developer options off (OxygenOS 16 does), the app turns
the AOD back on after the restart by itself.

That's it. **After every restart, the app turns it back on automatically**, even before
you unlock the phone. To turn it off, open the app and tap **Turn off**; it stays off after
restarts until you tap **Turn on** again.

### Mac or Linux

The `.cmd` and `.ps1` files are Windows-only, but the app isn't. Install SDK Platform-Tools
for your system, turn on USB debugging (step 2), and in the project folder run:

```
adb install -r -g prebuilt/AodKeepOn.apk
```

Keep the `-g`: it gives the app its permission. Then continue with step 5.

## Troubleshooting

| What you see | What to do |
|---|---|
| Windows says "running scripts is disabled" | Use the `.cmd` files (double-click). They run the scripts with a one-time bypass. |
| "adb not found" | Unzip Google's SDK Platform-Tools and put the `platform-tools` folder inside the project folder (step 3). |
| "No phone found" | Use a data cable (not charge-only), check USB debugging is on, try another USB port. |
| "Phone is unauthorized" | Unlock the phone and tap **Allow** on the USB debugging prompt. |
| The phone keeps asking to allow USB debugging, or you see "adb server version doesn't match" | Another program on the PC runs its own copy of adb (for example SuperDisplay or a phone-mirroring tool). Close it and try again. |
| "signed with a different key" | You have a copy of the app built with another key (for example your own build). Uninstall AOD Keep-On from the phone and run `install-app.cmd` again. |
| "Android SDK not found" or "JDK 17+ not found" (only `build-app.cmd`) | Install Android Studio and open it once, or set `ANDROID_HOME` / `JAVA_HOME`. Or use `install-app.cmd`, which doesn't need them. |
| "Installed, but the DUMP permission was not granted" | Your software blocks it. If Developer options has **Disable permission monitoring**, turn it on and run `install-app.cmd` again. |
| The app shows "One-time setup needed" | It was installed without its permission (for example by opening the APK on the phone). Run `install-app.cmd` from the PC. |
| The app says **Unknown** | Your phone's SystemUI doesn't have the switch, so this can't work on it (or a system update removed it). |
| The app says **OFF** right after Turn on | SystemUI ignored the switch: this phone or software version isn't supported. |
| The app says **ON** but the AOD still turns off | Check you picked a **full-screen** AOD style. AOD also turns off on purpose when the phone is in a pocket or covered. |
| AOD stops staying on after a restart | Open the app. If it says OFF, tap **Turn on**. If that happens after every restart, allow the app to auto-launch: Settings → Apps → AOD Keep-On → battery / auto launch. |

## Undo everything

The simplest way: **uninstall AOD Keep-On and restart the phone.** Nothing else was changed.

Or, with the phone on USB debugging, double-click **`restore.cmd`**. It:

1. Turns the switch off.
2. Uninstalls the app (otherwise it would turn the switch back on at the next restart).
3. Compares AOD-related settings (keys containing `aod`, `doze`, `ambient`, `panoramic`) with
   a "before" snapshot and lists any differences.

The snapshot is saved by the first `aod.cmd` / `.\aod.ps1 on` (or by hand with
`.\backup.ps1`) into `backups\`, which is git-ignored because it holds your phone's own
settings. Differences usually come from changes you made yourself, like switching AOD style,
so they are only listed. To write the snapshot values back anyway:

```powershell
.\restore.ps1 -ApplySettings -WhatIf   # preview
.\restore.ps1 -ApplySettings
```

Developer options and USB debugging are never touched. To remove a PC's access: Developer
options → **Revoke USB debugging authorisations**.

## Things to know

- **Battery and burn-in.** The AOD stays lit whenever the phone is face-up and uncovered.
  Pocket detection and the AOD's burn-in protection are separate code that the switch
  doesn't touch, but this is more screen-on time than the maker allows on these phones.
- **It isn't the maker's real "all day" mode.** It skips the hide instead of switching that
  mode on. The real flag is locked to debug builds (see [How it works](#how-it-works)).
- **A system update can break it.** It's a hidden debug switch, and the maker already blocks
  similar ones on retail phones. After an update, open the app: ON means it still works.
- **Brightness tops out around 70-100 nits** in bright light. That's the phone's own AOD
  brightness curve, and it can't be raised without root (see
  [AOD brightness](#aod-brightness)).
- **The clock-only AOD style is unaffected**, apart from two small side effects while the
  switch is on: SystemUI's face-down check for AOD turns on, and a *Scheduled* AOD may keep
  its clock updating outside your hours (not tested).
- **A SystemUI crash clears the switch** without a restart, and the app doesn't notice.
  Open the app and tap **Turn on**.
- **ADB approval expires** if the PC doesn't connect for 7 days, so the phone may ask again
  the next time you plug in.
- The PC scripts are **Windows only** (PowerShell).

## Without the app (PC scripts)

If you'd rather not install an app, the PC can flip the switch directly. You then have to do
it **after every restart**, with USB debugging on:

- Double-click **`aod.cmd`**, or run `.\aod.ps1 on` in PowerShell.

Other commands:

```powershell
.\aod.ps1 status   # is it on right now? (reads SystemUI's live value)
.\aod.ps1 watch    # 30 s live view (-Seconds N): light level -> AOD brightness, timeouts
.\aod.ps1 off      # back to the stock timeout (a restart also does this)
```

`watch` shows what the AOD does while the phone is locked:

```
23:08:23  AOD started
23:08:25  light    198 lux  ->  AOD  33.1 nits
23:08:29  timeout fired, skipped (keep_aod_on is active)
```

On Mac or Linux the scripts don't run, but the switch is one adb command
(`1` = keep on, `0` = stock; repeat after every restart):

```
adb shell dumpsys activity service com.android.systemui/.keyguard.KeyguardService debug keep_aod_on 1
```

## Build it yourself

`prebuilt\AodKeepOn.apk` is built from the source in `app\` with `app\build.ps1`. To check
your download, compare its hash with `prebuilt\SHA256.txt`:

```powershell
Get-FileHash .\prebuilt\AodKeepOn.apk -Algorithm SHA256
```

To build and install it yourself instead, you need
[Android Studio](https://developer.android.com/studio) (open it once so it downloads the
Android SDK), or the Android SDK and a JDK 17+. Then double-click **`build-app.cmd`**, or run
`.\app\build.ps1 -Install`.

- It uses plain SDK tools (javac, d8, aapt2, apksigner), no Gradle.
- The first build creates your own signing key, `app\keystore\signing.jks`, with a random
  password in `app\keystore\password.txt`. Both are git-ignored; back them up together.
  Android only updates an app signed with the same key, so to switch between the prebuilt
  app and your own build, uninstall AOD Keep-On first.
- Keys made by earlier versions of the script used the password `android`. The next build
  moves them to a random password automatically; the key itself doesn't change.
- Maintainers: `.\app\build.ps1 -Prebuilt` rebuilds `prebuilt\` and its `SHA256.txt` with the
  project's key.

## How it works

The switch is a debug field in SystemUI, reachable through `dumpsys`:

```
adb shell dumpsys activity service com.android.systemui/.keyguard.KeyguardService debug keep_aod_on 1
```

Checked in the SystemUI APK pulled from a OnePlus 12 on ColorOS 17:

- SystemUI asks the display panel whether all-day full-screen AOD is allowed
  (`isSupportPanoramicAllDayByPanelFeature`). When the answer is no, a hide timer fires a few
  seconds after the full-screen AOD appears (`hideByTimeoutReceiver`).
- Before hiding, `BaseAodClockLayoutController.onEnergySavingNotifyHide()` checks a debug
  field, `mKeepAodOn`. If it is 1, the hide is skipped and the log says
  `onEnergySavingNotifyHide: keep aod on for test!`
- `OplusKeyguardServiceExImpl.dumpPhaseThree(debug keep_aod_on 1)` sets that field. Unlike
  its neighbours, it has no `Build.isDebuggable()` check, so a retail phone accepts it.
- The field only exists in memory and SystemUI sets it to 0 at every start, which is why it
  has to be set again after a restart. SystemUI prints it in its `aod_display` dump
  (`keepAodOn: 1`), which is how the app and `.\aod.ps1 status` read it.

Setting `oplus_keyguard_panoramic_aod_all_day_support` by hand does not help: SystemUI writes
that value from the panel check for the Settings app to read, and it doesn't control the timer.
The real all-day flag can be set with `smt userEnablePanoramicAllDay true`, but only on debug
builds (`Build.isDebuggable()`).

### The app

`app\` is **AOD Keep-On**, a few hundred lines of Java with no libraries. It runs the same
`dumpsys` command itself, which needs `android.permission.DUMP`. Only ADB can grant that,
once:

- ColorOS 17 blocks `adb shell pm grant` and no longer has *Disable permission monitoring*
  in Developer options, but `adb install -g` still grants it during the install. That's
  what `install-app.cmd` (`app\install.ps1`) does.
- The permission belongs to the installed app, so it survives turning Developer options off
  (tested).
- A direct-boot-aware receiver re-applies your last choice after every restart. On the tested
  phone the switch was back on about 9 s after boot, before the first unlock.

### AOD brightness

Full-screen AOD brightness follows the ambient light with or without this project. Measured
with `.\aod.ps1 watch` on a OnePlus 12:

| Ambient light | AOD brightness |
|---|---|
| ~200 lux (room light) | 33 nits |
| ~350 lux | 40 nits |
| ~850 lux | 61 nits |
| ~1100 lux (phone torch) | 70 nits |

How SystemUI picks the value (`OplusPanoramicAODLightController.calculateBrightness`):

- A low-power AOD light sensor reports when the light band changes. SystemUI then takes one
  reading from the main light sensor, which sits under the top of the display.
- The reading is put into one of 26 bands (0, 25, 100, 200 … 2000, 2500, 3000, 3500 lux),
  looked up in a nit table (6 … 323 nits), and **divided by 1.6**.
- The band can be capped at level 18 (about 1700 lux, ~99 nits). If AOD starts right after
  the screen was on, the level is also capped at the screen brightness you had before locking.

It can't be raised without root: the nit table is a SystemUI resource
(`config_panoramic_aod_brightness_nit`) that shell-made overlays can't replace, and the
debug overrides in the same handler (`aod_brightness_debug`, `aod_lux_debug`) only work on
debug builds.

## Credit

The `keep_aod_on` trick was found by
[Astroisback/oneplus-13r-aod](https://github.com/Astroisback/oneplus-13r-aod)
for the OnePlus 13R (OxygenOS 16).
