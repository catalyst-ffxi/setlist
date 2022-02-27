_addon.name='Setlist'
_addon.author='catalyst-ffxi'
_addon.version='0.9'
_addon.commands={'setlist', 'sl'}

resources = require('resources')
files = require('files')
texts = require('texts')
config = require('config')
require('logger')

local songs = {}
local queue = L{}

local state = {
  interrupts = 0,
  set_name = nil,
  running = false,
  run_next = 0
}

local settings = config.load({
  sp = false,
  song_duration = 5.25,
  use_roller = false,
  max_interrupt = 3,
  display = {
    x = 1000,
    y = 100,
    visible = true
  }
})

local display_template = [[
  Setlist
  -------
  Queue: ${queue|none}
  Running: ${running|false}
  Next Sing: ${next_sing|n/a}
  Using SP: ${sp|No}
]]

local display = texts.new(
  display_template,
  {
    pos = { x = settings.display.x, y = settings.display.y },
    bg = { alpha = 50 },
    text = {
      size = 10,
      font = 'Consolas',
      stroke = {
          width = 1,
          alpha = 200
      }
    },
    padding = 4,
    flags = {
      draggable = true,
      right = false,
      bottom = false,
      bold = true 
    }
  }
)

if settings.display.visible then
  display:show()
end

function update_display()
  display.sp = settings.use_sp and 'Yes' or 'No'
  display.running = state.running
  
  if state.running and state.run_next > 0 then
    display.next_sing = math.ceil(state.run_next - os.clock())
  else
    display.next_sing = nil
  end

  if #queue > 0 then
    display.queue = queue:concat(' => ')
  else
    display.queue = nil
  end
end

windower.register_event('load', function()
  local file = files.new('songs.lua')

  if file:exists() then
    songs = require('songs')
  else
    notice('Creating songs file...')
    file:write('return {}')
  end

  update_display:loop(1)
  do_songs:loop(5)
end)

windower.register_event('login', function()
  player = windower.ffxi.get_player()
end)

windower.register_event('addon command', function(...)
  cmd = {...}
  if cmd[1] == 'help' then
    local chat = windower.log
    log('Setlist commands:')
    log('//sl set_name -- play the specified set')
    log('//sl start set_name -- play the specified set continuously')
    log('//sl stop -- stop continuous play')
    log('//sl visible -- show or hide the display')
    log('//sl sp -- toggle use of SP abilities')
    log('//sl roller -- toggle integration with roller')
    log('//sl save -- save current settings')
  elseif cmd[1] == 'start' then
    if cmd[2] == nil then
      error('You must pass a set name to this command')
    elseif songs[cmd[2]] == nil then
      error('Set '.. cmd[2] ..' not found')
    elseif songs[cmd[2]] then
      state.set_name = cmd[2]
      state.running = true
      state.run_next = 0
      log('Starting continuous sing with set: ' .. state.set_name)
    end
  elseif cmd[1] == 'stop' then
    stop()
  elseif cmd[1] == 'visible' then
    settings.display.visible = not settings.display.visible
    if settings.display.visible then
      display:show()
    else
      display:hide()
    end
  elseif cmd[1] == 'sp' then
    settings.use_sp = not settings.use_sp
    local verb = settings.use_sp and 'Start' or 'Stop'
    log(verb .. ' using SP abilities')
  elseif cmd[1] == 'roller' then
    settings.use_roller = not settings.use_roller
    local verb = settings.use_roller and 'Start' or 'Stop'
    log(verb .. ' using roller')
  elseif cmd[1] == 'save' then
    local pos_x, pos_y = display:pos()
    settings.display.x = pos_x
    settings.display.y = pos_y
    settings:save('all')
  else
    play_set(cmd[1])
  end
end)

windower.register_event('zone change', function(new_zone, old_zone)
  stop()
end)

windower.register_event('job change', function()
  stop()
end)

windower.register_event('status change', function(new_status_id , old_status_id)
  if new_status_id == 2 then -- player is KO
    stop()
  elseif new_status_id == 33 then -- player rested
    queue:clear()
  end
end)

function stop()
  if state.running or #queue > 0 then
    log('Stopping')
  end
  state.running = false
  state.set_name = nil
  queue:clear()
end

-- Play a set
--
function play_set(set_name)
  queue:clear()
  state.interrups = 0

  set = songs[set_name]
  if set then
    for key, val in ipairs(set) do
      if resources.spells:with('name', val) == nil then
        error('Song ' .. val .. ' does not exist. Check your spelling.')
        queue:clear()
        return
      end
      queue:append(val)
    end
  else
    error("Set ".. set_name .." not found")
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
    windower.chat.input('/ma "' .. song .. '" ' .. target)
  elseif state.running and settings.use_roller and windower.ffxi.get_player().sub_job == 'COR' then
    windower.send_command('roller start')
  end
end

-- React to a completed song
--
windower.register_event('action', function(action)
  if action.actor_id ~= windower.ffxi.get_player().id then return end

  if #queue > 0 then

    local current_song_id =  resources.spells:with('name', queue[1]).id

    if action.category == 4 and action.param == current_song_id then
      -- Queue up the next song
      queue:remove(1)
      coroutine.schedule(play_next_song, 3)

    elseif action.category == 8 and action.param == 28787
      and action.targets[1].actions[1].param == current_song_id then

      -- Song was interrupted, retry
      state.interrups = state.interrups + 1

      if state.interrups >= settings.max_interrupt then
        log('Interrupted too many times')
        queue:clear()
      else
        log('Interupted and retrying')      
        coroutine.schedule(play_next_song, 3)
      end
    end

  elseif state.running and (os.clock() - state.run_next < 3) and action.category > 1 then
    state.run_next = state.run_next + 3
  end
end)

function do_songs()
  if state.running == false or state.run_next > os.clock() or in_exp_zone() == false then
    return
  end

  if windower.ffxi.get_player().status ~= 0 then
    return -- player is dead or busy
  end

  local night = get_ability_recast('Nightingale')
  local trob = get_ability_recast('Troubadour')
  local clarion = get_ability_recast('Clarion Call')
  local soul = get_ability_recast('Soul Voice')
  local marcato = get_ability_recast('Marcato')
  local wait = settings.song_duration * 60

  local commands = L{}

  if settings.use_roller and windower.ffxi.get_player().sub_job == 'COR' then
    commands:append('roller stop')
  end

  if night == 0 and trob == 0 then
    if settings.use_sp and clarion == 0 and soul == 0 then
      log('Singing ' .. state.set_name .. ' with SV/Clarion')
      commands:append('input /ja "Soul Voice" <me>')
      commands:append('input /ja "Clarion Call" <me>')
    elseif marcato == 0 then
      log('Singing ' .. state.set_name .. ' with Marcato')
      commands:append('input /ja "Marcato" <me>')
    end
    commands:append('input /ja "Nightingale" <me>')
    commands:append('input /ja "Troubadour" <me>')
    wait = wait * 2
  else
    log('Singing ' .. state.set_name)
  end

  commands:append('sl ' .. state.set_name)

  local command_string = commands:concat('; wait 1.3;')
  windower.send_command(command_string)

  log('Sing again in ' .. wait .. ' seconds')
  state.run_next = os.clock() + wait
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
