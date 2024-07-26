local tr_lanes = 
    {
        { clock_mod = 1, clock_idx = nil, pattern = {}, current_position = 1},
        { clock_mod = 1, clock_idx = nil, pattern = {}, current_position = 1},
        { clock_mod = 1, clock_idx = nil, pattern = {}, current_position = 1},
        { clock_mod = 1, clock_idx = nil, pattern = {}, current_position = 1}
    }

local tr_api = {}

-- Adapted from https://github.com/monome/bowery/blob/main/euclidean.lua & https://gist.github.com/vrld/b1e6f4cce7a8d15e00e4
local function generate_euclidean_pattern(idx)
    local steps = params:get("steps_tr_" .. idx)
    local beats = params:get("beats_tr_" .. idx)
    local rotation = params:get("rotation_tr_" .. idx)

    local pattern = {}
    local beat_index = 0

    -- Fill pattern
    for i = 1, steps do
        pattern[i] = 
            {
                i <= beats
            }
    end
    
    
    -- Distribute beat events
    local function concatenate(pattern, dst, src)
        for _,v in ipairs(pattern[src]) do
            table.insert(pattern[dst], v)
        end
        pattern[src] = nil
    end
    
    while #pattern > beats do
        for i = 1, math.min(beats, #pattern - beats) do
            concatenate(pattern, i, #pattern)
        end
    end
    
    while #pattern > 1 do
        concatenate(pattern, #pattern-1, #pattern) 
    end

    local rotated_pattern = {}
    for i = 1, steps do
        rotated_pattern[i] = pattern[1][(i - rotation - 1) % steps + 1]
    end
    -- pattern = rotated_pattern

    -- -- Debug print to check the pattern
    -- print('post rotation')
    -- print(#rotated_pattern)

    local final_pattern = {}
    for i, v in ipairs(rotated_pattern) do
        local trigger_count = 0

        if v then
            beat_index = beat_index + 1
            trigger_count = beat_index
        end

        final_pattern[i] = {
            beat_index = trigger_count,
            volts = 0,  -- Assuming 5 volts for a trigger and 0 volts otherwise
            trigger = v  -- Use the true or false value that is at the current step
        }
    end   

    tr_lanes[idx].pattern = final_pattern
end

local function start_clock(idx)
    local this_lane = tr_lanes[idx]

    while true do
        local probability = params:get("play_probability_tr_" .. idx)

        if math.random() * 100 <= probability then
            if params:get("mode_tr_" .. idx) == 1 then  -- Clock 
                crow.ii.txo.tr_pulse(idx)
            elseif params:get("mode_tr_" .. idx) == 2 then -- Strum
                initiate_strum(idx)
            elseif params:get("mode_tr_" .. idx) == 3 then -- Burst
                trigger_burst(idx)
            elseif params:get("mode_tr_" .. idx) == 4 then -- Euclidean 
                next_euclidean_step(idx)
            end
        end

        clock.sync(this_lane.clock_mod)
    end
end

local function toggle_play_state(idx)
    local this_lane = tr_lanes[idx]

    if this_lane.clock_idx == nil then
        this_lane.clock_idx = clock.run(start_clock, idx)
    else
        clock.cancel(this_lane.clock_idx)
        this_lane.clock_idx = nil
    end
end

-- Shared Setup
function add_shared_params(idx)
    -- Play Button
    params:add_separator("play_header_tr_" ..idx, "Playback Control")

    params:add_binary("play_state_tr_" .. idx, "Start Clock", "toggle", 0)
    params:set_action("play_state_tr_" .. idx, function()
        toggle_play_state(idx)
    end)

    -- Clock
    params:add_separator("shared_config" .. idx, "Config")    
    params:add_option("mode_tr_" .. idx, "Trigger Mode", {"Clock", "Strum", "Burst", "Euclidean"}, 1)
    params:set_action('mode_tr_' .. idx, function(param)
        if param == 1 then
            show_clock_params(idx)
            hide_strum_params(idx)
            hide_burst_params(idx)
            hide_euclidean_params(idx)
        elseif param == 2 then
            hide_clock_params(idx)
            show_strum_params(idx)
            hide_burst_params(idx)
            hide_euclidean_params(idx)
        elseif param == 3 then
            hide_clock_params(idx)
            hide_strum_params(idx)
            show_burst_params(idx)
            hide_euclidean_params(idx)
        elseif param == 4 then
            generate_euclidean_pattern(idx)
            
            hide_clock_params(idx)
            hide_strum_params(idx)
            hide_burst_params(idx)
            show_euclidean_params(idx)
        end

        -- Update Menu
        _menu.rebuild_params()
    end)

    -- Tempo
    local clock_options = {"1/16", "1/8", "1/4", "1/2", "x1", "x2", "x4", "x8", "x16"}
    local clock_values = {16, 8, 4, 2, 1, 0.5, 0.25, 0.125, 0.0625}

    params:add_option("clock_mod_tr_" .. idx, "Clock Mod", clock_options, 6)
    params:set_action("clock_mod_tr_" .. idx, function(param)
        local this_lane = tr_lanes[idx]
        this_lane.clock_mod = clock_values[param]
    end)
    params:add{type = "control", id = "pulse_ms_tr_" .. idx, name = "Pulse Width", 
       controlspec = controlspec.new(10, 1000, 'lin', 10, 100, "ms")}
    params:set_action("pulse_ms_tr_" .. idx, function(value)
        crow.ii.txo.tr_time(idx, value)
    end)
    params:add{type= "control", id = "play_probability_tr_" .. idx, name = "Play Probability", 
        controlspec = controlspec.new(1, 100, 'lin', 1, 100, '%')}
end

-- Clock Setup
function add_clock_params(idx)
end

function show_clock_params(idx)
end

function hide_clock_params(idx)
end

-- Strum Setup
function add_strum_params(idx)
    params:add_separator("strum_mode_header_" .. idx, "Strum")
    params:add_option("strum_duration_" .. idx, "Strum Duration", 
        {"1/32 beats", "1/16 beats", "1/8 beats", "1/4 beats", "1/2 beats", "1 beats", "2 beats", "4 beats"}, 4)
    params:add{type = "control", id = "strum_pulse_count_" .. idx, name = "Trigger Count", 
        controlspec = controlspec.new(0, 12, 'lin', 1, 3, "triggers")}
    params:add{type = "control", id = "strum_clustering_percent_" .. idx, name = "Clustering", 
        controlspec = controlspec.new(0, 100, 'lin', 1, 50, "%")}
    params:add{type = "control", id = "strum_clustering_variation_" .. idx, name = "Variation", 
        controlspec = controlspec.new(0, 1, 'lin', 0.01, 0, "")}
end

function show_strum_params(idx)
    params:show("strum_mode_header_" .. idx)
    params:show("strum_duration_" .. idx)
    params:show("strum_pulse_count_" .. idx)
    params:show("strum_clustering_percent_" .. idx)
    params:show("strum_clustering_variation_" .. idx)
end

function hide_strum_params(idx)
    params:hide("strum_mode_header_" .. idx)
    params:hide("strum_duration_" .. idx)
    params:hide("strum_pulse_count_" .. idx)
    params:hide("strum_clustering_percent_" .. idx)
    params:hide("strum_clustering_variation_" .. idx)
end

function generate_strum_timing(idx)
    local duration_options = {1/32, 1/16, 1/8, 1/4, 1/2, 1, 2, 4}
    local duration_beats = duration_options[params:get("strum_duration_" .. idx)]
    local total_duration = clock.get_beat_sec() * duration_beats
    local num_pulses = params:get("strum_pulse_count_" .. idx)
    local clustering = params:get("strum_clustering_percent_" .. idx)
    local variation = params:get("strum_clustering_variation_" .. idx)

    local pulse_times = {}
    
    for i = 1, num_pulses do
      local t
      local normalized_index = i / num_pulses
  
      if clustering <= 50 then
        -- Interpolate between start cluster (0) and even distribution (50)
        local k = clustering / 50
        t = total_duration * (k * normalized_index + (1 - k) * math.pow(normalized_index, 2))
      else
        -- Interpolate between even distribution (50) and end cluster (100)
        local k = (clustering - 50) / 50
        t = total_duration * ((1 - k) * normalized_index + k * math.pow(normalized_index, 1/2))
      end
  
      -- Apply random variation if specified
      if variation > 0 then
        local rand_variation = (math.random() - 0.5) * 2 * variation * total_duration / num_pulses
        t = t + rand_variation
      end
      
      table.insert(pulse_times, t)
    end
    
    return pulse_times
  end
  

  function initiate_strum(idx)
    local strum_timing = generate_strum_timing(idx)

    for i, t in ipairs(strum_timing) do
        clock.run(function()
          clock.sleep(t)
          crow.ii.txo.tr_pulse(idx)          
          print(string.format("Playing pulse %d at time %f", i, t))
        end)
    end
end


-- Burst Setup
function add_burst_params(idx)
    params:add_separator("burst_mode_header_" .. idx, "Burst")
    params:add{type = "control", id = "burst_count_" .. idx, name = "Trigger Count", 
        controlspec = controlspec.new(0, 20, 'lin', 1, 3, "triggers")}
    params:add{type= "control", id = "trigger_interval_" .. idx, name = "Trigger Interval", 
        controlspec = controlspec.new(1, 1000, 'lin', 1, 50, "ms")}
    params:add{type = "control", id = "randomization_amount_" .. idx, name = "Humanize Amount", 
        controlspec = controlspec.new(0, 10, 'lin', 0.1, 0, "%")}
end

function show_burst_params(idx)
    params:show("burst_mode_header_" .. idx)
    params:show("burst_count_" .. idx)
    params:show("trigger_interval_" .. idx)
    params:show("randomization_amount_" .. idx)
end

function hide_burst_params(idx)
    params:hide("burst_mode_header_" .. idx)
    params:hide("burst_count_" .. idx)
    params:hide("trigger_interval_" .. idx)
    params:hide("randomization_amount_" .. idx)
end

-- Euclidean Setup
function add_euclidean_params(idx)
    params:add_separator("pattern_header_tr_" .. idx, "Euclidean")
    params:add_number("steps_tr_" .. idx, "Steps", 1, 32, 1)
    params:set_action("steps_tr_" .. idx, function()
        generate_euclidean_pattern(idx)
    end)

    params:add_number("beats_tr_" .. idx, "Beats", 1, 32, 1)
    params:set_action("beats_tr_" .. idx, function(param)
        generate_euclidean_pattern(idx)
    end)

    params:add_number("rotation_tr_" .. idx, "Rotation", 0, 32, 0)
    params:set_action("rotation_tr_" .. idx, function(param)
        generate_euclidean_pattern(idx)
    end)
end

function show_euclidean_params(idx)
    params:show("pattern_header_tr_" .. idx)
    params:show("steps_tr_" .. idx)
    params:show("beats_tr_" .. idx)
    params:show("rotation_tr_" .. idx)
end

function hide_euclidean_params(idx)
    params:hide("pattern_header_tr_" .. idx)
    params:hide("steps_tr_" .. idx)
    params:hide("beats_tr_" .. idx)
    params:hide("rotation_tr_" .. idx)
end

function next_euclidean_step(idx)
    local this_lane = tr_lanes[idx]
    local this_pattern = tr_lanes[idx].pattern
    local this_position = tr_lanes[idx].current_position
    local this_event = this_pattern[this_position]

    if this_event.trigger then
        crow.ii.txo.tr_pulse(idx)
    end

    this_lane.current_position = (tr_lanes[idx].current_position % #tr_lanes[idx].pattern) + 1
end

-- Burst Setup
function trigger_burst(idx)
    local trigger_interval = params:get("trigger_interval_" .. idx)
    local burst_count = params:get("burst_count_" .. idx)
    local randomization_percentage = params:get("randomization_amount_" .. idx)
    
    local randomization_amount = trigger_interval * (randomization_percentage / 100)
    
    for i = 1, burst_count do
        local base_delay = (i - 1) * trigger_interval
        local humanization = (math.random() * randomization_amount) - (randomization_amount / 2)
        local delay_ms = base_delay + humanization

        -- Convert delay to seconds for clock.sleep
        local delay_sec = delay_ms / 1000
        
        if delay_sec > 0 then
            clock.sleep(delay_sec)
        end

        crow.ii.txo.tr_pulse(idx)
        print('burst ' .. i .. ' delay: ' .. delay_ms .. 'ms')
    end
end

function tr_api:add_txo_tr_params(idx)
    params:add_group("telexo_tr_config" .. idx, "TR " .. idx, 20)
    add_shared_params(idx)
    add_clock_params(idx)
    add_strum_params(idx)
    add_burst_params(idx)
    add_euclidean_params(idx)
    hide_strum_params(idx)
    hide_burst_params(idx)
    hide_euclidean_params(idx)
end

return tr_api