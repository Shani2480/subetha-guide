# The Sub-Etha Guide (H2G2)

An all-in-one KDE Plasma 6 widget in the style of *The Hitchhiker's Guide to
the Galaxy*. It covers weather, system compute, storage and battery in one
card, with modular sections. Don't Panic.

Two looks: the 2005 film's cream Encyclopedia pages (light) and the 1981 BBC
Sub-Etha terminal's phosphor green on CRT black (dark). **Solar Auto** switches
between them at sunrise and sunset at the weather location.

## Sections

One header (title, location or host name, DON'T PANIC) sits over four
sections in a fixed order:

| Section | Shows |
| --- | --- |
| Weather | Sky hero card, temperature and feels-like, hourly and weekly drawers, Arthur and Marvin on the forecast strip (Open-Meteo) |
| System | CPU load / clock / temperature, memory, GPU load / temperature / VRAM, network throughput, cooling fans; optional host profile banner and 24-sample sparklines; process diagnostics launcher |
| Storage | Selected volumes: usage, free space, filesystem, live read / write throughput (the activity LED pulses past 50 MB/s) |
| Power | Laptop battery and peripherals, live charge / drain wattage, mains and power profile |

A section switched off folds away (its height animates to 0) and its feed
stops: no fetches, probes or sensors for a module that isn't shown.

On the desktop the card snaps to fixed layout steps:
- **Width:** 260, 360 or 740 px. At 740 the sections flow into two columns.
- **Height:** 110, 240 or 380 px, then more 110 px rows.

It settles 200 ms after a resize and animates there. Plasma's applet box
follows the resize handle freely, so the card snaps inside it and scrolls
when the content is taller.

## Settings

One tab per module:
- **Appearance & Sections:** theme and display mode (Full / Minimal), picked
  from preview cards with hover descriptions, and which sections show.
- **Weather & Location:** place search or detect, units, icon style, update
  interval, background animations, Arthur and Marvin.
- **System Hardware:** which pills, fans, sparklines, host profile,
  temperature unit, sampling interval.
- **Disks & Storage:** which volumes, throughput, figure and unit, warning
  level.
- **Power & Battery:** which devices, wattage, gauges, estimates, critical
  level.

**Process diagnostics**: the System section's `[LAUNCH FULL PROCESS
DIAGNOSTICS]` pill (Full mode) and the widget's context menu open the fullest
process monitor available. It tries, in order:
1. a themed companion at `package/contents/tools/subetha-monitor.py`, if present
2. KDE System Monitor
3. KSysGuard
4. otherwise Discover, opened on System Monitor's page to install it

## Install

```sh
./install.sh            # install or upgrade
./install.sh --restart  # ...and restart plasmashell
```

Then add **The Sub-Etha Guide (H2G2)** from the Widget Explorer (System
Information).

## Layout

```text
package/                       the Plasma applet (com.shani.subethaguide)
├── metadata.json
└── contents/
    ├── config/                main.xml (settings), config.qml (tabs)
    └── ui/
        ├── main.qml           feeds, theme, actions, representations
        ├── FullRepresentation.qml, *Section.qml, ModuleCard.qml
        ├── CompactRepresentation.qml
        ├── config*.qml, PreviewCard.qml
        ├── common/            theme, frames, pills, snapping, sparklines
        ├── weather/           WeatherFeed, FullView, MinimalView, characters, icons
        ├── system/            SystemFeed, SystemPanel, pills, SpecsBanner
        ├── disk/              DiskFeed, DiskPanel, DiskPillCard, VolumePicker
        └── battery/           BatteryFeed, BatteryPanel, BatteryPillCard, DevicePicker
```

## Data sources

- **Weather**: [Open-Meteo](https://open-meteo.com/), no API key.
- **System**: Plasma's sensor daemon (`ksystemstats`, through
  `org.kde.ksysguard.sensors`), throttled to the update interval. It runs
  only while the card is on screen and the session is unlocked. The host
  profile is read once: `/proc/cpuinfo`, `lspci`, memory type from the DMI
  tables through udev (no root), `uname` and `/etc/os-release`.
- **Storage**: one `df` + `lsblk` + `/proc/diskstats` probe, every 2 s while
  on screen and once a minute otherwise.
- **Power**: Plasma's `powermanagement` engine (UPower). Wattage comes from
  ksystemstats' `power/battery_*/chargeRate`, falling back to
  `/sys/class/power_supply/BAT*/power_now`.

Licensed GPL-2.0-or-later (see `LICENSE`).
