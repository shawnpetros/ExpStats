local M = {}

function M.clean_message(message)
    local text = tostring(message or '')
    text = text:gsub('[\30\31].', '')
    text = text:gsub('[\r\n]', '')
    text = text:gsub(',', '')
    text = text:gsub('%s+$', '')
    return text
end

function M.parse_exp(message)
    local text = M.clean_message(message)
    local amount = text:match('You gain%s+(%d+)%s+experience%s+points?')
    return amount and tonumber(amount) or nil
end

local function u16le(data, index)
    local a, b = data:byte(index, index + 1)
    if a == nil or b == nil then return nil end
    return a + b * 256
end

local function u32le(data, index)
    local a, b, c, d = data:byte(index, index + 3)
    if a == nil or b == nil or c == nil or d == nil then return nil end
    return a + b * 256 + c * 65536 + d * 16777216
end

-- Decode Horizon/Ashita's incoming 0x02D action-message payload. The field
-- layout mirrors XIUI's approved EXP-bar handler and SimpleLog's message table.
function M.parse_action_exp(data, player_id)
    if type(data) ~= 'string' or #data < 26 or type(player_id) ~= 'number' then
        return nil
    end

    local actor_id = u32le(data, 5)
    if actor_id ~= player_id then return nil end

    -- Horizon XIUI's 0x02D handler reads the message value at byte 17
    -- (e.data_modified offset 0x10 + 1), not the retail-style param_1 slot.
    local value = u32le(data, 17)
    local message_id = u16le(data, 25)
    if value == nil or message_id == nil then return nil end
    message_id = message_id % 1024

    if message_id == 8 or message_id == 105 or message_id == 253 then return value end
    return nil
end

function M.new_state(now)
    return {
        started_at = nil,
        last_gain_at = nil,
        total = 0,
        last = 0,
        recent = {},
        kills = 0,
    }
end

function M.add_exp(state, amount, now, idle_reset_seconds)
    if type(amount) ~= 'number' or amount <= 0 then return false end
    now = now or 0
    idle_reset_seconds = idle_reset_seconds or 1200

    if state.last_gain_at ~= nil and (now - state.last_gain_at) > idle_reset_seconds then
        state.started_at = nil
        state.total = 0
        state.last = 0
        state.recent = {}
        state.kills = 0
    end

    if state.started_at == nil then state.started_at = now end
    state.last_gain_at = now
    state.total = state.total + amount
    state.last = amount
    state.kills = state.kills + 1
    table.insert(state.recent, amount)
    while #state.recent > 10 do table.remove(state.recent, 1) end
    return true
end

function M.average_recent(state, count)
    if #state.recent == 0 then return 0 end
    count = math.min(count or 3, #state.recent)
    local total = 0
    local first = #state.recent - count + 1
    for index = first, #state.recent do total = total + state.recent[index] end
    return total / count
end

function M.exp_per_hour(state, now)
    if state.started_at == nil or state.kills < 2 then return 0 end
    local elapsed = (now or state.started_at) - state.started_at
    if elapsed <= 0 then return 0 end
    return state.total * 3600 / elapsed
end

function M.format_number(value)
    local n = math.floor((value or 0) + 0.5)
    local formatted = tostring(n)
    repeat
        local changed
        formatted, changed = formatted:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
    until changed == 0
    return formatted
end

return M
