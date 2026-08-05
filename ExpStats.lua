addon.name      = 'ExpStats';
addon.author    = 'troyBORG';
addon.version   = '0.5.2';
addon.desc      = 'Displays EXP pace, recent gains, EXP to next level, and estimated time to level.';
addon.link      = 'Pending HorizonXI Community Team review';

require 'common';

local chat      = require 'chat';
local imgui     = require 'imgui';
local settings  = require 'settings';
local core      = require 'core';

local defaults = T{
    visible = true,
    x = 420,
    y = 180,
    opacity = 0.72,
};

local config = settings.load(defaults);
local moving = { false };
local first_position = true;
local window_x = config.x;
local window_y = config.y;
local state = core.new_state(ashita.time.clock().ms / 1000);

settings.register('settings', 'settings_update', function (s)
    if s ~= nil then
        config = s;
        window_x = config.x;
        window_y = config.y;
    end
end);

local function now()
    return ashita.time.clock().ms / 1000;
end

local function reset_session()
    state = core.new_state(now());
    print(chat.header(addon.name):append(chat.message('Session statistics reset.')));
end

local function print_help()
    print(chat.header(addon.name):append(chat.message('Commands:')));
    print(chat.message('/expstats show|hide|move|reset|test|status'));
end

local function add_exp(amount)
    if core.add_exp(state, amount, now(), 1200) then
        return true;
    end
    return false;
end

local function get_exp_remaining()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    if player == nil then return nil; end
    return core.exp_to_next_level(player:GetExpCurrent(), player:GetExpNeeded());
end

ashita.events.register('packet_in', 'expstats_packet_in', function (e)
    if e.id ~= 0x02D then return; end
    local entity = GetPlayerEntity();
    if entity == nil then return; end
    local amount = core.parse_action_exp(e.data_modified, entity.ServerId);
    if amount ~= nil then add_exp(amount); end
end);

ashita.events.register('command', 'expstats_command', function (e)
    local args = e.command:args();
    if #args == 0 or not args[1]:any('/expstats', '/xs') then return; end
    e.blocked = true;

    local command = (#args >= 2) and args[2]:lower() or 'status';
    if command == 'show' then
        config.visible = true; settings.save();
    elseif command == 'hide' then
        config.visible = false; moving[1] = false; settings.save();
    elseif command == 'move' then
        config.visible = true;
        if moving[1] then
            config.x = math.floor(window_x);
            config.y = math.floor(window_y);
            moving[1] = false;
            settings.save();
        else
            moving[1] = true;
        end
        print(chat.header(addon.name):append(chat.message(moving[1] and 'Move mode enabled; drag the window.' or 'Move mode disabled.')));
    elseif command == 'reset' then
        reset_session();
    elseif command == 'test' then
        reset_session();
        for value = 100, 190, 10 do add_exp(value); end
        print(chat.header(addon.name):append(chat.message('Loaded ten test values: 100 through 190.')));
    elseif command == 'status' then
        local remaining = get_exp_remaining();
        local numeric_rate = core.exp_per_hour(state, now());
        local eta = core.format_duration(core.minutes_to_goal(remaining, numeric_rate));
        print(chat.header(addon.name):append(chat.message(string.format(
            'Total %s | %s/hr | TNL %s | ETA %s | Last %s | Avg(3) %s | Avg(10) %s',
            core.format_number(state.total), core.format_number(numeric_rate),
            remaining ~= nil and core.format_number(remaining) or '--', eta,
            core.format_number(state.last), core.format_number(core.average_recent(state, 3)),
            core.format_number(core.average_recent(state, 10))))));
    else
        print_help();
    end
end);

ashita.events.register('d3d_present', 'expstats_present', function ()
    if not config.visible then return; end

    if first_position then
        -- Always apply the persisted coordinates on the first rendered frame.
        -- ImGuiCond_Once can yield to ImGui's own stale window-state cache.
        imgui.SetNextWindowPos({ config.x, config.y }, ImGuiCond_Always);
        first_position = false;
    end

    imgui.SetNextWindowBgAlpha(config.opacity);
    local flags = bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoScrollbar);
    if not moving[1] then
        flags = bit.bor(flags, ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoInputs);
    end

    if imgui.Begin('EXP Stats###ExpStats', moving, flags) then
        local rate = state.kills >= 2 and core.format_number(core.exp_per_hour(state, now())) or '--';
        local last = state.kills > 0 and core.format_number(state.last) or '--';
        local average3 = state.kills > 0 and core.format_number(core.average_recent(state, 3)) or '--';
        local average10 = state.kills > 0 and core.format_number(core.average_recent(state, 10)) or '--';
        local remaining = get_exp_remaining();
        local numeric_rate = core.exp_per_hour(state, now());
        local tnl = remaining ~= nil and core.format_number(remaining) or '--';
        local eta = state.kills >= 2 and core.format_duration(core.minutes_to_goal(remaining, numeric_rate)) or '--';

        imgui.TextColored({ 0.95, 0.68, 1.00, 1.00 }, 'TNL: ' .. tnl);
        imgui.SameLine();
        imgui.TextColored({ 1.00, 0.82, 0.48, 1.00 }, '  ETA: ' .. eta);

        imgui.TextColored({ 1.00, 0.78, 0.18, 1.00 }, rate .. ' EXP/hr');
        imgui.SameLine();
        imgui.TextColored({ 0.72, 0.82, 1.00, 1.00 }, '  Last: ' .. last);
        imgui.SameLine();
        imgui.TextColored({ 0.65, 1.00, 0.72, 1.00 }, '  Avg(3): ' .. average3);
        imgui.SameLine();
        imgui.TextColored({ 0.50, 0.92, 0.88, 1.00 }, '  Avg(10): ' .. average10);

        if moving[1] then
            imgui.TextDisabled('Drag me, then use /expstats move to lock.');
        end
    end

    local x, y = imgui.GetWindowPos();
    if x ~= nil and y ~= nil then
        window_x = x;
        window_y = y;
    end
    if moving[1] then
        if x ~= nil and y ~= nil and (x ~= config.x or y ~= config.y) then
            config.x = math.floor(x);
            config.y = math.floor(y);
        end
    end
    imgui.End();
end);
