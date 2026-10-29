**The Sub-Etha Guide (H2G2)** is an all-in-one Plasma 6 widget in the style of *The Hitchhiker's Guide to the Galaxy*. It puts time, weather, system compute, storage, power and AI usage in one card. One-click skins restyle all of it, down to the window chrome, as another operating system or another world. Don't Panic.

**Two looks, plus skins**
- **Movie Encyclopedia** (light): the 2005 film's cream pages, rounded cards, capsule pills and flat comic-style shadows.
- **Sub-Etha Terminal** (dark): the 1981 BBC terminal's phosphor green on CRT black, with sharp edges, corner reticles, segmented LED gauges, scanlines and a soft phosphor glow.
- **Solar Auto** switches between them at sunrise and sunset at your weather location.
- **Theme Store**: one-click skins, applied live with no Plasma restart.

**Sections**
- **Clock:** local time, date and time-zone offset, as a slim pill or a large chronometer dial. An optional Galactic Epoch badge adds stardate and sidereal time.
- **Weather:** a sky hero card, temperature and feels-like, hourly and weekly drawers, and characters wandering the forecast strip (data from Open-Meteo).
- **System:** CPU load, clock and temperature; memory; GPU load, temperature and VRAM; network throughput with LAN / WAN addresses (click to copy); cooling fans; sparklines; and a process diagnostics launcher.
- **Storage:** usage, free space, filesystem and live read / write throughput for the volumes you pick.
- **Power:** laptop battery and peripherals, charge / drain wattage, health, mains and power profile.
- **AI (optional, off by default):** month-to-date and today's API spend against a budget, from the Anthropic or OpenAI Admin API, or the local models Ollama / Open WebUI has loaded in VRAM.

Each section can be **Full** or **Compact** on its own. In a panel, the widget shows one reading, several at once, or a cycle, and hovering opens the full card.

**Alerts**
CPU and GPU temperature, CPU, GPU and memory load, and disk use each have warning and critical thresholds you set. A reading has to hold a level for a few seconds (you choose how long) before it shows, so a one-off spike never trips one. A warning tags its card [WARN]. A critical reading turns crimson, blinks its value and gives its card a breathing glow. In a panel it flashes, and the hover card opens with an ALERT line. The motion can be switched off and the colours kept.

**Skins**
Skins are data, not code: a `skin.json` plus images and fonts, checked before they are packaged. Installing one never runs anything. A skin takes over the whole widget, with nothing of the Guide's look or wording left behind:
- **Its own operating system:** window chrome (Luna, Aqua, Aero, Material, terminal or HUD title bars and buttons), Win32 group bands, Sidebar gadgets or numbered flag tabs for the sections, and its own meters: bevelled, jelly "candy" bars, ASCII cells, angled blocks or analog dials.
- **Shapes:** rounded, chamfered (on the corners it picks), sharp or capsule cards and pills; segmented, flat, capsule or wavy gauges; solid, dashed, double or HUD bracket borders; hard, soft or glowing shadows; glass sheens and textures.
- **Its own art and words:** icons, hero illustrations by day and by night, a footer mark and motto, and its own labels and status quips.
- **Light and dark versions** that follow the Light / Dark / Solar Auto setting.

The panel item takes the skin's icons and accent colour too, keeping the panel's own text colour wherever the accent would not read.

**In the Theme Store**
- **Windows XP** (Luna)
- **Windows Vista Aero Glass** (Exact)
- **macOS Liquid Glass**
- **Material You** (M3 Expressive)
- **VT-Terminal** (1970s/1980s CRT)
- **Cyberpunk 2077** (Arasaka Kiroshi HUD)
- **Mirror's Edge** (Runner Vision)
- **Dexter's Laboratory** (Secret Mainframe)

**Manage Installed** in the Theme Store lists every skin on disk, so you can apply, hide or remove them.

**Works with the Sub-Etha System Monitor**
The widget shares its skin and light / dark setting with the companion desktop app, [Sub-Etha System Monitor](https://github.com/Shani2480/subetha-monitor), so changing either one changes both. Skins you hide in one are hidden in the other.

**What's new in 0.4.0**
- Skins now restyle the whole widget as an operating system: window chrome, section headers, meters, icons, art and wording. They also have their own fonts and effects.
- New skins: Windows XP, Windows Vista Aero Glass, macOS Liquid Glass, Material You and VT-Terminal.
- Mirror's Edge (Runner Vision) is rebuilt from scratch, with red numbered flag tabs, 16-block meters and night and day runner art. Install it again from the store: it is a new entry, and the old version stays installed until you remove it.
- Cyberpunk 2077 and Dexter's Laboratory are updated.
- Adventure Time has left the store. A copy you already have installed keeps working.
- Alerts with warning and critical thresholds, a hold time, and a panel flash.
- The optional AI section: API spend and budget, or local models.
- Theme sync with the Sub-Etha System Monitor.
- Manage Installed in the Theme Store: apply, hide or remove skins.
- The panel item uses the skin's icons and accent.
- Weather forecast day cards take the skin's pill shape.

**New in 0.3.0**
- Skins can have light and dark versions, and their own falling-sky hazards and clock lines.

**New in 0.2.0**
- Themes control the shape of cards, pills, gauges and buttons, not just colours and fonts.

Source, screenshots and the skin format: https://github.com/Shani2480/subetha-guide
