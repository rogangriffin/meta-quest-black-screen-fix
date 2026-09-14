# Meta Quest black screen with working Guardian and casting: confirmed workaround

This is a confirmed workaround for a specific Meta Quest “black screen of death” failure:

- The Meta logo, boot menu, and USB Update Mode are visible.
- Guardian/boundary lines or the casting red dot are visible in the lenses.
- Controllers, tracking, and sound still work.
- Casting shows the normal Home environment and menus, even though the lenses show black.
- Factory resets and ordinary reboots do not fix it.

On one affected Quest 2, normal color returned immediately after forcing the VR runtime to use standard Quest 2 panel chromaticities instead of its device-specific color calibration:

```text
debug.oculus.colorspace.use_typical_chromaticities=1
```

This is not an official Meta repair and has currently been verified on one headset. It does not root the headset, flash firmware, erase data, or modify a partition. The setting is temporary and will normally need to be reapplied after a full reboot.

## Before doing anything destructive

Do not factory-reset a usable installation just to try this workaround. A factory reset did not repair the tested headset and made regaining ADB access much harder.

This workaround is aimed only at the symptom combination above. If the boot logo and USB Update Mode are also invisible, or casting is black too, the cause is probably different.

## What you need

1. A Windows, macOS, or Linux computer.
2. `adb` (Android Debug Bridge).
3. Developer Mode enabled on the Quest.
4. An ADB connection whose status is `device`, not `unauthorized`.

Meta recommends Meta Quest Developer Hub (MQDH) for device setup and includes ADB tooling with it. Meta’s current setup instructions are here:

- [Meta Horizon OS quick-start guide](https://developers.meta.com/horizon/essentials/quick-start/)
- [Meta Quest device setup](https://developers.meta.com/horizon/documentation/native/android/mobile-device-setup/)
- [Android Debug Bridge for Meta Quest](https://developers.meta.com/horizon/documentation/unity/ts-adb/)

You can also install Google’s standalone [Android SDK Platform Tools](https://developer.android.com/tools/releases/platform-tools).

On macOS, MQDH’s bundled ADB is normally located at:

```text
/Applications/Meta Quest Developer Hub.app/Contents/Resources/bin/adb
```

If `adb` is not recognized in Terminal, either enable ADB in MQDH, install Platform Tools, or use the full quoted path:

```bash
"/Applications/Meta Quest Developer Hub.app/Contents/Resources/bin/adb" devices -l
```

## Step 1: Confirm ADB access

Run:

```bash
adb devices -l
```

The usable headset entry must end in `device`, for example:

```text
List of devices attached
192.168.1.50:5555    device product:hollywood model:Quest_2
```

If it says `unauthorized`, put on the headset and accept **Allow USB debugging**, ideally selecting **Always allow from this computer**. Meta notes that this authorization must be accepted inside the headset.

If one physical headset appears twice—for example, one unauthorized USB entry and one authorized wireless entry—target the working entry with `-s`:

```bash
adb -s '<device ID shown by adb devices>' shell getprop ro.product.device
```

Add the same `-s '<device ID>'` immediately after `adb` in every command below.

Optional: record the model and build before changing anything:

```bash
adb shell getprop ro.product.device
adb shell getprop ro.build.version.incremental
adb shell getprop ro.build.version.release
adb shell getprop ro.build.version.security_patch
```

Quest should report the device codename `hollywood`.

## Step 2: Apply the color-calibration workaround

Run these commands exactly:

```bash
adb shell setprop debug.oculus.sysPropDebug 1
adb shell setprop debug.oculus.colorspace.use_typical_chromaticities 1
adb shell setprop debug.oculus.visualizeLayers 0
adb shell setprop debug.oculus.showAlpha 0
adb shell am force-stop com.oculus.systemdriver
```

Wait about six seconds for the VR runtime to restart.

On macOS or Linux:

```bash
sleep 6
```

On Windows PowerShell:

```powershell
Start-Sleep -Seconds 6
```

Then restart Home and assert that the headset is being worn:

```bash
adb shell am force-stop com.oculus.vrshell
adb shell am start -n com.oculus.vrshell/.HomeActivity
adb shell am broadcast -a com.oculus.vrpowermanager.prox_close
```

Look into the headset. On the tested unit, the Home environment and menus immediately returned in normal color.

## Step 3: Verify the setting

Run:

```bash
adb shell getprop debug.oculus.colorspace.use_typical_chromaticities
```

The result should be:

```text
1
```

If the headset is still black, first verify that the command targeted the authorized device. Then repeat the `com.oculus.systemdriver` restart and wait the full six seconds before restarting `com.oculus.vrshell`.

If the property reads `1` and the exact matching symptoms remain unchanged, this may be a different black-screen failure. Rebooting the headset will discard the temporary debug property.

## Reapply it after a reboot

The `debug.oculus.*` property is volatile. A complete headset reboot normally clears it, so the black display may return until the commands are applied again.

### macOS one-click script

The companion file [restore-quest-display.command](./restore-quest-display.command) automates the fix. Put it in the same folder as this guide, make it executable once, and then double-click it whenever the problem returns:

```bash
chmod +x restore-quest-display.command
```

The script waits up to 90 seconds for exactly one authorized ADB device. It ignores `unauthorized` entries. Wireless Debugging must still be enabled and the headset must be on the same network.

### Windows PowerShell version

The companion file [Restore-QuestDisplay.ps1](./Restore-QuestDisplay.ps1) automates the same steps. Put it in the same folder as this guide. If PowerShell blocks unsigned scripts, run it once from a PowerShell prompt as:

```powershell
powershell -ExecutionPolicy Bypass -File .\Restore-QuestDisplay.ps1
```

The script waits up to 90 seconds for exactly one authorized ADB device. It ignores `unauthorized` entries. If `adb` is not already on PATH, it looks for Meta Quest Developer Hub’s bundled copy.

If multiple authorized devices are listed, set the headset ID first:

```powershell
$env:QUEST_SERIAL='<device ID>'
powershell -ExecutionPolicy Bypass -File .\Restore-QuestDisplay.ps1
```

## If the USB authorization dialog cannot be seen

Try Meta’s standard setup route first:

1. Create or join a verified Meta developer team.
2. Pair the headset in the Meta Horizon mobile app.
3. In the mobile app, open **Devices → your headset → Developer Mode** and enable it.
4. Install MQDH and complete **Device Manager → Set Up New Device**.
5. Connect a USB-C **data** cable, not a charge-only cable.
6. Accept **Allow USB debugging** in the headset.

These are the supported steps documented in [Meta’s Device Setup guide](https://developers.meta.com/horizon/documentation/native/android/mobile-device-setup/) and [MQDH headset setup](https://developers.meta.com/horizon/documentation/unity/ts-mqdh-device-setup/).

On the tested broken headset, the USB RSA authorization prompt was invisible, did not appear in casting, and closed after roughly two seconds. We worked around that by opening hidden Android Settings and enabling Android’s **Wireless debugging**:

1. Cast the headset to a phone or MQDH so you can navigate the otherwise invisible interface.
2. Open Android Settings using a utility already installed on the headset. We used the community [Singularity app](https://github.com/Lumince/singularity/releases) only for its Android Settings shortcut; root was **not** used or required.
3. Open **System → Developer options → Wireless debugging**.
4. Enable **Use wireless debugging** and accept the network prompt.
5. Select **Pair device with pairing code**.
6. Note the IP address, temporary pairing port, and six-digit code.
7. On the computer, run:

   ```bash
   adb pair '<headset IP>:<pairing port>'
   ```

8. Enter the six-digit pairing code when prompted.
9. Return to the main Wireless debugging page. Its normal connection port may differ from the temporary pairing port. Run:

   ```bash
   adb connect '<headset IP>:<connection port>'
   adb devices -l
   ```

10. Use the wireless entry ending in `device` for the workaround.

Installing third-party utilities carries risk. Download community tools only from their original project, and do not attempt Singularity’s root feature for this workaround. If you cannot authorize USB ADB and do not already have a safe way to open Android Settings or install an APK, there is not yet a universal bootstrap method; continue with Meta’s supported MQDH/device-setup route.

## Why this appears to work

This explanation is an evidence-based inference, not a confirmed diagnosis from Meta.

On the repaired Quest:

- Casting showed the correctly rendered scene.
- The LCD, backlight, boot UI, USB Update Mode, Guardian, and tracking all worked.
- Meta’s compositor-layer visualizer made all menu geometry visible as solid colors. Meta documents that visualizer in [Compositor layers](https://developers.meta.com/horizon/documentation/unity/os-compositor-layers/).
- The compositor’s alpha-channel diagnostic produced a white scene background and black menu silhouettes, proving texture sampling and geometry were active while normal RGB remained zero.
- Layer logs showed valid swapchains and `ColorScale (1, 1, 1, 1)`.
- The installed VR runtime contains panel color-space transformation code and a writable `debug.oculus.colorspace.use_typical_chromaticities` override.
- Enabling that one override restored normal RGB immediately.

The most likely explanation is that the device-specific panel chromaticity/calibration path is returning invalid data or an invalid transform, causing ordinary RGB output to be multiplied to black. Standard Quest chromaticities bypass that path. This may slightly reduce unit-specific color accuracy, but it restored an otherwise unusable display.

## Tested configuration

The confirmed headset reported:

```text
Model: Meta Quest 2
Device codename: hollywood
Build incremental: 52242990024200150
Android release: 14
Security patch string: 2026-06-03
```

The headset reportedly first developed the Guardian-visible/casting-works black-screen failure around the v57 era and remained broken through factory resets and later software.

## Undo the workaround

The simplest undo is a normal reboot. You can also set the override to zero and restart the runtime:

```bash
adb shell setprop debug.oculus.colorspace.use_typical_chromaticities 0
adb shell am force-stop com.oculus.systemdriver
```

Wait six seconds, then restart Home as described above.

## Useful report template

To help determine which headsets and builds this affects, report:

```text
Headset model:
Device codename:
Build incremental:
Did the boot logo/recovery display normally?
Was Guardian visible?
Did casting show the normal scene?
Did the compositor visualizer show solid-colored layers?
Did use_typical_chromaticities=1 restore normal color?
Did the fix survive a reboot?
```

Do not publish the headset serial number, Meta account email, wireless-debugging pairing code, or local IP address.

## References

- [Meta Horizon OS quick-start guide](https://developers.meta.com/horizon/essentials/quick-start/)
- [Meta Quest device setup](https://developers.meta.com/horizon/documentation/native/android/mobile-device-setup/)
- [Android Debug Bridge for Meta Quest](https://developers.meta.com/horizon/documentation/unity/ts-adb/)
- [Set up a headset with MQDH](https://developers.meta.com/horizon/documentation/unity/ts-mqdh-device-setup/)
- [Meta compositor-layer diagnostics](https://developers.meta.com/horizon/documentation/unity/os-compositor-layers/)
- [Singularity project releases](https://github.com/Lumince/singularity/releases) — optional community tool used only to reach Android Settings on the tested headset
