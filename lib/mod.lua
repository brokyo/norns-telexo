local mod = require 'core/mods'
local musicutil = require "musicutil"

local tr_lanes = 
    {
        {
            clock_mod = 1,
            clock_idx = nil,
            pattern = {},
            current_position = 1
        },
        {
            clock_mod = 1,
            clock_idx = nil,
            pattern = {},
            current_position = 1
        },
        {
            clock_mod = 1,
            clock_idx = nil,
            pattern = {},
            current_position = 1
        },
        {
            clock_mod = 1,
            clock_idx = nil,
            pattern = {},
            current_position = 1
        }
    }

local function reset_txo()
    crow.ii.txo.init(1)
end

-- Adapted from https://github.com/monome/bowery/blob/main/euclidean.lua & https://gist.github.com/vrld/b1e6f4cce7a8d15e00e4
local function generate_euclidean_pattern(idx)
    local steps = params:get("steps_tr_" .. idx)
    local beats = params:get("beats_tr_" .. idx)
    local rotation = params:get("rotation_tr_" .. idx)

    local pattern = {}

    -- Fill pattern
    for i = 1, steps do
        pattern[i] = {i <= beats}
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

    -- Apply rotation
    local rotated_pattern = {}
    for i = 1, steps do
        rotated_pattern[i] = pattern[1][(i - rotation - 1) % steps + 1]
    end


    tr_lanes[idx].pattern = pattern[1]
end

local function play_pattern(idx)
    local this_lane = tr_lanes[idx]

    while true do
        
        if this_lane.pattern[this_lane.current_position] then
            crow.ii.txo.tr_pulse(idx)
        end

        this_lane.current_position = (this_lane.current_position % #this_lane.pattern) + 1
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

local function add_txo_tr_params(idx)
    local euclidian_tr_param_ids = {
        "clock_mod_tr" .. idx,
        "steps_tr_" .. idx,
        "beats_tr_" .. idx,
        "rotation_tr_" .. idx,
        -- "duration_tr_" .. idx,
        -- "humanize_tr_" .. idx,
        -- "humanize_time_max_tr_" .. idx,
        -- "swing_tr_" ..idx,
        -- "swing_percentage_tr" .. idx,
        "play_state_tr_" .. idx
    }

    params:add_group("telexo_tr_config" .. idx, "TR " .. idx, 5)

    -- Set Clock Mod
    local clock_options = {"1/16", "1/8", "1/4", "1/2", "x1", "x2", "x4", "x8", "x16"}
    local clock_values = {16, 8, 4, 2, 1, 0.5, 0.25, 0.125, 0.0625}
    params:add_option("clock_mod_tr" .. idx, "Clock Mod", clock_options, 6)
    params:set_action("clock_mod_tr" .. idx, function(param)
        local this_lane = tr_lanes[idx]
        this_lane.clock_mod = clock_values[param]
    end)

    -- Set Steps
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

    -- Set Beats
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

    params:add_number(
        "rotation_tr_" .. idx,
        "Rotation",
        0,
        32,
        0
    )
    params:set_action("beats_tr_" .. idx, function(param)
        generate_euclidean_pattern(idx)
    end)

    -- Toggle Run
    params:add_trigger("play_state_tr_" .. idx, "Toggle Play State (K3)")
    params:set_action("play_state_tr_" .. idx, function()
        toggle_play_state(idx)
    end)

end


local function add_txo_cv_params(idx)
    local lfo_param_ids = {
        "lfo_params_" .. idx,
        "cyc_time_" .. idx, 
        "cv_range_" .. idx, 
        "cv_off_" .. idx,
        "osc_rect_" .. idx
    }

    local osc_param_ids = {
        "osc_params_" .. idx,
        "osc_note_" .. idx,
        "osc_amplitude_" .. idx,
    }

    local shared_param_ids = {
        "shared_params_" .. idx,
        "osc_phase_" .. idx,
        "wave_type_" .. idx,
        "pulse_width_" .. idx
    }

    params:add_group("telexo_cv_config" .. idx, "CV " .. idx, 13)

    -- Select telexo mode
    local telexo_modes = {'LFO', 'Oscillator'}
    params:add_option('telexo_mode_' .. idx, 'Mode ', telexo_modes, 1)
    params:set_action('telexo_mode_' .. idx, function(mode_idx)
        if mode_idx == 1 then
            -- Init Port
            crow.ii.txo.cv_init(idx)

            -- Hide Osc Params
            for _, param_id in ipairs(osc_param_ids) do
                params:hide(param_id)
            end

            -- Show LFO Params
            for _, param_id in ipairs(lfo_param_ids) do
                params:show(param_id)
            end

            -- Show Shared Params
            for _, param_id in ipairs(shared_param_ids) do
                params:show(param_id)
            end

            _menu.rebuild_params()
        elseif mode_idx == 2 then
            -- Init Port
            crow.ii.txo.cv_init(idx)
            crow.ii.txo.osc_fq(idx, 440)

            -- Hide LFO Params
            for _, param_id in ipairs(lfo_param_ids) do
                params:hide(param_id)
            end

            -- Show LFO Params
            for _, param_id in ipairs(osc_param_ids) do
                params:show(param_id)
            end

            -- Show Shared Params
            for _, param_id in ipairs(shared_param_ids) do
                params:show(param_id)
            end

            _menu.rebuild_params()
        end
    end)

    ----------------
    -- LFO PARAMS --
    ----------------
    params:add_separator('lfo_params_' .. idx, "LFO Params")
    -- Cycle time in seconds
    -- NB | Number is in deciseconds. Action is in ms. UI is in sconds. It's very confusing. 
    params:add_number(
        "cyc_time_" .. idx, 
        "Cycle Time", 
        1, 
        300, 
        1,
        function(param) return param:get() / 10 .. 's' end
    )
    params:set_action("cyc_time_" .. idx, function(param)
        local ms = param * 100   
        crow.ii.txo.osc_cyc(idx, ms)
    end)

    -- CV Depth
    params:add_number(
        "cv_range_" .. idx,
        "CV Depth",
        -100,
        100,
        0,
        function(param) return param:get() / 10 .. 'v' end
    )
    params:set_action("cv_range_" .. idx, function(param)
        local volts = param / 10
        crow.ii.txo.cv(idx, volts)
    end)

    -- CV Offset
    params:add_number(
        "cv_off_" .. idx,
        "CV Offset",
        -100,
        100,
        0,
        function(param) return param:get() / 10 .. 'v' end
    )
    params:set_action("cv_off_" .. idx, function(param)
        local volts = param / 10
        crow.ii.txo.cv_off(idx, volts)
    end)


    -- OSC rectifiaction
    params:add_number(
        "osc_rect_" .. idx,
        "LFO Rect",
        -2,
        2,
        0
    )
    params:set_action("osc_rect_" .. idx, function(param)
        crow.ii.txo.osc_rect(idx, param)
    end)

    -----------------------
    -- OSCILLATOR PARAMS --
    -----------------------
    params:add_separator('osc_params_' .. idx, "Oscillator Params")
    params:add_number(
        "osc_note_" .. idx,
        "Note",
        0,
        127,
        0,
        function(param) return musicutil.note_num_to_name(param:get(), 1) end
    )
    params:set_action("osc_note_" .. idx, function(midi_note)
        local note_frequency = musicutil.note_num_to_freq(midi_note)
        crow.ii.txo.osc_fq_set(idx, note_frequency)
    end)

    params:add_number(
        "osc_amplitude_" .. idx,
        "Amplitude",
        0,
        50,
        0,
        function(param) return param:get()/10 .. 'v' end
    )
    params:set_action("osc_amplitude_" .. idx, function(amp)
        local converted_amp = amp / 10
        crow.ii.txo.cv(idx, converted_amp)
    end)

    -------------------
    -- SHARED PARAMS --
    -------------------
    params:add_separator('shared_params_' .. idx, "Shared Params")
    -- Phase Offset
    params:add_number(
        "osc_phase_" .. idx,
        "Phase Offset",
        0,
        360,
        0,
        function(param) return param:get() .. '°' end
    )
    params:set_action("osc_phase_" .. idx, function(degrees)
        local phase_offset = (degrees / 360) * 16384 -- 0 > 16384 is telexo's expected range
        crow.ii.txo.osc_phase(idx, phase_offset)
    end)


    -- Wave shape
    -- NB | sine (0) triangle (100) saw (200) pulse (300) noise (400)
    params:add_number(
        "wave_type_" .. idx,
        "Wave Type",
        0,
        400,
        0
    )
    params:set_action("wave_type_" .. idx, function(wave)
        crow.ii.txo.osc_wave(idx, wave)
    end)

    params:add_number(
        "pulse_width_" .. idx,
        "Pulse Width",
        0,
        100,
        0
    )
    params:set_action("pulse_width_" .. idx, function(width)
        crow.ii.txo.osc_width(idx, width)
    end)

    -- -- Default to LFO params
    local all_params = {
        -- 'lfo_params_' .. idx,
        -- "cyc_time_" .. idx, 
        -- "cv_range_" .. idx, 
        -- "cv_off_" .. idx,
        -- "osc_rect_" .. idx,
        'osc_params_' .. idx,
        "osc_note_" .. idx,
        "osc_amplitude_" .. idx
        -- "shared_params_" .. idx,
        -- "osc_phase_" .. idx,
        -- "wave_type_" .. idx,
        -- "pulse_width_" .. idx
    }

    for _, param_id in ipairs(all_params) do
        params:hide(param_id)
    end
    _menu.rebuild_params()
end

mod.hook.register("script_pre_init", "telexo", function()
    params:add_separator('telexo-title', "TELEXo | TR")
    for idx=1,4 do
        add_txo_tr_params(idx)
    end
    params:add_separator('telexo-title', "TELEXo | CV")
    for idx=1,4 do
        add_txo_cv_params(idx)
    end
end)

mod.hook.register("script_post_cleanup", "telexo", function()
    reset_txo()
end)