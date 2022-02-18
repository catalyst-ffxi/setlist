_addon.name='Setlist'
_addon.author='catalyst-ffxi'
_addon.version='0.9'
_addon.commands={'setlist','sl'}

resources = require('resources')
files = require('files')

require('logger')

local songs = {}
local interrupts = 0
local max_interrupt = 3

windower.register_event('load', function()
  local file = files.new('songs.lua')
  
  if file:exists() then
    songs = require('songs')
  else
    log('Creating songs file...')
    file:write('return {}')
  end

  player = windower.ffxi.get_player()
  queue = {}
end)

windower.register_event('login',function()
  player = windower.ffxi.get_player()
end)

windower.register_event('addon command', function(...)
  cmd = {...}
  if cmd[1] == 'help' then
    local chat = windower.add_to_chat
    chat(207, 'Setlist commands:')
    chat(207, '//sl setname -- play the specified set')
  else
    play_set(cmd[1])
  end
end)

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

  set = songs[set_name]
  if set then
    for key, val in ipairs(set) do
      table.insert(queue, val)
    end
  else
    log("Set "..set_name.." not found")
  end

  play_next_song()
end

-- Plays the next queued song
--
function play_next_song()
  if #queue > 0 then
    local song = queue[1]
    local target = "<me>"

    log('Playing '..song)
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
      log('Interrupted too many times')
      queue = {}
    else
      log('Interupted and retrying')      
      coroutine.schedule(play_next_song, 3)
    end
  end
end)
