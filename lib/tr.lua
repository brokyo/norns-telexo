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

    params:add_option("clock_mod_tr_" .. idx, "Clock Mod", clock_options, 5)
    params:set_action("clock_mod_tr_" .. idx, function(param)
        local this_lane = tr_lanes[idx]
        this_lane.clock_mod = clock_values[param]
    end)
    params:add{type = "control", id = "pulse_ms_tr_" .. idx, name = "Pulse Width", 
       controlspec = controlspec.new(5, 500, 'lin', 5, 5, "ms")}
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
    params:add_option("strum_rhythm_" .. idx, "Rhythm", {"Even", "Dotted", "Triplet", "Swing"}, 1)
end

function show_strum_params(idx)
    params:show("strum_mode_header_" .. idx)
    params:show("strum_duration_" .. idx)
    params:show("strum_pulse_count_" .. idx)
    params:show("strum_clustering_percent_" .. idx)
    params:show("strum_clustering_variation_" .. idx)
    params:show("strum_rhythm_" .. idx)
end

function hide_strum_params(idx)
    params:hide("strum_mode_header_" .. idx)
    params:hide("strum_duration_" .. idx)
    params:hide("strum_pulse_count_" .. idx)
    params:hide("strum_clustering_percent_" .. idx)
    params:hide("strum_clustering_variation_" .. idx)
    params:hide("strum_rhythm_" .. idx)
end

function generate_strum_timing(idx)
    local duration_options = {1/32, 1/16, 1/8, 1/4, 1/2, 1, 2, 4}
    local duration_beats = duration_options[params:get("strum_duration_" .. idx)]
    local total_duration = clock.get_beat_sec() * duration_beats
    local num_pulses = params:get("strum_pulse_count_" .. idx)
    local clustering = params:get("strum_clustering_percent_" .. idx) / 100
    local variation = params:get("strum_clustering_variation_" .. idx)

    local pulse_times = {}
    local min_time = 0.001 -- Minimum time in seconds (1ms)
    
    local rhythm_options = {"Even", "Dotted", "Triplet", "Swing"}
    local rhythm_type = params:get("strum_rhythm_" .. idx)
    
    for i = 1, num_pulses do
        local normalized_index = (i - 1) / (num_pulses - 1)
        
        -- Apply clustering
        local t
        if clustering < 0.5 then
            -- Cluster towards the beginning
            t = total_duration * (normalized_index ^ (1 / (clustering * 2)))
        else
            -- Cluster towards the end
            t = total_duration * (1 - (1 - normalized_index) ^ (1 / ((1 - clustering) * 2)))
        end
        
        -- Apply random variation
        if variation > 0 then
            local max_variation = total_duration * variation / num_pulses
            t = t + (math.random() - 0.5) * max_variation
        end
        
        -- Apply rhythmic variation
        if rhythm_type == 2 then  -- Dotted
            if i % 2 == 0 then
                t = t * 1.5
            end
        elseif rhythm_type == 3 then  -- Triplet
            t = t * (i % 3 == 0 and 1.333 or 0.667)
        elseif rhythm_type == 4 then  -- Swing
            if i % 2 == 0 then
                t = t * 1.25
            end
        end
        
        -- Ensure t is within bounds and greater than min_time
        t = math.max(min_time, math.min(t, total_duration))
        
        table.insert(pulse_times, t)
    end
    
    -- Sort and adjust times to ensure minimum separation
    table.sort(pulse_times)
    for i = 2, #pulse_times do
        if pulse_times[i] - pulse_times[i-1] < min_time then
            pulse_times[i] = pulse_times[i-1] + min_time
        end
    end

    return pulse_times
end

function initiate_strum(idx)
    local strum_timing = generate_strum_timing(idx)
    -- tab.print(strum_timing)
    local start_time = clock.get_beats()

    for i, t in ipairs(strum_timing) do
        clock.run(function()
            clock.sync(start_time + t / clock.get_beat_sec())
            crow.ii.txo.tr_pulse(idx)
        end)
    end
end

-- Burst Setup
function add_burst_params(idx)
    params:add_separator("burst_mode_header_" .. idx, "Burst")
    params:add{type = "control", id = "burst_count_" .. idx, name = "Trigger Count", 
        controlspec = controlspec.new(0, 20, 'lin', 1, 3, "triggers")}
        params:add_option("trigger_interval_" .. idx, "Trigger Interval", 
        {"1/32", "1/16", "1/8", "1/4", "1/2", "1", "2", "4"}, 3)
    params:add{type = "control", id = "randomization_amount_" .. idx, name = "Humanize Amount", 
        controlspec = controlspec.new(0, 10, 'lin', 0.1, 0, "%")}
    params:add_option("burst_rhythm_" .. idx, "Rhythm", {"Even", "Dotted", "Triplet", "Swing"}, 1)
end

function show_burst_params(idx)
    params:show("burst_mode_header_" .. idx)
    params:show("burst_count_" .. idx)
    params:show("trigger_interval_" .. idx)
    params:show("randomization_amount_" .. idx)
    params:show("burst_rhythm_" .. idx)
end

function hide_burst_params(idx)
    params:hide("burst_mode_header_" .. idx)
    params:hide("burst_count_" .. idx)
    params:hide("trigger_interval_" .. idx)
    params:hide("randomization_amount_" .. idx)
    params:hide("burst_rhythm_" .. idx)
end

function trigger_burst(idx)
    local interval_options = {1/32, 1/16, 1/8, 1/4, 1/2, 1, 2, 4}
    local interval_beats = interval_options[params:get("trigger_interval_" .. idx)]
    local trigger_interval = clock.get_beat_sec() * interval_beats
    local burst_count = params:get("burst_count_" .. idx)
    local randomization_percentage = params:get("randomization_amount_" .. idx)
    local rhythm_type = params:get("burst_rhythm_" .. idx)

    local randomization_amount = trigger_interval * (randomization_percentage / 100)
    
    for i = 1, burst_count do
        local base_delay = (i - 1) * trigger_interval

        -- Apply rhythmic variation
        if rhythm_type == 2 then  -- Dotted
            if i % 2 == 0 then
                base_delay = base_delay * 1.5
            end
        elseif rhythm_type == 3 then  -- Triplet
            base_delay = base_delay * (i % 3 == 0 and 1.333 or 0.667)
        elseif rhythm_type == 4 then  -- Swing
            if i % 2 == 0 then
                base_delay = base_delay * 1.25
            end
        end
        
        local humanization = (math.random() * randomization_amount) - (randomization_amount / 2)
        local delay = base_delay + humanization
        
        if delay > 0 then
            clock.sleep(delay)
        end

        crow.ii.txo.tr_pulse(idx)
    end
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

function tr_api:add_txo_tr_params(idx)
    params:add_group("telexo_tr_config" .. idx, "TR " .. idx, 22)
    add_shared_params(idx)
    add_clock_params(idx)
    add_strum_params(idx)
    add_burst_params(idx)
    add_euclidean_params(idx)
    hide_strum_params(idx)
    hide_burst_params(idx)
    hide_euclidean_params(idx)
end

function tr_api:sync_triggers()
    for i = 1, 4 do
        tr_lanes[i].current_position = 1
    end
end

return tr_api