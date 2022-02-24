_addon.name='Setlist'
_addon.author='catalyst-ffxi'
_addon.version='0.9'
_addon.commands={'setlist','sl'}

resources = require('resources')
files = require('files')

require('logger')

local file = files.new('songs.lua')
local config = {}

local interrupts = 0
local max_interrupt = 3

local set_name = nil
local running = false
local run_next = 0

windower.register_event('load', function()
  if file:exists() then
    config = require('songs')
  else
    add_to_chat('Creating songs file...')
    file:write('return { settings = { useSP = false, songDuration = 5, nitroSongDuration = 10.5 }, songs = {} }')
  end

  player = windower.ffxi.get_player()
  queue = {}
end)

windower.register_event('login', function()
  player = windower.ffxi.get_player()
end)

windower.register_event('addon command', function(...)
  cmd = {...}
  if cmd[1] == 'help' then
    local chat = windower.add_to_chat
    add_to_chat('Setlist commands:')
    add_to_chat('//sl set_name -- play the specified set')
    add_to_chat('//sl start set_name -- play the specified set continuously')
    add_to_chat('//sl stop -- stop continuous play')
    add_to_chat('//sl useSP -- toggle use of SP abilities')
  elseif cmd[1] == 'start' then
    if cmd[2] == nil then
      add_to_chat('You must pass a set name to this command')
    elseif config.songs[cmd[2]] then
      set_name = cmd[2]
      running = true
      run_next = 0
      add_to_chat('Starting continuous sing with set: ' .. set_name)
    else
      add_to_chat('Set '.. cmd[2] ..' not found')
    end
  elseif cmd[1] == 'stop' then
    stop()
  elseif cmd[1] == 'useSP' then
    if config.settings.useSP then
      add_to_chat('Stop using SP')
    else
      add_to_chat('Start using SP')
    end
    config.settings.useSP = not config.settings.useSP
  else
    play_set(cmd[1])
  end
end)

windower.register_event('zone change', function(new_zone, old_zone)
  if running then
    stop()
  end
end)

windower.register_event('job change', function()
  if running then
    stop()
  end
end)

windower.register_event('status change', function(new_status_id , old_status_id)
  if new_status_id == 2 then -- player is KO
    stop()
  end
end)

function stop()
  running = false
  set_name = nil
  queue = {}
  add_to_chat('Stopping')
end

function add_to_chat(string)
  windower.add_to_chat(7, string)
end

-- Return the unique ID for a song by name
--
function resource_id_for_song(song)
  local resource = resources.spells:with('name', song)
  return resource.id
end

-- Play a set
--
function play_set(set_name)
  queue = {}
  interrupts = 0

  set = config.songs[set_name]
  if set then
    for key, val in ipairs(set) do
      table.insert(queue, val)
    end
  else
    add_to_chat("Set "..set_name.." not found")
  end

  play_next_song()
end

-- Plays the next queued song
--
function play_next_song()
  if #queue > 0 then
    local song = queue[1]
    local target = "<me>"

    add_to_chat('Playing '..song)
    windower.chat.input('/ma "'..song..'" '..target)
  end
end

-- React to a completed song
--
windower.register_event('action', function(action)
  if action.actor_id ~= player.id or #queue == 0 then
    return
  end

  resource_id = resources.spells:with('name', queue[1]).id

  -- Song played successfuly
  if action.category == 4 and action.param == resource_id then
    table.remove(queue, 1)
    coroutine.schedule(play_next_song, 3)

  -- Song was interrupted
  elseif action.category == 8 and action.param == 28787
    and action.targets[1].actions[1].param == resource_id then

    interrupts = interrupts + 1

    if interrupts >= max_interrupt then
      add_to_chat('Interrupted too many times')
      queue = {}
    else
      add_to_chat('Interupted and retrying')      
      coroutine.schedule(play_next_song, 3)
    end
  end
end)

function do_songs()
  if running == false or run_next > os.clock() or in_exp_zone() == false then
    return
  end

  local night = get_ability_recast('Nightingale')
  local trob = get_ability_recast('Troubadour')
  local clarion = get_ability_recast('Clarion Call')
  local soul = get_ability_recast('Soul Voice')
  local wait = 0

  if night == 0 and trob == 0 then
    if config.settings.useSP and clarion == 0 and soul == 0 then
      -- Songs with SV/Clarion
      add_to_chat('Singing ' .. set_name .. ' with NITRO SV/Clarion')
      windower.send_command(
          [[
              input /ja "Clarion Call" <me>;
              wait 1.3;
              input /ja "Soul Voice" <me>;
              wait 1.3;
              input /ja "Nightingale" <me>;
              wait 1.3;
              input /ja "Troubadour" <me>;
              wait 1.3;
              sl ]] .. set_name
      )
    else
      -- Regular nitro songs
      add_to_chat('Singing ' .. set_name .. ' with NITRO')
      windower.send_command(
          [[
              input /ja "Nightingale" <me>;
              wait 1.3;
              input /ja "Troubadour" <me>;
              wait 1.3;
              input /ja "Marcato" <me>;
              wait 1.3;
              sl ]] .. set_name
      )
    end
    wait = config.settings.nitroSongDuration * 60
  else
    -- Songs without nitro
    add_to_chat('Singing ' .. set_name .. ' without NITRO')
    play_set(set_name)
    wait = config.settings.songDuration * 60
  end

  add_to_chat('Sing again in ' .. wait .. ' seconds')
  run_next = os.clock() + wait
end

function get_ability_recast(name)
  local recasts = windower.ffxi.get_ability_recasts()
  local ability = resources.job_abilities:with('name', name)

  return recasts[ability.recast_id]
end

local zone_whitelist = S{
  'Promyvion - Dem',
  'Promyvion - Holla',
  'Promyvion - Mea',
  "Outer Ra'Kaznar"
}

function in_exp_zone()
  return zone_whitelist:contains(resources.zones[windower.ffxi.get_info().zone].english)
end

do_songs:loop(5)
