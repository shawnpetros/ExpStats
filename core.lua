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

-- Windows key events encode the previous key state in lParam bit 30 and the
-- transition state in bit 31. Match only the first key-down transition so a
-- held key cannot toggle an overlay repeatedly through auto-repeat.
function M.is_initial_keydown(wparam, lparam, virtual_key)
    if type(wparam) ~= 'number' or type(lparam) ~= 'number'
        or type(virtual_key) ~= 'number' or wparam ~= virtual_key then
        return false
    end
    local was_down = bit.band(lparam, bit.lshift(1, 30)) ~= 0
    local is_up = bit.band(lparam, bit.lshift(1, 31)) ~= 0
    return not was_down and not is_up
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
        band_active = false,
        band_exp = 0,
    }
end

function M.set_band_active(state, active)
    active = active == true
    if active and not state.band_active then
        state.band_exp = 0
    elseif not active then
        state.band_exp = 0
    end
    state.band_active = active
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
    if state.band_active then state.band_exp = state.band_exp + amount end
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

function M.exp_to_next_level(current_exp, needed_exp)
    if type(current_exp) ~= 'number' or type(needed_exp) ~= 'number' then return nil end
    if needed_exp <= 0 or current_exp < 0 or current_exp >= needed_exp then return 0 end
    return needed_exp - current_exp
end

function M.minutes_to_goal(remaining_exp, exp_per_hour)
    if type(remaining_exp) ~= 'number' or type(exp_per_hour) ~= 'number' then return nil end
    if remaining_exp <= 0 then return 0 end
    if exp_per_hour <= 0 then return nil end
    return remaining_exp * 60 / exp_per_hour
end

function M.format_duration(minutes)
    if type(minutes) ~= 'number' then return '--' end
    local total_minutes = math.max(0, math.ceil(minutes))
    if total_minutes < 60 then return tostring(total_minutes) .. 'm' end
    local hours = math.floor(total_minutes / 60)
    local remainder = total_minutes % 60
    if remainder == 0 then return tostring(hours) .. 'h' end
    return string.format('%dh %dm', hours, remainder)
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

function M.party_report(state, now, remaining_exp)
    local rate = M.exp_per_hour(state, now)
    local rate_text = state.kills >= 2 and M.format_number(rate) or '--'
    local remaining_text = remaining_exp ~= nil and M.format_number(remaining_exp) or '--'
    local eta_text = state.kills >= 2
        and M.format_duration(M.minutes_to_goal(remaining_exp, rate)) or '--'
    local last_text = state.kills > 0 and M.format_number(state.last) or '--'
    local average3_text = state.kills > 0 and M.format_number(M.average_recent(state, 3)) or '--'

    return string.format(
        'EXP: %s total | %s/hr | TNL %s | ETA %s | Last %s | Avg3 %s',
        M.format_number(state.total), rate_text, remaining_text, eta_text,
        last_text, average3_text)
end

return M
