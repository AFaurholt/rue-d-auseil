# Package

version = "0.1.0"
author = "afaurholt"
description = "text_adventure"
license = "MIT"

# Deps
requires "nim >= 1.5.1"
requires "nico >= 0.2.5"

srcDir = "src"

import strformat

const releaseOpts = "-d:danger"
const debugOpts = "-d:debug"

task test, "Runs testament":
  exec &"testament pattern \"tests/*.nim\""
  exec &"testament html"

task runr, "Runs text_adventure for current platform":
 exec &"nim c -r {releaseOpts} -o:text_adventure src/text_adventure.nim"

task rund, "Runs debug text_adventure for current platform":
 exec &"nim c -r {debugOpts} -o:text_adventure src/text_adventure.nim"

task release, "Builds text_adventure for current platform":
 exec &"nim c {releaseOpts} -o:text_adventure src/text_adventure.nim"

task webd, "Builds debug text_adventure for web":
 exec &"nim c {debugOpts} -d:emscripten -o:text_adventure.html src/text_adventure.nim"

task webr, "Builds release text_adventure for web":
 exec &"nim c {releaseOpts} -d:emscripten -o:text_adventure.html src/text_adventure.nim"

task debug, "Builds debug text_adventure for current platform":
 exec &"nim c {debugOpts} -o:text_adventure_debug src/text_adventure.nim"

task deps, "Downloads dependencies":
 exec "curl https://www.libsdl.org/release/SDL2-2.0.12-win32-x64.zip -o SDL2_x64.zip"
 exec "unzip SDL2_x64.zip"
 #exec "curl https://www.libsdl.org/release/SDL2-2.0.12-win32-x86.zip -o SDL2_x86.zip"

task androidr, "Release build for android":
  if defined(windows):
    exec &"nicoandroid.cmd"
  else:
    exec &"nicoandroid"
  exec &"nim c -c --nimcache:android/app/jni/src/armeabi {releaseOpts}  --cpu:arm   --os:android -d:androidNDK --noMain --genScript src/text_adventure.nim"
  exec &"nim c -c --nimcache:android/app/jni/src/arm64   {releaseOpts}  --cpu:arm64 --os:android -d:androidNDK --noMain --genScript src/text_adventure.nim"
  exec &"nim c -c --nimcache:android/app/jni/src/x86     {releaseOpts}  --cpu:i386  --os:android -d:androidNDK --noMain --genScript src/text_adventure.nim"
  exec &"nim c -c --nimcache:android/app/jni/src/x86_64  {releaseOpts}  --cpu:amd64 --os:android -d:androidNDK --noMain --genScript src/text_adventure.nim"
  withDir "android":
    if defined(windows):
      exec &"gradlew.bat assembleDebug"
    else:
      exec "./gradlew assembleDebug"
