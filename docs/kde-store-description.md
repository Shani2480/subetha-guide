**The Sub-Etha Guide (H2G2)** is an all-in-one Plasma 6 widget in the style of *The Hitchhiker's Guide to the Galaxy*. It puts time, weather, system compute, storage and battery in one card. Don't Panic.

**Two looks, plus skins**
- **Movie Encyclopedia** (light): the 2005 film's cream pages, rounded cards, capsule pills and flat comic-style shadows.
- **Sub-Etha Terminal** (dark): the 1981 BBC terminal's phosphor green on CRT black, with sharp edges, corner reticles, segmented LED gauges, scanlines and a soft phosphor glow.
- **Solar Auto** switches between them at sunrise and sunset at your weather location.
- **Theme Store**: one-click community skins, applied live with no Plasma restart.

**Sections**
- **Clock:** local time, date and time-zone offset, as a slim pill or a large chronometer dial. An optional Galactic Epoch badge adds stardate and sidereal time.
- **Weather:** a sky hero card, temperature and feels-like, hourly and weekly drawers, and Arthur and Marvin wandering the forecast strip (data from Open-Meteo).
- **System:** CPU load, clock and temperature; memory; GPU load, temperature and VRAM; network throughput with LAN / WAN addresses (click to copy); cooling fans; sparklines; and a process diagnostics launcher.
- **Storage:** usage, free space, filesystem and live read / write throughput for the volumes you pick.
- **Power:** laptop battery and peripherals, charge / drain wattage, health, mains and power profile.

Each section can be **Full** or **Compact** on its own. In a panel, the widget shows one reading, several at once, or a cycle, and hovering opens the full card. Temperature, disk and battery alerts wash orange and pulse red past thresholds you set.

**Skins**
Skins are data, not code: a `skin.json` plus images. Installing one never runs anything. A skin chooses colours, fonts, frames (a handheld chassis or a sci-fi bezel), walking sprite characters and the **geometry** of the whole card:
- Card and pill shapes: rounded, chamfered (45° cut corners), sharp or capsule.
- Gauge style: segmented, flat, capsule or chamfered.
- Border style: solid, dashed, double or HUD tech-brackets, with L-shaped corner brackets.
- Shadows: hard 2D offset, soft elevation or neon glow.

A skin can also have its own **light and dark looks**, which follow the Light / Dark / Solar Auto setting. It can replace the whale and petunias that fall from the weather sky with its own hazards, and give the clock its own status lines for when the system is calm and when it is under load.

Available in the Theme Store: **Adventure Time** (BMO Terminal), **Cyberpunk 2077** (Arasaka Kiroshi HUD), **Mirror's Edge** (Runner Vision) and **Dexter's Laboratory** (Secret Mainframe). The skins are fan-made; the characters and names belong to their owners.

**What's new in 0.3.0**
- Skins can have light and dark versions. All four store skins now have both, so the mode setting changes their look too.
- Each store skin has its own falling-sky hazards: the Ice King and Gunter, a crashing AV and a Trauma Team drone, a KrugerSec helicopter and a runner's satchel, a spilling beaker and a flying gear.
- New clock lines for each skin, for calm and busy moments, and a themed status badge.
- Store skins are updated to version 1.2.0; use **Update** in the Theme Store. Older widget versions still show these skins, with one look each.

**New in 0.2.0**
- Themes now control the shape of cards, pills, gauges and buttons, not just colours and fonts.
- The built-in light theme has capsule pills and gauges; the dark theme gets a phosphor glow.
- All four store skins are updated with their own geometry (version 1.1.0; use **Update** in the Theme Store).

Source, screenshots and the skin format: https://github.com/Shani2480/subetha-guide
