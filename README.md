# Set List

Create lists of Bard songs and play them. This is a work in progress.

*Disclaimer:* I created setlist for myself and my own play style. It is intentionally very simple and doesn't do much in the way of intelligence. It will not make any attempt to determine if your dummies are up or down; how long your songs have left on them; etc. It literally just plays a list you feed to it. If this works for you, great! If not, that's cool too.

## Setup

Download `setlist.lua` and save it to `./addons/setlist/setlist.lua`. Load it with `lua load setlist`.

An empty songs file will be created at `./addons/setlist/songs.lua`. Fill this file with your song lists and settings. See [sample.lua](./sample.lua) for example configuration.

You will need to `lua reload setlist` to pick up changes to `songs.lua`. 

## Usage

```
//sl [set_name] -- play the specified set
//sl stop -- stop playing
//sl start [set_name] -- play the specified set continuously
//sl switch [set_name] -- switch playing to a different set
//sl next [n] -- set the next play value to n seconds from now
//sl duration [n] -- set your base song duration in minutes (*without* NITRO)
//sl sp -- toggle use of SP abilities
//sl nitro -- toggle use of NITRO
//sl roller -- toggle integration with roller
//sl visible -- show or hide the display
//sl save -- save current settings
```

Continuous play is a new feature. YMMV. Make sure to set the your song duration using `sl duration [n]` according to your own duration gear, as this determines how often the loop will run. I find that 5.1 minutes works well for full duration carn bard, others may want to stick to 4 minutes.

You may need to edit the `zone_whitelist` variable depending on where you intend to use it.