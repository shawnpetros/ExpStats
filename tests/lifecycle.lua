package.path = './?.lua;' .. package.path

package.preload['common'] = function() return true end
package.preload['chat'] = function()
    local function value()
        return { append = function(self) return self end }
    end
    return { header=value, message=value, error=value }
end
package.preload['settings'] = function()
    return {
        load=function(defaults) return defaults end,
        register=function() end,
        save=function() end,
    }
end

local callbacks = {}
local clock_ms = 1000
addon = {}
ashita = {
    time={ clock=function() return { ms=clock_ms } end },
    events={ register=function(kind, _, fn) callbacks[kind]=fn end },
}
T = function(values)
    return setmetatable(values, { __index={ any=function(self, ...)
        for _, value in ipairs({...}) do
            if self[1] == value then return true end
        end
        return false
    end } })
end
bit = require('bit')
ImGuiCond_Always=1
ImGuiWindowFlags_AlwaysAutoResize=1
ImGuiWindowFlags_NoCollapse=2
ImGuiWindowFlags_NoScrollbar=4
ImGuiWindowFlags_NoTitleBar=8
ImGuiWindowFlags_NoInputs=16

local began, ended = 0, 0
local fail_draw = false
package.preload['imgui'] = function()
    return {
        SetNextWindowPos=function() end,
        SetNextWindowBgAlpha=function() end,
        Begin=function() began=began+1; return true end,
        End=function() ended=ended+1 end,
        TextColored=function()
            if fail_draw then error('simulated draw failure') end
        end,
        SameLine=function() end,
        TextDisabled=function() end,
        GetWindowPos=function() return 10, 20 end,
    }
end

local stale = true
local player = {
    GetBuffs=function() return {} end,
    GetExpCurrent=function()
        assert(began == ended, 'player memory read occurred inside an open ImGui window')
        if stale then error('simulated stale player during transition') end
        return 500
    end,
    GetExpNeeded=function() return 1000 end,
}
AshitaCore = {
    GetGuiManager=function() return { GetVisible=function() return true end } end,
    GetMemoryManager=function() return { GetPlayer=function() return player end } end,
    GetChatManager=function() return { QueueCommand=function() end } end,
}
GetPlayerEntity=function() return { ServerId=1234 } end

require('ExpStats')
callbacks.packet_in({ id=0x00A, data_modified='' })
local ok, err = pcall(callbacks.d3d_present)

assert(ok, 'transition frame escaped an error: ' .. tostring(err))
assert(began == ended, ('ImGui imbalance: Begin=%d End=%d'):format(began, ended))
assert(began == 0, 'transition frame should not open an ImGui window')

clock_ms = 4000
ok, err = pcall(callbacks.d3d_present)
assert(ok, 'stale post-transition read escaped an error: ' .. tostring(err))
assert(began == 0, 'failed snapshot should skip rendering')

stale = false
ok, err = pcall(callbacks.d3d_present)
assert(ok, 'stable frame escaped an error: ' .. tostring(err))
assert(began == 1 and ended == 1, ('stable ImGui imbalance: Begin=%d End=%d'):format(began, ended))

fail_draw = true
ok, err = pcall(callbacks.d3d_present)
assert(ok, 'draw failure escaped the callback: ' .. tostring(err))
assert(began == 2 and ended == 2, ('failed-draw ImGui imbalance: Begin=%d End=%d'):format(began, ended))
print('PASS: player reads stay outside ImGui and transition failures skip rendering safely')
