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
    local amount = text:match('^You gain (%d+) experience points?%.?$')
        or text:match('^You gain (%d+) experience points? and %d+ limit points?%.?$')
    return amount and tonumber(amount) or nil
end

function M.new_state(now)
    return {
        started_at = now or 0,
        total = 0,
        last = 0,
        recent = {},
        kills = 0,
    }
end

function M.add_exp(state, amount)
    if type(amount) ~= 'number' or amount <= 0 then return false end
    state.total = state.total + amount
    state.last = amount
    state.kills = state.kills + 1
    table.insert(state.recent, amount)
    while #state.recent > 3 do table.remove(state.recent, 1) end
    return true
end

function M.average_recent(state)
    if #state.recent == 0 then return 0 end
    local total = 0
    for _, value in ipairs(state.recent) do total = total + value end
    return total / #state.recent
end

function M.exp_per_hour(state, now)
    local elapsed = math.max(1, (now or state.started_at) - state.started_at)
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
