# LAST LIGHT — Release Checklist

## Project and data

- [ ] Confirm Godot 4.7.2 stable and run `.\scripts\dev.ps1 -Action import`.
- [ ] Run `.\scripts\dev.ps1 -Action check` and `.\scripts\test.ps1`.
- [ ] Inspect `git diff --check`; confirm `.godot/`, `build/`, user saves, keystores, and credentials are not staged.
- [ ] Confirm all bundled assets have licenses; Noto Sans Thai's SIL OFL is included in `projects/last-light/assets/fonts/OFL.txt`.
- [ ] Review English and Thai text, font fallback, large-text layout, and Reduce Flashes behavior.

## Windows

- [ ] Install the matching Godot 4.7.2 export templates.
- [ ] Run `.\scripts\export.ps1 -Platform Windows -Mode release`.
- [ ] Launch `projects\last-light\build\windows\LAST_LIGHT.exe` on a clean Windows machine without the editor.
- [ ] Verify keyboard, audio, settings/profile persistence, and windowed portrait layout.

## Android

- [ ] Configure Android SDK and JDK in Godot Editor Settings; install matching export templates.
- [ ] Run `.\scripts\export.ps1 -Platform Android -Mode debug`.
- [ ] Install the APK on a physical Android device and verify launch, audio, pause/resume, touch controls, safe area, and relaunch persistence.
- [ ] Test at least one notch/rounded-corner device and one lower-performance target if those are supported.
- [ ] Before store release, set the final package ID/version and sign with a release keystore stored outside the repository.

## Final gates

- [ ] Complete [PLAYTEST_PLAN.md](./PLAYTEST_PLAN.md) with at least one new player and record the results.
- [ ] Fix critical crashes, save loss, obscured warnings, and unresponsive controls.
- [ ] Confirm actual target-device frame rate and set a performance budget from measurements.
- [ ] Confirm local diagnostics are useful and contain no sensitive/player-identifying data.
- [ ] Do not claim Android/Windows release readiness until the exported builds pass on clean target devices.

Local diagnostic files are stored under the OS-specific Godot `user://logs/` directory. They are not uploaded or transmitted.
