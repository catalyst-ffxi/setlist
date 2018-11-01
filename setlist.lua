_addon.name='Setlist'
_addon.author='catalystGw'
_addon.version='0.1'
_addon.commands={'setlist','sl'}

config = require('config')
resources = require('resources')

require('logger')

MAX_INTERRUPT=3

windower.register_event('load', function()

  defaults = {
    sets={
      ['default']={
        ['1']={ name='Victory March' },
        ['2']={ name='Valor Minuet IV' },
        ['3']={ name='Swift Etude' },
        ['4']={ name='Valor Minuet V' },
        ['5']={ name="Mage's Ballad III", target="@me" }
      }
    },
    default_set="default",
  }

  settings = config.load(defaults)
  using = settings.default_set
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
    chat(207, '//sl new [name] -- Create a new set')
    chat(207, '//sl add [song] -- Add a song to the set')
    chat(207, '//sl rm [song] -- Remove a song from the set')
    chat(207, '//sl use [set] -- Use a different set')
    chat(207, '//sl play -- Play the current set')
    chat(207, '//sl [set1] [set2] [...] -- Play the sets in order')
    -- TODO:
    -- chat(207, '//sl list -- List set names')
    -- chat(207, '//sl songs -- List songs in the set')
  elseif cmd[1] == 'new' then
    new_set(cmd[2])
  elseif cmd[1] == 'use' then
    use_set(cmd[2])
  elseif cmd[1] == 'add' then
    add_song(cmd[2], cmd[3])
  elseif cmd[1] == 'rm' then
    remove_song(cmd[2], cmd[3])
  elseif cmd[1] == 'play' then
    play_current_set()
  else
    play_sets(cmd)
  end
end)

-- Creates a new set.
-- If the set exists, it is replaced by an empty set
--
function new_set(set_name)
  settings.sets[set_name] = {}
  settings:save('all')
  log('Set '..set_name..' created.')
  using = set_name
end

-- Change the currently selected set
--
function use_set(set_name)
  if settings.sets[set_name] then
    using = set_name
  else
    log('Set '..set_name..' not found')
  end
end

-- Add a song to the current set
--
function add_song(song, target)
  local resource_id = resource_id_for_song(song)

  if resource_id then
    local value = {
      name=song,
      target=target
    }
    table.insert(current_set(), value)
    log('Added song '..song..' to the current set')
    settings:save('all')
  else
    log('Song '..song..' does not exist')
  end
end

-- Remove a song from the current set
--
function remove_song(song, target)
  for k, v in pairs(current_set()) do
    if v.song == song and v.target == target then
      table.remove(current_set(), k)
      log('Removed song '..song..' from the current set')
      return
    end
  end
  log('Song '..song..' could not be removed from the current set')
end

-- Return the currently selected set
--
function current_set()
  return settings.sets[using]
end

-- Return the unique ID for a song by name
--
function resource_id_for_song(song)
  local resource = resources.spells:with('name', song)
  return resource.id
end


-- Play the current set
--
function play_current_set()
  queue = {}
  interrupts = 0

  append_ordered_songs_to_queue(current_set())
  play_next_song()
end

-- Play an array of sets
--
function play_sets(set_names)
  queue = {}
  interrupts = 0

  for _, set_name in pairs(set_names) do
    set = settings.sets[set_name]
    if set then
      append_ordered_songs_to_queue(set)
    else
      log("Set "..set_name.." not found")
    end
  end
  play_next_song()
end

-- Append a song to the play queue
--
function append_ordered_songs_to_queue(set)
  -- Sort songs by key value
  local keys = {}
  for k in pairs(set) do table.insert(keys, k) end
  table.sort(keys)

  -- Insert sorted songs into queue
  for _, k in ipairs(keys) do
    table.insert(queue, set[k])
  end
end

-- Plays the next queued song
--
function play_next_song()
  if #queue > 0 then
    local song = queue[1]
    local target = "<me>"
    local target = (song.target and song.target ~= '@me') and song.target or '<me>'

    -- TODO: Dont use Pianissimo if it is already active
    -- and buffactive['Pianissimo'] == false 
    if song.target then
      windower.chat.input('/ja "Pianissimo" <me>')
      coroutine.sleep(3)
    end

    log('Playing '..song.name)
    windower.chat.input('/ma "'..song.name..'" '..target)
  end
end

-- React to a completed song
--
windower.register_event('action', function(action)
  if action.actor_id ~= player.id or #queue == 0 then
    return
  end

  resource_id = resource_id_for_song(queue[1].name)

  -- Song played successfuly
  if action.category == 4 and action.param == resource_id then
    table.remove(queue, 1)
    coroutine.schedule(play_next_song, 3)
  end

  -- Song was interrupted
  if action.category == 8 and action.param == 28787
    and action.targets[1].actions[1].param == resource_id then

    interrupts = interrupts + 1

    if interrupts >= MAX_INTERRUPT then
      log('Interrupted too many times')
    else
      log('Interupted and retrying')      
      coroutine.schedule(play_next_song, 3)
    end
  end
end)
