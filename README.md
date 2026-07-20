# Greekboard

A floating macOS 14+ Greek monotonic keyboard that works independently of the
system input sources. Physical keys are highlighted without changing what they
type, while clicking a virtual key inserts Unicode text into the previously
active application.

## Build

```sh
./scripts/build_app.sh
open "output/Greekboard.app"
```

The generated app is ad-hoc signed. Click-to-type requires Accessibility access;
global physical-key highlighting requires Input Monitoring access. Both are
requested only from explicit buttons in the app. Viewer mode works without
either permission.

## Test

```sh
./scripts/run_tests.sh
```
