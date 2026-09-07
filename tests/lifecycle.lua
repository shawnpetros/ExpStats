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
local player_reads = 0
local player = {
    GetBuffs=function() return {} end,
    GetExpCurrent=function()
        player_reads = player_reads + 1
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
assert(began == 1, 'transition frame should render from cached Lua state')
assert(player_reads == 0, 'transition render touched player memory')

clock_ms = 4000
ok, err = pcall(callbacks.d3d_present)
assert(ok, 'stale post-transition read escaped an error: ' .. tostring(err))
assert(began == 2 and ended == 2, 'post-transition render should remain balanced')
assert(player_reads == 0, 'post-transition render touched player memory')

stale = false
ok, err = pcall(callbacks.d3d_present)
assert(ok, 'stable frame escaped an error: ' .. tostring(err))
assert(began == 3 and ended == 3, ('stable ImGui imbalance: Begin=%d End=%d'):format(began, ended))
assert(player_reads == 0, 'stable render touched player memory')

fail_draw = true
ok, err = pcall(callbacks.d3d_present)
assert(ok, 'draw failure escaped the callback: ' .. tostring(err))
assert(began == 4 and ended == 4, ('failed-draw ImGui imbalance: Begin=%d End=%d'):format(began, ended))
assert(player_reads == 0, 'failed draw path touched player memory')

local bytes = {}
for index = 1, 26 do bytes[index] = 0 end
local function put_u16(index, value)
    bytes[index] = value % 256
    bytes[index + 1] = math.floor(value / 256) % 256
end
local function put_u32(index, value)
    put_u16(index, value % 65536)
    put_u16(index + 2, math.floor(value / 65536))
end
put_u32(5, 1234)
put_u32(17, 200)
put_u16(25, 8)
callbacks.packet_in({ id=0x02D, data_modified=string.char(unpack(bytes)) })
assert(player_reads == 1, 'confirmed EXP event should refresh player snapshot once')

fail_draw = false
ok, err = pcall(callbacks.d3d_present)
assert(ok, 'cached EXP render escaped an error: ' .. tostring(err))
assert(player_reads == 1, 'cached EXP render performed another player-memory read')
assert(began == 5 and ended == 5, ('cached ImGui imbalance: Begin=%d End=%d'):format(began, ended))
print('PASS: d3d_present renders cached state without player-memory reads')
