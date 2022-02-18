# Set List

Create lists of Bard songs and play them all in a row. This is a work in progress.

## Usage

Download `setlist.lua` and save it to `./addons/setlist/setlist.lua`. Load it with `lua load setlist`.

An empty songs file will be created at `./addons/setlist/songs.lua`. Fill this file with your song lists. See [sample.lua](./sample.lua) for example usage.

Call `setlist` or `sl` followed by the name of the desired list to play it. ie: `sl attack`.

For use with in-game macros, use `/console sl attack` as the macro line.