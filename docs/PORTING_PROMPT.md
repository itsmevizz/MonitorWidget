# Porting MonitorBar to your Mac and monitor

Copy everything in the block below into an AI coding assistant that can run shell commands on your Mac (for example Claude Code, Cursor, or similar). Run it from the root of a cloned `MonitorWidget` repository.

---

```text
You are helping me get MonitorBar (a macOS menu bar app that controls an external monitor over DDC/CI) running on my Mac and my monitor. The repo is the current directory. Read README.md and MONITOR_REPORT.md first.

Work in this order and report back after each step:

1. Identify this system
   - Run: sw_vers; uname -m; system_profiler SPDisplaysDataType
   - Confirm the Mac is Apple Silicon (arm64) on macOS 14 or later. If it is Intel, stop and tell me: this app does not support Intel Macs.
   - Note the external displays listed and their connection.

2. Confirm DDC/CI reaches my monitor
   - Run: ioreg -r -c DCPAVServiceProxy -w0 | grep -E 'Location|IOClass'
   - At least one service must show Location = "External". If none does, tell me the monitor is not reachable over DDC/CI (check cable type and the monitor's DDC/CI setting) and stop.
   - Build the CLI: swift build -c release --product monitorctl
   - Run: .build/release/monitorctl list, then .build/release/monitorctl scan
   - Save the scan output to docs/monitor-scan-<model>.txt. Do not change any setting while scanning.

3. Analyse the monitor
   - From the scan, list: supported standard features (brightness 0x10, contrast 0x12, color preset 0x14, RGB gains 0x16/0x18/0x1A, input 0x60, volume 0x62, mute 0x8D, power 0xD6).
   - List the picture-mode or user-mode codes the monitor reports (vendor-specific codes such as 0xE0–0xE8 or 0xDC). Do not guess what they mean.
   - Note any feature in the capability string that Sources/DDCKit/VCP.swift does not name.

4. Make the app fit this monitor
   - Picture-mode labels: in Sources/MonitorWidget/ContentView.swift, the picture-mode chips are labelled "Mode 0xNN". Add a `pictureModeNames: [UInt8: String]` dictionary to Sources/DDCKit/VCP.swift for the names the monitor's on-screen menu uses, and use it for the chip labels. Only add names I confirm to you. If I haven't told you the names, leave the raw codes and ask me to read the names from the monitor's menu in order (do not invent them).
   - Input names: if the monitor reports input codes not in VCP.inputNames, add them there with the names from the monitor's manual or menu.
   - Do not expose factory reset (0x04) or power-off (0xD6). Do not write vendor-specific codes except the picture-mode selector, which the app already uses.
   - Keep changes small and confined to VCP.swift names and the lists above. Do not change the DDC protocol code unless the scan shows a read or write error.

5. Test without changing my settings
   - Before any write test, read the current value and write it back.
   - Do not switch picture mode or input to test. If a test is required, tell me first and I will decide.
   - Run: .build/release/monitorctl get brightness (and contrast) to confirm reads work.

6. Build and run
   - Run: ./scripts/build-app.sh
   - Run: open build/MonitorBar.app
   - Confirm the menu bar item appears. If it does not on macOS 26, tell me to allow it in System Settings → Menu Bar.

7. Report
   - Summarise: the Mac and macOS version, the monitor model, which features work, what you changed (file and line), and anything you could not verify.
   - Do not commit or push unless I ask.
```

---

## Notes for maintainers

- The prompt intentionally stops before changing picture modes or inputs on a live monitor, because those can reset settings or blank the screen.
- Names for picture modes must come from the monitor's own menu. Monitor brands label modes differently (for example sRGB, Reading, Movie, Darkroom), and the same code can mean different modes on different models.
