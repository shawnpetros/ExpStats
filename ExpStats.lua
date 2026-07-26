addon.name      = 'ExpStats';
addon.author    = 'troyBORG';
addon.version   = '0.1.0';
addon.desc      = 'Displays session EXP/hour, last EXP gain, and rolling three-kill average.';
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
local state = core.new_state(ashita.time.clock().ms / 1000);

settings.register('settings', 'settings_update', function (s)
    if s ~= nil then config = s; end
    settings.save();
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
    if core.add_exp(state, amount) then
        return true;
    end
    return false;
end

ashita.events.register('text_in', 'expstats_text_in', function (e)
    local amount = core.parse_exp(e.message);
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
        config.visible = true; moving[1] = not moving[1];
        print(chat.header(addon.name):append(chat.message(moving[1] and 'Move mode enabled; drag the window.' or 'Move mode disabled.')));
    elseif command == 'reset' then
        reset_session();
    elseif command == 'test' then
        reset_session(); add_exp(120); add_exp(150); add_exp(180);
        print(chat.header(addon.name):append(chat.message('Loaded test values: 120, 150, 180.')));
    elseif command == 'status' then
        print(chat.header(addon.name):append(chat.message(string.format(
            'Total %s | %s/hr | Last %s | Last 3 avg %s',
            core.format_number(state.total), core.format_number(core.exp_per_hour(state, now())),
            core.format_number(state.last), core.format_number(core.average_recent(state))))));
    else
        print_help();
    end
end);

ashita.events.register('d3d_present', 'expstats_present', function ()
    if not config.visible then return; end

    if first_position then
        imgui.SetNextWindowPos({ config.x, config.y }, ImGuiCond_Once);
        first_position = false;
    end

    imgui.SetNextWindowBgAlpha(config.opacity);
    local flags = bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoScrollbar);
    if not moving[1] then
        flags = bit.bor(flags, ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoInputs);
    end

    if imgui.Begin('EXP Stats###ExpStats', moving, flags) then
        local rate = core.format_number(core.exp_per_hour(state, now()));
        local last = state.kills > 0 and core.format_number(state.last) or '--';
        local average = state.kills > 0 and core.format_number(core.average_recent(state)) or '--';

        imgui.TextColored({ 1.00, 0.78, 0.18, 1.00 }, rate .. ' EXP/hr');
        imgui.SameLine();
        imgui.TextColored({ 0.72, 0.82, 1.00, 1.00 }, '  Last: ' .. last);
        imgui.SameLine();
        imgui.TextColored({ 0.65, 1.00, 0.72, 1.00 }, '  Avg(3): ' .. average);

        if moving[1] then
            imgui.TextDisabled('Drag me, then use /expstats move to lock.');
        end
    end

    if moving[1] then
        local x, y = imgui.GetWindowPos();
        if x ~= nil and y ~= nil and (x ~= config.x or y ~= config.y) then
            config.x = math.floor(x);
            config.y = math.floor(y);
            settings.save();
        end
    end
    imgui.End();
end);
