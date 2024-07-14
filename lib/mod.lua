local mod = require 'core/mods'
local tr_api = {}
local cv_api = {}

mod.hook.register("script_pre_init", "telexo", function()
    tr_api = include('norns-telexo/lib/tr')
    cv_api = include('norns-telexo/lib/cv')

    params:add_separator('telexo-title', "TELEXo | TR")
    for idx=1,4 do
        tr_api:add_txo_tr_params(idx)
    end

    params:add_separator('telexo-title', "TELEXo | CV")
    for idx=1,4 do
        cv_api:add_txo_cv_params(idx)
    end
end)

mod.hook.register("script_post_cleanup", "telexo", function()
    crow.ii.txo.init(1)
end)