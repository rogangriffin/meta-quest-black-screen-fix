#!/bin/zsh

set -euo pipefail

ADB="/Applications/Meta Quest Developer Hub.app/Contents/Resources/bin/adb"
QUEST_SERIAL="${QUEST_SERIAL:-}"

if [[ ! -x "$ADB" ]]; then
  echo "Meta Quest Developer Hub's ADB tool was not found:"
  echo "$ADB"
  echo
  read -r "?Press Return to close."
  exit 1
fi

echo "Waiting for the Quest 2 over wireless debugging..."
connected=0

for attempt in {1..90}; do
  device_list=$("$ADB" devices 2>/dev/null || true)
  if [[ -n "$QUEST_SERIAL" ]]; then
    state=$("$ADB" -s "$QUEST_SERIAL" get-state 2>/dev/null || true)
  else
    authorized_devices=("${(@f)$(printf '%s\n' "$device_list" | awk '$2 == "device" { print $1 }')}")
    if (( ${#authorized_devices[@]} == 1 )); then
      QUEST_SERIAL="${authorized_devices[1]}"
      state="device"
    else
      state=""
    fi
  fi
  if [[ "$state" == "device" && -n "$QUEST_SERIAL" ]]; then
    connected=1
    break
  fi
  sleep 1
done

if (( ! connected )); then
  echo
  echo "The headset was not found after 90 seconds."
  echo "Make sure it is on, connected to the same Wi-Fi, and Wireless debugging is enabled."
  echo "If multiple authorized devices are listed, run this script from Terminal as:"
  echo "QUEST_SERIAL='<device ID>' '$0'"
  echo
  "$ADB" devices -l || true
  echo
  read -r "?Press Return to close."
  exit 1
fi

echo "Headset connected as $QUEST_SERIAL. Applying the display recovery override..."

"$ADB" -s "$QUEST_SERIAL" shell setprop debug.oculus.sysPropDebug 1
"$ADB" -s "$QUEST_SERIAL" shell setprop debug.oculus.colorspace.use_typical_chromaticities 1
"$ADB" -s "$QUEST_SERIAL" shell setprop debug.oculus.visualizeLayers 0
"$ADB" -s "$QUEST_SERIAL" shell setprop debug.oculus.showAlpha 0

echo "Restarting the VR compositor..."
"$ADB" -s "$QUEST_SERIAL" shell am force-stop com.oculus.systemdriver
sleep 6

echo "Restarting Home..."
"$ADB" -s "$QUEST_SERIAL" shell am force-stop com.oculus.vrshell
"$ADB" -s "$QUEST_SERIAL" shell am start -n com.oculus.vrshell/.HomeActivity >/dev/null
sleep 3
"$ADB" -s "$QUEST_SERIAL" shell am broadcast -a com.oculus.vrpowermanager.prox_close >/dev/null

applied=$("$ADB" -s "$QUEST_SERIAL" shell getprop debug.oculus.colorspace.use_typical_chromaticities | tr -d '\r')
if [[ "$applied" != "1" ]]; then
  echo "The headset connected, but the display override was not accepted."
  echo
  read -r "?Press Return to close."
  exit 1
fi

echo
echo "Done. Normal headset color should now be restored."
echo "You can close this window."
echo
read -r "?Press Return to close."
