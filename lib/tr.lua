local tr_lanes = 
    {
        {
            clock_mod = 1,
            clock_idx = nil,
            paired_cv = 0,
            pattern = {},
            current_position = 1
        },
        {
            clock_mod = 1,
            clock_idx = nil,
            paired_cv = 0,
            pattern = {},
            current_position = 1
        },
        {
            clock_mod = 1,
            clock_idx = nil,
            paired_cv = 0,
            pattern = {},
            current_position = 1
        },
        {
            clock_mod = 1,
            clock_idx = nil,
            paired_cv = 0,
            pattern = {},
            current_position = 1
        }
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

local function play_pattern(idx)
    while true do
        local this_lane = tr_lanes[idx]
        local this_pattern = tr_lanes[idx].pattern
        local this_position = tr_lanes[idx].current_position
        local this_event = this_pattern[this_position]

        if params:get("mode_tr_" .. idx) == 1 then  -- Euclidean Rhythm
            if this_event.trigger then
                local probability = params:get("play_probability_tr_" .. idx)
                if math.random() * 100 <= probability then
                    crow.ii.txo.tr_pulse(idx)
                end
            end

            this_lane.current_position = (tr_lanes[idx].current_position % #tr_lanes[idx].pattern) + 1
        elseif params:get("mode_tr_" .. idx) == 2 then  -- Clock Div
            local probability = params:get("play_probability_tr_" .. idx)
            if math.random() * 100 <= probability then
                crow.ii.txo.tr_pulse(idx)
            end
        end

        clock.sync(this_lane.clock_mod)
    end
end

local function toggle_play_state(idx)
    local this_lane = tr_lanes[idx]

    if this_lane.clock_idx == nil then
        this_lane.clock_idx = clock.run(play_pattern, idx)
    else
        clock.cancel(this_lane.clock_idx)
        this_lane.clock_idx = nil
    end
end

function tr_api:add_txo_tr_params(idx)
    params:add_group("telexo_tr_config" .. idx, "TR " .. idx, 11)

    --Mode
    params:add_separator("mode_header_" .. idx, "Mode")
    params:add_option("mode_tr_" .. idx, "Trigger Mode", {"Euclidean", "Clock"}, 1)
    params:set_action('mode_tr_' .. idx, function(param)
        if param == 1 then
            params:show("pattern_header_tr_" .. idx)
            params:show("steps_tr_" .. idx)
            params:show("beats_tr_" .. idx)
            params:show("rotation_tr_" .. idx)
        elseif param == 2 then
            params:hide("pattern_header_tr_" .. idx)
            params:hide("steps_tr_" .. idx)
            params:hide("beats_tr_" .. idx)
            params:hide("rotation_tr_" .. idx)
        end

        -- Update Menu
        _menu.rebuild_params()
    end)

    -- Tempo
    local clock_options = {"1/16", "1/8", "1/4", "1/2", "x1", "x2", "x4", "x8", "x16"}
    local clock_values = {16, 8, 4, 2, 1, 0.5, 0.25, 0.125, 0.0625}

    -- Clock
    params:add_separator("tempo_header_" .. idx, "Tempo")
    params:add_option("clock_mod_tr_" .. idx, "Clock Mod", clock_options, 6)
    params:set_action("clock_mod_tr_" .. idx, function(param)
        local this_lane = tr_lanes[idx]
        this_lane.clock_mod = clock_values[param]
    end)
    params:add_number("play_probability_tr_" .. idx, "Play Probability", 1, 100, 100)

    --
    -- Euclidean Params
    --
    params:add_separator("pattern_header_tr_" .. idx, "Pattern")
    -- Steps
    params:add_number(
        "steps_tr_" .. idx,
        "Steps",
        1,
        32,
        1
    )
    params:set_action("steps_tr_" .. idx, function()
        generate_euclidean_pattern(idx)
    end)
    -- Beats
    params:add_number(
        "beats_tr_" .. idx,
        "Beats",
        1,
        32,
        1
    )
    params:set_action("beats_tr_" .. idx, function(param)
        generate_euclidean_pattern(idx)
    end)
    -- Rotation
    params:add_number(
        "rotation_tr_" .. idx,
        "Rotation",
        0,
        32,
        0
    )
    params:set_action("rotation_tr_" .. idx, function(param)
        generate_euclidean_pattern(idx)
    end)

    --
    -- Playback
    --
    params:add_separator("play_header_tr_" ..idx, "Playback Control")

    -- Toggle Run
    params:add_trigger("play_state_tr_" .. idx, "Toggle Play State (K3)")
    params:set_action("play_state_tr_" .. idx, function()
        toggle_play_state(idx)
    end)

    generate_euclidean_pattern(idx)
end

return tr_api