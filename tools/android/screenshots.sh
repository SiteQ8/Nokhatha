#!/bin/sh
# Takes the Play screenshots on an emulator: the sample household in Arabic and English,
# every tab, and the first-run setup. Runs inside the emulator step of android.yml.
set -e
APK=android/app/build/outputs/apk/debug/app-debug.apk
PKG=com.eworldq8.nokhatha
adb install -r "$APK"
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0941
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 -e mobile hide
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
mkdir -p shots
for lang in ar en; do
  for tab in today home car subs more; do
    adb shell am start -S -W -n "$PKG/.MainActivity" --ez sample true --es tab "$tab" --es lang "$lang"
    sleep 6
    adb exec-out screencap -p > "shots/$lang-$tab.png"
  done
done
for combo in "home task" "subs sub" "home addtask" "home edit" "car odo"; do
  set -- $combo
  adb shell am start -S -W -n "$PKG/.MainActivity" --ez sample true --es tab "$1" --es sheet "$2" --es lang ar
  sleep 7
  adb exec-out screencap -p > "shots/ar-sheet-$2.png"
done
adb shell am start -S -W -n "$PKG/.MainActivity" --ez sample true --ez widget true --es lang ar
sleep 6
adb exec-out screencap -p > shots/ar-widget.png
adb shell pm clear "$PKG" >/dev/null
for page in settings docs warranties techs travel spend about things; do
  adb shell am start -S -W -n "$PKG/.MainActivity" --ez sample true --es tab more --es page "$page" --es lang ar
  sleep 6
  adb exec-out screencap -p > "shots/ar-page-$page.png"
done
for lang in ar en; do
  adb shell am start -S -W -n "$PKG/.MainActivity" --es screen setup --es lang "$lang"
  sleep 6
  adb exec-out screencap -p > "shots/$lang-setup.png"
  adb shell am start -S -W -n "$PKG/.MainActivity" --es lang "$lang"
  sleep 6
  adb exec-out screencap -p > "shots/$lang-welcome.png"
done
ls -la shots
