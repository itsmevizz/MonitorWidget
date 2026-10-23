# Monitor analysis: Acer KA270 P6

Captured on an Apple M4 Mac, macOS 26.6.1, using `monitorctl scan` and cross-checked with `m1ddc`.

## Identity

| Field | Value |
|---|---|
| macOS name | KA270 P6 |
| Manufacturer (EDID) | ACR (Acer) |
| Model string (DDC) | `ACER` |
| Year of manufacture | 2026 |
| Native resolution | 1920 x 1080 @ 144 Hz (max refresh 144 Hz) |
| Serial | 2626027A33W01 |
| MCCS version | 2.2 |
| Connection | External (macOS reports `Location = External` on its DDC service) |
| Current input | HDMI 1 (`0x11`) |

## Current settings (read over DDC/CI)

| Feature | VCP | Value | Max | Notes |
|---|---|---|---|---|
| Brightness | 0x10 | 80 | 100 | |
| Contrast | 0x12 | 50 | 100 | |
| Color preset | 0x14 | 5 (6500 K) | 11 | |
| Red gain | 0x16 | 50 | 100 | |
| Green gain | 0x18 | 50 | 100 | |
| Blue gain | 0x1A | 50 | 100 | |
| Input source | 0x60 | 17 (HDMI 1) | | |
| Speaker volume | 0x62 | 100 | 100 | |
| Audio mute | 0x8D | 2 (unmuted) | | MCCS: 1 = mute, 2 = unmute |
| OSD language | 0xCC | 2 | 13 | |
| Power mode | 0xD6 | 1 (On) | | |

## Supported features

The monitor's MCCS capability string:

```
(prot(monitor)type(LCD))model(ACER)cmds(01 02 03 07 0C E3 F3)
vcp(04 10 12 14(05 06 08 0B) 16 18 1A 59 5A 5B 5C 5D 5E 60(01 11) 62 8D
    9B 9C 9D 9E 9F A0 CC(01 02 03 04 05 06 07 08 09 0a 0c 0d 0e 14 16 1E 24)
    D6(01 02 04 05) E0(00 04 05) E1(01 05 06) E2(00 01 02 03 04 09 0C 0D 14 15 16)
    E3 E4 E5 E7(00 01 02) E8(00 01 02 03 04))
mswhql(1) asset_eep(40) mccs_ver(2.2)
```

### Standard features the widget uses

- **Brightness, contrast, RGB gains, speaker volume**: continuous 0–100.
- **Color preset**: 6500 K, 7500 K, 9300 K, User 1.
- **Input source**: only VGA 1 (`0x01`) and HDMI 1 (`0x11`) are listed. DisplayPort and USB-C are **not** exposed to DDC, so the widget can't switch to them.
- **Audio mute**: toggle.
- **Power mode**: On / Standby / Off (soft) / Off (hard). Read-only in the widget. Writing it can leave the panel off with no DDC wake-up, so I left it out.

### Acer vendor-specific codes (not exposed in the widget)

- `0x59`–`0x5E` and `0x9B`–`0xA0`: six 0–100 channels, probably color/gamma tuning (Acer "Color" / "Gamma" OSD items). Not labelled in the MCCS spec, so I haven't written them.
- `0xE0`–`0xE8`: enumerated Acer OSD modes (picture mode, eco/blue-light, and similar). Reads return 255 for some, which looks like "not active". Left alone on purpose.
- `0x04` (restore factory defaults): **deliberately not exposed**. It resets every setting.

## Controlling it in software

- The monitor supports **DDC/CI over the USB-C/DP link**. The widget and CLI write VCP codes over the IOAVService I2C channel at address `0x37`.
- Writes read back correctly. I verified brightness 80 → 70 → 80.
- Values match `m1ddc` (brightness 80, contrast 50, volume 100, input 17, mute 2).
- Reads have no side effects. Writes take effect immediately. Whether a write persists across a monitor power cycle is untested.

## Limits

- The Mac-side display brightness slider does not affect the monitor's DDC brightness. The widget controls the monitor's backlight directly.
- Input switching is limited to VGA/HDMI 1, as above.
- Some DDC commands are rate-limited (~40 ms gap). The widget coalesces slider drags into one write per ~60 ms.
