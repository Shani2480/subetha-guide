# The Sub-Etha Guide (H2G2)

An all-in-one KDE Plasma 6 widget in the style of *The Hitchhiker's Guide to
the Galaxy*. It covers weather, system compute, storage and battery in one
card, with modular sections. Don't Panic.

<p align="center">
  <img src="docs/screenshots/weather-dark.gif" width="400" alt="Weather card in the Sub-Etha terminal theme, with Arthur and Marvin drifting across the forecast">
  &nbsp;
  <img src="docs/screenshots/weather-light.gif" width="400" alt="The same weather card in the Movie Encyclopedia theme">
</p>

Two looks: the 2005 film's cream Encyclopedia pages (light) and the 1981 BBC
Sub-Etha terminal's phosphor green on CRT black (dark). **Solar Auto** switches
between them at sunrise and sunset at the weather location.

## Gallery

**Sub-Etha Terminal** (dark): weather, system and storage + power, every
section at Full density.

![Weather, system and storage/power sections in the dark CRT theme](docs/screenshots/dark.jpg)

**Movie Encyclopedia** (light): the same sections on cream pages.

![The same sections in the light Encyclopedia theme](docs/screenshots/light.jpg)

**Compact density**: every section folded to slim pills, in both themes.
Each section switches on its own with the `[ - ]` / `[ + ]` tag on its card.

![All sections at Compact density, dark and light](docs/screenshots/compact.jpg)

**In a panel**: pick one reading, several at once, or a cycle, with micro
meters. Hovering opens the large card for what the panel shows.

![Panel readings with the hover card open, dark and light](docs/screenshots/panel.jpg)

**Alerts**: CPU and GPU temperatures wash orange and then pulse red past
configurable points on their scale. A full disk blinks, and so can a low
battery.

<p align="center">
  <img src="docs/screenshots/alerts.gif" width="380" alt="Compact view with hot CPU and GPU cards pulsing red and a critical disk blinking">
</p>

## Sections

One header (title, location or host name, DON'T PANIC) sits over four
sections in a fixed order:

| Section | Shows |
| --- | --- |
| Weather | Sky hero card, temperature and feels-like, hourly and weekly drawers, Arthur and Marvin on the forecast strip (Open-Meteo) |
| System | CPU load / clock / temperature, memory, GPU load / temperature / VRAM (pick the GPU on multi-GPU systems), network throughput with LAN / WAN addresses (click to copy), cooling fans; optional host profile banner and 24-sample sparklines; process diagnostics launcher |
| Storage | Selected volumes: usage, free space, filesystem, live read / write throughput (the activity LED pulses past 50 MB/s) |
| Power | Laptop battery and peripherals, live charge / drain wattage, health, mains and power profile |

Each section is **Full** (drawers, graphs, characters) or **Compact** (slim
pills) on its own, and in the System section each sensor card is **Small** or
**Large**. Metrics carry themed tooltips with the detail behind the number.

A section switched off folds away (its height animates to 0) and its feed
stops: no fetches, probes or sensors for a module that isn't shown.

On the desktop the card snaps to fixed layout steps:
- **Width:** 260, 360 or 740 px. At 740 the sections flow into two columns.
- **Height:** 110, 240 or 380 px, then more 110 px rows.

It settles 200 ms after a resize and animates there. Plasma's applet box
follows the resize handle freely, so the card snaps inside it and scrolls
when the content is taller.

## Panel

In a panel the widget shows weather temperature, CPU load or temperature,
GPU temperature, memory, network download or battery, several of them side
by side, or steps through them every few seconds. An icon and a micro meter
per reading are optional. Hovering opens a themed card with the large
version of what the panel shows; clicking opens the full Guide, and a middle
click refreshes it.

## Settings

One tab per module:
- **Appearance & Sections:** theme, per-section density (picked from preview
  cards with hover descriptions), which sections show, and the panel display.
- **Weather & Location:** place search or detect, units, icon style, update
  interval, background animations, Arthur and Marvin.
- **System Hardware:** which pills and their sizes, GPU, fans, sparklines,
  host profile, temperature unit and colour alerts (warning and critical as
  a share of the 30-100 °C scale), sampling interval.
- **Disks & Storage:** which volumes, throughput, figure and unit, warning
  level.
- **Power & Battery:** which devices, wattage, gauges, estimates, critical
  level and low-battery blink.

**Process diagnostics**: the System section's `[LAUNCH FULL PROCESS
DIAGNOSTICS]` pill (Full mode) and the widget's context menu open the fullest
process monitor available. It tries, in order:
1. a themed companion at `package/contents/tools/subetha-monitor.py`, if present
2. KDE System Monitor
3. KSysGuard
4. otherwise Discover, opened on System Monitor's page to install it

## Languages

English, German, Dutch, French and Spanish, following the system language.
The translations live in `translate/`; after changing any text, run
`./translate/build.sh` to refresh the template, merge it into every language
and compile them into the package. To add a language:

```sh
msginit -i translate/template.pot -o translate/<lang>.po -l <lang>
```

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
    ├── locale/                compiled translations
    └── ui/
        ├── main.qml           feeds, theme, actions, representations
        ├── FullRepresentation.qml, *Section.qml, ModuleCard.qml
        ├── CompactRepresentation.qml, PanelReadings.qml, PanelHoverPopup.qml
        ├── config*.qml, PreviewCard.qml
        ├── common/            theme, frames, pills, snapping, sparklines, tooltips, i18n
        ├── weather/           WeatherFeed, FullView, MinimalView, characters, icons
        ├── system/            SystemFeed, SystemPanel, pills, SpecsBanner
        ├── disk/              DiskFeed, DiskPanel, DiskPillCard, VolumePicker
        └── battery/           BatteryFeed, BatteryPanel, BatteryPillCard, DevicePicker
translate/                     template.pot, <lang>.po, build.sh
docs/screenshots/              the images above
```

## Data sources

- **Weather**: [Open-Meteo](https://open-meteo.com/), no API key.
- **System**: Plasma's sensor daemon (`ksystemstats`, through
  `org.kde.ksysguard.sensors`), throttled to the update interval. It runs
  only while the card is on screen and the session is unlocked. The host
  profile is read once: `/proc/cpuinfo`, `lspci`, memory type from the DMI
  tables through udev (no root), `uname` and `/etc/os-release`.
- **Network identity**: local address, gateway and DNS from `ip` and
  `resolvectl`; the public address from [ipify](https://www.ipify.org/),
  at most once every 15 minutes and only while the network card is shown.
- **Storage**: one `df` + `lsblk` + `/proc/diskstats` probe, every 2 s while
  on screen and once a minute otherwise.
- **Power**: Plasma's `powermanagement` engine (UPower). Wattage comes from
  ksystemstats' `power/battery_*/chargeRate`, falling back to
  `/sys/class/power_supply/BAT*/power_now`.

Screenshots use a London forecast and placeholder network addresses.

Licensed GPL-2.0-or-later (see `LICENSE`).
