local client_screen_size, entity_get_local_player, entity_get_player_weapon, entity_get_prop, entity_is_alive, globals_frametime, renderer_gradient, ui_get, ui_new_checkbox, ui_new_color_picker, ui_new_slider, ui_reference, ui_set, ui_set_callback, ui_set_visible = client.screen_size, entity.get_local_player, entity.get_player_weapon, entity.get_prop, entity.is_alive, globals.frametime, renderer.gradient, ui.get, ui.new_checkbox, ui.new_color_picker, ui.new_slider, ui.reference, ui.set, ui.set_callback, ui.set_visible
local clamp = function(v, min, max) local num = v; num = num < min and min or num; num = num > max and max or num; return num end


local session_seconds_played = 0 
local formatted_time = "00:00:00" 


local function update_and_schedule_time_increment()
    session_seconds_played = session_seconds_played + 1

    local hours = math.floor(session_seconds_played / 3600)
    local minutes = math.floor((session_seconds_played % 3600) / 60)
    local seconds = math.floor(session_seconds_played % 60)

    formatted_time = string.format("%02d:%02d:%02d", hours, minutes, seconds)


    if client and client.delay_call then
        client.delay_call(1, update_and_schedule_time_increment)
    else
        
    end
end


if client and client.delay_call then
    client.delay_call(1, update_and_schedule_time_increment)
    
else
    
end


local notify = (function()
    local vector = vector
    local lerp = function(a, b, t) return a + (b - a) * t end
    local screen_size = function() return vector(client.screen_size()) end
    local measure_text = function(font, text_to_measure) 
        return vector(renderer.measure_text(font, text_to_measure)) 
    end

    local NotificationSystem = {
        notifications = { bottom = {} },
        max = { bottom = 6 }
    }
    NotificationSystem.__index = NotificationSystem

    function NotificationSystem.new_bottom(r, g, b, ...)
        local screen = screen_size()
        table.insert(NotificationSystem.notifications.bottom, {
            started = false,
            instance = setmetatable({
                active = false,
                timeout = 5,
                color = { r = r, g = g, b = b, a = 0 }, 
                x = screen.x / 2,
                y = screen.y,
                text = {...}
            }, NotificationSystem)
        })
    end

    function NotificationSystem:handler()
        for i = #NotificationSystem.notifications.bottom, 1, -1 do 
            local notification = NotificationSystem.notifications.bottom[i]
            if notification and not notification.instance.active and notification.started then
                table.remove(NotificationSystem.notifications.bottom, i)
            end
        end

        local active_count = 0
        for i = 1, #NotificationSystem.notifications.bottom do
            if NotificationSystem.notifications.bottom[i].instance.active then
                active_count = active_count + 1
            end
        end

        for idx, notification in pairs(NotificationSystem.notifications.bottom) do
            if idx > NotificationSystem.max.bottom then break end 

            if notification.instance.active then
                notification.instance:render_bottom(idx, active_count)
            end
            
            if not notification.started then
                notification.instance:start()
                notification.started = true
            end
        end
    end

    function NotificationSystem:start()
        self.active = true
        self.delay = globals.realtime() + self.timeout
    end

    function NotificationSystem:get_text()
        local result = ""
        local text_parts_container = self.text[1] 
        
        if type(text_parts_container) == "table" then
            for i, part in pairs(text_parts_container) do
                local current_text_part = ""

                if part and part[1] ~= nil then
                    local p1_type = type(part[1])
                    if p1_type == "string" or p1_type == "number" or p1_type == "boolean" then
                        current_text_part = tostring(part[1])
                    else
                        current_text_part = "" 
                    end
                end

                local width = measure_text("", current_text_part).x 
                local r, g, b = 255, 255, 255
                if part and part[2] then 
                    r, g, b = 255, 255, 255 
                end

                result = result .. ("\a%02x%02x%02x%02x%s"):format(r, g, b, self.color.a, current_text_part)
            end
        end
        return result
    end

    local render_utils = (function()
        local utils = {}
        
        function utils.rounded_rect(x, y, w, h, radius, r, g, b, a)
            radius = math.min(w/2, h/2, radius)
            renderer.rectangle(x, y + radius, w, h - radius*2, r, g, b, a)
            renderer.rectangle(x + radius, y, w - radius*2, radius, r, g, b, a)
            renderer.rectangle(x + radius, y + h - radius, w - radius*2, radius, r, g, b, a)
            renderer.circle(x + radius, y + radius, r, g, b, a, radius, 180, 0.25)
            renderer.circle(x - radius + w, y + radius, r, g, b, a, radius, 90, 0.25)
            renderer.circle(x - radius + w, y - radius + h, r, g, b, a, radius, 0, 0.25)
            renderer.circle(x + radius, y - radius + h, r, g, b, a, radius, -90, 0.25)
        end
        
        function utils.rounded_rect_outline(x, y, w, h, radius, thickness, r, g, b, a)
            radius = math.min(w/2, h/2, radius)
            if radius == 1 then
                renderer.rectangle(x, y, w, thickness, r, g, b, a)
                renderer.rectangle(x, y + h - thickness, w, thickness, r, g, b, a)
            else
                renderer.rectangle(x + radius, y, w - radius*2, thickness, r, g, b, a)
                renderer.rectangle(x + radius, y + h - thickness, w - radius*2, thickness, r, g, b, a)
                renderer.rectangle(x, y + radius, thickness, h - radius*2, r, g, b, a)
                renderer.rectangle(x + w - thickness, y + radius, thickness, h - radius*2, r, g, b, a)
                renderer.circle_outline(x + radius, y + radius, r, g, b, a, radius, 180, 0.25, thickness)
                renderer.circle_outline(x + radius, y + h - radius, r, g, b, a, radius, 90, 0.25, thickness)
                renderer.circle_outline(x + w - radius, y + radius, r, g, b, a, radius, -90, 0.25, thickness)
                renderer.circle_outline(x + w - radius, y + h - radius, r, g, b, a, radius, 0, 0.25, thickness)
            end
        end
        
        function utils.glow_notification(x, y, w, h, width, rounding, r, g, b, a, has_inner)
            local thickness = 1
            local offset = 1

            if has_inner then
                utils.rounded_rect(x, y, w, h, rounding, 25, 25, 25, a) 
            end
            
            for i = 0, width do
                local alpha_mul = a/2 * (i/width)^3
                utils.rounded_rect_outline(
                    x - i, y - i, 
                    w + i*2, h + i*2, 
                    rounding + i, 1, 
                    r, g, b, alpha_mul/1.5
                )
            end
        end

        -- НОВАЯ ФУНКЦИЯ ДЛЯ ОТРИСОВКИ АНИМИРОВАННЫХ СКАН-ЛИНИЙ
        function utils.draw_animated_scanlines(x, y, w, h, base_alpha, speed)
            local line_height = 1 -- Высота одной линии
            local line_spacing = 3 -- Расстояние между линиями
            local line_color_r, line_color_g, line_color_b = 50, 255, 50 -- Зеленый цвет для "хакерского" стиля

            -- Смещение линий со временем
            local offset_y = (globals.realtime() * speed) % (line_height + line_spacing)

            for current_y_offset = 0, h + line_spacing, line_height + line_spacing do
                local draw_y = y + current_y_offset - offset_y
                
                -- Зацикливаем линии внутри высоты уведомления
                if draw_y < y then
                    draw_y = draw_y + h + line_spacing
                elseif draw_y > y + h + line_spacing then
                    draw_y = draw_y - (h + line_spacing)
                end

                -- Убедимся, что рисуем только внутри границ уведомления
                if draw_y + line_height > y and draw_y < y + h then
                    -- Альфа-канал зависит от базовой альфы уведомления
                    local line_alpha = math.min(base_alpha, 255) * 0.15 -- Очень тонкий эффект
                    renderer.rectangle(x, draw_y, w, line_height, line_color_r, line_color_g, line_color_b, line_alpha)
                end
            end
        end
        
        return utils
    end)()

    function NotificationSystem:render_bottom(index, active_count)
        local screen = screen_size()
        local padding = 6
        local text_render_offset_x = -5 -- Смещение текста влево на 5 пикселей
        local text = "      " .. self:get_text()
        local text_size = measure_text("", text)
        local rounding = 8
        local spacing = 5
        
        local width = padding + text_size.x + spacing*2
        local height = 12 + 10 + 1 
        
        local x = self.x - width/2
        local y = math.ceil(self.y - 40 + 0.4)

        local frame_time = globals.frametime()
        
        if globals.realtime() < self.delay then
            self.y = lerp(self.y, screen.y - 45 - (active_count - index) * (height + 15), frame_time * 7) 
            self.color.a = lerp(self.color.a, 255, frame_time * 2) 
        else
            self.y = lerp(self.y, self.y - 10, frame_time * 15)
            self.color.a = lerp(self.color.a, 0, frame_time * 20) 
            if self.color.a <= 1 then
                self.active = false
            end
        end
        
        if self.color.a > 0 then
            -- Отрисовываем фон уведомления
            render_utils.glow_notification(
                x, y, width, height, 15, rounding,
                25, 25, 25, self.color.a, 
                true
            )

            -- ОТРИСОВКА АНИМИРОВАННЫХ СКАН-ЛИНИЙ ПОВЕРХ ФОНА
            render_utils.draw_animated_scanlines(x, y, width, height, self.color.a, 20) -- Скорость 20, можно настроить

            local text_x = x + spacing + 2 + padding + text_render_offset_x -- ПРИМЕНЕНО СМЕЩЕНИЕ ТЕКСТА
            renderer.text(
                text_x, y + height/2 - text_size.y/2,
                self.color.r, self.color.g, self.color.b, self.color.a, 
                "M", nil, text
            )
        end
    end

    client.set_event_callback("paint_ui", function()
        NotificationSystem:handler()
    end)

    return NotificationSystem
end)()

local user = {} do
    local local_player = entity.get_local_player() 
    user.name = entity.get_player_name(local_player) 
    user.version = "ＡＩＭＳＥＮＳＥ"
end

do
    local dependencies = {
        ['pui'] = {
            name = 'gamesense/pui',
            link = 'https://gamesense.pub/forums/viewtopic.php?id=41761'
        },
        ['weapons'] = {
            name = 'gamesense/csgo_weapons',
            link = 'https://gamesense.pub/forums/viewtopic.php?id=18807'
        },
        ['surface'] = {
            name = 'gamesense/surface',
            type = 'workshop',
            link = 'https://gamesense.pub/forums/viewtopic.php?id=18793'
        },
        ['base64'] = {
            name = 'gamesense/base64',
            type = 'workshop',
            link = 'https://gamesense.pub/forums/viewtopic.php?id=21619'
        },
        ['clipboard'] = {
            name = 'gamesense/clipboard',
            type = 'workshop',
            link = 'https://gamesense.pub/forums/viewtopic.php?id=28678'
        },
    }

    local located = true

    for gname, method in pairs(dependencies) do
        local success = pcall(require, method.name)

        if not success then
            client.error_log(string.format('[-] Unable to locate %s library. You need to subscribe to it here %s', gname, method.link))
            located = false
        end
    end

    if not located then
        return error('[~] Script was unable to start. You can investigate error above.')
    end
end

local ffi = require 'ffi'
local vector = require("vector")
local pui = require("gamesense/pui")
local weapons = require ("gamesense/csgo_weapons")
local surface = require ('gamesense/surface')
local base64 = require ('gamesense/base64')
local clipboard = require ('gamesense/clipboard')
local http = require'gamesense/http'
local images = require'gamesense/images'
local entitys = require'gamesense/entity'
local easing = require'gamesense/easing'
local json = require("json")
m_alpha = 0

local reference = {} do

    reference.ragebot = {} do
        reference.ragebot.enabled = pui.reference("RAGE", "Aimbot", "Enabled")
        reference.ragebot.double_tap = pui.reference("RAGE", "Aimbot", "Double tap") 
        reference.ragebot.dt_limit = {pui.reference("rage", "aimbot", "Double tap fake lag limit")}
        reference.ragebot.duck = pui.reference("RAGE", "Other", "Duck peek assist")
        reference.ragebot.quick_peek =  pui.reference("Rage", "Other", "Quick peek assist") 
        reference.ragebot.ovr = { pui.reference('rage', 'aimbot', 'minimum damage override') }
        reference.ragebot.force_bodyaim = pui.reference('RAGE', 'Aimbot', 'Force body aim')
        reference.ragebot.force_safepoint = pui.reference('RAGE', 'Aimbot', 'Force safe point')
    end

    reference.antiaim = {} do
        reference.antiaim.enable = pui.reference("AA", "Anti-aimbot angles", "Enabled")
        reference.antiaim.pitch = { pui.reference("AA", "Anti-aimbot angles", "Pitch") }
        reference.antiaim.yaw = { pui.reference("AA", "Anti-aimbot angles", "Yaw") }
        reference.antiaim.base = pui.reference("AA", "Anti-aimbot angles", "Yaw base")
        reference.antiaim.jitter = { pui.reference("AA", "Anti-aimbot angles", "Yaw jitter") }
        reference.antiaim.body = { pui.reference("AA", "Anti-aimbot angles", "Body yaw") }
        reference.antiaim.edge = pui.reference("AA", "Anti-aimbot angles", "Edge yaw")
        reference.antiaim.fs_body = pui.reference("AA", "Anti-aimbot angles", "Freestanding body yaw")
        reference.antiaim.freestand = pui.reference("AA", "Anti-aimbot angles", "Freestanding")
        reference.antiaim.roll = pui.reference("AA", "Anti-aimbot angles", "Roll")
        -- Удалено: Slow motion, On shot anti-aim, Leg movement
    end 

    reference.fakelag1 = {} do
        reference.fakelag1.enable = {pui.reference('AA', 'Fake lag', 'Enabled')}
        reference.fakelag1.amount = pui.reference('AA', 'Fake lag', 'Amount')
        reference.fakelag1.variance = pui.reference('AA', 'Fake lag', 'Variance')
        reference.fakelag1.limit = pui.reference('AA', 'Fake lag', 'Limit')
    end

    reference.misc = {} do
        reference.misc.clantag = pui.reference('Misc', 'Miscellaneous', 'Clan tag spammer')
        reference.misc.draw_output = pui.reference('MISC', 'Miscellaneous', 'Draw console output')
    end

end

local memory = {}  do
    memory.get_client_entity = vtable_bind('client.dll', 'VClientEntityList003', 3, 'void*(__thiscall*)(void***, int)')

    memory.animstate = {} do

        local animstate_t = ffi.typeof 'struct { char pad0[0x18]; float anim_update_timer; char pad1[0xC]; float started_moving_time; float last_move_time; char pad2[0x10]; float last_lby_time; char pad3[0x8]; float run_amount; char pad4[0x10]; void* entity; void* active_weapon; void* last_active_weapon; float last_client_side_animation_update_time; int	 last_client_side_animation_update_framecount; float eye_timer; float eye_angles_y; float eye_angles_x; float goal_feet_yaw; float current_feet_yaw; float torso_yaw; float last_move_yaw; float lean_amount; char pad5[0x4]; float feet_cycle; float feet_yaw_rate; char pad6[0x4]; float duck_amount; float landing_duck_amount; char pad7[0x4]; float current_origin[3]; float last_origin[3]; float velocity_x; float velocity_y; char pad8[0x4]; float unknown_float1; char pad9[0x8]; float unknown_float2; float unknown_float3; float unknown; float m_velocity; float jump_fall_velocity; float clamped_velocity; float feet_speed_forwards_or_sideways; float feet_speed_unknown_forwards_or_sideways; float last_time_started_moving; float last_time_stopped_moving; bool on_ground; bool hit_in_ground_animation; char pad10[0x4]; float time_since_in_air; float last_origin_z; float head_from_ground_distance_standing; float stop_to_full_running_fraction; char pad11[0x4]; float magic_fraction; char pad12[0x3C]; float world_force; char pad13[0x1CA]; float min_yaw; float max_yaw; } **'
        
        memory.animstate.offset = 0x9960

        memory.animstate.get = function (self, ent)
            if not ent then
                return
            end
            local client_entity = memory.get_client_entity(ent)

            if not client_entity then
                return
            end
            

            return ffi.cast(animstate_t, ffi.cast('uintptr_t', client_entity) + self.offset)[0]
        end

        
    end

    memory.animlayers = {} do
        if not pcall(ffi.typeof, 'bt_animlayer_t') then
            ffi.cdef[[
                typedef struct {
                    float   anim_time;
                    float   fade_out_time;
                    int     nil;
                    int     activty;
                    int     priority;
                    int     order;
                    int     sequence;
                    float   prev_cycle;
                    float   weight;
                    float   weight_delta_rate;
                    float   playback_rate;
                    float   cycle;
                    int     owner;
                    int     bits;
                } bt_animlayer_t, *pbt_animlayer_t
            ]]
        end

        memory.animlayers.offset = ffi.cast('int*', ffi.cast('uintptr_t', client.find_signature('client.dll', '\x8B\x89\xCC\xCC\xCC\xCC\x8D\x0C\xD1')) + 2)[0]


        memory.animlayers.get = function (self, ent)
            local client_entity = memory.get_client_entity(ent)

            if not client_entity then
                return
            end

            return ffi.cast('pbt_animlayer_t*', ffi.cast('uintptr_t', client_entity) + self.offset)[0]
        end
    end

    memory.activity = {} do
        if not pcall(ffi.typeof, 'bt_get_sequence') then
            ffi.cdef[[
                typedef int(__fastcall* bt_get_sequence)(void* entity, void* studio_hdr, int sequence);
            ]]
        end

        memory.activity.offset = 0x2950
        memory.activity.location = ffi.cast('bt_get_sequence', client.find_signature('client.dll', '\x55\x8B\xEC\x53\x8B\x5D\x08\x56\x8B\xF1\x83'))

    
        memory.activity.get = function (self, sequence, ent)
            local client_entity = memory.get_client_entity(ent)

            if not client_entity then
                return
            end

            local studio_hdr = ffi.cast('void**', ffi.cast('uintptr_t', client_entity) + self.offset)[0]

            if not studio_hdr then
                return;
            end

            return self.location(client_entity, studio_hdr, sequence);
        end
    end

    memory.user_input = {} do
        if not pcall(ffi.typeof, 'bt_cusercmd_t') then
            ffi.cdef[[
                typedef struct {
                    struct bt_cusercmd_t (*cusercmd)();
                    int     command_number;
                    int     tick_count;
                    float   view[3];
                    float   aim[3];
                    float   move[3];
                    int     buttons;
                } bt_cusercmd_t;
            ]]
        end

        if not pcall(ffi.typeof, 'bt_get_usercmd') then
            ffi.cdef[[
                typedef bt_cusercmd_t*(__thiscall* bt_get_usercmd)(void* input, int, int command_number);
            ]]
        end

        memory.user_input.vtbl = ffi.cast('void***', ffi.cast('void**', ffi.cast('uintptr_t', client.find_signature('client.dll', '\xB9\xCC\xCC\xCC\xCC\x8B\x40\x38\xFF\xD0\x84\xC0\x0F\x85') or error('fipp')) + 1)[0])
        memory.user_input.location = ffi.cast('bt_get_usercmd', memory.user_input.vtbl[0][8])

        memory.user_input.get_command = function (self, command_number)
            return self.location(self.vtbl, 0, command_number)
        end
    end

    function memory.get_simtime(ent)
        local pointer = memory.get_client_entity(ent)

        if pointer then
            return entity.get_prop(ent, "m_flSimulationTime"), ffi.cast("float*", ffi.cast("uintptr_t", pointer) + 620)[0]
        else
            return 0
        end
    end


end 

local c_math , c_tweening  do

    c_math = {} do
        function c_math.normalize_yaw(a)
            while a > 180 do
                a = a - 360
            end

            while a < -180 do
                a = a + 360
            end

            return a
        end

        function c_math.threat_yaw()
            local aa_threat = client.current_threat()

            if not aa_threat then
                return
            end

            local my_origin = vector(entity.get_origin(entity.get_local_player()))
            local _, threat_yaw = my_origin:to(vector(entity.get_origin(aa_threat))):angles()

            return threat_yaw
        end
            
        function c_math.clamp(x, a, b)
            if a > x then
                return
                    a
            elseif
                b < x then
                return
                    b
            else
                return x
            end
        end

        function c_math.extend_vector(pos, length, angle)
            local rad = angle * math.pi / 180
            if rad == nil then return end
            if angle == nil or pos == nil or length == nil then return end
            return { pos[1] + (math.cos(rad) * length), pos[2] + (math.sin(rad) * length), pos[3] };
        end

        function c_math.contains(tbl, value)
            local tbl_len = #tbl

            for i=1, tbl_len do
                if tbl[i] == value then
                    return true
                end
            end

            return false
        end

        function c_math.lerp(a, b, w)  
            return a + (b - a) * w  
        end

        function c_math.color_lerp(r1, g1, b1, a1, r2, g2, b2, a2, t)
            local r = c_math.lerp(r1, r2, t)
            local g = c_math.lerp(g1, g2, t)
            local b = c_math.lerp(b1, b2, t)
            local a = c_math.lerp(a1, a2, t)

            return r, g, b, a
        end

        function c_math.closest_ray_point(p, s, e)
            local t, d = p - s, e - s
            local l = d:length()
            d = d / l
            local r = d:dot(t)
            if r < 0 then return s elseif r > l then return e end
            return s + d * r
        end

        function  c_math.split(str, sep)
            local result = {}
            local start = str:find(sep)

            if not start then
                return {str}
            end

            local pos = 1

            while start do
                result[#result+1] = str:sub(pos, start)

                pos = start+sep:len()

                start = str:find(sep, pos)

                if not start then
                    result[#result+1] = str:sub(pos)
                end
            end

            return result
        end



    end 

    c_tweening = {} do
        local native_GetTimescale = vtable_bind('engine.dll', 'VEngineClient014', 91, 'float(__thiscall*)(void*)')

        local function solve(easings_fn, prev, new, clock, duration)
            local prev = easings_fn(clock, prev, new - prev, duration)

            if type(prev) == 'number' then
                if math.abs(new - prev) <= .01 then
                    return new
                end

                local fmod = prev % 1

                if fmod < .001 then
                    return math.floor(prev)
                end

                if fmod > .999 then
                    return math.ceil(prev)
                end
            end

            return prev
        end

        local mt = {}; do
            local function update(self, duration, target, easings_fn)
                if duration == nil and target == nil and easings_fn == nil then
                    return self.value
                end

                local value_type = type(self.value)
                local target_type = type(target)

                if target_type == 'boolean' then
                    target = target and 1 or 0
                    target_type = 'number'
                end

                assert(value_type == target_type, string.format('type mismatch, expected %s (received %s)', value_type, target_type))

                if target ~= self.to then
                    self.clock = 0

                    self.from = self.value
                    self.to = target
                end

                local clock = globals.frametime() / native_GetTimescale()
                local duration = duration or .15

                if self.clock == duration then
                    return target
                end

                if clock <= 0 and clock >= duration then
                    self.clock = 0

                    self.from = target
                    self.to = target

                    self.value = target

                    return target
                end

                self.clock = math.min(self.clock + clock, duration)
                self.value = solve(easings_fn or self.easings, self.from, self.to, self.clock, duration)

                return self.value;
            end

            mt.__metatable = false
            mt.__call = update
            mt.__index = mt
        end

        function c_tweening:new(default, easings_fn)
            if type(default) == 'boolean' then
                default = default and 1 or 0
            end

            local this = {}

            this.clock = 0
            this.value = default or 0

            this.easings = easings_fn or function(t, b, c, d)
                return c * t / d + b
            end

            return setmetatable(this, mt)
        end
    end

end 

local color do
    local create_color, create_color_object, Color do
        Color = {} do
            function Color:clone()
                return create_color_object(
                    self.r, self.g, self.b, self.a
                )
            end

            function Color:to_hex()
                return ('%02X%02X%02X%02X'):format(self.r, self.g, self.b, self.a)
            end

            function Color:as_hex(hex_value)
                local r, g, b, a = hex_value:match('(%x%x)(%x%x)(%x%x)(%x%x)')

                return create_color_object(tonumber(r, 16), tonumber(g, 16), tonumber(b, 16), tonumber(a, 16))
            end

            function Color:lerp(color_target, weight)
                return create_color_object(
                    c_math.lerp(self.r, color_target.r, weight),
                    c_math.lerp(self.g, color_target.g, weight),
                    c_math.lerp(self.b, color_target.b, weight),
                    c_math.lerp(self.a, color_target.a, weight)
                )
            end

            function Color:grayscale(ratio)
                return create_color_object(
                    self.r * ratio,
                    self.g * ratio,
                    self.b * ratio,
                    self.a
                )
            end

            function Color:alpha_modulate(alpha, modulate)
                return create_color_object(
                    self.r,
                    self.g,
                    self.b,
                    modulate and self.a*alpha or alpha
                )
            end

            function Color:unpack()
                return self.r, self.g, self.b, self.a
            end
        end

        function create_color_object(self, ...)
            local args = {...}

            if type(self) == 'number' then
                table.insert(args, 1, self)
            end

            if type(args[1]) == 'table' then
                if args[1][1] then
                    args = args[1]
                else
                    args = {args[1].r, args[1].g, args[1].b, args[1].a}
                end
            end

            if type(args[1]) == 'string' then
                return setmetatable({
                    r = 255, g = 255, b = 255, a = 255
                }, {
                    __index = Color
                }):as_hex(args[1])
            end

            return setmetatable({
                r = args[1] or 255,
                g = args[2] or 255,
                b = args[3] or 255,
                a = args[4] or 255
            }, {
                __index = Color
            })
        end

        local stock_colors = {} do
            stock_colors.raw_green = create_color_object(0, 255, 0);
            stock_colors.raw_red = create_color_object(255, 0, 0);

            stock_colors.red = create_color_object(255, 0, 50);
            stock_colors.white = create_color_object();
            stock_colors.gray = create_color_object(200, 200, 200);
            stock_colors.green = create_color_object(143, 194, 21);
            stock_colors.sea = create_color_object(59, 208, 182);
            stock_colors.blue = create_color_object(95, 156, 204);
            stock_colors.pink = create_color_object(209, 101, 145);
            stock_colors.yellow = create_color_object(233, 213, 2);
            stock_colors.purplish = create_color_object(193, 144, 252);

            stock_colors.onshot = create_color_object(100, 148, 237, 255);
            stock_colors.freestanding = create_color_object(132, 195, 16, 255);
            stock_colors.edge = create_color_object(209, 159, 230, 255);
            stock_colors.fixik = create_color_object('00FFCBFF');

            stock_colors.string_to_color_array = (function (str)
                local arr =  {}
                local match, mend = str:find('\a')

                if not match then
                    arr[#arr+1] = str
                else
                    while match do
                        local prmatch = match
                        local prend = mend

                        match, mend = str:find('\a', match+1)

                        if match == nil then
                            arr[#arr+1] = str:sub(prend, #str)

                            break
                        else
                            arr[#arr+1] = str:sub(prmatch, match-1)
                        end
                    end
                end

                local cnt = 0
                local out = {}

                for i=1, #arr do
                    for hex_col, s in arr[i]:gmatch('\a(%x%x%x%x%x%x%x%x)(.+)') do
                        out[#out+1] = {
                            color = create_color(hex_col),
                            text = s
                        };

                        cnt = cnt + 1
                    end
                end

                if cnt == 0 then
                    out[#out+1] = {
                        color = create_color('FFFFFFFF'),
                        text = str
                    }
                end

                return out
            end)

            stock_colors.animated_text = (function (text, speed, color_start, color_end, alpha)
                local first = color_start and create_color(color_start.r, color_start.g, color_start.b, alpha) or create_color(255, 200, 255, alpha)
                local second = color_end and create_color(color_end.r, color_end.g, color_end.b, alpha) or create_color(100, 100, 100, alpha)

                local res = ""

                for idx = 1, #text + 1 do
                    local letter = text:sub(idx, idx)

                    local alpha1 = (idx - 1) / (#text - 1)
                    local m_speed = globals.realtime() * ((50 / 25) or 1.0)
                    local m_factor = m_speed % math.pi

                    local c_speed = speed or 1
                    local m_sin = math.sin(m_factor * c_speed + (alpha1 or 0))
                    local m_abs = math.abs(m_sin)
                    local clr = first:lerp(second, m_abs)

                    res = ("%s\a%s%s"):format(res, clr:to_hex(), letter)
                end

                return res
            end)
        end

        create_color = setmetatable(stock_colors, {
            __call = create_color_object
        })
    end

    color = create_color
end

local player = {
    shifting = false, 
    defensive = false, 
    onground = false, 
    is_fs_peek = false,
    duckamount = 0,
    speed =0,
    packets = 0,
    fs_side = 'none',
    state = "stand",
    body_yaw = 0.0,
    get_players = {},
    lc_left = 0.0,
    crouching = false,
}  do

    local  function get_double_tap()
        local me = entity.get_local_player()
        local m_nTickBase = entity.get_prop(me, 'm_nTickBase')
        local client_latency = client.latency()
        local shift = math.floor(m_nTickBase - globals.tickcount() - 3 - toticks(client_latency) * .5 + .5 * (client_latency * 10))
        local wanted = -14 + (reference.ragebot.dt_limit[1]:get() - 1) + 3 
        return shift <= wanted
    end

    local tickbase_max = 0 
    local last_commandnumber
    



    local function defensive_predict(cmd)
        local me = entity.get_local_player()

        if not me or last_commandnumber ~= cmd.command_number then
            return false
        end
        local tickbase = entity.get_prop(me, "m_nTickBase") or 0

        if math.abs(tickbase - tickbase_max) > 64 then
            tickbase_max = 0
        end
        
		if tickbase > tickbase_max then
            tickbase_max = tickbase
        elseif tickbase < tickbase_max then
            -- block empty
        end
 
        player.lc_left = math.min(14, math.max(0, tickbase_max - tickbase - 1))
        return player.lc_left ~= 1 and player.lc_left > 2  and globals.chokedcommands() < 13
        
    end
    client.set_event_callback("run_command", function(cmd)
        last_commandnumber = cmd.command_number
        player.shifting = get_double_tap()
    end)
    

    local function is_onground()
        local animstate = memory.animstate:get(entity.get_local_player())

        if not animstate then
            return true
        end

        local ptr_addr = ffi.cast('uintptr_t', ffi.cast('void*', animstate))
        local landed_on_ground_this_frame = ffi.cast('bool*', ptr_addr + 0x120)[0] --- @offset

        return animstate.on_ground and not landed_on_ground_this_frame
    end

    local function is_fs_peek()
        local me = entity.get_local_player()
        local enemy = client.current_threat()
        if not me or entity.is_dormant(enemy) then 
            return false
        end
        local pitch, yaw = client.camera_angles(me)
        --my activation arc
        local left2 = c_math.extend_vector({entity.get_origin(me)},30,yaw + 60)
        local right2 = c_math.extend_vector({entity.get_origin(me)},30,yaw - 60)
       
        local pitch, yaw_e = entity.get_prop(enemy, "m_angEyeAngles")
        local enemy_right2 = c_math.extend_vector({entity.get_origin(enemy)},20,yaw_e - 35)
        local enemy_left2 = c_math.extend_vector({entity.get_origin(enemy)},20,yaw_e + 35)

        local _, dmg_left2 =  client.trace_bullet(enemy, enemy_left2[1], enemy_left2[2], enemy_left2[3] + 30, left2[1], left2[2], left2[3], true)
        local _, dmg_right2 = client.trace_bullet(enemy, enemy_right2[1], enemy_right2[2], enemy_right2[3] + 30, right2[1], right2[2], right2[3], true)
        if  dmg_right2 > 0 and dmg_left2 > 0 then
            return  false
        elseif dmg_left2 > 0 then
            return  true
        elseif dmg_right2 > 0 then
            return  true
        end

        return false
    end 

    local function get_state()
        if not player.onground then
            if player.duckamount > 0.5 then
                return 'air crouch'
            else
                return 'air'
            end
        end

        if player.duckamount > 0.5 or reference.ragebot.duck:get() then
            if player.speed > 4 then
                return 'crouch move'
            else
                return 'crouch'
            end
        end


        if slowmotion_state then
            return 'slow-motion'
        end

        if player.speed > 4 then
            return 'move'
        end

        return 'stand'
    end
    local function get_side(target)
        local local_pos, enemy_pos = vector(entity.hitbox_position(entity.get_local_player(), 0)), vector(entity.hitbox_position(target, 0))

        local _, yaw = (local_pos-enemy_pos):angles()
        local l_dir, r_dir = vector():init_from_angles(0, yaw+90), vector():init_from_angles(0, yaw-90)
        local l_pos, r_pos = local_pos + l_dir * 110, local_pos + r_dir * 110

        local fraction = client.trace_line(target, enemy_pos.x, enemy_pos.y, enemy_pos.z, l_pos.x, l_pos.y, l_pos.z)
        local fraction_s = client.trace_line(target, enemy_pos.x, enemy_pos.y, enemy_pos.z, r_pos.x, r_pos.y, r_pos.z)

        if fraction > fraction_s then
            return 'left'
        elseif fraction_s > fraction then
            return 'right'
        elseif fraction == fraction_s then
            return 'none'
        end

        return 'none'
    end    

    local function get_fs_side()
        local me = entity.get_local_player()
        local target, cross_target,best_yaw = nil, nil, 362
        local enemy_list = entity.get_players(true)
        local stomach_origin = vector(entity.hitbox_position(me, 2))
        local camera_angles = vector(client.camera_angles())

        for idx=1, #enemy_list do
            local ent = enemy_list[idx]
            local ent_wpn = entity.get_player_weapon(ent)

            if ent_wpn then
                local enemy_head = vector(entity.hitbox_position(ent, 2))
                local _, yaw = (stomach_origin-enemy_head):angles()
                local base_diff = math.abs(camera_angles.y-yaw)

                if base_diff < best_yaw then
                    cross_target = ent
                    best_yaw = base_diff
                end
            end
        end

        if not target then
            target = cross_target
        end

        return target and get_side(target) or 'none'
    end


    function player.predict_command(cmd)
        local me = entity.get_local_player()
       
        player.speed = vector(entity.get_prop(me, 'm_vecVelocity')):length()
        
        player.state = get_state()
        player.fs_side = get_fs_side()
        player.defensive = defensive_predict(cmd)
        player.onground = is_onground()
        player.is_fs_peek = is_fs_peek()
        player.duckamount = entity.get_prop(me, 'm_flDuckAmount')
       
        
    end

    function player.setup_command(cmd)
        player.get_players = entity.get_players()
        
        player.crouching = cmd.in_duck == 1
        player.walking = player.speed > 5 and (cmd.in_speed == 1)
    end

    

end 




local ui_handler = {} do
    local group1  = pui.group("AA", "Anti-aimbot angles")
    local fakelag1  = pui.group("AA", "Fake lag")
    local other1  = pui.group("AA", "Other")
    local e_statement1 = {"global","stand","slow-motion","move","crouch","crouch move","air","air crouch","fake lag","on shot","on use","manual","safe head","freestand"}

    local configs = {} do
        configs.import = function(settings)
            assert(clipboard.get() ~= nil, 'Parameter value cannot be empty!')
            --local settings = clipboard.get():match('[%w%+%/]+%=*')
            xpcall(function()
                local parse_data = json.parse(base64.decode(settings))
                ui_handler.configs_da:load(parse_data)
            end, function()
                
            end)
            client.exec("play buttons\\blip2;")
        end
        configs.export = function()
            local settings = ui_handler.configs_da:save()
            local stringify_data = base64.encode(json.stringify(settings))
            clipboard.set(stringify_data)
            client.exec("play buttons\\blip2;")
        end

        local default = "eyJidWlsZGVyIjp7ImZha2UgbGFnIjp7IjEiOjAsIjIiOjAsIjMiOjAsIjQiOjAsIjUiOjAsIjYiOjAsIjciOjAsImVuYWJsZSI6ZmFsc2UsImV4cGFuZCI6Im9mZiIsImVwZF9yaWdodCI6MCwiZXBkX2xlZnQiOjAsInNwZWVkIjoxLCJkZWZfbGVmdCI6MCwiZGVsYXkiOjEsImJhc2UiOiJsb2NhbCB2aWV3IiwiYWRkIjowLCJieV9tb2RlIjoib2ZmIiwiZGVmX3JpZ2h0IjowLCJkZWZfYm9keSI6ImRlZmF1bHQiLCJyb2xsIjowLCJkZWZfc3BlZWQiOjEsImVwZF93YXkiOjAsImJyZWFrX2xjIjpmYWxzZSwiZGVmX3BpdGNoX251bSI6MCwiZGVmX3lhd19udW0iOjAsImJ5X251bSI6MCwiZGVmX3lhdyI6ImRlZmF1bHQiLCJkZWZfcGl0Y2giOiJkZWZhdWx0Iiwid2F5c19tYW51YWwiOmZhbHNlLCJqaXR0ZXJfYWRkIjowLCJkZWZlbnNpdmUiOmZhbHNlLCJ4X3dheSI6Mywiaml0dGVyIjoib2ZmIiwieWF3X3JhbmRvbWl6ZSI6MH0sImFpciBjcm91Y2giOnsiMSI6MCwiMiI6MCwiMyI6MCwiNCI6MCwiNSI6MCwiNiI6MCwiNyI6MCwiZW5hYmxlIjp0cnVlLCJleHBhbmQiOiJvZmYiLCJlcGRfcmlnaHQiOjE4MCwiZXBkX2xlZnQiOi0xODAsInNwZWVkIjozMSwiZGVmX2xlZnQiOi0xODAsImRlbGF5IjoxLCJiYXNlIjoiYXQgdGFyZ2V0cyIsImFkZCI6MCwiYnlfbW9kZSI6InN0YXRpYyIsImRlZl9yaWdodCI6MTgwLCJkZWZfYm9keSI6ImF1dG8iLCJyb2xsIjowLCJkZWZfc3BlZWQiOjI1LCJlcGRfd2F5IjowLCJicmVha19sYyI6dHJ1ZSwiZGVmX3BpdGNoX251bSI6LTksImRlZl95YXdfbnVtIjowLCJieV9udW0iOjE4MCwiZGVmX3lhdyI6InJhbmRvbSBzdGF0aWMiLCJkZWZfcGl0Y2giOiJyYW5kb20gc3RhdGljIiwid2F5c19tYW51YWwiOmZhbHNlLCJqaXR0ZXJfYWRkIjowLCJkZWZlbnNpdmUiOnRydWUsInhfd2F5IjozLCJqaXR0ZXIiOiJvZmYiLCJ5YXdfcmFuZG9taXplIjowfSwib24gc2hvdCI6eyIxIjowLCIyIjowLCIzIjowLCI0IjowLCI1IjowLCI2IjowLCI3IjowLCJlbmFibGUiOmZhbHNlLCJleHBhbmQiOiJvZmYiLCJlcGRfcmlnaHQiOjAsImVwZF9sZWZ0IjowLCJzcGVlZCI6MSwiZGVmX2xlZnQiOjAsImRlbGF5IjoxLCJiYXNlIjoibG9jYWwgdmlldyIsImFkZCI6MCwiYnlfbW9kZSI6Im9mZiIsImRlZl9yaWdodCI6MCwiZGVmX2JvZHkiOiJkZWZhdWx0Iiwicm9sbCI6MCwiZGVmX3NwZWVkIjoxLCJlcGRfd2F5IjowLCJicmVha19sYyI6ZmFsc2UsImRlZl9waXRjaF9udW0iOjAsImRlZl95YXdfbnVtIjowLCJieV9udW0iOjAsImRlZl95YXciOiJkZWZhdWx0IiwiZGVmX3BpdGNoIjoiZGVmYXVsdCIsIndheXNfbWFudWFsIjpmYWxzZSwiaml0dGVyX2FkZCI6MCwiZGVmZW5zaXZlIjpmYWxzZSwieF93YXkiOjMsImppdHRlciI6Im9mZiIsInlhd19yYW5kb21pemUiOjB9LCJmcmVlc3RhbmQiOnsiMSI6MCwiMiI6MCwiMyI6MCwiNCI6MCwiNSI6MCwiNiI6MCwiNyI6MCwiZW5hYmxlIjp0cnVlLCJleHBhbmQiOiJvZmYiLCJlcGRfcmlnaHQiOjAsImVwZF9sZWZ0IjowLCJzcGVlZCI6MSwiZGVmX2xlZnQiOjAsImRlbGF5IjoxLCJiYXNlIjoibG9jYWwgdmlldyIsImFkZCI6MCwiYnlfbW9kZSI6Im9mZiIsImRlZl9yaWdodCI6MCwiZGVmX2JvZHkiOiJhdXRvIiwicm9sbCI6MCwiZGVmX3NwZWVkIjoxLCJlcGRfd2F5IjowLCJicmVha19sYyI6dHJ1ZSwiZGVmX3BpdGNoX251bSI6MCwiZGVmX3lhd19udW0iOjAsImJ5X251bSI6MCwiZGVmX3lhdyI6ImZsaWNrIGV4cGxvaXQiLCJkZWZfcGl0Y2giOiJ1cCBzd2l0Y2giLCJ3YXlzX21hbnVhbCI6ZmFsc2UsImppdHRlcl9hZGQiOjM2LCJkZWZlbnNpdmUiOnRydWUsInhfd2F5IjozLCJqaXR0ZXIiOiJvZmZzZXQiLCJ5YXdfcmFuZG9taXplIjowfSwib24gdXNlIjp7IjEiOjAsIjIiOjAsIjMiOjAsIjQiOjAsIjUiOjAsIjYiOjAsIjciOjAsImVuYWJsZSI6dHJ1ZSwiZXhwYW5kIjoib2ZmIiwiZXBkX3JpZ2h0IjowLCJlcGRfbGVmdCI6MCwic3BlZWQiOjEsImRlZl9sZWZ0IjowLCJkZWxheSI6MSwiYmFzZSI6ImxvY2FsIHZpZXciLCJhZGQiOjAsImJ5X21vZGUiOiJzdGF0aWMiLCJkZWZfcmlnaHQiOjAsImRlZl9ib2R5IjoiZGVmYXVsdCIsInJvbGwiOjAsImRlZl9zcGVlZCI6MSwiZXBkX3dheSI6MCwiYnJlYWtfbGMiOnRydWUsImRlZl9waXRjaF9udW0iOjAsImRlZl95YXdfbnVtIjowLCJieV9udW0iOjE4MCwiZGVmX3lhdyI6ImRlZmF1bHQiLCJkZWZfcGl0Y2giOiJkZWZhdWx0Iiwid2F5c19tYW51YWwiOmZhbHNlLCJqaXR0ZXJfYWRkIjoyMSwiZGVmZW5zaXZlIjpmYWxzZSwieF93YXkiOjMsImppdHRlciI6Im9mZiIsInlhd19yYW5kb21pemUiOjB9LCJzYWZlIGhlYWQiOnsiMSI6MCwiMiI6MCwiMyI6MCwiNCI6MCwiNSI6MCwiNiI6MCwiNyI6MCwiZW5hYmxlIjpmYWxzZSwiZXhwYW5kIjoib2ZmIiwiZXBkX3JpZ2h0IjowLCJlcGRfbGVmdCI6MCwic3BlZWQiOjEsImRlZl9sZWZ0IjowLCJkZWxheSI6MSwiYmFzZSI6ImxvY2FsIHZpZXciLCJhZGQiOjAsImJ5X21vZGUiOiJvZmYiLCJkZWZfcmlnaHQiOjAsImRlZl9ib2R5IjoiZGVmYXVsdCIsInJvbGwiOjAsImRlZl9zcGVlZCI6MSwiZXBkX3dheSI6MCwiYnJlYWtfbGMiOmZhbHNlLCJkZWZfcGl0Y2hfbnVtIjowLCJkZWZfeWF3X251bSI6MCwiYnlfbnVtIjowLCJkZWZfeWF3IjoiZGVmYXVsdCIsImRlZl9waXRjaCI6ImRlZmF1bHQiLCJ3YXlzX21hbnVhbCI6ZmFsc2UsImppdHRlcl9hZGQiOjAsImRlZmVuc2l2ZSI6ZmFsc2UsInhfd2F5IjozLCJqaXR0ZXIiOiJvZmYiLCJ5YXdfcmFuZG9taXplIjowfSwibW92ZSI6eyIxIjowLCIyIjowLCIzIjowLCI0IjowLCI1IjowLCI2IjowLCI3IjowLCJlbmFibGUiOnRydWUsImV4cGFuZCI6ImxlZnRcL3JpZ2h0IiwiZXBkX3JpZ2h0IjoyMywiZXBkX2xlZnQiOi0yMywic3BlZWQiOjEsImRlZl9sZWZ0IjoxODAsImRlbGF5IjoyLCJiYXNlIjoiYXQgdGFyZ2V0cyIsImFkZCI6LTMsImJ5X21vZGUiOiJzdGF0aWMiLCJkZWZfcmlnaHQiOi0xODAsImRlZl9ib2R5IjoiYXV0byIsInJvbGwiOjAsImRlZl9zcGVlZCI6NjQsImVwZF93YXkiOjAsImJyZWFrX2xjIjp0cnVlLCJkZWZfcGl0Y2hfbnVtIjotMzIsImRlZl95YXdfbnVtIjowLCJieV9udW0iOjE4MCwiZGVmX3lhdyI6InNwaW4iLCJkZWZfcGl0Y2giOiJ1cCBzd2l0Y2giLCJ3YXlzX21hbnVhbCI6ZmFsc2UsImppdHRlcl9hZGQiOjE5LCJkZWZlbnNpdmUiOnRydWUsInhfd2F5IjozLCJqaXR0ZXIiOiJvZmYiLCJ5YXdfcmFuZG9taXplIjowfSwibWFudWFsIjp7IjEiOjAsIjIiOjAsIjMiOjAsIjQiOjAsIjUiOjAsIjYiOjAsIjciOjAsImVuYWJsZSI6ZmFsc2UsImV4cGFuZCI6Im9mZiIsImVwZF9yaWdodCI6MCwiZXBkX2xlZnQiOjAsInNwZWVkIjoxLCJkZWZfbGVmdCI6MCwiZGVsYXkiOjEsImJhc2UiOiJsb2NhbCB2aWV3IiwiYWRkIjowLCJieV9tb2RlIjoib2ZmIiwiZGVmX3JpZ2h0IjowLCJkZWZfYm9keSI6ImRlZmF1bHQiLCJyb2xsIjowLCJkZWZfc3BlZWQiOjEsImVwZF93YXkiOjAsImJyZWFrX2xjIjpmYWxzZSwiZGVmX3BpdGNoX251bSI6MCwiZGVmX3lhd19udW0iOjAsImJ5X251bSI6MCwiZGVmX3lhdyI6ImRlZmF1bHQiLCJkZWZfcGl0Y2giOiJkZWZhdWx0Iiwid2F5c19tYW51YWwiOmZhbHNlLCJqaXR0ZXJfYWRkIjowLCJkZWZlbnNpdmUiOmZhbHNlLCJ4X3dheSI6Mywiaml0dGVyIjoib2ZmIiwieWF3X3JhbmRvbWl6ZSI6MH0sImFpciI6eyIxIjotNDgsIjIiOjQ4LCIzIjotNzcsIjQiOjUyLCI1IjotMjIsIjYiOjUyLCI3IjotMjEsImVuYWJsZSI6dHJ1ZSwiZXhwYW5kIjoieC13YXkiLCJlcGRfcmlnaHQiOjkyLCJlcGRfbGVmdCI6LTkwLCJzcGVlZCI6MSwiZGVmX2xlZnQiOi0xODAsImRlbGF5IjoxLCJiYXNlIjoiYXQgdGFyZ2V0cyIsImFkZCI6MCwiYnlfbW9kZSI6ImppdHRlciIsImRlZl9yaWdodCI6MTgwLCJkZWZfYm9keSI6ImF1dG8iLCJyb2xsIjo0NSwiZGVmX3NwZWVkIjoxNSwiZXBkX3dheSI6MTgwLCJicmVha19sYyI6dHJ1ZSwiZGVmX3BpdGNoX251bSI6ODksImRlZl95YXdfbnVtIjowLCJieV9udW0iOjk1LCJkZWZfeWF3Ijoic3BpbiIsImRlZl9waXRjaCI6InJhbmRvbSIsIndheXNfbWFudWFsIjp0cnVlLCJqaXR0ZXJfYWRkIjozOSwiZGVmZW5zaXZlIjp0cnVlLCJ4X3dheSI6Nywiaml0dGVyIjoib2ZmIiwieWF3X3JhbmRvbWl6ZSI6MH0sInNsb3ctbW90aW9uIjp7IjEiOjAsIjIiOjAsIjMiOjAsIjQiOjAsIjUiOjAsIjYiOjAsIjciOjAsImVuYWJsZSI6dHJ1ZSwiZXhwYW5kIjoic3BpbiIsImVwZF9yaWdodCI6ODEsImVwZF9sZWZ0IjotNzksInNwZWVkIjozMCwiZGVmX2xlZnQiOi0xODAsImRlbGF5IjoxLCJiYXNlIjoiYXQgdGFyZ2V0cyIsImFkZCI6MCwiYnlfbW9kZSI6ImppdHRlciIsImRlZl9yaWdodCI6MTgwLCJkZWZfYm9keSI6ImF1dG8iLCJyb2xsIjotNDAsImRlZl9zcGVlZCI6NjQsImVwZF93YXkiOjAsImJyZWFrX2xjIjp0cnVlLCJkZWZfcGl0Y2hfbnVtIjotOCwiZGVmX3lhd19udW0iOjAsImJ5X251bSI6MTgwLCJkZWZfeWF3Ijoic3BpbiIsImRlZl9waXRjaCI6InJhbmRvbSIsIndheXNfbWFudWFsIjpmYWxzZSwiaml0dGVyX2FkZCI6MTcsImRlZmVuc2l2ZSI6dHJ1ZSwieF93YXkiOjMsImppdHRlciI6ImNlbnRlciIsInlhd19yYW5kb21pemUiOjI2fSwic3RhbmQiOnsiMSI6LTg4LCIyIjo4NCwiMyI6LTQ2LCI0IjowLCI1IjowLCI2IjowLCI3IjowLCJlbmFibGUiOnRydWUsImV4cGFuZCI6Ingtd2F5IiwiZXBkX3JpZ2h0IjotMjIsImVwZF9sZWZ0IjozMSwic3BlZWQiOjEsImRlZl9sZWZ0IjotMTgwLCJkZWxheSI6MSwiYmFzZSI6ImF0IHRhcmdldHMiLCJhZGQiOjAsImJ5X21vZGUiOiJqaXR0ZXIiLCJkZWZfcmlnaHQiOjE4MCwiZGVmX2JvZHkiOiJhdXRvIiwicm9sbCI6MCwiZGVmX3NwZWVkIjo2NCwiZXBkX3dheSI6MCwiYnJlYWtfbGMiOnRydWUsImRlZl9waXRjaF9udW0iOjAsImRlZl95YXdfbnVtIjowLCJieV9udW0iOi01OSwiZGVmX3lhdyI6InNwaW4iLCJkZWZfcGl0Y2giOiJyYW5kb20iLCJ3YXlzX21hbnVhbCI6dHJ1ZSwiaml0dGVyX2FkZCI6NzMsImRlZmVuc2l2ZSI6dHJ1ZSwieF93YXkiOjMsImppdHRlciI6ImNlbnRlciIsInlhd19yYW5kb21pemUiOjB9LCJjcm91Y2giOnsiMSI6MCwiMiI6MCwiMyI6MCwiNCI6MCwiNSI6MCwiNiI6MCwiNyI6MCwiZW5hYmxlIjp0cnVlLCJleHBhbmQiOiJsZWZ0XC9yaWdodCIsImVwZF9yaWdodCI6LTIyLCJlcGRfbGVmdCI6MjIsInNwZWVkIjoyOSwiZGVmX2xlZnQiOi0xODAsImRlbGF5Ijo0LCJiYXNlIjoibG9jYWwgdmlldyIsImFkZCI6MCwiYnlfbW9kZSI6Im9wcG9zaXRlIiwiZGVmX3JpZ2h0IjoxODAsImRlZl9ib2R5IjoiYXV0byIsInJvbGwiOi0xLCJkZWZfc3BlZWQiOjEsImVwZF93YXkiOjE4MCwiYnJlYWtfbGMiOnRydWUsImRlZl9waXRjaF9udW0iOi0zOSwiZGVmX3lhd19udW0iOjAsImJ5X251bSI6MTgwLCJkZWZfeWF3IjoiZGVmYXVsdCIsImRlZl9waXRjaCI6Inplcm8iLCJ3YXlzX21hbnVhbCI6ZmFsc2UsImppdHRlcl9hZGQiOjg2LCJkZWZlbnNpdmUiOnRydWUsInhfd2F5Ijo3LCJqaXR0ZXIiOiJjZW50ZXIiLCJ5YXdfcmFuZG9taXplIjoxMDB9LCJjcm91Y2ggbW92ZSI6eyIxIjowLCIyIjowLCIzIjowLCI0IjowLCI1IjowLCI2IjowLCI3IjowLCJlbmFibGUiOnRydWUsImV4cGFuZCI6ImxlZnRcL3JpZ2h0IiwiZXBkX3JpZ2h0IjoyMSwiZXBkX2xlZnQiOi0yMSwic3BlZWQiOjQwLCJkZWZfbGVmdCI6LTE4MCwiZGVsYXkiOjIsImJhc2UiOiJsb2NhbCB2aWV3IiwiYWRkIjowLCJieV9tb2RlIjoiaml0dGVyIiwiZGVmX3JpZ2h0IjoxODAsImRlZl9ib2R5IjoiYXV0byIsInJvbGwiOi0zNCwiZGVmX3NwZWVkIjozMywiZXBkX3dheSI6NTIsImJyZWFrX2xjIjp0cnVlLCJkZWZfcGl0Y2hfbnVtIjowLCJkZWZfeWF3X251bSI6MCwiYnlfbnVtIjoxODAsImRlZl95YXciOiJzaWRld2F5cyIsImRlZl9waXRjaCI6InVwIHN3aXRjaCIsIndheXNfbWFudWFsIjpmYWxzZSwiaml0dGVyX2FkZCI6NDgsImRlZmVuc2l2ZSI6dHJ1ZSwieF93YXkiOjUsImppdHRlciI6Im9mZiIsInlhd19yYW5kb21pemUiOjB9LCJnbG9iYWwiOnsiMSI6MCwiMiI6MCwiMyI6MCwiNCI6MCwiNSI6MCwiNiI6MCwiNyI6MCwiZXhwYW5kIjoib2ZmIiwiZXBkX3JpZ2h0IjowLCJlcGRfbGVmdCI6MCwic3BlZWQiOjEsImRlZl9sZWZ0IjowLCJkZWxheSI6MSwiYnlfbnVtIjowLCJhZGQiOjAsImJ5X21vZGUiOiJvZmYiLCJkZWZfcmlnaHQiOjAsImRlZl9ib2R5IjoiZGVmYXVsdCIsInJvbGwiOjAsImRlZl9zcGVlZCI6MSwiZXBkX3dheSI6MCwiYnJlYWtfbGMiOmZhbHNlLCJkZWZfcGl0Y2hfbnVtIjowLCJkZWZfeWF3X251bSI6MCwiZGVmZW5zaXZlIjpmYWxzZSwiZGVmX3lhdyI6ImRlZmF1bHQiLCJkZWZfcGl0Y2giOiJkZWZhdWx0Iiwid2F5c19tYW51YWwiOmZhbHNlLCJqaXR0ZXJfYWRkIjowLCJiYXNlIjoibG9jYWwgdmlldyIsInhfd2F5IjozLCJqaXR0ZXIiOiJvZmYiLCJ5YXdfcmFuZG9taXplIjowfX0sImNvbmRpdGlvbiI6Im1vdmUiLCJWaXN1YWxzIjp7InNjb3BlX2xpbmVzX2luaXRpYWxfcG9zIjoxOTAsIm1pc3NfY29sb3IiOiIjRkYwMDAwMDEiLCJtYW51YWxfYXJyb3dzX2FjY2VudCI6IiM0RDRENERGRiIsImhpdF9jb2xvciI6IiMwMEY2RkYwMSIsIm1hbnVhbF9vZmZzZXQiOjUwLCJtYW51YWxfYXJyb3dzX2NvbG9yIjoiI0ZGRkZGRkZGIiwiZmFkZV9hbmltYXRpb25fc3BlZWQiOjEyLCJ2ZXJ0aWNhbF9vZmZzZXQiOjM1LCJpbmRpY2F0b3JfY29sb3IiOiIjRkZGRkZGRkYiLCJzY29wZV9saW5lc19jb2xvcl9waWNrZXIiOiIjOEI4OEZGRkYiLCJhbmltYXRpb25fYnJlYWtlciI6WyJ+Il0sImN1c3RvbV9zY29wZSI6dHJ1ZSwib25fYWlyX29wdGlvbnMiOiJmcm96ZW4iLCJvbl9ncm91bmRfb3B0aW9ucyI6ImZyb3plbiIsIm1hbnVhbF9hcnJvd3MiOnRydWUsIm5vdGlmeV9vdXRwdXQiOnRydWUsInNjb3BlX2xpbmVzX29mZnNldCI6MTUsImFpbWJvdF9sb2dzIjp0cnVlLCJyZW5ld2VkX2NvbG9yIjoiIzRENEQ0REZGIiwiaW5kaWNhdG9ycyI6dHJ1ZX0sIm1hbnVhbF9hYV9ob3RrZXkiOnsibWFudWFsX2JhY2siOlsyLDAsIn4iXSwibWFudWFsX2xlZnQiOlsyLDkwLCJ+Il0sIm1hbnVhbF9yaWdodCI6WzIsMCwifiJdLCJtYW51YWxfZm9yd2FyZCI6WzIsMCwifiJdfSwibWlzYyI6eyJhdXRvX2hpZGVzaG90cyI6ZmFsc2UsImZwc19hbHdheXMiOnRydWUsImNsYW50YWciOnRydWUsInBlZWtmaXgiOnRydWUsImV2ZW50X2xvZ2dlciI6dHJ1ZSwiZmlsdGVyIjp0cnVlLCJhdXRvX2hpZGVzaG90c193cG5zIjpbIkRlYWdsZSIsIn4iXSwiZml4X2hpZGVzaG90Ijp0cnVlLCJmcHNfYm9vc3QiOnRydWUsImN1c3RvbV9vdXRwdXQiOnRydWUsImNoYXRfc3BhbW1yZSI6dHJ1ZSwiZnBzX2RldGVjdCI6WyJPbiBQZWVrIiwiSGl0dGFibGUiLCJ+Il0sImZwc19vcHQiOlsiM0QgU2t5IiwiRm9nIiwiU2hhZG93cyIsIkJsb29kIiwiRGVjYWxzIiwiQmxvb20iLCJSYWdkb2xzIiwiRXllIENhbmR5IiwiT3RoZXIiLCJ+Il19LCJhbnRpX2FpbSI6eyJ3YXJtdXBfYWEiOlsifiJdLCJkaXNfZnMiOlsic3RhbmQiLCJzbG93LW1vdGlvbiIsIm1vdmUiLCJjcm91Y2giLCJjcm91Y2ggbW92ZSIsImFpciIsImFpciBjcm91Y2giLCJ+Il0sImFudGlfYnJ1dGVmb3JjZV90eXBlIjoiRWlzaGV0aCIsImFudGlfYmFja3N0YWIiOnRydWUsImVkZ2VfeWF3IjpbMSw2OSwifiJdLCJhbnRpX2JydXRlZm9yY2UiOnRydWUsInRvZ2dsZV9mYWtlbGFnIjpmYWxzZSwic2FmZV9oZWFkIjpbImhlaWdodCBkaXN0YW5jZSIsImhpZ2ggZGlzdGFuY2UiLCJrbmlmZSIsIn4iXSwiZmRfZWRnZSI6dHJ1ZSwibGFkZGVyIjp0cnVlLCJmcmVlc3RhbmRpbmciOlsxLDQsIn4iXSwiZGVmZW5zaXZlIjpbImRhbWFnZSByZWNlaXZlZCIsIndlYXBvbiBzd2l0Y2giLCJ+Il0sInVzZV9hYSI6dHJ1ZSwibWFudWFsX2FhIjpmYWxzZX0sImFpbXRvb2xzIjp7InByb19zcHJlYWQiOlsxLDAsIn4iXSwianVtcF9zY291dCI6WzEsMCwifiJdLCJjdXN0b21fcmVzb2x2ZXIiOnRydWV9LCJuYXZpZ2F0aW9uIjp7ImFhX2NvbWJvIjoiYnVpbGRlciIsIm9wdGlvbnMiOiJIb21lIn19"
        configs.default = function()
            local parse_data = json.parse(base64.decode(default))
            ui_handler.configs_da:load(parse_data)
            client.exec("play buttons\\blip2;")
    
			
        end
    end

local function load_and_fade_image()
    local image_url = "http://a1147355.xsph.ru/loaderassets/00968B3E-1F27-4B74-87C6-CED8261C26022C.png"

    http.get(image_url, function(success, response)
        if not success or response.status ~= 200 then return end

        local js_code = [[
            let image_panel = $.CreatePanel('Panel', $.GetContextPanel(), 'ImagePanel');
            image_panel.style.width = '100%';
            image_panel.style.height = '100%';
            image_panel.style.backgroundColor = 'rgba(0, 0, 0, 0)';
            image_panel.style.align = 'center center';
            image_panel.style.verticalAlign = 'center';
            image_panel.style.flowChildren = 'down';
            image_panel.SetDraggable(true);

            let top_label = $.CreatePanel('Label', image_panel, 'TopText');
            top_label.text = 'powered by kocmoc';
            top_label.style.fontSize = '18px';
            top_label.style.fontWeight = 'bold';
            top_label.style.fontFamily = 'Arial, sans-serif';
            top_label.style.color = 'red';
            top_label.style.align = 'center center';
            top_label.style.marginBottom = '8px';
            top_label.style.opacity = '0';

            let image = $.CreatePanel('Image', image_panel, 'MyImage');
            image.SetImage(']] .. image_url .. [[');
            image.style.width = '600px';
            image.style.height = '850px';
            image.style.align = 'center center';
            image.style.verticalAlign = 'center';
            image.style.opacity = '0';
            image.style.marginBottom = '12px';

            let spinner_container = $.CreatePanel('Panel', image_panel, 'SpinnerContainer');
            spinner_container.style.width = '40px';
            spinner_container.style.height = '40px';
            spinner_container.style.borderRadius = '50%';
            spinner_container.style.align = 'center center';
            spinner_container.style.opacity = '0';
            spinner_container.style.overflow = 'noclip';
            spinner_container.rotation = 0;

            let dot = $.CreatePanel('Panel', spinner_container, 'RedDot');
            dot.style.width = '6px';
            dot.style.height = '16px';
            dot.style.borderRadius = '3px';
            dot.style.backgroundColor = 'red';
            dot.style.position = '0px 12px 0px';

            let bottom_label = $.CreatePanel('Label', image_panel, 'BottomText');
            bottom_label.text = 'AimSense Interpolation';
            bottom_label.style.fontSize = '24px';
            bottom_label.style.fontWeight = 'bold';
            bottom_label.style.fontFamily = 'Arial, sans-serif';
            bottom_label.style.color = 'red';
            bottom_label.style.align = 'center center';
            bottom_label.style.marginTop = '10px';
            bottom_label.style.opacity = '0';

            let discord_label = $.CreatePanel('Label', image_panel, 'DiscordText');
            discord_label.text = 'discord.gg/aimsense';
            discord_label.style.fontSize = '16px';
            discord_label.style.fontWeight = 'normal';
            discord_label.style.fontFamily = 'Arial, sans-serif';
            discord_label.style.color = '#CCCCCC';
            discord_label.style.align = 'center center';
            discord_label.style.marginTop = '4px';
            discord_label.style.opacity = '0';

            function rotate_spinner() {
                if (!spinner_container || !spinner_container.IsValid()) return;
                spinner_container.rotation += 6;
                if (spinner_container.rotation >= 360) spinner_container.rotation = 0;
                spinner_container.style.transform = 'rotateZ(' + spinner_container.rotation + 'deg)';
                $.Schedule(0.03, rotate_spinner);
            }

            function animate_label_color() {
                if (!bottom_label || !bottom_label.IsValid()) return;
                let colors = ['red', 'white'];
                let index = 0;
                function loop() {
                    if (!bottom_label || !bottom_label.IsValid()) return;
                    bottom_label.style.color = colors[index];
                    index = (index + 1) % colors.length;
                    $.Schedule(0.6, loop);
                }
                loop();
            }

            function spawn_snowflake() {
                let flake = $.CreatePanel('Panel', image_panel, '');
                flake.style.width = '4px';
                flake.style.height = '4px';
                flake.style.borderRadius = '50%';
                flake.style.backgroundColor = 'white';
                flake.style.position = Math.floor(Math.random() * 100) + '% -10px 0';
                flake.style.zIndex = '1000';
                let x = Math.floor(Math.random() * 100);
                let y = -10;
                let speed = 1 + Math.random() * 2;

                function fall() {
                    if (!flake || !flake.IsValid()) return;
                    y += speed;
                    flake.style.position = x + '% ' + y + 'px 0';
                    if (y < 1000) {
                        $.Schedule(0.03, fall);
                    } else {
                        flake.DeleteAsync(0.0);
                    }
                }
                fall();
            }

            function snow_loop() {
                spawn_snowflake();
                $.Schedule(0.1, snow_loop);
            }

            function fade_in() {
                let steps = 20;
                let duration = 0.5;
                let interval = duration / steps;
                let step = 0;
                function update() {
                    if (step <= steps && image.IsValid()) {
                        let opacity = step / steps;
                        image.style.opacity = opacity.toString();
                        top_label.style.opacity = opacity.toString();
                        spinner_container.style.opacity = opacity.toString();
                        bottom_label.style.opacity = opacity.toString();
                        discord_label.style.opacity = opacity.toString();
                        image_panel.style.backgroundColor = 'rgba(0, 0, 0, ' + (opacity * 0.7).toFixed(2) + ')';
                        step++;
                        if (step <= steps) {
                            $.Schedule(interval, update);
                        }
                    }
                }
                update();
                rotate_spinner();
                animate_label_color();
                snow_loop();
            }

            function fade_out() {
                let steps = 20;
                let duration = 0.5;
                let interval = duration / steps;
                let step = 0;
                function update() {
                    if (step <= steps && image.IsValid()) {
                        let opacity = 1 - (step / steps);
                        image.style.opacity = opacity.toString();
                        top_label.style.opacity = opacity.toString();
                        spinner_container.style.opacity = opacity.toString();
                        bottom_label.style.opacity = opacity.toString();
                        discord_label.style.opacity = opacity.toString();
                        image_panel.style.backgroundColor = 'rgba(0, 0, 0, ' + (opacity * 0.7).toFixed(2) + ')';
                        step++;
                        if (step <= steps) {
                            $.Schedule(interval, update);
                        } else {
                            if (image_panel.IsValid()) {
                                image_panel.DeleteAsync(0.0);
                            }
                        }
                    }
                }
                update();
            }

            fade_in();
            $.Schedule(6.0, function() {
                if (image_panel.IsValid()) {
                    fade_out();
                }
            });
        ]]

        panorama.loadstring(js_code, "CSGOMainMenu")()
    end)
end

load_and_fade_image()


local function get_steam_name()
    local player = entity.get_local_player()
    if player and player ~= 0 then
        local name = entity.get_player_name(player)
        if name and #name > 0 then
            return name
        end
    end
    return "Unknown"
end

local miss_count = 0

-- Отслеживаем выстрелы
client.set_event_callback("shot", function(bullet)
    if bullet.attacker == client.userid_to_entindex(client.get_local_player()) then
        if bullet.hitgroup == 0 then -- hitgroup 0 — мисс
            miss_count = miss_count + 1
        end
    end
end)

-- Функция для обновления label
local function update_miss_label()
    if ui_handler.navigation and ui_handler.navigation.defaultl then
        ui_handler.navigation.default:set(string.format("\aff0000FF \r Session Time: " .. formatted_time))
    end
end

-- Подписываемся на paint
client.set_event_callback("paint", update_miss_label)

    ui_handler.navigation  = {} do
		
		ui_handler.navigation.options = group1:combobox("\ntab", { " Welcome", ' Aimtool$', ' Anti-aim', " Visuals", " Miscellaneous", " { Menu Addons }"})

        local steam_name = get_steam_name()
        ui_handler.navigation.label = fakelag1:label("\a333333FF‾‾‾‾‾‾‾‾‾‾‾‾‾")
        ui_handler.navigation.label = fakelag1:label("\aff0000FF \rDumped by - pseylashda & byte.tech staff")
		ui_handler.navigation.label = fakelag1:label(("\aff0000FF \rWelcome back, DUMPED"):format(steam_name))
        ui_handler.navigation.label = fakelag1:label("\aff0000FF \rStatus Server: DUMPED")
		ui_handler.navigation.label = fakelag1:label("\a333333FF‾‾‾‾‾‾‾‾‾‾‾‾‾")
        ui_handler.navigation.label = fakelag1:label("\r")
        
		ui_handler.navigation.labe1l = group1:label("\aff0000FF\r")
		ui_handler.navigation.aa_combo = group1:combobox('\n', { "features", "builder" }):depend({ ui_handler.navigation.options, ' Anti-aim' })
		
        ui_handler.navigation.labe12 = other1:label("\aff0000FF TIP: \rShare your config or import")
        ui_handler.navigation.import = other1:button("\aff0000FF\r Import", function() configs.import(clipboard.get():match('[%w%+%/]+%=*')) end)
        ui_handler.navigation.export = other1:button("\aff0000FF\r Export", function() configs.export() end)
        ui_handler.navigation.default = other1:button("\aff0000FF\r Default", function() configs.default() end)
        ui_handler.navigation.default = other1:label("\a333333FF‾‾‾‾‾‾‾‾‾‾‾‾‾")
        ui_handler.navigation.default = other1:button("\aff0000FF\r Connect to Chill&Frag", function() client.exec"connect 46.174.51.234:27015" end)
        ui_handler.navigation.default = other1:button("\aff0000FF\r Gamesense Features fix", function()  end)
        ui_handler.navigation.labe12 = other1:label("\aff0000FF TIP: \rHas normal ping for Aimsense!")
        ui_handler.navigation.default = group1:label("\aff0000FF \r Information:\r "):depend({ui_handler.navigation.options, ' Welcome'})
        ui_handler.navigation.default = group1:label("\a333333FF‾‾‾‾‾‾‾‾‾‾‾‾‾"):depend({ui_handler.navigation.options, ' Welcome'})
        ui_handler.navigation.default = group1:label("\aff0000FF \r Build: \aff0000FFDebug"):depend({ui_handler.navigation.options, ' Welcome'})
        ui_handler.navigation.default = group1:label("\aff0000FF \r Version: 1.1"):depend({ui_handler.navigation.options, ' Welcome'})
        ui_handler.navigation.default = group1:label("\aff0000FF \r Last Update: 31.07.2025"):depend({ui_handler.navigation.options, ' Welcome'})
        ui_handler.navigation.default = group1:label("\aff0000FF \r Session Time: " .. formatted_time):depend({ui_handler.navigation.options, ' Welcome'})
        ui_handler.navigation.default = group1:label("\a333333FF‾‾‾‾‾‾‾‾‾‾‾‾‾"):depend({ui_handler.navigation.options, ' Welcome'})
		
    end

    ui_handler.aimtools = {} do
        ui_handler.aimtools.accuracy_exploit =  group1:multiselect("\aff0000FF\r Accuracy Exploit",{"no delay", "improve head", ""})
        ui_handler.aimtools.track_exploit =  group1:multiselect("\aff0000FF\r Extend Backtrack",{"12 tick", "24 tick", "32 tick",})
        ui_handler.aimtools.jump_scout =  group1:hotkey("\aff0000FF\r JumpScout")
        ui_handler.aimtools.improve_hitboxes =  group1:checkbox("\aff0000FF\r Improve hitboxes")
        ui_handler.aimtools.fake =  group1:label("\aff0000FF —————————————————— \r")
        ui_handler.aimtools.notice =  group1:label("\aff0000FF TIP:\r Dont use Extend")
        ui_handler.aimtools.notice2 =  group1:label("\aff0000FF TIP:\r Backtrack with Accuracy Exploit")
        ui_handler.aimtools.fake4 =  group1:label("\aff0000FF —————————————————— \r")
        ui_handler.aimtools.predict_bartik =  group1:checkbox("\aff0000FF\r Bartik ~ Tweaks\r")
        ui_handler.aimtools.hitboxespredict =  group1:multiselect("\aff0000FF\r Predict Hitboxes",{"Head", "Chest", "Stomach", "Arms",})
        ui_handler.aimtools.predict_tick = group1:slider("\aff0000FF\r Delay\n", 0, 12, 0, true)
        ui_handler.aimtools.fake5 =  group1:label("\aff0000FF —————————————————— \r")
        ui_handler.aimtools.predict_kelvin =  group1:checkbox("\aff0000FF\r Kelvin ~ Tweaks\r")
        ui_handler.aimtools.dormantaim =  group1:hotkey("\aff0000FF\r Dormant Aimbot \r")
        ui_handler.aimtools.resolver =  group1:checkbox("\aff0000FF\r Custom Resolver BETA \r")
        ui_handler.aimtools.fake6 =  group1:label("\aff0000FF —————————————————— \r")
        ui_handler.aimtools.texploit =  group1:checkbox("\aff0000FF\r Lag Exploit\r")
        ui_handler.aimtools.slowaa = group1:checkbox("\aff0000FF\r Aggresive Mode \r")


local last_state = nil

client.set_event_callback("paint_ui", function()
    local state = ui_handler.aimtools.predict_bartik:get()
    if state == last_state then return end -- не менялось, выходим
    last_state = state

    local refs = {
        ui_handler.aimtools.predict_tick,
        ui_handler.aimtools.hitboxespredict
    }

    for _, ref in ipairs(refs) do
        if ref and ref.set_visible then
            ref:set_visible(state)
        end
    end
end)

local last_state = nil

client.set_event_callback("paint_ui", function()
    local state = ui_handler.aimtools.predict_kelvin:get()
    if state == last_state then return end -- не менялось, выходим
    last_state = state

    local refs = {
        ui_handler.aimtools.dormantaim,
        ui_handler.aimtools.resolver
    }

    for _, ref in ipairs(refs) do
        if ref and ref.set_visible then
            ref:set_visible(state)
        end
    end
end)


        for _, v in pairs(ui_handler.aimtools) do
            v:depend({ ui_handler.navigation.options, ' Aimtool$' })
        end
    end

    ui_handler.anti_aim = {} do
        ui_handler.anti_aim.edge_yaw = group1:hotkey("\aff0000FF⁜\r Edge yaw")
        ui_handler.anti_aim.use_aa = group1:checkbox("\aff0000FF⁜\r Edge Anti-Aim")
        ui_handler.anti_aim.anti_backstab = group1:checkbox("\aff0000FF⁜\r Avoid backstab")
        ui_handler.anti_aim.fd_edge = group1:checkbox("\aff0000FF⁜\r Edge Fakeduck")
        ui_handler.anti_aim.ladder = group1:checkbox("\aff0000FF⁜\r Fast ladder")
		ui_handler.anti_aim.freestanding = group1:hotkey("\aff0000FF⁜\r Freestanding")
        ui_handler.anti_aim.dis_fs = group1:multiselect("\nignore_freestand",{"stand","slow-motion","move","crouch","crouch move","air","air crouch"})
		ui_handler.anti_aim.anti_bruteforce = group1:checkbox("\aff0000FF⁜\r Anti-Bruteforce")
        ui_handler.anti_aim.anti_bruteforce_type = group1:combobox("\nanti_bruteforce_type","Lilith","Eisheth"):depend({ ui_handler.anti_aim.anti_bruteforce, true})
        ui_handler.anti_aim.defensive = group1:multiselect("\aff0000FF⁜\r Use Defensive",{"on shot","flashed","damage received","reloading","weapon switch"})
        ui_handler.anti_aim.safe_head = group1:multiselect("\aff0000FF⁜\r Safe Head",{ "height distance", "high distance", "knife", "zeus", })
        ui_handler.anti_aim.warmup_aa = group1:multiselect("\aff0000FF⁜\r Warmup AA",{"warmup","round end"})
        ui_handler.anti_aim.manual_aa = group1:checkbox("\aff0000FF⁜\r  Manual AA")
		ui_handler.anti_aim.toggle_fakelag = group1:checkbox("\aff0000FF⁜\r Enable Fakelag")
        ui_handler.anti_aim.yaw_exploit = group1:checkbox("\aff0000FF⁜\r Yaw exploit")
        for _, v in pairs(ui_handler.anti_aim) do
            v:depend({ ui_handler.navigation.options, ' Anti-aim' }, { ui_handler.navigation.aa_combo, "features" })
        end
    end

    ui_handler.manual_aa_hotkey = {} do
        ui_handler.manual_aa_hotkey.manual_left = group1:hotkey("\aff0000FF⁜\r Manual left")
        ui_handler.manual_aa_hotkey.manual_right = group1:hotkey("\aff0000FF⁜\r Manual right")
        ui_handler.manual_aa_hotkey.manual_forward = group1:hotkey("\aff0000FF⁜\r Manual forward")
        ui_handler.manual_aa_hotkey.manual_back = group1:hotkey("\aff0000FF⁜\r Manual reset")
        for _, v in pairs(ui_handler.manual_aa_hotkey) do
            v:depend({ ui_handler.navigation.options, ' Anti-aim'  }, { ui_handler.anti_aim.manual_aa, true },{ui_handler.navigation.aa_combo, "features"})
        end
    end

    ui_handler.builder , ui_handler.way_manual = {} , {} do
        ui_handler.condition = group1:combobox("\ncondition", e_statement1):depend({ ui_handler.navigation.options, ' Anti-aim'  }, { ui_handler.navigation.aa_combo, "builder" })

        local tooltips  = {delay = { [1] = "Off", [2] = "BEST",[5] = "RS",[10] = "SW" },roll = { [-40] = "MAX", [0] = "Off", [40] = "MAX" },body = { [-120] = "BEST", [0] = "Off", [120] = "BEST" },}
        for _, state in ipairs(e_statement1) do
            ui_handler.builder[state] = {}
            local this = ui_handler.builder[state]
            if state ~= "global" then
                this.enable = group1:checkbox('\aff0000FF⁜\r Enable\n'..state, false)
            end
            this.base = group1:combobox("\aff0000FF⁜\r  Base\n"..state, {"local view", "at targets"})
            this.add = group1:slider("\aff0000FF⁜\r  Yaw\n"..state, -180, 180, 0, true, "°", 1)
            this.expand = group1:combobox("\aff0000FF⁜\r  Expand\n"..state,{ "off", "left/right","x-way","spin"})

            this.epd_left = group1:slider("\aff0000FF⁜\r  Left \n" .. state, -180, 180, 0, true, "°", 1):depend({this.expand,"x-way",true},{this.expand,"off",true})
            this.epd_right = group1:slider("\aff0000FF⁜\r  Right \n" .. state, -180, 180, 0, true, "°", 1):depend({this.expand,"x-way",true},{this.expand,"off",true})
            this.delay = group1:slider("\aff0000FF⁜\r  \aCDCDCD60Delay\n" .. state, 1, 10, 0, true, "t", 1, tooltips.delay):depend({this.expand,"left/right"})
            this.speed = group1:slider("\aff0000FF⁜\r  \aCDCDCD60Speed\n" .. state, 1, 64, 1, true, "t", 1):depend({this.expand,"spin"})

            this.ways_manual = group1:checkbox('\aff0000FF⁜\r  Ways manual\n'..state, false):depend({ this.expand, "x-way" })
            this.x_way = group1:slider("\aff0000FF⁜\r  total \n" .. state, 3, 7, 3, true, "-w"):depend({ this.expand, "x-way" })
            this.x_waylabel = group1:label("\aff0000FF⁜\r  Way"):depend({this.expand,"x-way"}, {this.ways_manual,true})

            
            this.x_way:set_callback(function (ctx) this.x_waylabel:set("\aff0000FF⁜\r  Way \aCDCDCD60" .. ctx.value) end, true)
            this.epd_way = group1:slider("\aff0000FF⁜\r  Way\n" .. state, -180, 180, 0, true, "°", 1):depend({this.expand,"x-way"}, {this.ways_manual,false})
            for w = 1, 7 do
                this[w] = group1:slider("\n"..w..state, -180, 180, 0, true, "°", 1, {[0] = "R"}):depend({this.expand, "x-way"}, this.ways_manual, {this.x_way, w, 7})
            end
            this.jitter = group1:combobox("\aff0000FF⁜\r  Modifier\n" .. state,{ "off", "offset", "center", "random"})
            this.jitter_add = group1:slider("\nyaw_jitter_add " .. state, -180, 180, 0, true,"°"):depend({this.jitter,"off",true})

            this.yaw_randomize = group1:slider('\aff0000FF⁜\r  Randomization \n' .. state, 0, 100, 0, 0, '%', 1, {[0] = "Off"})



            this.by_mode = group1:combobox("\aff0000FF⁜\r  Body\n" .. state,{ "off", "static", "opposite", "jitter" })
            this.by_num = group1:slider("\aff0000FF⁜\r  \aCDCDCD60num\n" .. state, -180, 180, 0, true, "°", 1, tooltips.body):depend({ this.by_mode, "off", true }, { this.by_mode, "opposite", true })
            this.roll = group1:slider("\aff0000FF⁜\r  \aCDCDCD60roll\n" .. state, -45, 45, 0, true, "°", 1, tooltips.roll)
            this.break_lc = group1:checkbox("\aff0000FF⁜\r  Break LC\n" .. state)
            this.defensive = group1:checkbox("\aff0000FF⁜\r  Force Defensive\n" .. state)

            this.def_pitch = group1:combobox("\aff0000FF⁜\r  Picth\n defensive" .. state,{ "default", "up", "zero", "up switch","down switch", "random static","random","custom"}):depend({this.defensive,true})
            this.def_pitch_num = group1:slider("\aff0000FF⁜\r  \aCDCDCD60num\n Picth defensive" .. state, -89, 89, 0, true, "°", 1):depend({this.defensive,true},{this.def_pitch,"custom"})

            this.def_yaw = group1:combobox("\aff0000FF⁜\r  Yaw\n defensive" .. state,{ "default", "forward", "sideways", "delayed","spin","random", "random static","flick exploit","custom",}):depend({this.defensive,true})
            this.def_left = group1:slider("\aff0000FF⁜\r  \aCDCDCD60left\n Yaw defensive" .. state, -180, 180, 0, true, "°", 1):depend({this.defensive,true},{this.def_yaw, function()
                return  this.def_yaw:get() == "delayed" or  this.def_yaw:get() == "spin" or  this.def_yaw:get() == "random" or  this.def_yaw:get() == "random static"
            end})
            this.def_right = group1:slider("\aff0000FF⁜\r  \aCDCDCD60right\n Yaw defensive" .. state, -180, 180, 0, true, "°", 1):depend({this.defensive,true},{this.def_yaw, function()
                return  this.def_yaw:get() == "delayed" or  this.def_yaw:get() == "spin" or  this.def_yaw:get() == "random" or  this.def_yaw:get() == "random static"
            end})
            this.def_speed = group1:slider("\aff0000FF⁜\r  \aCDCDCD60speed\n Yaw defensive" .. state, 1, 64, 1, true, "t", 1):depend({this.defensive,true},{this.def_yaw, "spin" })
            this.def_yaw_num = group1:slider("\aff0000FF⁜\r  \aCDCDCD60num\n Yaw defensive" .. state, -180, 180, 0, true, "°", 1):depend({this.defensive,true},{this.def_yaw,"custom"})
            this.def_body = group1:combobox("\aff0000FF⁜\r  Body\n Defensive" .. state,{ "default", "auto", "jitter"}):depend({this.defensive,true})

            for _, v in pairs(this) do
                local arr = { { ui_handler.navigation.options, ' Anti-aim' }, { ui_handler.navigation.aa_combo, "builder" }, { ui_handler.condition, state } }
                if _ ~= "enable" and state ~= "global" then
                    arr = { { ui_handler.navigation.options, ' Anti-aim' }, { ui_handler.navigation.aa_combo, "builder" }, { ui_handler.condition, state }, { this.enable, true } }
                end
                v:depend(table.unpack(arr))
            end
        end
    end

    ui_handler.Visuals = {} do
		ui_handler.Visuals.aimbot_logs =  group1:checkbox("\aff0000FF\r HitLogs")
		ui_handler.Visuals.notify_output =  group1:checkbox("\aff0000FF\r Notify Color")
		ui_handler.Visuals.hit_color_label =  group1:label("\aff0000FF\r Hit color")
		ui_handler.Visuals.hit_color =  group1:color_picker("\aff0000FF\r Hit color", 255, 255, 255, 1)
		ui_handler.Visuals.miss_color_label =  group1:label("\aff0000FF⁜r Miss color")
		ui_handler.Visuals.miss_color =  group1:color_picker("\aff0000FF\r Miss color", 255, 255, 255, 1)
        ui_handler.Visuals.indicators =  group1:checkbox("\aff0000FF\r Indicators")
        ui_handler.Visuals.vertical_offset = group1:slider("\aff0000FF\r  \aCDCDCD60offset\n indicators", 20, 100, 10, true, "px"):depend({ui_handler.Visuals.indicators, true})
        ui_handler.Visuals.indicator_color = group1:color_picker("\nindicator_colordsadsa", 255, 255, 255, 255):depend({ui_handler.Visuals.indicators, true})
        ui_handler.Visuals.renewed_color = group1:color_picker("\nindicator Reneweddsadsa", 77, 77, 77, 255):depend({ui_handler.Visuals.indicators, true})
        ui_handler.Visuals.manual_arrows =  group1:checkbox("\aff0000FF\r Manual Indicator")  
        ui_handler.Visuals.manual_offset = group1:slider("\aff0000FF\r  \aCDCDCD60offset\n manual", 10, 100, 50, true, "px"):depend({ui_handler.Visuals.manual_arrows, true})
        ui_handler.Visuals.manual_arrows_color = group1:color_picker("\nmanual_arrowsdsadsadsa", 255, 255, 255, 255):depend({ui_handler.Visuals.manual_arrows, true})
        ui_handler.Visuals.manual_arrows_accent = group1:color_picker("\nmanual_arrows_Accentfdafdas", 77, 77, 77, 255):depend({ui_handler.Visuals.manual_arrows, true})
        ui_handler.Visuals.animation_breaker = group1:multiselect("\aff0000FF\r Animation breaker",{"zero on land","earthquake","sliding slow motion","sliding crouch","on ground","aerobic","quick peek legs"})
        ui_handler.Visuals.on_ground_options = group1:combobox("\aff0000FF\r  on ground", {"frozen", "walking","jitter","sliding","swag"}):depend({ ui_handler.Visuals.animation_breaker, "on ground" })
        ui_handler.Visuals.on_air_options = group1:combobox("\aff0000FF\r  aerobic", {"frozen", "walking", "swag" }):depend({ui_handler.Visuals.animation_breaker, "aerobic" })
        ui_handler.Visuals = ui_handler.Visuals or {}
        ui_handler.Visuals.fake1 =  group1:label("\aff0000FF —————————————————— \r")
        ui_handler.Visuals.custom_scope = group1:checkbox("\aff0000FF\r Custom Scope")
        ui_handler.Visuals.scope_lines_color_picker = group1:color_picker("\aff0000FF\r Color", 255, 255, 255, 255)
        ui_handler.Visuals.scope_lines_initial_pos = group1:slider("\aff0000FF\r Initial position", 0, 500, 190)
        ui_handler.Visuals.scope_lines_offset = group1:slider("\aff0000FF\r Offset", 0, 500, 15)
        ui_handler.Visuals.fade_animation_speed = group1:slider("\aff0000FF\r Fade animation speed", 3, 20, 12)
        ui_handler.Visuals.fake3 =  group1:label("\aff0000FF —————————————————— \r")
        ui_handler.Visuals.aspect_ratio = group1:slider("\aff0000FF\r Aspect ratio", 1, 199, 100, true, "%", 0.01, aspect_ratio_table)
        ui_handler.Visuals.fake2 =  group1:label("\aff0000FF —————————————————— \r")
        ui_handler.Visuals.customindicators = group1:checkbox("\aff0000FF \r Custom Indicators")
        ui_handler.Visuals.fake =  group1:label("\aff0000FF \r Disable Skeet Indicators Manually")

-- Обновление видимости
local last_state = nil

client.set_event_callback("paint_ui", function()
    local state = ui_handler.Visuals.custom_scope:get()
    if state == last_state then return end -- не менялось, выходим
    last_state = state

    local refs = {
        ui_handler.Visuals.scope_lines_color_picker,
        ui_handler.Visuals.scope_lines_initial_pos,
        ui_handler.Visuals.scope_lines_offset,
        ui_handler.Visuals.fade_animation_speed
    }

    for _, ref in ipairs(refs) do
        if ref and ref.set_visible then
            ref:set_visible(state)
        end
    end
end)


          
		
		ui_handler.Visuals.notify_output:depend({ ui_handler.Visuals.aimbot_logs, true })
        ui_handler.Visuals.hit_color_label:depend({ ui_handler.Visuals.aimbot_logs, true }, { ui_handler.Visuals.notify_output, true })
        ui_handler.Visuals.miss_color_label:depend({ ui_handler.Visuals.aimbot_logs, true }, { ui_handler.Visuals.notify_output, true })
        ui_handler.Visuals.hit_color:depend({ ui_handler.Visuals.aimbot_logs, true }, { ui_handler.Visuals.notify_output, true })
        ui_handler.Visuals.miss_color:depend({ ui_handler.Visuals.aimbot_logs, true }, { ui_handler.Visuals.notify_output, true })

        for _, v in pairs(ui_handler.Visuals) do
            v:depend({ ui_handler.navigation.options, ' Visuals' })
        end

    end

    ui_handler.indicators = {} do
        ui_handler.indicators.bartiks = group1:checkbox("\aff0000FF\r Gamesense Customize")
        ui_handler.indicators.fakebartik = group1:label("\r")
        ui_handler.indicators.dpiscale = group1:combobox("\aff0000FF\r DPI Scale", {"100%", "125%", "150%", "175%" })

        local last_state = nil

client.set_event_callback("paint_ui", function()
    local state = ui_handler.indicators.bartiks:get()
    if state == last_state then return end 
    last_state = state

    local refs = {
        ui_handler.indicators.fakebartik, -- сюда добавляем новые уи
        ui_handler.indicators.dpiscale 
    }

    for _, ref in ipairs(refs) do
        if ref and ref.set_visible then
            ref:set_visible(state)
        end
    end
end)
        
        for _, v in pairs(ui_handler.indicators) do
            v:depend({ ui_handler.navigation.options, ' { Menu Addons }' })
        end
    
   end 
    

    ui_handler.misc = {} do
        ui_handler.misc.clantag = group1:checkbox("\aff0000FF⁜\r Clan tag Spammer")
        ui_handler.misc.chat_spammre = group1:checkbox('\aff0000FF⁜\r TrashTalk')
		ui_handler.misc.fps_boost = group1:checkbox('\aff0000FF⁜\r Fps Boost')
		ui_handler.misc.fps_always = group1:checkbox('\aff0000FF⁜\r Remove Particles/Shaders')
		ui_handler.misc.fps_detect = group1:multiselect('\aff0000FF⁜\r  detections', {'On Peek', 'Hittable'})
		ui_handler.misc.fps_opt = group1:multiselect('\aff0000FF⁜\r  select', {'3D Sky', 'Fog', 'Shadows', 'Blood', 'Decals', 'Bloom', 'Ragdols', 'Eye Candy', 'Molotov', 'Other'})
        -- ui_handler.misc.custom_output =  group1:checkbox("\aff0000FF⁜\r scale dpi") 
        ui_handler.misc.event_logger =  group1:checkbox("\aff0000FF⁜\r Console logs") 
        ui_handler.misc.filter = group1:checkbox('\aff0000FF⁜\r Console Filter')
        ui_handler.misc.auto_hideshots = group1:checkbox("\aff0000FF⁜\r Automatic ")
        ui_handler.misc.auto_hideshots_wpns = group1:multiselect("\nAutomatic Hideshot Weapons",{ "Pistols", "Deagle" }):depend({ ui_handler.misc.auto_hideshots, true })
        ui_handler.misc.cvar = group1:checkbox("\aff0000FF⁜\r Unlock All CVars")
		ui_handler.misc.prospread = group1:checkbox("\aff0000FF⁜\r ProSpread ")
		ui_handler.misc.fps_always:depend({ui_handler.misc.fps_boost, true})
		ui_handler.misc.fps_detect:depend({ui_handler.misc.fps_boost, true}, {ui_handler.misc.fps_always, false})
		ui_handler.misc.fps_opt:depend({ui_handler.misc.fps_boost, true})

        for _, v in pairs(ui_handler.misc) do
            v:depend({ ui_handler.navigation.options, ' Miscellaneous' })
        end
    end    
end 
  
    ui_handler.configs_da = pui.setup(ui_handler)
  

local anti_aim = {} do

    anti_aim.features = {} do

        anti_aim.features.use_aa = false
        anti_aim.features.stab = false
        anti_aim.features.fast_ladder = false
        anti_aim.features.safe_head = false
        anti_aim.features.manual = 0.0
        anti_aim.features.defensive = false
        anti_aim.features.warmup_aa = false

        anti_aim.features.legit_antiaim = {} do
            local start_time = globals.realtime()

            function anti_aim.features.legit_antiaim.run(cmd)
                
                if not ui_handler.anti_aim.use_aa:get() then
                    return false
                end
    
                if cmd.in_use == 0 then
                    start_time = globals.realtime()
                    return
                end
    
                local player = entity.get_local_player()
    
                if player == nil then
                    return
                end
    
                local player_origin = { entity.get_origin(player) }
    
                local CPlantedC4 = entity.get_all('CPlantedC4')
                local dist_to_bomb = 999
    
                if #CPlantedC4 > 0 then
                    local bomb = CPlantedC4[1]
                    local bomb_origin = { entity.get_origin(bomb) }
    
                    dist_to_bomb = vector(player_origin[1], player_origin[2], player_origin[3]):dist(vector(bomb_origin[1],
                        bomb_origin[2], bomb_origin[3]))
                end
    
                local CHostage = entity.get_all('CHostage')
                local dist_to_hostage = 999
    
                if CHostage ~= nil then
                    if #CHostage > 0 then
                        local hostage_origin = { entity.get_origin(CHostage[1]) }
    
                        dist_to_hostage = math.min(
                            vector(player_origin[1], player_origin[2], player_origin[3]):dist(vector(hostage_origin[1],
                                hostage_origin[2], hostage_origin[3])),
                            vector(player_origin[1], player_origin[2], player_origin[3]):dist(vector(hostage_origin[1],
                                hostage_origin[2], hostage_origin[3])))
                    end
                end
    
                if dist_to_hostage < 65 and entity.get_prop(player, 'm_iTeamNum') ~= 2 then
                    return
                end
    
                if dist_to_bomb < 65 and entity.get_prop(player, 'm_iTeamNum') ~= 2 then
                    return
                end
    
                if cmd.in_use then
                    if globals.realtime() - start_time < 0.02 then
                        return
                    end
                end
    
                cmd.in_use = false
                return true
            end
            
        end

        anti_aim.features.anti_backstab = {} do

            function anti_aim.features.anti_backstab.run()
                local players = entity.get_players(true)
                for i = 1, #players do
                    local x, y, z = entity.get_prop(players[i], 'm_vecOrigin')
                    local origin = vector(entity.get_prop(entity.get_local_player(), 'm_vecOrigin'))
                    local distance = math.sqrt((x - origin.x) ^ 2 + (y - origin.y) ^ 2 + (z - origin.z) ^ 2)
                    local weapon = entity.get_player_weapon(players[i])
                    if entity.get_classname(weapon) == 'CKnife' and distance <= 200 then
                        return true
                    end
                end
                
                return false
            end
            
        end

        anti_aim.features.ladder = {} do
            function anti_aim.features.ladder.run(cmd)
                if not ui_handler.anti_aim.ladder:get() then
                    return false
                end
                if entity.get_prop(entity.get_local_player(), "m_MoveType") ~= 9 or cmd.forwardmove == 0 then 
                    return false
                end
                local camera_pitch, camera_yaw = client.camera_angles()
                local descending = cmd.forwardmove < 0 or camera_pitch > 45
                cmd.in_moveleft, cmd.in_moveright = descending and 1 or 0, not descending and 1 or 0
                cmd.in_forward, cmd.in_back = descending and 1 or 0, not descending and 1 or 0
                cmd.pitch, cmd.yaw = 89, c_math.normalize_yaw(cmd.yaw + 90)
                return true
            end
        end

        anti_aim.features.safe = {} do

            function anti_aim.features.safe.run(cmd)
                local result = math.huge;
                local heightDifference = 0;
                local localplayer = entity.get_local_player();
                local entities = entity.get_players(true);

                for i = 1, #entities do
                    local ent = entities[i];
                    local ent_origin = { entity.get_origin(ent) }
                    local lp_origin = { entity.get_origin(localplayer) }
                    if ent ~= localplayer and entity.is_alive(ent) then
                        local distance = (vector(ent_origin[1], ent_origin[2], ent_origin[3]) - vector(lp_origin[1], lp_origin[2], lp_origin[3])):length2d();
                        if distance < result then
                            result = distance;
                            heightDifference = ent_origin[3] - lp_origin[3];
                        end
                    end
                end

                local distance_to_enemy = { math.floor(result / 10), math.floor(heightDifference) }

                local weapon = entity.get_player_weapon(entity.get_local_player())
                local knife = weapon ~= nil and entity.get_classname(weapon) == 'CKnife'
                local zeus = weapon ~= nil and entity.get_classname(weapon) == 'CWeaponTaser'
            
                local safe_knife = (ui_handler.anti_aim.safe_head:get('knife')) and knife and not player.onground
                local safe_zeus = (ui_handler.anti_aim.safe_head:get('zeus')) and zeus and  not player.onground
                local distance_height = (ui_handler.anti_aim.safe_head:get('height distance')) and distance_to_enemy[2] < -50
                local distance_hight = (ui_handler.anti_aim.safe_head:get('high distance')) and  distance_to_enemy[1] > 119

                if safe_knife or safe_zeus  or distance_hight or distance_height then
                    return true
                end

                return false
                
           end 
        end

        anti_aim.features.manual_antiaim = {} do
            local manual_cur = nil
            local manual_keys = {
                { "left",    yaw = -90, item = ui_handler.manual_aa_hotkey.manual_left },
                { "right",   yaw = 90,  item = ui_handler.manual_aa_hotkey.manual_right },
                { "reset",   yaw = nil, item = ui_handler.manual_aa_hotkey.manual_back },
                { "forward", yaw = 180, item = ui_handler.manual_aa_hotkey.manual_forward },
            }

            for i, v in ipairs(manual_keys) do
                ui.set(v.item.ref, "Toggle")
            end

            function anti_aim.features.manual_antiaim.run()

                if not ui_handler.anti_aim.manual_aa:get() then 
                    return 0
                end

                for i, v in ipairs(manual_keys) do
                    local active, mode = v.item:get()

                    if v.active == nil then v.active = active end
                    if v.active == active then goto done end
                    v.active = active


                    if v.yaw == nil then manual_cur = nil end
    
                    if mode == 1 then
                        manual_cur = active and i or nil
                        goto done
                    elseif mode == 2 then
                        manual_cur = manual_cur ~= i and i or nil
                        goto done
                    end


                    ::done::

                end

                return manual_cur ~= nil and manual_keys[manual_cur].yaw or 0

            end

            
        end
 
        anti_aim.features.on_hotkey = {} do
            function anti_aim.features.on_hotkey.run()
                local ignore_freestanding = c_math.contains(ui_handler.anti_aim.dis_fs:get(), player.state) and not anti_aim.features.use_aa
                local fs_on_hotkey = ignore_freestanding and ui_handler.anti_aim.freestanding:get() and anti_aim.features.manual == 0
                local edge_on_hotkey = ui_handler.anti_aim.edge_yaw:get() or (ui_handler.anti_aim.fd_edge:get() and  reference.ragebot.duck:get() )
                

                reference.antiaim.edge:set(edge_on_hotkey)
                reference.antiaim.freestand:set(fs_on_hotkey)
                reference.antiaim.freestand.hotkey:set(fs_on_hotkey and "Always on" or "On hotkey")

            end
        end

        anti_aim.features.defensive_ = {} do

            local function is_exploit_ready_and_active(wpn)
         
                local doubletap_active = reference.ragebot.double_tap.hotkey:get()
                local fakeduck_active = reference.ragebot.duck:get()


                if fakeduck_active or not (onshot_active or doubletap_active) or doubletap_active and not player.shifting then
                    return false
                end

                if wpn then
                    local wpn_info = weapons(wpn)

                    if wpn_info then
                        if wpn_info.is_revolver then
                            return false
                        end
                    end
                end

                return true
            end

            function anti_aim.features.defensive_.run(cmd)
      
                if not entity.get_local_player() then
                    return false
                end
                local me = entity.get_local_player()
                local wpn = me and entity.get_player_weapon(me) or nil
                

                if not is_exploit_ready_and_active(wpn) then
                    return false
                end

                local animlayers = memory.animlayers:get(me)

                if not animlayers then
                    return false
                end

                local weapon_activity_number = memory.activity:get(animlayers[1]['sequence'], me)
                local flash_activity_number = memory.activity:get(animlayers[9]['sequence'], me)
                local is_reloading = animlayers[1]['weight'] ~= 0.0 and weapon_activity_number == 967
                local is_flashed = animlayers[9]['weight'] > 0.1 and flash_activity_number == 960
                local is_under_attack = animlayers[10]['weight'] > 0.1
                local is_swapping_weapons = cmd.weaponselect > 0

                if (ui_handler.anti_aim.defensive:get("flashed") and is_flashed)
                or (ui_handler.anti_aim.defensive:get("damage received") and is_under_attack)
                or (ui_handler.anti_aim.defensive:get("reloading") and is_reloading)
                or (ui_handler.anti_aim.defensive:get("weapon switch") and is_swapping_weapons) 
                or (ui_handler.anti_aim.defensive:get("on shot") and reference.antiaim.onshot.hotkey:get() ) then
                    return false
                end

                return true
            end
        end

        anti_aim.features.warmup_antiaim = {} do
            function anti_aim.features.warmup_antiaim.run()
                local game_rules = entity.get_game_rules()

                if not game_rules then
                    return false
                end

                local warmup_period do
                    local is_active = ui_handler.anti_aim.warmup_aa:get("warmup")
                    local is_warmup = entity.get_prop(game_rules, 'm_bWarmupPeriod') == 1

                    warmup_period = is_active and is_warmup
                end

                if not warmup_period then
                    local player_resource = entity.get_player_resource()

                    if player_resource then
                        local are_all_enemies_dead = true

                        for i=1, globals.maxplayers() do
                            if entity.get_prop(player_resource, 'm_bConnected', i) == 1 then
                                if entity.is_enemy(i) and entity.is_alive(i) then
                                    are_all_enemies_dead = false

                                    break
                                end
                            end
                        end

                        warmup_period = (are_all_enemies_dead and globals.curtime() < (entity.get_prop(game_rules, 'm_flRestartRoundTime') or 0)) and ui_handler.anti_aim.warmup_aa:get("round end")
                    end
                end

                if warmup_period then
                    return true
                end

                return false
            end
        end

        function anti_aim.features.main(cmd)
            anti_aim.features.use_aa = anti_aim.features.legit_antiaim.run(cmd)
            anti_aim.features.stab = anti_aim.features.anti_backstab.run()
            anti_aim.features.fast_ladder = anti_aim.features.ladder.run(cmd)
            anti_aim.features.safe_head = anti_aim.features.safe.run(cmd)
            anti_aim.features.manual = anti_aim.features.manual_antiaim.run()
            anti_aim.features.defensive = anti_aim.features.defensive_.run(cmd)
            anti_aim.features.on_hotkey.run()
            anti_aim.features.warmup_aa = anti_aim.features.warmup_antiaim.run(cmd)
            
        end
        
        
    end

    anti_aim.builder = {} do
        anti_aim.builder.venture = false
        anti_aim.builder.latest = 0
        anti_aim.builder.switch = false
        anti_aim.builder.delay = 0
        anti_aim.builder.restrict = 0
        anti_aim.builder.last_packets = 0
        anti_aim.builder.way = 0

        
        local function get_state(state)
            
            local double_tap = reference.ragebot.double_tap.hotkey:get()
            local fake_duck = reference.ragebot.duck:get()

            local freestand = ui_handler.anti_aim.freestanding:get() and player.is_fs_peek and c_math.contains(ui_handler.anti_aim.dis_fs:get(), player.state)

            
            if ui_handler.builder['on use'].enable:get()  and  anti_aim.features.use_aa then
                return  'on use'
            end
            
            if ui_handler.builder['manual'].enable:get() and anti_aim.features.manual ~= 0 then
                return 'manual'
            end

            if ui_handler.builder['freestand'].enable:get() and freestand then
                return 'freestand'
            end

           
            if  ui_handler.builder['safe head'].enable:get() and anti_aim.features.safe_head then
                return 'safe head'
            end

            if ui_handler.builder['on shot'].enable:get() and onshot and not double_tap and not fake_duck then
                return 'on shot'
            end

            if ui_handler.builder['fake lag'].enable:get() and not onshot and not double_tap and not fake_duck then
                return 'fake lag'
            end


            return state
        end

        local function yaw(this)
            if  anti_aim.features.use_aa then
                return 0 , "180" ,this.base.value 
            end
            if anti_aim.features.stab then
                return 0 , "off" ,this.base.value 
            end  
            return 'default' ,   "180" ,reference.antiaim.edge:get() and "local view" or this.base.value 
        end

        local choke  = 1
        local function modifier(this)
            local add , expand = this.add.value, this.expand.value 

            local delay = (expand ~= "left/right" or not player.shifting)  and 1 or this.delay.value 
            if globals.chokedcommands() == 0 then
                choke = choke + 1
            end
            local add_ab_left , add_ab_right= 0 , 0
            if ui_handler.anti_aim.anti_bruteforce:get() and anti_aim.builder.venture then
                if ui_handler.anti_aim.anti_bruteforce_type:get() == "Lilith" then
                    add_ab_right = anti_aim.builder.restrict * 3
                    add_ab_left= anti_aim.builder.restrict * -3
                elseif ui_handler.anti_aim.anti_bruteforce_type:get() == "Eisheth" then
                    add_ab_right = anti_aim.builder.restrict * -3
                    add_ab_left= anti_aim.builder.restrict * 3
                end
            end


            if (choke - anti_aim.builder.last_packets >= anti_aim.builder.delay)  then
                anti_aim.builder.delay = delay
                anti_aim.builder.switch = not anti_aim.builder.switch
                anti_aim.builder.last_packets = choke
            end
            
            if expand == "left/right" then
                local  epd_left , epd_right = this.epd_left.value , this.epd_right.value 
                add = add + ( anti_aim.builder.switch and epd_left +add_ab_left or epd_right + add_ab_right)
            elseif expand == "x-way" then
                local x_way , epd_way= this.x_way.value ,this.epd_way.value
                anti_aim.builder.way = anti_aim.builder.way < (x_way - 1) and (anti_aim.builder.way + 1) or 0
                if this.ways_manual.value then
                    
                   add = add +  this[anti_aim.builder.way+1]:get()
                else
                    local step = (anti_aim.builder.way) / (x_way - 1)
                    add = add + c_math.lerp(-epd_way, epd_way, step)
                end
            elseif expand == "spin" then
                local  epd_left , epd_right , speed = this.epd_left.value , this.epd_right.value , this.speed.value
                add = add + c_math.lerp(epd_left, epd_right , globals.curtime() * (speed * 0.1) % 1)
            end

            local jitter_mode, jitter_degree = this.jitter.value, this.jitter_add.value

            if jitter_mode == "offset" then
                add = add + (anti_aim.builder.switch and jitter_degree +add_ab_left or 0 + add_ab_right)
            elseif jitter_mode == "center" then
                add = add + (anti_aim.builder.switch and -jitter_degree / 2 +add_ab_left or jitter_degree / 2 + add_ab_right)
            elseif jitter_mode == "random" then
                add = add + (math.random(0, jitter_degree) - jitter_degree / 2)
            end


     
            
            if not anti_aim.features.use_aa  then

                add = add + anti_aim.features.manual + math.random(this.yaw_randomize:get() * 0.01 * -add, this.yaw_randomize:get() * 0.01 * add)
            end
            if anti_aim.features.use_aa then
                add = add + 180
            end

            

          

            return c_math.normalize_yaw(add )
        end

        local function body(this)
            local by_mdoe , by_num , by_tpye  = this.by_mode.value , 0 , "static"

            if by_mdoe == "static" then
                by_tpye = "static"
                by_num = this.by_num.value
            elseif by_mdoe == "jitter" then
                 by_tpye = "static"
                by_num = anti_aim.builder.switch and this.by_num.value or - this.by_num.value
            elseif by_mdoe == "opposite" then
                by_tpye = "static"
                if player.fs_side == 'left' then
                    by_num = 180
                elseif player.fs_side == 'right' then
                    by_num = -180
                else
                    by_num = 0
                end
            elseif by_mdoe == "off" then
                by_tpye = "off"
            end

            return c_math.normalize_yaw(by_num)  ,  by_tpye

        end

        local srx = nil
        local pitch_srx = nil
        
        local function defensive_builder(cmd,this)
     
            cmd.force_defensive = this.break_lc.value 
       
            local yaw , pitch = this.def_yaw.value , this.def_pitch.value 
            local pitch_num , yaw_num , body_tpye , body_num = 'default' ,nil ,nil ,nil
            if pitch == "up" then pitch_num = -88
            elseif pitch == "zero" then pitch_num = 0 
            elseif pitch == "up switch" then pitch_num = client.random_int(-45, 65)
            elseif pitch == "down switch" then pitch_num = client.random_int(45, 65)
            elseif pitch == "random" then pitch_num =  client.random_int(-89, 89)
            elseif pitch == "random static" then 
                

                if not pitch_srx then
                    pitch_srx = client.random_int(-89, 89)
                end
                pitch_num = pitch_srx

            elseif pitch == "custom" then pitch_num = this.def_pitch_num.value

            end


            if yaw == "sideways" then 
                yaw_num = (anti_aim.builder.switch and 90 or -90 ) + client.random_int(-15, 15)
            elseif yaw == "forward" then
                yaw_num = 180  + client.random_int(-30, 30)
            elseif yaw == "delayed" then
                local left ,  right  = this.def_left.value , this.def_right.value 
                yaw_num = (anti_aim.builder.switch and left or right ) 

            elseif yaw == "spin" then
                local left ,  right  , speed = this.def_left.value , this.def_right.value , this.def_speed.value
                yaw_num =  c_math.lerp(left, right , globals.curtime() * (speed * 0.1) % 1)
            elseif yaw == "random" then
                local left ,  right  = this.def_left.value , this.def_right.value 
                yaw_num =  client.random_int(left,right)
            elseif yaw == "random static" then
                local left ,  right  = this.def_left.value , this.def_right.value 
                if not srx then
                    srx = client.random_int(left,right)
                end
                yaw_num = srx

            elseif yaw == "flick exploit" then
                yaw_num = (player.fs_side  ==  'left' and -90 or 90) +client.random_int(-20,20)
            elseif yaw == "custom" then
                yaw_num = player.fs_side  ==  'left' and  this.def_yaw_num.value  or -this.def_yaw_num.value
            end
   
            local body = this.def_body.value
            if body == "default" then
                body_tpye = "static"
                body_num = 120
            elseif body == "auto" then
                
                if yaw_num ~= nil then
                    body_tpye = "static"
                    body_num =  yaw_num < 0 and -60 or 60
                end
              
            elseif  body == "jitter" then
                body_tpye = "static"
                body_num = anti_aim.builder.switch and -120 or 120
            end

            return pitch_num , yaw_num , body_tpye , body_num

        end
      
        function anti_aim.builder.main(cmd)
            local state = get_state(player.state)
            local this =  ui_handler.builder[state].enable.value and ui_handler.builder[state] or ui_handler.builder["global"]
            local pitch , yaw_type , yaw_base = yaw(this)
            local yaw_add = modifier(this)
            local by_num , by_tpye = body(this)
        
            --print(cmd.force_defensive)
            local pitch_num , yaw_num , body_tpye , body_num  = defensive_builder(cmd,this)
      
            if  (player.defensive  and not anti_aim.features.fast_ladder and not  anti_aim.features.use_aa  and player.shifting) and this.defensive.value and anti_aim.features.defensive then 
            
                pitch = pitch_num ~= nil and pitch_num or pitch
                yaw_add = yaw_num ~= nil and yaw_num or yaw_add
      
                by_num = body_num ~= nil and body_num or by_num

                by_tpye =  body_tpye ~= nil and body_tpye or by_tpye
            else
                srx = nil
                pitch_srx = nil
            end
     
            if anti_aim.features.warmup_aa then
                pitch = 0
                yaw_type = "spin"
                yaw_add = 42
                by_tpye = "off"
            end
           

            if anti_aim.builder.venture then
                if anti_aim.builder.latest + 2 == globals.curtime() then
                    anti_aim.builder.venture = false
                end
            end
          

          
            reference.antiaim.pitch[1]:set(type(pitch) == "number" and 'custom' or pitch)
            reference.antiaim.pitch[2]:set(type(pitch) == "number" and pitch or 0 )
            reference.antiaim.yaw[1]:set(yaw_type)
            reference.antiaim.yaw[2]:set( c_math.normalize_yaw(yaw_add) )
            reference.antiaim.base:set(yaw_base)
            reference.antiaim.fs_body:set(false)
            reference.antiaim.jitter[1]:set("off")
            reference.antiaim.jitter[2]:set(0)
            reference.antiaim.body[1]:set(by_tpye)
            reference.antiaim.body[2]:set(by_num)

        end 

    end

    anti_aim.venture = {} do
        local latest = 0
        local damaged = 0
        
        local function trigger(event)
            local me = entity.get_local_player()

           

            local valid = (me and entity.is_alive(me))
            if not valid or latest == globals.tickcount() then 
                return  
            end
            local attacker = client.userid_to_entindex(event.userid)
            if not attacker or not entity.is_enemy(attacker) or entity.is_dormant(attacker) then return end
            local impact = vector(event.x, event.y, event.z)
            local enemy_view = vector(entity.get_origin(attacker))
            enemy_view.z = enemy_view.z + 64
            local dists = {}
            for i = 1, #player.get_players do
                local v = player.get_players[i]

                if not entity.is_enemy(v) then
                    local head = vector(entity.hitbox_position(v, 0))
                    local point = c_math.closest_ray_point(head, enemy_view, impact)
                    dists[#dists+1] = head:dist(point)
                    if v == me then dists.mine = dists[#dists] end
                end
            end
            local closest = math.min( unpack(dists) )
            if (dists.mine and closest) and dists.mine < 40 or (closest == dists.mine and dists.mine < 128) then
           
                latest = globals.tickcount() 
                anti_aim.builder.latest = globals.curtime()
                anti_aim.builder.venture = true
                anti_aim.builder.restrict = math.random(1, 3)
            end
        end
        client.set_event_callback("bullet_impact", trigger)

  
        
    end

end 

local Visuals = {} do
    local screen_size = vector(client.screen_size())
    local screen_center = screen_size * 0.5
    local smooth_scope = c_tweening:new(0)
    Visuals.animation_breaker = {} do

        function Visuals.animation_breaker.run()
            
            local me = entity.get_local_player()
            if not me then
                return
            end
            local animlayers = memory.animlayers:get(me)
            if not animlayers then
                return
            end
          
            local leg_air = ui_handler.Visuals.on_air_options:get()
            
            if ui_handler.Visuals.animation_breaker:get("on ground") and player.onground then
                
                local leg_move = ui_handler.Visuals.on_ground_options:get()
                if leg_move == "frozen" then
                    entity.set_prop(me, 'm_flPoseParameter', 1, 0)
                    reference.antiaim.leg_movement:set("Always slide")
                elseif leg_move == "walking" then
                    entity.set_prop(me, 'm_flPoseParameter', 0.5, 7)
                    reference.antiaim.leg_movement:set("Never slide")
                elseif leg_move == "jitter" and player.state == 'move' then
                    entity.set_prop(me, 'm_flPoseParameter', client.random_float(0.65, 1), 0)
                   
                    reference.antiaim.leg_movement:set("Always slide")
                elseif leg_move == 'sliding' and player.state == 'move' then
                    entity.set_prop(me, 'm_flPoseParameter', 0, 9)
                    entity.set_prop(me, 'm_flPoseParameter', 0, 10)
                    reference.antiaim.leg_movement:set("Never slide")
                elseif leg_move == 'swag' then
                    entity.set_prop(me, "m_flPoseParameter",1, globals.tickcount() % 4 > 1 and 0.5 / 10 or 1)
                end
            end

            local move_type = entity.get_prop(me, 'm_MoveType')
            if ui_handler.Visuals.animation_breaker:get("aerobic") and not player.onground and not (move_type == 9 or move_type == 8) then
                local air_legs = ui_handler.Visuals.on_air_options:get()
                
                if air_legs == 'frozen' then
                    entity.set_prop(me, 'm_flPoseParameter', 1, 6)
                elseif air_legs == 'walking' then
                    local cycle do
                        cycle = globals.realtime() * 0.7 % 2
                        if cycle > 1 then
                            cycle = 1 - (cycle - 1)
                        end
                    end
                    animlayers[6]['weight'] = 1
                    animlayers[6]['cycle'] = cycle
                elseif air_legs == 'swag' then
                    
                    entity.set_prop(entity.get_local_player(), "m_flPoseParameter", math.random(0, 10)/10, 6)
                end
            end

            if ui_handler.Visuals.animation_breaker:get("sliding slow motion") and reference.antiaim.slowmotion.hotkey:get() then
                entity.set_prop(me, 'm_flPoseParameter', 0, 9)
            end

            if ui_handler.Visuals.animation_breaker:get("sliding crouch") and (player.state == 'crouch' or player.state == 'crouch move') then
                entity.set_prop(me, 'm_flPoseParameter', 0, 8)
            end

            if ui_handler.Visuals.animation_breaker:get("zero on land")  and memory.animstate:get(me).hit_in_ground_animation and player.onground then
                entity.set_prop(me, 'm_flPoseParameter', 0.5, 12)
            end

            if ui_handler.Visuals.animation_breaker:get("earthquake")  then

                animlayers[12]['weight'] = client.random_float(-0.3, 0.75)


            end
            
            

        end

        function Visuals.animation_breaker.post(cmd)
            if ui_handler.Visuals.animation_breaker:get("quick peek legs") and reference.ragebot.quick_peek.hotkey:get() then
                local me = entity.get_local_player()
                local move_type = entity.get_prop(me, 'm_MoveType')

                if move_type == 2 then
                    local command = memory.user_input:get_command(cmd.command_number)

                    if command then
                        command.buttons = bit.band(command.buttons, bit.bnot(8))
                        command.buttons = bit.band(command.buttons, bit.bnot(16))
                        command.buttons = bit.band(command.buttons, bit.bnot(512))
                        command.buttons = bit.band(command.buttons, bit.bnot(1024))
                    end
                end
            end
        end


        function Visuals.finish_command(cmd)
            local me = entity.get_local_player()
            if not me then
                return
            end

            Visuals.animation_breaker.post(cmd)
        end

    end

Visuals.sidebar = {} do
    local name = "Feel the heat. That's Aimsense Debug"
    local cache = {}
    for w in string.gmatch(name, '.[\1-\191]*') do
        cache[#cache + 1] = {
            w = w,
            n = 0,
            d = false,
            p = { 0 }
        }
    end

    
    local function linear(t, d, s)
        t[1] = c_math.clamp(t[1] + (globals.frametime() * s * (d and 1 or -1)), 0, 1)
        return t[1]
    end

    local menu_color = ui.reference("MISC", "Settings", "Menu color")
    function Visuals.sidebar.run()
        if not ui.is_menu_open() then
            return
        end
        
        local result = {}
        local sidebar, accent = { 64, 64, 64, 244 }, { 192, 192, 192, 244 }
        local realtime = globals.realtime()

        for i, v in ipairs(cache) do
            if realtime >= v.n then
                v.d = not v.d
                v.n = realtime + client.random_float(1, 3)
            end

            
            local alpha = linear(v.p, v.d, 2)
            local r, g, b, a = c_math.color_lerp(sidebar[1], sidebar[2], sidebar[3], sidebar[4], accent[1], accent[2],
                accent[3], accent[4], math.min(alpha + 0.3, 1))

            result[#result + 1] = string.format('\a%02x%02x%02x%02x%s', r, g, b, 200, v.w)
        end

        ui_handler.navigation.label:set(table.concat(result))
    end

end

Visuals.hide_menu = {} do
    function Visuals.hide_menu.run()
        local show = ui_handler.anti_aim.toggle_fakelag:get()
        local hide = false
        
        -- Улучшенная функция для безопасного управления видимостью
        local function set_visibility(element, state)
            if not element then return end
            
            -- Обрабатываем разные форматы элементов:
            -- 1. Обычный reference (число)
            -- 2. Таблица {ref, parent}
            -- 3. Объект с полем .ref
            local ref = type(element) == "table" and (element[1] or element.ref) or element
            if ref and type(ref) == "number" then
                ui.set_visible(ref, state)
            end
        end

        -- Полный список всех элементов для скрытия
        local aa_elements = {
            -- Основные элементы анти-аима
            reference.antiaim.enable,
            reference.antiaim.pitch and reference.antiaim.pitch[1],
            reference.antiaim.pitch and reference.antiaim.pitch[2],
            reference.antiaim.yaw and reference.antiaim.yaw[1],
            reference.antiaim.yaw and reference.antiaim.yaw[2],
            reference.antiaim.base,
            reference.antiaim.jitter and reference.antiaim.jitter[1],
            reference.antiaim.jitter and reference.antiaim.jitter[2],
            reference.antiaim.body and reference.antiaim.body[1],
            reference.antiaim.body and reference.antiaim.body[2],
            reference.antiaim.edge,
            reference.antiaim.fs_body,
            reference.antiaim.freestand,
            reference.antiaim.freestand and reference.antiaim.freestand.hotkey,
            reference.antiaim.roll,
            
            -- Дополнительные элементы (исправлена опечатка в Fake peek)
            pui.reference("AA", "Other", "Slow motion"),
            pui.reference("AA", "Other", "On shot Anti-aim"), 
            pui.reference("AA", "Other", "Leg movement"),
            pui.reference("AA", "Other", "Fake peek")  -- Исправлено refference на reference
        }
        
        -- Скрываем все элементы
        for _, element in ipairs(aa_elements) do
            set_visibility(element, hide)
        end
        
        -- Показываем элементы фейклага (с дополнительными проверками)
        if reference.fakelag1 then
            local fl_elements = {
                reference.fakelag1.enable and reference.fakelag1.enable[1],
                reference.fakelag1.amount,
                reference.fakelag1.variance,
                reference.fakelag1.limit
            }
            
            for _, element in ipairs(fl_elements) do
                if element then  -- Добавлена проверка на существование
                    set_visibility(element, show)
                end
            end
        end
    end
end

    Visuals.indicators = {} do
        local indicator_global = c_tweening:new(0)
        local indicator_grenade = c_tweening:new(1.0)
        local smooth_charge = c_tweening:new(0)
        local smooth_state = c_tweening:new(1.0)
        local previous_state = player.state
        local state_name = player.state

        local list = {
            {
                name = "%s",
                format = function()
                    return state_name:upper()
                end,
                active = function()
                    return true
                end,
                color = function(accent, accent_second)
                    return accent:lerp(accent_second, smooth_state())
                end,

                animation = c_tweening:new(0)
            },
            {
                name = "MIN DMG",
                active = function()
                    return reference.ragebot.ovr[1].hotkey:get() and reference.ragebot.ovr[1]:get() 
                end,
                animation = c_tweening:new(0)
            },
   
{
    name = "RAPID",
    active = function()
        return reference.ragebot.double_tap.hotkey:get()
    end,
    color = function(accent)
        
        if reference.ragebot.double_tap.hotkey:get() then
         
            return color.green:lerp(accent, smooth_charge())
        else

            return color.red:lerp(accent, smooth_charge())
        end
    end,
    render_addition = function(pos, accent, ctx)
        renderer.circle(
            pos.x + 1,
            pos.y + 1,
            accent.r,
            accent.g,
            accent.b,
            255 * ctx,
            3,
            180,
            smooth_charge(),
            1
        )
    end,
    offset_x = function(scope)
        return smooth_charge() * -4 * scope + scope * 1
    end,
    animation = c_tweening:new(0)
},

            {
                name = "FS",
                active = function()
                    return ui_handler.anti_aim.freestanding:get()
                end,
                animation = c_tweening:new(0)
            },

            {
                name = "ON SHOT",
                active = function()
                end,
                animation = c_tweening:new(0)
            },

            {
                name = "EDGE",
                active = function()
                    return reference.antiaim.edge:get()
                end,
                animation = c_tweening:new(0)
            },
            {
                name = "BODY",
                active = function()
                    return reference.ragebot.force_bodyaim:get()
                end,
                animation = c_tweening:new(0)
            },
            {
                name = "FORCE BODY",
                active = function()
                    return reference.ragebot.force_bodyaim:get()
                end,
                animation = c_tweening:new(0)
            }
        }

        Visuals.indicators.states = {
            ['air'] = 'in air',
            ['crouch'] = 'ducking',
            ['crouch move'] = 'duck move',
            ['move'] = 'moving',
            ['stand'] = 'standing',
           
        }

        function Visuals.indicators.prerun(global_alpha, grenade_alpha)

            local ctx_alpha = global_alpha * grenade_alpha

            local indicator_offset = ui_handler.Visuals.vertical_offset:get()
            local indicator_position = screen_center + vector(0, indicator_offset)
            local scope_animation = smooth_scope()
            local rev_scope_animation = 1 - scope_animation

            local indicator_accent = color(ui_handler.Visuals.indicator_color:get())
            local indicator_renewed = color(ui_handler.Visuals.renewed_color:get())
            local indicator_label = color.animated_text('aimsense', 1, indicator_renewed, indicator_accent, ctx_alpha*255)
            local indicator_label_size = vector(renderer.measure_text('b', 'aimsense'))
          
            
            local scope_offset = indicator_label_size.x * 0.5 * scope_animation + scope_animation * 3

            renderer.text(indicator_position.x + scope_offset - indicator_label_size.x * 0.5, indicator_position.y - indicator_label_size.y * 0.5, 255, 255, 255, ctx_alpha*255, 'b', 0, indicator_label)

            indicator_position = indicator_position + vector(0, indicator_label_size.y - 1)

            --[[
                local bar_centre = { indicator_position.x + scope_offset  -indicator_label_size.x * 1.7  -7, indicator_position.y - indicator_label_size.y*1 +7}
    
                local bar_color = indicator_accent

                renderer.gradient(bar_centre[1],bar_centre[2]  , 60, 1, bar_color.r, bar_color.g, bar_color.b, ctx_alpha*255, bar_color.r, bar_color.g, bar_color.b, ctx_alpha*255, true)
                renderer.gradient(bar_centre[1],bar_centre[2] , 1, 10, bar_color.r, bar_color.g, bar_color.b,  ctx_alpha *255,  bar_color.r, bar_color.g, bar_color.b, 0, false)
                renderer.gradient(bar_centre[1] + 59, bar_centre[2], 1, 10,  bar_color.r, bar_color.g, bar_color.b, ctx_alpha *255,   bar_color.r, bar_color.g, bar_color.b, 0, false)
            ]]
            


            for i=1, #list do
                local indicator = list[i]
                local indicator_animation = indicator.animation(0.15, ({indicator.active()})[1] or false)

                if indicator_animation > 0.01 then
                    local indicator_text = indicator.name:format(indicator.format and indicator.format() or '')
                    local indicator_color do
                        if type(indicator.color) == 'table' then
                            --- @type table
                            indicator_color = indicator.color
                        elseif type(indicator.color) == 'function' then
                            indicator_color = indicator.color(indicator_accent, indicator_renewed)
                        else
                            indicator_color = indicator_accent:clone()
                        end
                    end

                    local text_size = vector(renderer.measure_text('-', indicator_text))
                    local _x_offset = indicator.offset_x or 0

                    if type(_x_offset) == 'function' then
                        _x_offset = _x_offset(rev_scope_animation)
                    end

                    local _scope_offset = text_size.x*scope_animation*0.5 + scope_animation * 3

                    renderer.text(indicator_position.x + _scope_offset - text_size.x * 0.5 - 1 + _x_offset, indicator_position.y - text_size.y * 0.5, indicator_color.r, indicator_color.g, indicator_color.b, 255 * indicator_animation*ctx_alpha, '-', 0, indicator_text)

                    if indicator.render_addition then
                        indicator.render_addition(vector(indicator_position.x + text_size.x + _scope_offset + _x_offset, indicator_position.y), indicator_accent, indicator_animation*ctx_alpha)
                    end
                    indicator_position = indicator_position + vector(0, text_size.y) * indicator_animation
                end
            end
        end

        function Visuals.indicators.run()
            local me = entity.get_local_player()

            if not entity.is_alive(me)  then
                return 
            end

            local wpn_info = weapons(entity.get_player_weapon(me))
            
            if not wpn_info then
                return 
            end
    
            local is_scoped = entity.get_prop(me, 'm_bIsScoped') == 1
            
            
            smooth_scope(0.1, is_scoped)
            local exploits_charged = player.shifting
            
            smooth_charge(0.1, exploits_charged or false)

            local player_state = Visuals.indicators.states[player.state] or player.state


            if previous_state ~= player_state then
                smooth_state(0.15, 1)

                if smooth_state() == 1.0 then
                    state_name = player_state

                    previous_state = player_state
                end
            else
                smooth_state(0.15, 0)
            end
            
            local indicator_state = indicator_global(0.15, ui_handler.Visuals.indicators:get())
            
            local grenade_b =  wpn_info == 'grenade' or is_scoped
            local grenade_state = indicator_grenade(0.15, grenade_b and 0.5 or 1.0)
            if indicator_state > 0.01 then
                
                Visuals.indicators.prerun(indicator_state, grenade_state)
            
            end

        end


    end        

    Visuals.manual_arrows = {} do
        local arrows = {
            main = c_tweening:new(0),
            left = c_tweening:new(0),
            right = c_tweening:new(0)
        }
        Visuals.manual_arrows.prerun = function()
            local me = entity.get_local_player() 

            if not entity.is_alive(me)  then
                return 
            end

            local scope_check = smooth_scope() 
            local main = arrows.main(0.15,  ui_handler.Visuals.manual_arrows:get() ) *255 
        
            if main < 1 then
                return
            end

            local  left = arrows.left(0.15, anti_aim.features.manual == -90 ) * 255 
            local  right = arrows.right(0.15,  anti_aim.features.manual == 90 ) * 255 
            
            local  manual_offset = ui_handler.Visuals.manual_offset:get()
            local  manual_arrows_color = color(ui_handler.Visuals.manual_arrows_color:get())
            local  manual_arrows_accent = color(ui_handler.Visuals.manual_arrows_accent:get())
            local  base_position_left = vector(screen_center.x , screen_center.y + 13)
       
            renderer.triangle(
            base_position_left.x - (manual_offset + 9),
            base_position_left.y,
            base_position_left.x - manual_offset,
            base_position_left.y - 7, base_position_left.x - manual_offset,
            base_position_left.y + 7,
            manual_arrows_color.r ,
            manual_arrows_color.g ,
            manual_arrows_color.b, 
            left)

            
            renderer.triangle(
            base_position_left.x - (manual_offset + 9),
            base_position_left.y,
            base_position_left.x - manual_offset,
            base_position_left.y - 5, base_position_left.x - manual_offset,
            base_position_left.y + 5,
            manual_arrows_accent.r ,
            manual_arrows_accent.g ,
            manual_arrows_accent.b, 
            75)

            renderer.triangle(
            base_position_left.x + (manual_offset + 9),
            base_position_left.y,
            base_position_left.x + manual_offset,
            base_position_left.y - 5,
            base_position_left.x + manual_offset,
            base_position_left.y + 5,
            manual_arrows_color.r ,
            manual_arrows_color.g ,
            manual_arrows_color.b,
            right)
            renderer.triangle(
            base_position_left.x + (manual_offset + 9),
            base_position_left.y,
            base_position_left.x + manual_offset,
            base_position_left.y - 5,
            base_position_left.x + manual_offset,
            base_position_left.y + 5,
            manual_arrows_accent.r ,
            manual_arrows_accent.g ,
            manual_arrows_accent.b,
            75)

            
        end
    end

-- Получаем размеры экрана
local screen_w, screen_h = client.screen_size()
local screen_center = { x = screen_w / 2, y = screen_h / 2 }

-- Функция отрисовки водяного знака
Visuals.draw_forced_watermark = function ()
    if ui_handler.Visuals.indicators:get() then
        local x, y = 10, screen_center.y - 15 local t1, t2, t3 = "AimSense ~ gs", "Build: Debug", "User: " .. user.name for i = 1, #t1 do local c = t1:sub(i, i) renderer.text(x, y, 255, 255, 255, 255, '', 0, c) x = x + renderer.measure_text('', c) + 1 end x = 10 for i = 1, #t2 do local c = t2:sub(i, i) renderer.text(x, y + 12, 255, 255, 255, 255, '', 0, c) x = x + renderer.measure_text('', c) + 1 end x = 10 for i = 1, #t3 do local c = t3:sub(i, i) renderer.text(x, y + 24, 255, 255, 255, 255, '', 0, c) x = x + renderer.measure_text('', c) + 1 end

    end
end

-- Регистрируем функцию на каждый кадр
client.set_event_callback("paint", Visuals.draw_forced_watermark)

-- Регистрируем функцию на каждый кадр
client.set_event_callback("paint", Visuals.draw_forced_watermark)
   
Visuals.on_load = {} 
local alpha = 69
local toggled = false

function Visuals.on_load.run()        
    -- Логика изменения прозрачности
    if alpha > 0 and toggled then
        alpha = alpha - 0.5
    elseif not toggled then
        alpha = alpha + 2
        if alpha >= 254 then toggled = true end
    end

    -- Условие сохранено, но ничего не рисуем
    if alpha > 1 then
        --[[ -- Визуальный вывод отключён

        renderer.rectangle(
            0, 0, 
            screen_size.x, screen_size.y, 
            80, 0, 120, alpha * 0.5
        )

        local text1 = "AIMSENSE "
        local text1_w = renderer.measure_text("c+", text1)
        local text2 = "DEBUG"
        local text2_w = renderer.measure_text("c+", text2)
        local total_w = text1_w + text2_w
        local start_x = screen_size.x/2 - total_w/2
        local y_pos = screen_size.y/2 - renderer.measure_text("c+", "A")/2

        renderer.text(
            start_x, 
            y_pos, 
            255, 255, 255, alpha,
            "c+", 
            0x200, 
            text1
        )

        renderer.text(
            start_x + text1_w,  
            y_pos, 
            100, 200, 255, alpha,
            "c+", 
            0x200, 
            text2
        )

        --]]
      end
   end
end

local Miscellaneous = {} do




Miscellaneous.clantag = {} do
    local build = function(str)
        local tag = {}

        -- Появление текста с анимированным "|"
        for i = 1, #str do
            tag[#tag + 1] = str:sub(1, i) .. "|"
        end

        -- Полный текст с "|"
        tag[#tag + 1] = str .. "|"

        -- Исчезновение текста с "|"
        for i = 1, #str do
            tag[#tag + 1] = str:sub(i + 1) .. "|"
        end

        -- Пустые значения для плавности
        tag[#tag + 1] = " "
        tag[#tag + 1] = "|"
        tag[#tag + 1] = " "

        return tag
    end

    local old_time = 0

    function Miscellaneous.clantag()
        if not ui_handler.misc.clantag:get() then
            return
        end

        local tag = build("aimsense ~ gs")
        local curtime = math.floor(globals.curtime() * 4.5)

        if old_time ~= curtime then
            client.set_clan_tag(tag[(curtime % #tag) + 1])
            old_time = curtime
        end

        reference.misc.clantag:set(false)
    end
end


    Miscellaneous.event_logger = {} do
        local cache = {}
        local hitgroups = {
            'body',
            'head',
            'chest',
            'stomach',
            'left arm',
            'right arm',
            'left leg',
            'right leg',
            'neck',
            '?',
            'gear'
        }
        function Miscellaneous.event_logger.aim_fire(event)
            local this = {
                tick = event.tick,
                timestamp = client.timestamp(),
                wanted_damage = event.damage,
                wanted_hit_chance = event.hit_chance,
                wanted_hitgroup = event.hitgroup
            }

            cache[event.id] = this
        end

        function Miscellaneous.event_logger.aim_hit(event)
            local cached = cache[event.id]

            if not cached then
                return
            end

            local options = {}

            local backtrack = globals.tickcount() - cached.tick

            if backtrack ~= 0 then
                options[#options+1] = string.format('delay: %d tick%s (%i ms)', backtrack, math.abs(backtrack) == 1 and '' or 's', math.round(backtrack*globals.tickinterval()*1000))
            end

            local register_delay = client.timestamp() - cached.timestamp

            if register_delay ~= 0 then
                options[#options+1] = string.format('delay: %i ms', register_delay)
            end

            local name = entity.get_player_name(event.target)
            local hitgroup = hitgroups[event.hitgroup + 1] or '?'
            local target_hitgroup = hitgroups[cached.wanted_hitgroup + 1] or '?'
            local damage = event.damage
            local health = entity.get_prop(event.target, 'm_iHealth')
            local hit_chance = event.hit_chance
            local logger_text = string.format('aimsense: registered shot %s\'s %s for the %d%s dmg (%s, %d remaining%s)',
                name,
                hitgroup,
                tonumber(damage),
                cached.wanted_damage ~= damage and string.format('(%d)', cached.wanted_damage) or '',
                target_hitgroup ~= hitgroup and string.format('aimed: %s(%d%%)', target_hitgroup, hit_chance) or string.format('th: %d%%', hit_chance),
                health,
                #options > 0 and string.format(', %s', table.concat(options, ', ')) or ''
            )

            if ui_handler.misc.event_logger:get() then
                print(logger_text)
            end
        end


			math.round = function(x)
			return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
			end

        function Miscellaneous.event_logger.aim_miss(event)
            local cached = cache[event.id]

            if not cached then
                return
            end

            local options = {}

            local backtrack = globals.tickcount() - cached.tick

            if backtrack ~= 0 then
                options[#options+1] = string.format('delay: %d tick%s (%i ms)', backtrack, math.abs(backtrack) == 1 and '' or 's', math.round(backtrack*globals.tickinterval()*1000))
            end

            local register_delay = client.timestamp() - cached.timestamp

            if register_delay ~= 0 then
                options[#options+1] = string.format('delay: %i ms', register_delay)
            end

            local name = entity.get_player_name(event.target)
            local hitgroup = hitgroups[event.hitgroup + 1] or '?'
            local reason = event.reason
            local damage = cached.wanted_damage
            local hit_chance = event.hit_chance
            local logger_text = string.format('aimsense: miss %s\'s %s due to %s (td: %d, th: %d%%%s)',
                name,
                hitgroup,
                reason,
                tonumber(damage),
                hit_chance,
                #options > 0 and string.format(', %s', table.concat(options, ', ')) or ''
            )

            if ui_handler.misc.event_logger:get() then
                print(logger_text)
            end
        end

        local hurt_weapons = {
            ['knife'] = 'Knifed';
            ['hegrenade'] = 'Naded';
            ['inferno'] = 'Burned';
        }

        function Miscellaneous.event_logger.player_hurt(event)
            local attacker = client.userid_to_entindex(event.attacker)

            if not attacker or attacker ~= entity.get_local_player() then
                return
            end

            local target = client.userid_to_entindex(event.userid)

            if not target then
                return
            end

            local wpn_type = hurt_weapons[event.weapon]

            if not wpn_type then
                return
            end

            local name = entity.get_player_name(target)
            local damage = event.dmg_health

            local logger_text = string.format('%s %s for %d dmg',
                wpn_type,
                name,
                tonumber(damage)
            )

            if ui_handler.misc.event_logger:get() then
                print(logger_text)
            end
        end

    end
    
    Miscellaneous.auto_hideshots = {} do
        local ovr = false
        local latest = false
        function Miscellaneous.auto_hideshots.run(cmd)
            if  not  ui_handler.misc.auto_hideshots:get() then
                return
            end
            local me = entity.get_local_player()
            if not me  then
                return
            end
            local weapon = entity.get_player_weapon(me) 
            local weapon_t = weapon and weapons(weapon)
            local is_peeking = reference.ragebot.quick_peek:get() and reference.ragebot.quick_peek.hotkey:get()

            local can_teleport = not ( player.crouching)
            local can_dt = false
            
            if weapon_t then
                local weapon_id = entity.get_prop(weapon, "m_iItemDefinitionIndex")
                
                local weapon_auto = weapon_t.is_full_auto
                local is_deagle = weapon_id == 1
    
                can_dt = weapon_auto
                
                if ( (weapon_t.weapon_type_int == 1 and not is_deagle) and not ui_handler.misc.auto_hideshots_wpns:get ("Pistols") )
                or ( is_deagle and not ui_handler.misc.auto_hideshots_wpns:get ("Deagle") ) then
                    can_dt = true
                end
            end

            local allow = player.onground and is_dt and not (can_dt or can_teleport)

            if allow then
                reference.ragebot.double_tap:override(false)
                reference.antiaim.onshot.hotkey:override({"Always on", 0})
                ovr = true
            else
                if ovr then
                    reference.ragebot.double_tap:override(true)
                    reference.antiaim.onshot.hotkey:override()
                    ovr = false
                end
            end
        end

        ui_handler.misc.auto_hideshots:set_callback(function (this)
            if not this.value then
                reference.ragebot.double_tap:override()
                reference.antiaim.onshot.hotkey:override()
            end
        end)
    end

    ui_handler.misc.filter:set_callback(function(self)
        cvar.con_filter_text:set_string('[aimsense]')
        cvar.con_filter_enable:set_raw_int(self.value and 1 or 0)
    end, true)

    defer(function()
        cvar.con_filter_enable:set_raw_int(tonumber(cvar.con_filter_enable:get_string()))
    end)

end

local callbacks = {} do
    function callbacks.start()
        client.exec("clear")
        client.color_log(0, 150, 255, 'starting..')
        client.color_log(0, 150, 255, 'hook 1 ')
        client.color_log(0, 150, 255, 'hook 2')
        client.color_log(0, 150, 255, 'hook 3')
        client.color_log(0, 150, 255, 'hook 4')
        client.color_log(0, 150, 255, 'other 37 hooks enabled')
        print("succesfully, welcome to aimsense debug!")
    end

    callbacks.start()

    function callbacks.predict_command(cmd)
        player.predict_command(cmd)
    end

    function callbacks.paint(ctx)
        Visuals.indicators.run()
        Visuals.manual_arrows.prerun()
        Visuals.draw_forced_watermark()
    end

    function callbacks.paint_ui()
        Visuals.hide_menu.run()
        Visuals.sidebar.run()
        Visuals.on_load.run()
    end

    function callbacks.net_update_end() 
        Miscellaneous.clantag()
    end

    function callbacks.setup_command(cmd)
        player.setup_command(cmd)
        Miscellaneous.auto_hideshots.run(cmd)
        anti_aim.features.main(cmd)
        anti_aim.builder.main(cmd)
        if ui_handler.Visuals.on_ground_options:get() == 'swag' and ui_handler.Visuals.animation_breaker:get("on ground") then
            reference.antiaim.leg_movement:set(cmd.command_number % 3 == 0 and "Off" or "Always slide")
        end
    end

    function callbacks.aim_fire(event)
        Miscellaneous.event_logger.aim_fire(event)
    end

    function callbacks.aim_hit(event)
        Miscellaneous.event_logger.aim_hit(event)
    end

    function callbacks.aim_miss(event)
        Miscellaneous.event_logger.aim_miss(event)
    end

    function callbacks.player_hurt(event)
        Miscellaneous.event_logger.player_hurt(event)
    end

end

client.set_event_callback('aim_fire', callbacks.aim_fire)
client.set_event_callback('aim_hit', callbacks.aim_hit)
client.set_event_callback('aim_miss', callbacks.aim_miss)
client.set_event_callback('player_hurt', callbacks.player_hurt)
client.set_event_callback("net_update_end", callbacks.net_update_end)
client.set_event_callback("paint_ui", callbacks.paint_ui)
client.set_event_callback("paint", callbacks.paint)
client.set_event_callback('finish_command', Visuals.finish_command)
client.set_event_callback('setup_command', callbacks.setup_command)
client.set_event_callback("pre_render", Visuals.animation_breaker.run)
client.set_event_callback('predict_command', callbacks.predict_command)

--@ все конец!

--region Aimsense
local lua = {}

--region math
math.clamp = function(value, minimum, maximum)
    assert(value and minimum and maximum, '')
    if minimum > maximum then minimum, maximum = maximum, minimum end
    return math.max(minimum, math.min(maximum, value))
end

math.lerping = function(a, b, w)
    return a + (b - a) * w
end

math.lerp = function(start, enp, time)
    time = time or 0.005
    time = math.clamp(globals.absoluteframetime() * time * 175.0, 0.01, 1.0)
    local a = math.lerping(start, enp, time)
    if enp == 0.0 and a < 0.02 and a > -0.02 then
        a = 0.0
    elseif enp == 1.0 and a < 1.01 and a > 0.99 then
        a = 1.0
    end
    return a
end

local events do
    local event_mt = { } do
        event_mt.__call = function(self, fn, bool)
            local action = bool and client.set_event_callback or client.unset_event_callback
            action(self[1], fn)
        end

        event_mt.set = function(self, fn)
            client.set_event_callback(self[1], fn)
        end

        event_mt.unset = function(self, fn)
            client.unset_event_callback(self[1], fn)
        end

        event_mt.__index = event_mt
    end

    events = setmetatable({}, {
        __index = function(self, index)
            self[index] = setmetatable({index}, event_mt)
            return self[index]
        end,
    })
end

lerp = function(a, b, t)
    return a + t * (b - a)
end

local animations = { } do
    animations.max_lerp_low_fps = (1 / 45) * 400
    animations.color_lerp = function(start, end_pos, time)
        local frametime = globals.frametime() * 350
        time = time * math.min(frametime, animations.max_lerp_low_fps)
        return lerp(start, end_pos, time)
    end
    
    animations.lerp = function(start, end_pos, time)
        if start == end_pos then
            return end_pos
        end
    
        local frametime = globals.frametime() * 350
        time = time * math.min(frametime, animations.max_lerp_low_fps)
    
        local val = start + (end_pos - start) * math.clamp(time, 0.01, 3)
    
        if(math.abs(val - end_pos) < 0.01) then
            return end_pos
        end
    
        return val
    end

    animations.base_speed = 1
    animations._list = {}

    animations.new = function(name, new_value, speed, init)
        speed = speed or animations.base_speed
        
        local is_color = type(new_value) == "userdata"

        if animations._list[name] == nil then
            animations._list[name] = (init and init) or (is_color and color(255) or 0)
        end

        local interp_func

        if is_color then
            interp_func = animations.color_lerp
        else
            interp_func = animations.lerp
        end

        animations._list[name] = interp_func(animations._list[name], new_value, speed)
        
        return animations._list[name]
    end
end

local screen_x, screen_y = client.screen_size()

local Visuals = { } do
    Visuals.RGBAtoHEX = function(redArg, greenArg, blueArg, alphaArg)
        return string.format('%.2x%.2x%.2x%.2x', redArg, greenArg, blueArg, alphaArg)
    end

    Visuals.gradient_text = function(time, string, r, g, b, a, r2, g2, b2, a2)
        local t_out, t_out_iter = {}, 1
    
        local r_add = (r2 - r)
        local g_add = (g2 - g)
        local b_add = (b2 - b)
        local a_add = (a2 - a)
    
        for i = 1, #string do
            local iter = (i - 1)/(#string - 1) + time
            t_out[t_out_iter] = "\a" .. Visuals.RGBAtoHEX(r + r_add * math.abs(math.cos(iter)), g + g_add * math.abs(math.cos(iter)), b + b_add * math.abs(math.cos(iter)), a + a_add * math.abs(math.cos(iter)))
    
            t_out[t_out_iter + 1] = string:sub(i, i)
    
            t_out_iter = t_out_iter + 2
        end
    
        return table.concat(t_out)
    end

    -- Основные функции для отрисовки
    Visuals.rec = function(x, y, w, h, radius, r, g, b, a)
        radius = math.min(w/2, h/2, radius)
        renderer.rectangle(x, y + radius, w, h - radius*2, r, g, b, a)
        renderer.rectangle(x + radius, y, w - radius*2, radius, r, g, b, a)
        renderer.rectangle(x + radius, y + h - radius, w - radius*2, radius, r, g, b, a)
        renderer.circle(x + radius, y + radius, r, g, b, a, radius, 180, 0.25)
        renderer.circle(x - radius + w, y + radius, r, g, b, a, radius, 90, 0.25)
        renderer.circle(x - radius + w, y - radius + h, r, g, b, a, radius, 0, 0.25)
        renderer.circle(x + radius, y - radius + h, r, g, b, a, radius, -90, 0.25)
    end
    
    Visuals.rec_outline = function(x, y, w, h, radius, thickness, r, g, b, a)
        radius = math.min(w/2, h/2, radius)
        renderer.rectangle(x + radius, y, w - radius*2, thickness, r, g, b, a)
        renderer.rectangle(x + radius, y + h - thickness, w - radius*2, thickness, r, g, b, a)
        renderer.rectangle(x, y + radius, thickness, h - radius*2, r, g, b, a)
        renderer.rectangle(x + w - thickness, y + radius, thickness, h - radius*2, r, g, b, a)
        renderer.circle_outline(x + radius, y + radius, r, g, b, a, radius, 180, 0.25, thickness)
        renderer.circle_outline(x + radius, y + h - radius, r, g, b, a, radius, 90, 0.25, thickness)
        renderer.circle_outline(x + w - radius, y + radius, r, g, b, a, radius, -90, 0.25, thickness)
        renderer.circle_outline(x + w - radius, y + h - radius, r, g, b, a, radius, 0, 0.25, thickness)
    end

    -- Функция для свечения уведомлений
    Visuals.glow_module_notify = function(x, y, w, h, width, rounding, r, g, b, a, has_inner)
        if has_inner then
            Visuals.rec(x, y, w, h, rounding, 25, 25, 25, a)
        end
        
        for k = 0, width do
            local alpha_mul = a/2 * (k/width)^3
            Visuals.rec_outline(x - k, y - k, w + k*2, h + k*2, rounding + k, 1, r, g, b, alpha_mul/1.5)
        end
    end
end

local misc = {
    aimbot_logs = {
        notify_data = {},
        hitgroup = {'generic', 'head', 'chest', 'stomach', 'left arm', 'right arm', 'left leg', 'right leg', 'neck', '?', 'gear'},
        fire_data = {hitchance = 0}
    }
}

function misc.aimbot_logs.notifications()
    if not ui_handler.Visuals.aimbot_logs:get() then 
        misc.aimbot_logs.notify_data = {}
        return 
    end

    --=== НАСТРОЙКИ ВНЕШНЕГО ВИДА ===--
    local base_y_offset = 80       -- Высота первого уведомления от низа экрана
    local spacing = 60             -- Расстояние между уведомлениями
    local notification_height = 46 -- Высота плитки уведомления
    local text_y_offset = -7      -- Смещение текста по вертикали (-1 = выше, 1 = ниже)
    local duration_visible = 3.5   -- Время видимости (сек)
    local duration_fade = 3.5     -- Время анимации (сек)
    --===============================--

    local current_time = globals.realtime()
    
    for i = #misc.aimbot_logs.notify_data, 1, -1 do
        local log = misc.aimbot_logs.notify_data[i]
        local time_alive = current_time - log.time
        
        -- Анимация появления/исчезания
        if time_alive < duration_fade then
            log.alpha = animations.lerp(log.alpha or 0, 255, 0.15)
        elseif time_alive > duration_visible then
            log.alpha = animations.lerp(log.alpha or 255, 0, 0.15)
            if log.alpha < 5 then
                table.remove(misc.aimbot_logs.notify_data, i)
                goto continue
            end
        end

        -- Позиционирование
        local y_pos = screen_y - (base_y_offset + ((i-1) * spacing))
        local text_width = renderer.measure_text("", log.text) + renderer.measure_text("b", " ") + 30
        local x_pos = screen_x / 2 - text_width / 2
        
        -- Отрисовка
        if log.alpha > 0 then
            -- Фон уведомления
            Visuals.glow_module_notify(x_pos, y_pos, text_width, notification_height, 7, 8, 
                log.color[1], log.color[2], log.color[3], log.alpha, true)
            
            -- Иконка (с учетом смещения текста)
            renderer.text(
                x_pos + 10, 
                y_pos + notification_height/2 + text_y_offset, 
                255, 199, 255, log.alpha, "b", "c", ""
            )
            
            -- Текст (с учетом смещения)
            renderer.text(
                x_pos + 35, 
                y_pos + notification_height/2 + text_y_offset, 
                255, 255, 255, log.alpha, "", "c", log.text
            )
        end
        
        ::continue::
    end
end

function misc.aimbot_logs.aim_fire(c)
    if not ui_handler.Visuals.aimbot_logs:get() then return end
    misc.aimbot_logs.fire_data.hitchance = math.floor(c.hit_chance)
end

function misc.aimbot_logs.aim_hit(c)
    if not ui_handler.Visuals.aimbot_logs:get() then return end

    local target = entity.get_player_name(c.target) or "unknown"
    local hitgroup = misc.aimbot_logs.hitgroup[c.hitgroup + 1] or '?'
    local damage = c.damage or 0
    local hitchance = misc.aimbot_logs.fire_data.hitchance or 0

    table.insert(misc.aimbot_logs.notify_data, {
        text = string.format("registered shot in %s's %s for %d dmg (hc: %d%%)", 
                           target:lower(), hitgroup, damage, hitchance),
        color = {ui_handler.Visuals.hit_color:get()},
        alpha = 0,
        time = globals.realtime()
    })
end

function misc.aimbot_logs.aim_miss(c)
    if not ui_handler.Visuals.aimbot_logs:get() then return end

    local target = entity.get_player_name(c.target) or "unknown"
    local reason = c.reason or "unknown"
    local hitchance = misc.aimbot_logs.fire_data.hitchance or 0

    table.insert(misc.aimbot_logs.notify_data, {
        text = string.format("missed shot at %s due to %s (hc: %d%%)", 
                           target:lower(), reason, hitchance),
        color = {ui_handler.Visuals.miss_color:get()},
        alpha = 0,
        time = globals.realtime()
    })
end

-- Инициализация
events.paint:set(misc.aimbot_logs.notifications)
events.aim_fire:set(misc.aimbot_logs.aim_fire)
events.aim_hit:set(misc.aimbot_logs.aim_hit)
events.aim_miss:set(misc.aimbot_logs.aim_miss)

client.set_event_callback("shutdown", function()
    events.paint:unset(misc.aimbot_logs.notifications)
    events.aim_fire:unset(misc.aimbot_logs.aim_fire)
    events.aim_hit:unset(misc.aimbot_logs.aim_hit)
    events.aim_miss:unset(misc.aimbot_logs.aim_miss)
end)

local misc_helpers = {}

local fps_cvars = {
    r_3dsky = cvar.r_3dsky:get_int(),
    fog_enable = cvar.fog_enable:get_int(),
    fog_enable_water_fog = cvar.fog_enable_water_fog:get_int(),
    fog_enableskybox = cvar.fog_enableskybox:get_int(),
    r_shadows = cvar.r_shadows:get_int(),
    violence_hblood = cvar.violence_hblood:get_int(),
    violence_ablood = cvar.violence_ablood:get_int(),
    r_decals = cvar.r_decals:get_int(),
    mat_postprocess_enable = cvar.mat_postprocess_enable:get_int(),
    cl_disable_ragdolls = cvar.cl_disable_ragdolls:get_int(),
    r_eyegloss = cvar.r_eyegloss:get_int(),
    r_eyemove = cvar.r_eyemove:get_int(),
    r_eyeshift_x = cvar.r_eyeshift_x:get_int(),
    r_eyeshift_y = cvar.r_eyeshift_y:get_int(),
    r_eyeshift_z = cvar.r_eyeshift_z:get_int(),
    r_eyesize = cvar.r_eyesize:get_int(),
    cl_detail_avoid_radius = cvar.cl_detail_avoid_radius:get_int(),
    cl_detail_max_sway = cvar.cl_detail_max_sway:get_int(),
    dsp_slow_cpu = cvar.dsp_slow_cpu:get_int(),
    func_break_max_pieces = cvar.func_break_max_pieces:get_int(),
    r_drawtracers = cvar.r_drawtracers:get_int(),
    r_dynamic = cvar.r_dynamic:get_int(),
    r_drawparticles = cvar.r_drawparticles:get_int(),
    muzzleflash_light = cvar.muzzleflash_light:get_int(),
    mat_hdr_enabled = cvar.mat_hdr_enabled:get_int(),
}

function misc_helpers.fps_boost(value)
    cvar.r_3dsky:set_int((value and ui_handler.misc.fps_opt:get('3D Sky')) and 0 or fps_cvars.r_3dsky)

    cvar.fog_enable:set_int((value and ui_handler.misc.fps_opt:get('Fog')) and 0 or fps_cvars.fog_enable)
    cvar.fog_enable_water_fog:set_int((value and ui_handler.misc.fps_opt:get('Fog')) and 0 or fps_cvars.fog_enable_water_fog)
    cvar.fog_enableskybox:set_int((value and ui_handler.misc.fps_opt:get('Fog')) and 0 or fps_cvars.fog_enableskybox)

    cvar.r_shadows:set_int((value and ui_handler.misc.fps_opt:get('Shadows')) and 0 or fps_cvars.r_shadows)

    cvar.violence_hblood:set_int((value and ui_handler.misc.fps_opt:get('Blood')) and 0 or fps_cvars.violence_hblood)
    cvar.violence_ablood:set_int((value and ui_handler.misc.fps_opt:get('Blood')) and 0 or fps_cvars.violence_ablood)

    cvar.r_decals:set_int((value and ui_handler.misc.fps_opt:get('Decals')) and 0 or fps_cvars.r_decals)

    cvar.mat_postprocess_enable:set_int((value and ui_handler.misc.fps_opt:get('Bloom')) and 0 or fps_cvars.mat_postprocess_enable)

    cvar.cl_disable_ragdolls:set_int((value and ui_handler.misc.fps_opt:get('Ragdols')) and 0 or fps_cvars.cl_disable_ragdolls)

    cvar.r_eyegloss:set_int((value and ui_handler.misc.fps_opt:get('Eye candy')) and 0 or fps_cvars.r_eyegloss)
    cvar.r_eyemove:set_int((value and ui_handler.misc.fps_opt:get('Eye candy')) and 0 or fps_cvars.r_eyemove)
    cvar.r_eyeshift_x:set_int((value and ui_handler.misc.fps_opt:get('Eye candy')) and 0 or fps_cvars.r_eyeshift_x)
    cvar.r_eyeshift_y:set_int((value and ui_handler.misc.fps_opt:get('Eye candy')) and 0 or fps_cvars.r_eyeshift_y)
    cvar.r_eyeshift_z:set_int((value and ui_handler.misc.fps_opt:get('Eye candy')) and 0 or fps_cvars.r_eyeshift_z)
    cvar.r_eyesize:set_int((value and ui_handler.misc.fps_opt:get('Eye candy')) and 0 or fps_cvars.r_eyesize)

    cvar.r_drawparticles:set_int((value and ui_handler.misc.fps_opt:get('Molotov')) and 0 or fps_cvars.r_drawparticles)

    cvar.cl_detail_avoid_radius:set_int((value and ui_handler.misc.fps_opt:get('Other')) and 0 or fps_cvars.cl_detail_avoid_radius)
    cvar.cl_detail_max_sway:set_int((value and ui_handler.misc.fps_opt:get('Other')) and 0 or fps_cvars.cl_detail_max_sway)
    cvar.dsp_slow_cpu:set_int((value and ui_handler.misc.fps_opt:get('Other')) and 0 or fps_cvars.dsp_slow_cpu)
    cvar.func_break_max_pieces:set_int((value and ui_handler.misc.fps_opt:get('Other')) and 0 or fps_cvars.func_break_max_pieces)
    cvar.r_drawtracers:set_int((value and ui_handler.misc.fps_opt:get('Other')) and 0 or fps_cvars.r_drawtracers)
    cvar.r_dynamic:set_int((value and ui_handler.misc.fps_opt:get('Other')) and 0 or fps_cvars.r_dynamic)
    cvar.muzzleflash_light:set_int((value and ui_handler.misc.fps_opt:get('Other')) and 0 or fps_cvars.muzzleflash_light)
    cvar.mat_hdr_enabled:set_int((value and ui_handler.misc.fps_opt:get('Other')) and 0 or fps_cvars.mat_hdr_enabled)
end

ui_handler.misc.fps_boost:set_callback(function(self)
    if self:get() and ui_handler.misc.fps_always:get() then
        misc_helpers.fps_boost(true)
    else
        misc_helpers.fps_boost(false)
    end
end)

ui_handler.misc.fps_always:set_callback(function(self)
    if ui_handler.misc.fps_boost:get() and self:get() then
        misc_helpers.fps_boost(true)
    else
        misc_helpers.fps_boost(false)
    end
end)

ui_handler.misc.fps_opt:set_callback(function(self)
    if ui_handler.misc.fps_boost:get() and ui_handler.misc.fps_always:get() then
        misc_helpers.fps_boost(true)
    else
        misc_helpers.fps_boost(false)
    end
end)



local ref = {
    aimbot = ui.reference('RAGE', 'Aimbot', 'Enabled'),
    doubletap = {
        main = { ui.reference('RAGE', 'Aimbot', 'Double tap') },
        fakelag_limit = ui.reference('RAGE', 'Aimbot', 'Double tap fake lag limit')
    }
}

local local_player, callback_reg, dt_charged = nil, false, false

local function check_charge()
    local m_nTickBase = entity.get_prop(local_player, 'm_nTickBase')
    local client_latency = client.latency()
    local shift = math.floor(m_nTickBase - globals.tickcount() - 3 - toticks(client_latency) * .5 + .5 * (client_latency * 10))

    local wanted = -14 + (ui.get(ref.doubletap.fakelag_limit) - 1) + 3 --error margin

    dt_charged = shift <= wanted
end

client.set_event_callback('setup_command', function()
    if not ui.get(ref.doubletap.main[2]) or not ui.get(ref.doubletap.main[1]) then
        ui.set(ref.aimbot, true)

        if callback_reg then
            client.unset_event_callback('run_command', check_charge)
            callback_reg = false
        end
        return
    end

    local_player = entity.get_local_player()

    if not callback_reg then
        client.set_event_callback('run_command', check_charge)
        callback_reg = true
    end

    local threat = client.current_threat()

    if not dt_charged
    and threat
    and bit.band(entity.get_prop(local_player, 'm_fFlags'), 1) == 0
    and bit.band(entity.get_esp_data(threat).flags, bit.lshift(1, 11)) == 2048 then
        ui.set(ref.aimbot, false)
    else
        ui.set(ref.aimbot, true)
    end
end)

client.set_event_callback('shutdown', function()
    ui.set(ref.aimbot, true)
end)

--region anti crasher
local CS_UM_SendPlayerItemFound = 63
local DispatchUserMessage_t = ffi.typeof [[ bool(__thiscall*)(void*, int msg_type, int nFlags, int size, const void* msg)
]]

local VClient018 = client.create_interface('client.dll', 'VClient018')
local pointer = ffi.cast('uintptr_t**', VClient018)
local vtable = ffi.cast('uintptr_t*', pointer[0])
local size = 0
while vtable[size] ~= 0x0 do
   size = size + 1
end

local hooked_vtable = ffi.new('uintptr_t[?]', size)
for i = 0, size - 1 do
    hooked_vtable[i] = vtable[i]
end

pointer[0] = hooked_vtable
local oDispatch = ffi.cast(DispatchUserMessage_t, vtable[38])
local function hkDispatch(thisptr, msg_type, nFlags, size, msg)
    if msg_type == CS_UM_SendPlayerItemFound then
        return false
    end

    return oDispatch(thisptr, msg_type, nFlags, size, msg)
end

client.set_event_callback('shutdown', function()
    hooked_vtable[38] = vtable[38]
    pointer[0] = vtable
end)
hooked_vtable[38] = ffi.cast('uintptr_t', ffi.cast(DispatchUserMessage_t, hkDispatch))
--endregion

local notify = (function()
    local vector = vector
    local lerp = function(a, b, t) return a + (b - a) * t end
    local screen_size = function() return vector(client.screen_size()) end
    local measure_text = function(font, text_to_measure) 
        return vector(renderer.measure_text(font, text_to_measure)) 
    end

    local NotificationSystem = {
        notifications = { bottom = {} },
        max = { bottom = 6 }
    }
    NotificationSystem.__index = NotificationSystem

    function NotificationSystem.new_bottom(r, g, b, ...)
        local screen = screen_size()
        table.insert(NotificationSystem.notifications.bottom, {
            started = false,
            instance = setmetatable({
                active = false,
                timeout = 5,
                color = { r = r, g = g, b = b, a = 0 }, 
                x = screen.x / 2,
                y = screen.y,
                text = {...}
            }, NotificationSystem)
        })
    end

    function NotificationSystem:handler()
        for i = #NotificationSystem.notifications.bottom, 1, -1 do 
            local notification = NotificationSystem.notifications.bottom[i]
            if notification and not notification.instance.active and notification.started then
                table.remove(NotificationSystem.notifications.bottom, i)
            end
        end

        local active_count = 0
        for i = 1, #NotificationSystem.notifications.bottom do
            if NotificationSystem.notifications.bottom[i].instance.active then
                active_count = active_count + 1
            end
        end

        for idx, notification in pairs(NotificationSystem.notifications.bottom) do
            if idx > NotificationSystem.max.bottom then break end 

            if notification.instance.active then
                notification.instance:render_bottom(idx, active_count)
            end
            
            if not notification.started then
                notification.instance:start()
                notification.started = true
            end
        end
    end

    function NotificationSystem:start()
        self.active = true
        self.delay = globals.realtime() + self.timeout
    end

    function NotificationSystem:get_text()
        local result = ""
        local text_parts_container = self.text[1] 
        
        if type(text_parts_container) == "table" then
            for i, part in pairs(text_parts_container) do
                local current_text_part = ""

                if part and part[1] ~= nil then
                    local p1_type = type(part[1])
                    if p1_type == "string" or p1_type == "number" or p1_type == "boolean" then
                        current_text_part = tostring(part[1])
                    else
                        current_text_part = "" 
                    end
                end

                local width = measure_text("", current_text_part).x 
                local r, g, b = 255, 255, 255
                if part and part[2] then 
                    r, g, b = 255, 255, 255 
                end

                result = result .. ("\a%02x%02x%02x%02x%s"):format(r, g, b, self.color.a, current_text_part)
            end
        end
        return result
    end

    local render_utils = (function()
        local utils = {}
        
        function utils.rounded_rect(x, y, w, h, radius, r, g, b, a)
            radius = math.min(w/2, h/2, radius)
            renderer.rectangle(x, y + radius, w, h - radius*2, r, g, b, a)
            renderer.rectangle(x + radius, y, w - radius*2, radius, r, g, b, a)
            renderer.rectangle(x + radius, y + h - radius, w - radius*2, radius, r, g, b, a)
            renderer.circle(x + radius, y + radius, r, g, b, a, radius, 180, 0.25)
            renderer.circle(x - radius + w, y + radius, r, g, b, a, radius, 90, 0.25)
            renderer.circle(x - radius + w, y - radius + h, r, g, b, a, radius, 0, 0.25)
            renderer.circle(x + radius, y - radius + h, r, g, b, a, radius, -90, 0.25)
        end
        
        function utils.rounded_rect_outline(x, y, w, h, radius, thickness, r, g, b, a)
            radius = math.min(w/2, h/2, radius)
            if radius == 1 then
                renderer.rectangle(x, y, w, thickness, r, g, b, a)
                renderer.rectangle(x, y + h - thickness, w, thickness, r, g, b, a)
            else
                renderer.rectangle(x + radius, y, w - radius*2, thickness, r, g, b, a)
                renderer.rectangle(x + radius, y + h - thickness, w - radius*2, thickness, r, g, b, a)
                renderer.rectangle(x, y + radius, thickness, h - radius*2, r, g, b, a)
                renderer.rectangle(x + w - thickness, y + radius, thickness, h - radius*2, r, g, b, a)
                renderer.circle_outline(x + radius, y + radius, r, g, b, a, radius, 180, 0.25, thickness)
                renderer.circle_outline(x + radius, y + h - radius, r, g, b, a, radius, 90, 0.25, thickness)
                renderer.circle_outline(x + w - radius, y + radius, r, g, b, a, radius, -90, 0.25, thickness)
                renderer.circle_outline(x + w - radius, y + h - radius, r, g, b, a, radius, 0, 0.25, thickness)
            end
        end
        
        function utils.glow_notification(x, y, w, h, width, rounding, r, g, b, a, has_inner)
            local thickness = 1
            local offset = 1

            if has_inner then
                utils.rounded_rect(x, y, w, h, rounding, 25, 25, 25, a) 
            end
            
            for i = 0, width do
                local alpha_mul = a/2 * (i/width)^3
                utils.rounded_rect_outline(
                    x - i, y - i, 
                    w + i*2, h + i*2, 
                    rounding + i, 1, 
                    r, g, b, alpha_mul/1.5
                )
            end
        end

        
        function utils.draw_animated_scanlines(x, y, w, h, base_alpha, speed)
            local line_height = 1 
            local line_spacing = 3 
            local line_color_r, line_color_g, line_color_b = 50, 255, 50 

            
            local offset_y = (globals.realtime() * speed) % (line_height + line_spacing)

            for current_y_offset = 0, h + line_spacing, line_height + line_spacing do
                local draw_y = y + current_y_offset - offset_y
                
                
                if draw_y < y then
                    draw_y = draw_y + h + line_spacing
                elseif draw_y > y + h + line_spacing then
                    draw_y = draw_y - (h + line_spacing)
                end


                if draw_y + line_height > y and draw_y < y + h then
                   
                    local line_alpha = math.min(base_alpha, 255) * 0.15 -- Очень тонкий эффект
                    renderer.rectangle(x, draw_y, w, line_height, line_color_r, line_color_g, line_color_b, line_alpha)
                end
            end
        end
        
        return utils
    end)()

    function NotificationSystem:render_bottom(index, active_count)
        local screen = screen_size()
        local padding = 6
        local text_render_offset_x = -5 -- Смещение текста влево на 5 пикселей
        local text = "      " .. self:get_text()
        local text_size = measure_text("", text)
        local rounding = 8
        local spacing = 5
        
        local width = padding + text_size.x + spacing*2
        local height = 12 + 10 + 1 
        
        local x = self.x - width/2
        local y = math.ceil(self.y - 40 + 0.4)

        local frame_time = globals.frametime()
        
        if globals.realtime() < self.delay then
            self.y = lerp(self.y, screen.y - 45 - (active_count - index) * (height + 15), frame_time * 7) 
            self.color.a = lerp(self.color.a, 255, frame_time * 2) 
        else
            self.y = lerp(self.y, self.y - 10, frame_time * 15)
            self.color.a = lerp(self.color.a, 0, frame_time * 20) 
            if self.color.a <= 1 then
                self.active = false
            end
        end
        
        if self.color.a > 0 then
            -- Отрисовываем фон уведомления
            render_utils.glow_notification(
                x, y, width, height, 15, rounding,
                25, 25, 25, self.color.a, 
                true
            )

            -- ОТРИСОВКА АНИМИРОВАННЫХ СКАН-ЛИНИЙ ПОВЕРХ ФОНА
            render_utils.draw_animated_scanlines(x, y, width, height, self.color.a, 20) -- Скорость 20, можно настроить

            local text_x = x + spacing + 2 + padding + text_render_offset_x -- ПРИМЕНЕНО СМЕЩЕНИЕ ТЕКСТА
            renderer.text(
                text_x, y + height/2 - text_size.y/2,
                self.color.r, self.color.g, self.color.b, self.color.a, 
                "M", nil, text
            )
        end
    end

    client.set_event_callback("paint_ui", function()
        NotificationSystem:handler()
    end)

    return NotificationSystem
end)()
    
    client.delay_call(2.3, function()
        notify.new_bottom(0, 180, 255, { { ' Aimsense |' }, { " Debug succesfully loaded" } })

end)
    
-- local functions
local screen_size = client.screen_size
local get_local_player = entity.get_local_player
local get_prop = entity.get_prop
local is_alive = entity.is_alive
local get_weapon = entity.get_player_weapon
local frametime = globals.frametime
local gradient = renderer.gradient

local ui_get = function(ref) return ref:get() end
local clamp = function(v, min, max) return math.max(min, math.min(max, v)) end
local easing = require "gamesense/easing"


local scope_overlay_ref = ui.reference("VISUALS", "Effects", "Remove scope overlay")

-- ui_handler
local v = ui_handler.Visuals
local alpha = 0


local function paint_ui()
    if v.custom_scope:get() then
        ui.set(scope_overlay_ref, true)
    end
end


local function paint()
    if not v.custom_scope:get() then return end

    
    ui.set(scope_overlay_ref, false)

    local me = get_local_player()
    if not me or not is_alive(me) then return end

    local weapon = get_weapon(me)
    if not weapon then return end

    local zoom_level = get_prop(weapon, "m_zoomLevel")
    local scoped = get_prop(me, "m_bIsScoped") == 1
    local resume_zoom = get_prop(me, "m_bResumeZoom") == 1

    local valid = zoom_level ~= nil and zoom_level > 0 and scoped and not resume_zoom

    local speed = ui_get(v.fade_animation_speed)
    local ft = speed > 3 and frametime() * speed or 1
    local fade = easing.linear(alpha, 0, 1, 1)

    alpha = clamp(alpha + (valid and ft or -ft), 0, 1)
    if alpha <= 0 then return end

    
    local w, h = screen_size()
    local offset = ui_get(v.scope_lines_offset) * h / 1080
    local pos = ui_get(v.scope_lines_initial_pos) * h / 1080
    local r, g, b, a = ui_get(v.scope_lines_color_picker)
    local final_a = a * fade

    
    gradient(w/2 - pos + 2, h/2, pos - offset, 1, r, g, b, 0, r, g, b, final_a, true)
    gradient(w/2 + offset, h/2, pos - offset, 1, r, g, b, final_a, r, g, b, 0, true)

    
    gradient(w/2, h/2 - pos + 2, 1, pos - offset, r, g, b, 0, r, g, b, final_a, false)
    gradient(w/2, h/2 + offset, 1, pos - offset, r, g, b, final_a, r, g, b, 0, false)
end


local function toggle_callbacks()
    local active = v.custom_scope:get()
    local _func = client[(active and "" or "un") .. "set_event_callback"]
    _func("paint_ui", paint_ui)
    _func("paint", paint)
end


v.custom_scope:set_callback(toggle_callbacks)
toggle_callbacks() -- 

local steam_name = panorama.open().MyPersonaAPI.GetName() or "player"
local current_time = "00:00"
local time_last_update = 0

-- === Функция для обновления времени ===
function update_watermark_time()
    local current_realtime = globals.realtime()
    if current_realtime - time_last_update > 5 then
        time_last_update = current_realtime
        http.get("http://a1147355.xsph.ru/luatime/get_time.php", function(success, response)
            if success and response.status == 200 then
                current_time = response.body:gsub("<[^>]*>", ""):gsub("^%s*(.-)%s*$", "%1")
                current_time = current_time:match("(%d%d:%d%d)") or current_time
            else
                current_time = "Server Err"
            end
        end)
    end
end

-- === Функция для отрисовки закругленного прямоугольника ===
function draw_rounded_rectangle(x, y, width, height, radius, r, g, b, a)
    -- Основной прямоугольник
    renderer.rectangle(x + radius, y, width - radius * 2, height, r, g, b, a)
    renderer.rectangle(x, y + radius, radius, height - radius * 2, r, g, b, a)
    renderer.rectangle(x + width - radius, y + radius, radius, height - radius * 2, r, g, b, a)
    
    -- Углы (упрощенная версия)
    for i = 0, radius do
        local offset = math.floor(radius - math.sqrt(radius * radius - i * i))
        if offset < radius then
            renderer.rectangle(x + offset, y + i, radius - offset, 1, r, g, b, a)
            renderer.rectangle(x + offset, y + height - i - 1, radius - offset, 1, r, g, b, a)
            renderer.rectangle(x + width - radius + offset, y + i, radius - offset, 1, r, g, b, a)
            renderer.rectangle(x + width - radius + offset, y + height - i - 1, radius - offset, 1, r, g, b, a)
        end
    end
end

-- === Анимация градиента ===
function get_gradient_color(time_offset)
    local time = globals.realtime() + time_offset
    local cycle = math.sin(time * 2) * 0.5 + 0.5  -- Значение от 0 до 1
    
    local red = 255
    local green = math.floor(60 + (195 * cycle))  -- От 60 до 255
    local blue = math.floor(60 + (195 * cycle))   -- От 60 до 255
    
    return {red, green, blue, 255}
end

-- === Основная функция отрисовки ватермарки ===
function draw_aimsense_watermark()
    -- Включается от ui_handler.Visuals.indicators
    if not ui_handler.Visuals.indicators:get() then return end

    update_watermark_time()

    -- Цвета
    local bg_color = {25, 25, 25, 200}  -- Темный фон
    local border_color = {60, 60, 60, 255}  -- Граница
    local text_white_color = {255, 255, 255, 255}  -- Белый текст
    local text_red_color = {255, 60, 60, 255}  -- Красный текст
    
    -- Цвета для анимации
    local gradient_color1 = get_gradient_color(0)
    local gradient_color2 = get_gradient_color(1)

    -- Используем жирный шрифт
    local font = "b"
    local font_size = 0

    local ping = math.floor(client.latency() * 1000)
    local fps = math.floor(1 / globals.frametime())
    local screen_width, screen_height = client.screen_size()

    -- Текстовые строки
    local aimsense_text = " AIMSENSE"
    local alpha_text = "RELEASE"
    
    -- Иконки (используем символы Unicode)
    local user_icon = ""
    local fps_icon = ""
    local ping_icon = ""
    local time_icon = ""

    -- Отступы и размеры
    local horizontal_padding = 12
    local vertical_padding = 6
    local item_spacing = 10
    local block_spacing = 6
    local border_radius = 3
    local stripe_height = 2
    local icon_spacing = 4  -- Расстояние между иконкой и текстом

    -- Измерение ширины текста и иконок
    local aimsense_w = renderer.measure_text(font, aimsense_text)
    local alpha_w = renderer.measure_text(font, alpha_text)
    
    -- Для второго блока измеряем каждый элемент отдельно
    local user_icon_w = renderer.measure_text(font, user_icon)
    local player_text_w = renderer.measure_text(font, steam_name)
    local fps_icon_w = renderer.measure_text(font, fps_icon)
    local fps_text_w = renderer.measure_text(font, fps .. " fps")
    local ping_icon_w = renderer.measure_text(font, ping_icon)
    local ping_text_w = renderer.measure_text(font, ping .. " ms")
    local time_icon_w = renderer.measure_text(font, time_icon)
    local time_text_w = renderer.measure_text(font, current_time)
    
    -- Высота текста
    local text_height = 13
    local block_height = text_height + (vertical_padding * 2)

    -- Размеры блоков
    local first_block_width = aimsense_w + alpha_w + (horizontal_padding * 2) + item_spacing
    
    -- Правильный расчет ширины второго блока
    local second_block_width = horizontal_padding * 2 + 
                              user_icon_w + icon_spacing + player_text_w + item_spacing +
                              fps_icon_w + icon_spacing + fps_text_w + item_spacing +
                              ping_icon_w + icon_spacing + ping_text_w + item_spacing +
                              time_icon_w + icon_spacing + time_text_w

    -- Позиционирование (верхний правый угол)
    local screen_margin_x = 12
    local screen_margin_y = 12
    local second_block_x = screen_width - screen_margin_x - second_block_width
    local first_block_x = second_block_x - block_spacing - first_block_width
    local block_y = screen_margin_y

    -- === Отрисовка первого блока (Aimsense Debug) ===
    -- Фон с закругленными углами
    draw_rounded_rectangle(first_block_x, block_y, first_block_width, block_height, border_radius, 
                          bg_color[1], bg_color[2], bg_color[3], bg_color[4])
    
    -- Анимированная полоска сверху
    for i = 0, first_block_width - 1 do
        local progress = i / first_block_width
        local color = get_gradient_color(progress * 2)
        renderer.rectangle(first_block_x + i, block_y, 1, stripe_height, color[1], color[2], color[3], color[4])
    end

    -- Текст первого блока
    local text_y = block_y + vertical_padding
    local current_x = first_block_x + horizontal_padding
    
    -- AIMSENSE (красный, жирный)
    renderer.text(current_x, text_y, text_red_color[1], text_red_color[2], text_red_color[3], text_red_color[4], font, font_size, aimsense_text)
    current_x = current_x + aimsense_w + item_spacing
    
    -- ALPHA (белый, жирный)
    renderer.text(current_x, text_y, text_white_color[1], text_white_color[2], text_white_color[3], text_white_color[4], font, font_size, alpha_text)

    -- === Отрисовка второго блока (статистика) ===
    -- Фон с закругленными углами
    draw_rounded_rectangle(second_block_x, block_y, second_block_width, block_height, border_radius,
                          bg_color[1], bg_color[2], bg_color[3], bg_color[4])
    
    -- Анимированная полоска снизу
    for i = 0, second_block_width - 1 do
        local progress = i / second_block_width
        local color = get_gradient_color(progress * 2 + 1)
        renderer.rectangle(second_block_x + i, block_y + block_height - stripe_height, 1, stripe_height, color[1], color[2], color[3], color[4])
    end

    -- Текст второго блока
    current_x = second_block_x + horizontal_padding
    
    -- Имя игрока с иконкой
    renderer.text(current_x, text_y, text_red_color[1], text_red_color[2], text_red_color[3], text_red_color[4], font, font_size, user_icon)
    current_x = current_x + user_icon_w + icon_spacing
    renderer.text(current_x, text_y, text_white_color[1], text_white_color[2], text_white_color[3], text_white_color[4], font, font_size, steam_name)
    current_x = current_x + player_text_w + item_spacing
    
    -- FPS с иконкой
    renderer.text(current_x, text_y, text_red_color[1], text_red_color[2], text_red_color[3], text_red_color[4], font, font_size, fps_icon)
    current_x = current_x + fps_icon_w + icon_spacing
    renderer.text(current_x, text_y, text_white_color[1], text_white_color[2], text_white_color[3], text_white_color[4], font, font_size, fps .. " fps")
    current_x = current_x + fps_text_w + item_spacing
    
    -- Ping с иконкой
    renderer.text(current_x, text_y, text_red_color[1], text_red_color[2], text_red_color[3], text_red_color[4], font, font_size, ping_icon)
    current_x = current_x + ping_icon_w + icon_spacing
    renderer.text(current_x, text_y, text_white_color[1], text_white_color[2], text_white_color[3], text_white_color[4], font, font_size, ping .. " ms")
    current_x = current_x + ping_text_w + item_spacing
    
    -- Время с иконкой
    renderer.text(current_x, text_y, text_red_color[1], text_red_color[2], text_red_color[3], text_red_color[4], font, font_size, time_icon)
    current_x = current_x + time_icon_w + icon_spacing
    renderer.text(current_x, text_y, text_white_color[1], text_white_color[2], text_white_color[3], text_white_color[4], font, font_size, current_time)
end

-- === Вызов при каждом кадре ===
client.set_event_callback("paint_ui", draw_aimsense_watermark)

-- === Инициализация ===
client.delay_call(0.1, function()
end)

-- local variables for API functions
local client_screen_size, entity_get_local_player, entity_get_player_weapon, entity_get_prop, entity_is_alive, globals_frametime, ui_get, ui_set =
    client.screen_size, entity.get_local_player, entity.get_player_weapon, entity.get_prop, entity.is_alive, globals.frametime, ui.get, ui.set

local clamp = function(v, min, max)
    local num = v
    num = num < min and min or num
    num = num > max and max or num
    return num
end

-- JumpScout Logic
local jump_scout_hotkey = ui_handler.aimtools.jump_scout
local hit_chance_ref = ui.reference("RAGE", "Aimbot", "Minimum hit chance")
local min_damage_ref = ui.reference("RAGE", "Aimbot", "Minimum damage")

local previous_hit_chance = nil
local previous_min_damage = nil

client.set_event_callback("run_command", function(cmd)
    if not jump_scout_hotkey:get() then return end

    local lp = entity_get_local_player()
    if not lp or not entity_is_alive(lp) then return end

    local weapon = entity_get_player_weapon(lp)
    if not weapon then return end

    local weapon_id = entity_get_prop(weapon, "m_iItemDefinitionIndex")
    if weapon_id ~= 40 then return end -- Only apply to SSG 08

    local flags = entity_get_prop(lp, "m_fFlags")
    local on_ground = bit.band(flags, 1) == 1

    if not on_ground then
        if previous_hit_chance == nil then
            previous_hit_chance = ui_get(hit_chance_ref)
            ui_set(hit_chance_ref, 0)
        end
        if previous_min_damage == nil then
            previous_min_damage = ui_get(min_damage_ref)
            ui_set(min_damage_ref, 1)
        end
    elseif previous_hit_chance ~= nil or previous_min_damage ~= nil then
        if previous_hit_chance ~= nil then
            ui_set(hit_chance_ref, previous_hit_chance)
            previous_hit_chance = nil
        end
        if previous_min_damage ~= nil then
            ui_set(min_damage_ref, previous_min_damage)
            previous_min_damage = nil
        end
    end
end)

local sentences = {
    "Мамашу твою ебали by AimSense.lua",
    "хуину в тебя закинул by AimSense.lua",
    "отсоси член и купи AimSense.lua",
    "все же ты отсосал лучшей луашке AimSense.lua",
    "вставай на колени перед AimSense",
    "ставлю 100$ что твоя мать не играла с AimSense",
    "ты че там играешь с Luasense? а мог бы ебашить с AimSense",
    "ебем паблики вместе с AimSense",
    "чую прилив сил когда даю на клык твоей матери вместе с AimSense",
    "запятнаем твое имя вместе с discord.gg/aimsense",
    "Лучшие сорта только тут discord.gg/aimsense",
    "снова сука где то плачет а все потому что не купила AimSense",
    "базарю ты хуй отсосешь потому что не юзаешь discord.gg/aimsense",
    "1 by discord.gg/aimsense",
    "Хватает бабосов на твою мать шлюху из за discord.gg/aimsense",
    "перед нами открыты все двери потому что юзаем AimSense",
    "лови хуец сын шалавы ты слабой by discord.gg/aimsense",
    "маманю твою ебал, что на это скажешь? by discord.gg/aimsense",
    "чисто мамашу твою тут на своем хуем перевернуля by AimSense",
    "чисто мамаше твоей хуй за щеку киданул by discord.gg/aimsense",
    "сын шлюхи, ты зачем свою мамашу на мой хуй бросил by discord.gg/aimsense",
    "чисто в ебало тебе член сую сын шлюхи, ты че такой серьезный, я же говорю что мать твою ебал by discord.gg/aimsense",
    "чисто матери сынка шлюхи обоссал бля буду by discord.gg/aimsense",
    "чисто по феншую мать твою паебываю ты заметил это by discord.gg/aimsense",
    "я щас тебе в ухо настучу своим членом, бармалей ты ебаный by discord.gg/aimsense",
    "сын шлюхи не спи, я мать твою ебал by discord.gg/aimsense",
    "бля буду мать твою выебал уже ты хули спать ушёл мудила кривоеблая by discord.gg/aimsense",
    "чисто мамашу твою через окно хуем выкинул by discord.gg/aimsense",
    "ты зачем мой хуй сосешь, пидорас дырявый by discord.gg/aimsense",
    "чисто мамашу твою отьебал тут by discord.gg/aimsense",
    "твою жирную мамашу вертел на хую by discord.gg/aimsense",
    "чет твоя слабая мамаша пиздаком вешается на мой хуй by discord.gg/aimsense",
    "ебучку сломал твоей мамашке by discord.gg/aimsense",
    "мамашу твою пидорасил об стену by discord.gg/aimsense",
    "давай быстрее хуй насасывай, опездол немощный by discord.gg/aimsense",
    "ну че вы там хуй принялись мой сосать, фанаты слабые? by discord.gg/aimsense",
    "чет нашел своим хуем в пиздаке твоей мамаши прошлогоднюю заначку by discord.gg/aimsense",
    "чет на своем волосатом мотороллере прокатил твою мамашу by discord.gg/aimsense",
    "внатуре разнес своей залупой табло вашим мамашкам, жалкие дети шлюх by discord.gg/aimsense",
    "какого хуя твоя мать использовала в локальной войне мой хуй как автомат калашникова? by discord.gg/aimsense",
    "чет продырявил твою жалкую мамашу by discord.gg/aimsense",
    "мамашу твою отпидорасил чет при всех by discord.gg/aimsense",
    "чёт в пиздаке твоей мамани устроил парад хуев by discord.gg/aimsense",
    "твою мамашу сдал на мясокомбинат нахуй, что бы себе чехол для хуя сшить by discord.gg/aimsense",
    "сейчас внатуре пиздак твоей мамани облею спермой, словно обоями нахуй by discord.gg/aimsense",
    "чет мой хуй в пиздаке твоей мамаши начинает по стенам долбить с силой титана by discord.gg/aimsense",
    "рассаду из хуев посадил в пиздак твоей мамаши by discord.gg/aimsense",
    "ну че откинулась-то, хуйня немощная by discord.gg/aimsense",
    "слабак давай хуй соси мой быстрее, опездол слабый by discord.gg/aimsense",
    "чет развел на анальные поебушки твою мамашу by discord.gg/aimsense",
    "на растрел хуев отвел мамашку твою, за то что мой хуец плохо насасывал by discord.gg/aimsense",
    "ты понимаешь, что я твою мать отправил хуем на орбиту, что бы она отражала своей пиздой метеоритную атаку? by discord.gg/aimsense",
    "хуем тебя в космос закинул, сын шлюхи by discord.gg/aimsense",
    "кости бросал твоей спидозной мамаше словно собаке by discord.gg/aimsense",
    "разобрал пиздак твоей мамаши словно это ак 47 by discord.gg/aimsense",
    "мда, снова пришлось окупировать твоё очко by discord.gg/aimsense",
    "ты там уже выдохся что ли, слабак ебанный by discord.gg/aimsense",
    "чисто на раз-два твоя мамаша свою калитку открывает, что бы мою залупу встретить by discord.gg/aimsense",
    "хуем разгадал пароль от анальных ворот твоей мамаши by discord.gg/aimsense",
    "хуем перевернул твой пиздак как футболку by discord.gg/aimsense",
    "сын шлюхи, ты зачем свою мамашу на мой хуй бросил by discord.gg/aimsense",
    "чет гланды разворотил мамаше твоей by discord.gg/aimsense",
    "хуем побывал в анальных пещерах твоей мамы by discord.gg/aimsense",
    "зачем когда ты мой хуй сосет, желание загадаешь? by discord.gg/aimsense",
    "слабак снова что ли свою мамашу проебал, когда с моим хуем боролся? by discord.gg/aimsense",
    "давай агрессивнее пиши, пока я снова твою мамульку не выебал by discord.gg/aimsense",
    "чурка ты че там мой хуй сосешь в пол силы, слабак ебанный? by discord.gg/aimsense",
    "внатуре опрокинул пиздак твоей мамульки своим хуем by discord.gg/aimsense",
    "чет хуем закидывал камни в пиздак твоей мамаши by discord.gg/aimsense",
    "сын шлюхи заебал уже на месте стоять и мой хуй сосать, опездол дырявый by discord.gg/aimsense",
    "я думаю ты уже догадался, что твоя мать своим очком скользит по моему хую by discord.gg/aimsense",
    "после того как я выебал твою мамашу, она кидается на мой хуй с голодными глазами как только его видит by discord.gg/aimsense",
    "чисто мамаше твоей хуй за щеку киданул by discord.gg/aimsense",
    "сижу тут бедолагу хуем в угол загоняю, а вы что делаете? by discord.gg/aimsense",
    "мамашу твою тут же растоптал члениной своей by discord.gg/aimsense",
    "сидит тут слабак, от безысходности свое ебало спермой облил, что бы не палить свое ебало покрасневшее by discord.gg/aimsense",
    "слабак, намотай сопли свои на кулак и дай отпор, сын шлюхи by discord.gg/aimsense",
    "пиздец тут маманю твою раскидал по хуям чисто by discord.gg/aimsense",
    "чисто мать твоя шлюха by discord.gg/aimsense",
    "сын шлюхи, быстрее хуй мой соси говорю by discord.gg/aimsense",
    "эй слабый, а ну быстро свою мамашу от моего хуя убери, пока я ей в щеку не уперся by discord.gg/aimsense",
    "ты че там кони двинул, сын пидораса by discord.gg/aimsense",
    "ты где там потерялся, сын шлюхи by discord.gg/aimsense",
    "я сказал мать твоя шлюха by discord.gg/aimsense",
    "а ну дай достойный отпор, что бы я твою мамашу не отпидорасил by discord.gg/aimsense",
    "чисто мамашу твою поёбывал тут by discord.gg/aimsense",
    "зачем твоя мамаша на мой хуй кидается, лол by discord.gg/aimsense",
    "эй слабак, хуй будешь? by discord.gg/aimsense",
    "я тебе сказал ебало завалить, сын шлюхи by discord.gg/aimsense",
    "твоей мамаше хуй за щеку присунул чет by discord.gg/aimsense",
    "ты че там заикаться то начал, опездол by discord.gg/aimsense",
    "чисто маманю твою по хуям пустил тут by discord.gg/aimsense",
    "слабый, оправдай свою маманю шлюху by discord.gg/aimsense",
    "чисто мамашу твою тут на своем хуем перевернуля by discord.gg/aimsense",
    "маманю твою ебал, что на это скажешь? by discord.gg/aimsense",
    "ты зачем на мой хуй уселся как на кресло-то? by discord.gg/aimsense",
    "ты мой хуй с вафлей перепутал? by discord.gg/aimsense",
    "я твою мать ебу, а ты влюбляешься чёт by discord.gg/aimsense",
    "в тебе хуев больше чем клеток by discord.gg/aimsense",
    "я из рта твоей мамаши хуем все слюни вытяну by discord.gg/aimsense",
    "ты не вафля нахуй, ты вафленок ебаный by discord.gg/aimsense",
    "в твоём рту хуев за день было больше чем посетителей в мавзолее за год by discord.gg/aimsense",
    "твой рот вместо купюр принемает хуи и только в пятитысячном размере by discord.gg/aimsense",
    "преисподняя сосет хуй и я тоже сосу хуй by discord.gg/aimsense",
    "твоя мать получат приз, как миллионый посетитель моего хуя by discord.gg/aimsense",
    "я бассами глушу звуки из очка твоей мамаши by discord.gg/aimsense",
    "ты по моему хую взбираешься, как джек по бобовому стеблю by discord.gg/aimsense",
    "ты мой хуй перевозишь в контробанде? by discord.gg/aimsense",
    "твой рот за мой хуй горой? by discord.gg/aimsense",
    "а ты знал, что мой хуй пищезаменитель твоей мамаши? by discord.gg/aimsense",
    "колчаном мать твою ебал by discord.gg/aimsense",
    "твоя мамаша динамик моего хуя by discord.gg/aimsense",
    "я бил посуду об пизду твоей мамаши by discord.gg/aimsense",
    "ебал твою мамашу на крыше дома твоего by discord.gg/aimsense",
    "мой хуй не ручка, зачем твоя мать написала себе на лбу моим хуем? by discord.gg/aimsense",
    "моим хуем откапывали храм в пизде твоей мамаши by discord.gg/aimsense",
    "твоя мама точит зубы об мой хуй by discord.gg/aimsense",
    "ебать ты чушка обосраная, а твоя мамаша пидораска картавая by discord.gg/aimsense",
    "как то пушкин сказал, что на пизде твоей мамаши больше волос чем у еврея by discord.gg/aimsense",
    "твоя мама хуесоска, а ты пидорас слизистый by discord.gg/aimsense",
    "ты слизняк моего хуя by discord.gg/aimsense",
    "твоя мамаша отдыхала в турции на моем хую by discord.gg/aimsense",
    "мать твою ебал, дурачок by discord.gg/aimsense",
    "понимаешь, что твоя мать мой хуй, как зеницу ока бережет by discord.gg/aimsense",
    "я хуем тебе ебло покрашу как тянки касметикой by discord.gg/aimsense",
    "я пиздак твоей матери хуем проткну как шар, и она лопнет by discord.gg/aimsense",
    "ты после моего хуя судьбу изменил, в нормальное русло by discord.gg/aimsense",
    "ты от моего хуя тикаешь как от ветра, ну это бесполезно, смирись by discord.gg/aimsense",
    "мой хуй тебя пиздил так же жестко как плеткой в старые былые времена by discord.gg/aimsense",
    "ты с моего хуя рот свой унести не можешь by discord.gg/aimsense",
    "ты уходишь по английски, после отсоса дверь за собой закрываешь by discord.gg/aimsense",
    "я твою мать так резко ебал что у нее пиздак дымком попахивал by discord.gg/aimsense",
    "ты на моем хую прыгаешь своей пиздой как важный by discord.gg/aimsense",
    "ты хочешь браслет себе на руку ввиде моего хуя by discord.gg/aimsense",
    "ты на моем хую тусишься очком своим как дом при взрыве by discord.gg/aimsense",
    "я пизду твоей матери положил у падика как коврик by discord.gg/aimsense",
    "мой хуй тебя из под земли достал и отъебал by discord.gg/aimsense",
    "я тебя хуем тискаю как дети плюшевые игрушки by discord.gg/aimsense",
    "твою мать в падике на перилах ебал by discord.gg/aimsense",
    "мой хуй в тебя вошел, у тебя аж на лобке волосы встали by discord.gg/aimsense",
    "ты мой хуй искал в пизде своей мамки by discord.gg/aimsense",
    "ты за моим хуем ухаживаешь как горничная by discord.gg/aimsense",
    "я пиздак твоей матери зажарил как яишницу by discord.gg/aimsense",
    "в 1945 была принята диклорация о посищение твоего рта на мой хуй by discord.gg/aimsense",
    "пизду твоей матери в мусорку кинул, он уже не годен для ебли by discord.gg/aimsense",
    "ты неможешь забыть мой член, как девушки первый поцелуй by discord.gg/aimsense",
    "ты для моего хуя со своего табора коня спиздил by discord.gg/aimsense",
    "ты пытался моему хую отсосать, ну он тебе отвечал 'абанент временно не доступин' ну просто твой рот заебал его by discord.gg/aimsense",
    "пиздак твоей матери на всалку пора отправлять, там уже карыто какое ето by discord.gg/aimsense",
    "я на пизде твоей матери трусы сушить щас буду by discord.gg/aimsense",
    "я хуем продырявил тебя так, что ты стал как тряпка половая by discord.gg/aimsense",
    "мой хуй для твоей матери как проводник в жизне by discord.gg/aimsense",
    "ты мой хуй воздушными поцелуями зацепить пытался by discord.gg/aimsense",
    "ты на последок мой член сосал как машина ебаная by discord.gg/aimsense",
    "я твою мать хотел поебать, а она и так уже дырявая by discord.gg/aimsense",
    "ты пизду свою стелишь под двери мои by discord.gg/aimsense",
    "я хуем тебе в лоб щас постучу нахуй by discord.gg/aimsense",
    "я твою мать щас на хуй положу как блин ебать by discord.gg/aimsense",
    "я на пизде твоей мамашки макароны жарил by discord.gg/aimsense",
    "я на пизде твоей матери каньками катался by discord.gg/aimsense",
    "я через пизду твоей матери тебя кормил by discord.gg/aimsense",
    "в пиздаке твоей матери мусор хуем вытащу щас by discord.gg/aimsense",
    "я твою мать на хуй насадил как на стул посадил by discord.gg/aimsense",
    "ты в мой хуй веришь как в чудо by discord.gg/aimsense",
    "ты мой хуй пытаешься курить как сигу by discord.gg/aimsense",
    "я твою мать хуем пну она в дерево уебется by discord.gg/aimsense",
    "я твою щеку хуем проткнул как оргалит ебать by discord.gg/aimsense",
    "ты на моем хую как футбольный мяч, мой хуй тебя пинает by discord.gg/aimsense",
    "я щас в твоем пиздаке хуем порядок наводить буду by discord.gg/aimsense",
    "я в пиздак твоей мамке хуем зашел как батька в дом нахуй by discord.gg/aimsense",
    "мне тебя с хуя стряхнуть как пепел с сигареты чтоле? by discord.gg/aimsense",
    "я успевал твоей матери еще на переменах в школе ща щеку сунуть by discord.gg/aimsense",
    "ты же на 23 февраля будешь свою пизду к моему хую приподносить by discord.gg/aimsense",
    "людям обычно в мае тепло, ну а ты как пидарас у меня под яйцами сидишь и греешься by discord.gg/aimsense",
    "я тебе щас крч в ухо кончу со рта выльется как бифидок нахуй by discord.gg/aimsense",
    "я в пизде твоей мамашки правлю своим хуем как ленин ленинградом в 41 сука by discord.gg/aimsense",
    "ты блять к моем хую со всем сердцем а он на тебя ссыт by discord.gg/aimsense",
    "я твоей матери на новый год в пизду алевьеху закинул и месил еблом твоим by discord.gg/aimsense",
    "ты нахуй своей пиздой на моем хую танец бойца исправлял, питух ебаный by discord.gg/aimsense",
    "твоя мать на мой хуй клюет, платва ебаная by discord.gg/aimsense",
    "твою мать хуем залил by discord.gg/aimsense",
    "я твою мать забориной ебал by discord.gg/aimsense",
    "я своим хуем оглушил тваю мамашу by discord.gg/aimsense",
    "твою мать сонную ебу, она еле оживает, как утка бля by discord.gg/aimsense",
    "я твою мать алкоголем ебал by discord.gg/aimsense",
    "твоя мать дрочит на меня by discord.gg/aimsense",
    "я твою мать качергой ебал by discord.gg/aimsense",
    "твой же рот мне на сцене сосал by discord.gg/aimsense",
    "мой хуй с твоей губой развлекается by discord.gg/aimsense",
    "я об пизду твоей матери бычки тушил by discord.gg/aimsense",
    "твою мать хуем избаловал чет by discord.gg/aimsense",
    "ты щеку потянул, когда мой хуй сосал by discord.gg/aimsense",
    "ты свою мамку по моему согласию ебал by discord.gg/aimsense",
    "я нождачкой хуярил по пизде твоей матери by discord.gg/aimsense",
    "я тёркой тер пиздак твоей матери by discord.gg/aimsense",
    "на ебло тебе ссу, карлик ты ебаный by discord.gg/aimsense",
    "я твою мать обоссал пока ты клитор сестре лизал by discord.gg/aimsense",
    "твою мать осудили пожизенно за гулянки с моим хуем by discord.gg/aimsense",
    "твою мать ебу в парке на лавочке by discord.gg/aimsense",
    "твоя мать на мой член с 5 этажа падала by discord.gg/aimsense",
    "твой рот на свой хуй одену щас by discord.gg/aimsense",
    "я твоей мамке хуем в глаз тыкал by discord.gg/aimsense",
    "я твоей матери на ебло кончал пока ты хуй отца сосал by discord.gg/aimsense",
    "хуем тебя на чистую правду выведу сука by discord.gg/aimsense",
    "ты свою мать учил хуй сосать я твой раб хуя by discord.gg/aimsense",
    "я твоей матери хуем по губе давал я твой раб хуя by discord.gg/aimsense",
    "твою мать за клубом хуем драл я твой раб хуя by discord.gg/aimsense",
    "ты на мой хуй трепещишь как скворец ебаный я твой раб хуя by discord.gg/aimsense",
    "я тебе ебло обосрал, опарыш ты ебаный by discord.gg/aimsense",
    "ты на мой хуй подсел как на спайс by discord.gg/aimsense",
    "я твоей матери хуем по щеке ударил, у нее челюсть сломалась by discord.gg/aimsense",
    "я твоей матери залупой по лбу хуярил пока ты мне яйца лизал by discord.gg/aimsense",
    "я твой пиздец на хую вертел, слабак by discord.gg/aimsense",
    "твоя мамаша мой хуй как трофей хранит by discord.gg/aimsense",
    "я твою мать хуем в асфальт закатал by discord.gg/aimsense",
    "ты мой хуй в пизде своей мамки искал, как золото в шахте by discord.gg/aimsense",
    "я твою мать на хую крутил как пропеллер by discord.gg/aimsense",
    "твой рот мой хуй как магнит притягивает by discord.gg/aimsense",
    "я твою мамашу хуем по спине хлестал by discord.gg/aimsense",
    "ты мой хуй сосешь, как будто это твой долг перед нацией by discord.gg/aimsense",
    "я твою мать в пизде её же трусами заткнул by discord.gg/aimsense",
    "твоя мамаша мой хуй как микрофон в караоке держит by discord.gg/aimsense",
    "я твою мать хуем по лбу стучал, как по барабану by discord.gg/aimsense",
    "ты мой хуй в жопе своей мамки нашел, археолог хуев by discord.gg/aimsense",
    "я твою мать на хую качал, как на карусели by discord.gg/aimsense",
    "твой рот мой хуй как вакуумная помпа засасывает by discord.gg/aimsense",
    "я твою мамашу хуем в угол загнал, как таракана by discord.gg/aimsense",
    "ты мой хуй сосешь, как будто это твой последний шанс на жизнь by discord.gg/aimsense",
    "я твою мать на хую вертел, как шашлык на мангале by discord.gg/aimsense",
    "твоя мамаша мой хуй как реликвию в музее хранит by discord.gg/aimsense",
    "я твою мать хуем по жопе шлепал, как по барабану by discord.gg/aimsense",
    "ты мой хуй в пизде своей мамки искал, как иголку в стоге сена by discord.gg/aimsense",
    "я твою мамашу на хую крутил, как на вертеле by discord.gg/aimsense",
    "твой рот мой хуй как черная дыра засасывает by discord.gg/aimsense",
    "я твою мать хуем в асфальт впечатал by discord.gg/aimsense",
    "ты мой хуй сосешь, как будто это твой единственный источник кислорода by discord.gg/aimsense",
    "я твою мамашу на хую качал, как на качелях by discord.gg/aimsense",
    "твоя мамаша мой хуй как трофей на стену повесила by discord.gg/aimsense",
    "я твою мать хуем по ебалу водил, как кистью по холсту by discord.gg/aimsense",
    "ты мой хуй в жопе своей мамки искал, как клад на острове by discord.gg/aimsense",
    "я твою мать на хую вертел, как на шампуре by discord.gg/aimsense",
    "твой рот мой хуй как пылесос засасывает by discord.gg/aimsense",
    "я твою мамашу хуем по спине гладил, как по струнам гитары by discord.gg/aimsense",
    "ты мой хуй сосешь, как будто это твой последний глоток воды в пустыне by discord.gg/aimsense",
    "я твою мать на хую крутил, как на карусели в парке by discord.gg/aimsense",
    "твоя мамаша мой хуй как святыню в храме хранит by discord.gg/aimsense",
    "я твою мать хуем по жопе хлестал, как плеткой by discord.gg/aimsense",
    "ты мой хуй в пизде своей мамки искал, как сокровище в пирамиде by discord.gg/aimsense",
    "я твою мамашу на хую вертел, как на вертеле над костром by discord.gg/aimsense",
    "твой рот мой хуй как магнитная лента притягивает by discord.gg/aimsense",
    "я твою мать хуем по лбу бил, как молотком по наковальне by discord.gg/aimsense",
    "ты мой хуй сосешь, как будто это твой единственный шанс на спасение by discord.gg/aimsense",
    "я твою мамашу на хую качал, как на карусели в луна-парке by discord.gg/aimsense",
    "твоя мамаша мой хуй как икону в церкви почитает by discord.gg/aimsense",
    "я твою мать хуем по жопе шлепал, как по барабану в оркестре by discord.gg/aimsense",
    "ты мой хуй в жопе своей мамки искал, как золото в реке by discord.gg/aimsense",
    "я твою мамашу на хую крутил, как на вертеле в печи by discord.gg/aimsense",
    "твой рот мой хуй как вакуумный насос засасывает by discord.gg/aimsense",
    "я твою мать хуем по ебалу водил, как по холсту кистью художника by discord.gg/aimsense",
    "ты мой хуй сосешь, как будто это твой последний шанс на искупление by discord.gg/aimsense"
}

local function on_player_death(event)
    local attacker = client.userid_to_entindex(event.attacker)
    local victim = client.userid_to_entindex(event.userid)

    if attacker == entity.get_local_player() and victim ~= entity.get_local_player() then

        local chat_spammer_enabled = ui_handler.misc.chat_spammre:get()

        if chat_spammer_enabled then
            local killsay = "say " .. sentences[math.random(#sentences)]
            client.exec(killsay)
        end
    end
end


local function toggle_trashtalk_callback()

    local is_trashtalk_enabled = ui_handler.misc.chat_spammre:get()

    if is_trashtalk_enabled then

        client.set_event_callback("player_death", on_player_death)
    else

        client.unset_event_callback("player_death", on_player_death)
    end
end


ui_handler.misc.chat_spammre:set_callback(toggle_trashtalk_callback)

toggle_trashtalk_callback()

local aspect_ratio_reference = ui_handler.Visuals.aspect_ratio 

if not aspect_ratio_reference then

    return 
end

local function set_aspect_ratio(aspect_ratio_multiplier)
    local screen_width, screen_height = client.screen_size()
    local aspectratio_value = (screen_width * aspect_ratio_multiplier) / screen_height

    if math.abs(aspect_ratio_multiplier - 1.0) < 0.001 then
        aspectratio_value = 0
    end
    client.set_cvar("r_aspectratio", tonumber(aspectratio_value))
end

local function gcd(m, n)
    while m ~= 0 do
        m, n = math.fmod(n, m), m;
    end
    return n
end

local aspect_ratio_table = {}
local screen_width, screen_height = client.screen_size()

for i = 1, 200 do
    local i2 = i * 0.01
    local multiplier = 2 - i2
    
    local divisor = gcd(math.floor(screen_width * multiplier + 0.5), screen_height)
    local aspect_ratio_str = string.format("%d:%d", math.floor(screen_width * multiplier / divisor + 0.5), screen_height / divisor)

    if math.floor(screen_width * multiplier / divisor + 0.5) < 100 or math.abs(multiplier - 1.0) < 0.001 then
        aspect_ratio_table[i] = aspect_ratio_str
    end
end



if type(aspect_ratio_reference.set_display_values) == "function" then
    aspect_ratio_reference:set_display_values(aspect_ratio_table)
else


end

local function on_aspect_ratio_changed()


    local slider_value 
    if type(aspect_ratio_reference.get) == "function" then
        slider_value = aspect_ratio_reference:get()
    else




        return 
    end

    if slider_value ~= nil and type(slider_value) == "number" then
        local aspect_ratio = slider_value * 0.01
        local multiplier = 2 - aspect_ratio 
        set_aspect_ratio(multiplier)
    end
end


if type(aspect_ratio_reference.set_callback) == "function" then
    aspect_ratio_reference:set_callback(on_aspect_ratio_changed)
else


end


on_aspect_ratio_changed()

local client_camera_angles, client_latency, client_screen_size, client_set_event_callback, entity_get_local_player, entity_get_player_resource, entity_get_player_weapon, entity_get_prop, entity_hitbox_position, entity_is_alive, globals_chokedcommands, globals_curtime, globals_tickcount, globals_tickinterval, math_abs, math_ceil, math_floor, math_max, math_min, renderer_gradient, renderer_indicator, renderer_load_svg, renderer_measure_text, renderer_rectangle, renderer_text, renderer_texture, table_insert, tonumber, unpack, pairs, type = client.camera_angles, client.latency, client.screen_size, client.set_event_callback, entity.get_local_player, entity.get_player_resource, entity.get_player_weapon, entity.get_prop, entity.hitbox_position, entity.is_alive, globals.chokedcommands, globals.curtime, globals.tickcount, globals.tickinterval, math.abs, math.ceil, math.floor, math.max, math.min, renderer.gradient, renderer.indicator, renderer_load_svg, renderer.measure_text, renderer.rectangle, renderer.text, renderer.texture, table.insert, tonumber, unpack, pairs, type

local dragging = (function() local a={}local b,c,d,e,f,g,h,i,j,k,l,m,n,o;local p={__index={drag=function(self,...)local q,r=self:get()local s,t=a.drag(q,r,...)if q~=s or r~=t then self:set(s,t)end;return s,t end,set=function(self,q,r)local j,k=client.screen_size()ui.set(self.x_reference,q/j*self.res)ui.set(self.y_reference,r/k*self.res)end,get=function(self)local j,k=client.screen_size()return ui.get(self.x_reference)/self.res*j,ui.get(self.y_reference)/self.res*k end}}function a.new(u,v,w,x)x=x or 10000;local j,k=client.screen_size()local y=ui.new_slider("LUA","A",u.." window position",0,x,v/j*x)local z=ui.new_slider("LUA","A","\n"..u.." window position y",0,x,w/k*x)ui.set_visible(y,false)ui.set_visible(z,false)return setmetatable({name=u,x_reference=y,y_reference=z,res=x},p)end;client.set_event_callback("paint",function()c=ui.is_menu_open()f,g=d,e;d,e=ui.mouse_position()i=h;h=client.key_state(0x01)==true;m=l;l={}o=n;n=false;j,k=client.screen_size()end)function a.drag(q,r,A,B,C,D,E)if c and i~=nil then if(not i or o)and h and f>q and g>r and f<q+A and g<r+B then n=true;q,r=q+d-f,r+e-g;if not D then q=math.max(0,math.min(j-A,q))r=math.max(0,math.min(k-B,r))end;if E then end end end;table.insert(l,{q,r,A,B})return q,r,A,B end;return a end)()
local ui_lib = (function() local function a(b,c,d,e)c=c or""d=d or 1;e=e or#b;local f=""for g=d,e do f=f..c..tostring(b[g])end;return f end;local function h(b,i)for g=1,#b do if b[g]==i then return true end end;return false end;local function j(k,...)if not k then error(a({...}),3)end end;local function l(b)local m,n=false,false;for o,k in pairs(b)do if type(o)=="number"then m=true else n=true end end;return m,n end;local p=globals.realtime()local q={}local r={}local s={}local function t(b)local u=false;for o,k in pairs(b)do if getmetatable(k)==s then u=true end end;return u end;local function v(k,w)return k~=q[w].default end;local function x(k)return#k>0 end;function s.__index(w,o)if q[w]~=nil and type(o)=="string"and o:sub(1,1)~="_"then return q[w][o]or r[o]end end;function s.__call(w,...)local y={...}if globals.realtime()==p and#y==1 and type(y[1])=="table"then local z={}local A=y[1]local B=false;local C=false;local D={}for o,k in pairs(A)do if type(o)~="number"then D[o]=k;C=true end end;if A[1]~=nil and(type(A[1])~="table"or not t(A[1]))then D[1]=A[1]B=true;if type(D[1])~="table"then D[1]={D[1]}end end;if C then table.insert(z,D)end;for g=B and 2 or 1,#A do if t(A[g])then table.insert(z,A[g])end end;for g=1,#z do local E=z[g]local k;if E[1]~=nil then k=E[1]end;for o,F in pairs(E)do if o~=1 then w:add_children(F,k,o)end end end;return w end;if#y==0 then return w:get()else local G,H=pcall(ui.set,y[1].reference,select(2,unpack(y)))end end;function s.__tostring(w)return"Menu item: "..w.tab.." - "..w.container.." - "..w.name end;function r.new(I,J,K,L,...)local y={...}local M,N;local O;if type(I)=="function"and I~=ui.reference then for o,k in pairs(ui)do if k==I and o:sub(1,4)=="new_"then O=o:sub(5,-1)end end;local G;G,M=pcall(I,J,K,L,unpack(y))if not G then error(M,2)end;N=I==ui.reference else M=I;N=true end;if O==nil then local k={pcall(ui.get,M)}if k[1]==false then O="button"else k={select(2,unpack(k))}if#k==1 then local P=type(k[1])if P=="string"then local G=pcall(ui.set,M,nil)ui.set(M,k[1])O=G and"textbox"or"combobox"elseif P=="number"then local G=pcall(ui.set,M,-9999999999999999)ui.set(M,k[1])O=G and"listbox"or"slider"elseif P=="boolean"then O="checkbox"elseif P=="table"then O="multiselect"end elseif#k>=2 and type(k[1])=="boolean"and type(k[2])=="number"then O="hotkey"elseif#k==4 then if type(k[1])=="number"and type(k[2])=="number"and type(k[3])=="number"and type(k[4])=="number"then O="color_picker"end end end end;local Q;if N==false and O~=nil then if O=="slider"then Q=y[3]or y[1]elseif O=="combobox"then Q=y[1][1]elseif O=="checkbox"then Q=false end end;local w={}q[w]={tab=J,container=K,name=L,reference=M,type=O,default=Q,visible=true,ui_callback=nil,callbacks={},is_gamesense_reference=N,children_values={},children_callbacks={}}if N==false and O~=nil then if O=="slider"then q[w].min=y[1]q[w].max=y[2]elseif O=="combobox"or O=="multiselect"or O=="listbox"then q[w].values=y[1]end end;return setmetatable(w,s)end;function r:set(...)local R={...}local S=q[self]local T={pcall(ui.set,S.reference,unpack(R))}end;function r:get()local S=q[self]return ui.get(S.reference)end;function r:contains(k)local S=q[self]if S.type=="multiselect"then return h(ui.get(S.reference),k)elseif S.type=="combobox"then return ui.get(S.reference)==k else error(string.format("Invalid type %s for contains",S.type),2)end end;function r:as_keys()local S=q[self]if S.type=="multiselect"then local k=ui.get(S.reference)local f={}for g=1,#k do f[k[g]]=true end;return f elseif S.type=="combobox"then return{[ui.get(S.reference)]=true}else error(string.format("Invalid type %s for as_keys",S.type),2)end end;function r:set_visible(U)local S=q[self]if S==nil then error("Invalid ui element",2)end;ui.set_visible(S.reference,U)S.visible=U end;function r:set_default(k)q[self].default=k;self:set(k)end;function r:add_children(V,W,o)local S=q[self]local X=type(W)=="function"if W==nil then W=true;if S.type=="boolean"then W=true elseif S.type=="combobox"then X=true;W=v elseif S.type=="multiselect"then X=true;W=x end end;if getmetatable(V)==s then V={V}end;for Y,F in pairs(V)do if X then q[F].parent_visible_callback=W else q[F].parent_visible_value=W end;self[o or F.reference]=F end;r._process_callbacks(self)end;function r:add_callback(Z)local S=q[self]table.insert(S.callbacks,Z)r._process_callbacks(self)end;r.set_callback=r.add_callback;function r:_process_callbacks()local S=q[self]if S.ui_callback==nil then local Z=function(M,_)local k=self:get()local a0=S.combo_elements;if a0~=nil and#a0>0 then local a1;for g=1,#a0 do local a2=a0[g]if#a2>0 then local a3={}for g=1,#a2 do if h(k,a2[g])then table.insert(a3,a2[g])end end;if#a3>1 then a1=a1 or k;for g=#a3,1,-1 do if h(S.value_prev,a3[g])and#a3>1 then table.remove(a3,g)end end;local a4=a3[1]for g=#a1,1,-1 do if a1[g]~=a4 and h(a2,a1[g])then table.remove(a1,g)end end elseif#a3==0 and not(a2.required==false)then a1=a1 or k;if S.value_prev~=nil then for g=1,#S.value_prev do if h(a2,S.value_prev[g])then table.insert(a1,S.value_prev[g])break end end end end end end;if a1~=nil then self:set(a1)end;S.value_prev=k;k=a1 or k end;for o,F in pairs(self)do local a5=q[F]local a6=false;if S.visible then if a5.parent_visible_callback~=nil then a6=a5.parent_visible_callback(k,self,F)elseif S.type=="multiselect"then local a7=type(a5.parent_visible_value)for g=1,#k do if a7 and h(a5.parent_visible_value,k[g])or a5.parent_visible_value==k[g]then a6=true;break end end elseif type(a5.parent_visible_value)=="table"then a6=a5.parent_visible_value[k]or h(a5.parent_visible_value,k)else a6=k==a5.parent_visible_value end end;ui.set_visible(a5.reference,a6)a5.visible=a6;if a5.ui_callback~=nil then a5.ui_callback(F)end end;for g=1,#S.callbacks do S.callbacks[g]()end end;ui.set_callback(S.reference,Z)S.ui_callback=Z end;S.ui_callback()end;local a8={}local a9={__index=function(Y,o)if a8[o]then return a8[o]end;local aa=o;if aa:sub(1,4)~="new_"then aa="new_"..aa end;if ui[aa]~=nil then local ab=ui[aa]return function(self,L,...)local y={...}local a0={}local ac=aa:sub(5,-1)local ad="Cannot create a "..ac..": "local w;if ab==ui.new_textbox and L==nil then L="\n"end;L=(self.prefix or"")..L..(self.suffix or"")if ab==ui.new_slider then local ae,af,ag,ah,ai,aj,ak=unpack(y)if type(ag)=="table"then local al=ag;ag=al.default;ah=al.show_tooltip;ai=al.unit;aj=al.scale;ak=al.tooltips end;if ag~=nil then end;if ai~=nil then end;ag=ag or nil;if ah==nil then ah=true end;ai=ai or nil;aj=aj or 1;ak=ak or nil;w=r.new(ui.new_slider,self.tab,self.container,L,ae,af,ag,ah,ai,aj,ak)elseif ab==ui.new_combobox or ab==ui.new_multiselect or ab==ui.new_listbox then local am={...}if#am==1 and type(am[1])=="table"then am=am[1]end;if ab==ui.new_multiselect then local an={}for g=1,#am do local I=am[g]if type(I)=="table"then table.insert(a0,I)for ao=1,#I do table.insert(an,I[ao])end else table.insert(an,I)end end;am=an end;for g=1,#am do local I=am[g]end;if ab==ui.new_multiselect then local G;G,w=pcall(r.new,ui.new_multiselect,self.tab,self.container,L,am)if not G then error(w,2)end end elseif ab==ui.new_hotkey then if y[1]==nil then y[1]=false end;local ap=unpack(y)elseif ab==ui.new_button then local Z=unpack(y)elseif ab==ui.new_color_picker then local aq,ar,as,at=unpack(y)end;if w==nil then local G;G,w=pcall(r.new,ab,self.tab,self.container,L,...)if not G then error(w,2)end end;self[q[w].reference]=w;if#a0>0 then q[w].combo_elements=a0;local au={}for g=1,#a0 do if not a0[g].required==false then table.insert(au,a0[g][1])end end;w:set(au)q[w].value_prev=au;r._process_callbacks(w)end;return w end end end}local av={RAGE={"Aimbot","Other"},AA={"Anti-aimbot angles","Fake lag","Other"},LEGIT={"Weapon type","Aimbot","Triggerbot","Other"},VISUALS={"Player ESP","Other ESP","Colored models","Effects"},MISC={"Miscellaneous","Settings","Lua","Other"},SKINS={"Weapon skin","Knife options","Glove options"},PLAYERS={"Players","Adjustments"},LUA={"A","B"}}for J,aw in pairs(av)do av[J]={}for g=1,#aw do av[J][aw[g]:lower()]=true end end;function a8.new(J,K)J=J:upper()return setmetatable({tab=J,container=K,items={}},a9)end;function a8.reference(J,K,L)if L==nil and type(J)=="table"and getmetatable(J)==a9 then L=K;J,K=J.tab,J.container end;local ax={pcall(ui.reference,J,K,L)}j(ax[1]==true,"Cannot reference a Gamesense menu item: the menu item does not exist.")local ay={select(2,unpack(ax))}local az={}for g=1,#ay do local M=ay[g]local w=r.new(M,J,K,L)table.insert(az,w)end;return unpack(az)end;local aA=setmetatable({},{__index=function(Y,o)if ui[o]~=nil and o~="new_string"and(o==ui.reference or o:sub(1,4)=="new_")then return function(...)local G,f=pcall(ui[o],...)if not G then error(f,2)end;return r.new(f,...)end end end})return setmetatable(a8,{__call=function(Y,...)return a8.new(...)end,__index=function(Y,aB)return r[aB]or aA[aB]or ui[aB]end}) end)()

local dragging_indicators = dragging.new("indicators", 10, 10)

-- Переупорядоченные bool_items
local bool_items = {
    ["Double tap"] = {
        references = {({ui_lib.reference("RAGE", "Aimbot", "Double tap")})[1], ({ui_lib.reference("RAGE", "Aimbot", "Double tap")})[2]},
        text = " DT",
        color = {255, 255, 255} -- White
    },
    ["Ping"] = {
        references = {({ui_lib.reference("MISC", "Miscellaneous", "Ping spike")})[1], ({ui_lib.reference("MISC", "Miscellaneous", "Ping spike")})[2]},
        text = " PING",
        color = {126, 195, 12} -- Green
    },
    ["MinDMG"] = {
        references = {({ui_lib.reference("RAGE", "Aimbot", "Minimum damage override")})[1], ({ui_lib.reference("RAGE", "Aimbot", "Minimum damage override")})[2]},
        text = " MD",
        color = {255, 255, 255} -- White
    },
    ["Freestanding"] = {
        references = {({ui_lib.reference("AA", "Anti-aimbot angles", "Freestanding")})[1], ({ui_lib.reference("AA", "Anti-aimbot angles", "Freestanding")})[2]},
        text = " FS",
        color = {255, 255, 255} -- White
    },
    ["FakeDuck"] = {
        references = {({ui_lib.reference("RAGE", "Other", "Duck peek assist")})[1], ({ui_lib.reference("RAGE", "Other", "Duck peek assist")})[2]},
        text = " DUCK",
        color = {255, 255, 255} -- White
    },
    ["OnShot"] = {
        references = {({ui_lib.reference("AA", "Other", "On shot anti-aim")})[1], ({ui_lib.reference("AA", "Other", "On shot anti-aim")})[2]},
        text = " OSAA",
        color = {255, 255, 255} -- White
    },
    ["PreferBody"] = {
        references = {({ui_lib.reference("RAGE", "Aimbot", "Force body aim")})[1], ({ui_lib.reference("RAGE", "Aimbot", "Force body aim")})[2]},
        text = " FORCE BODY",
        color = {255, 255, 0} -- White
    },
}

local function rectangle_outline(x, y, w, h, r, g, b, a, s)
	s = s or 1
	renderer_rectangle(x, y, w, s, r, g, b, a) -- top
	renderer_rectangle(x, y+h-s, w, s, r, g, b, a) -- bottom
	renderer_rectangle(x, y+s, s, h-s*2, r, g, b, a) -- left
	renderer_rectangle(x+w-s, y+s, s, h-s*2, r, g, b, a) -- right
end

local function table_contains(tbl, val)
	for i=1,#tbl do
		if tbl[i] == val then
			return true
		end
	end
	return false
end

local function normalize_yaw(angle)
	angle = (angle % 360 + 360) % 360
	return angle > 180 and angle - 360 or angle
end

local bar_min_width = 130

local math_lerp = function(a, b, t) return a + (b - a) * t end

-- Цвет Double Tap
local dt_r, dt_g, dt_b = 255, 255, 255 -- начальный цвет: белый
local dt_alpha = 0

local svg_patterns = {}

local function table_get_keys(tbl)
	local keys = {}
	for key, _ in pairs(tbl) do
		table_insert(keys, key)
	end
	return keys
end

local function gen_pattern(width, height)
	local svg = [[
<svg width="]] .. width .. [[" height="]] .. height .. [[" viewBox="0 0 ]] .. width .. [[ ]] .. height .. [[">
<rect width="]] .. width .. [[" height="]] .. height .. [[" y="0" x="0" fill="#151515"/>
#pattern
</svg>
]]
	for x=0, width, 4 do
		for y=0, height, 4 do
			local pattern = [[
<rect height="3" width="1" x="]] .. x+1 .. [[" y="]] .. y .. [[" fill="#0d0d0d"/>
<rect height="1" width="1" x="]] .. x+3 .. [[" y="]] .. y .. [[" fill="#0d0d0d"/>
<rect height="2" width="1" x="]] .. x+3 .. [[" y="]] .. y+2 .. [[" fill="#0d0d0d"/>
]]
			svg = svg:gsub("#pattern", pattern .. "#pattern")
		end
	end
	svg = svg:gsub("#pattern\n", "")
	return svg
end

local function draw_container(x, y, w, h, a, header, background_pattern)
	a = a or 255
	rectangle_outline(x, y, w, h, 18, 18, 18, a)
	rectangle_outline(x+1, y+1, w-2, h-2, 62, 62, 62, a)
	rectangle_outline(x+2, y+2, w-4, h-4, 44, 44, 44, a, 3)
	rectangle_outline(x+5, y+5, w-10, h-10, 62, 62, 62, a)

	if background_pattern then
		local rw, ph, lxa, pw = w-12, h-12, 0

		for i=6, 2, -1 do
			pw = 2^i
			if rw % pw < 7 then
				break
			end
		end

		for i=1, 2 do
			if svg_patterns[pw] == nil or svg_patterns[pw][ph] == nil then
				svg_patterns[pw] = svg_patterns[pw] or {}
				svg_patterns[pw][ph] = renderer_load_svg(gen_pattern(pw, ph), pw, ph) or -1
			end

			if svg_patterns[pw][ph] ~= -1 then
				for xa=0, rw-pw, pw do
					renderer_texture(svg_patterns[pw][ph], x+6+xa+lxa, y+6, pw, ph, 255, 255, 255, a)
				end
			end

			if rw % pw == 0 then break end
			lxa, pw = rw - (rw % pw), rw % pw
			rw = pw
		end
	else
		renderer_rectangle(x+6, y+6, w-12, h-12, 25, 25, 25, a)
	end

	if header then
		local x, y = x+7, y+7
		local w1, w2 = math_floor((w-14)/2), math_ceil((w-14)/2)

		for i=1, 2 do
			renderer_gradient(x, y, w1, 1, 59, 175, 222, a, 202, 70, 205, a, true)
			renderer_gradient(x+w1, y, w2, 1, 202, 70, 205, a, 201, 227, 58, a, true)
			y, a = y+1, a*0.2
		end
	end
end

local custom_items_names, custom_items_groups = {}, {}

local j=1
-- For loop below will cause an error because custom_items is removed.
-- I am commenting it out based on the user's explicit request to remove custom_items.
-- for i=1, #custom_items do
-- 	local item = custom_items[i]
-- 	if item.group == nil then
-- 		table_insert(custom_items_names, item.name)
-- 		j = j + 1
-- 	else
-- 		if custom_items_groups[item.group] == nil then
-- 			custom_items_groups[item.group] = {i=j}
-- 		end
-- 		table_insert(custom_items_groups[item.group], item)
-- 	end
-- end

-- for _, group_items in pairs(custom_items_groups) do
-- 	local names = {}
-- 	for i=1,#group_items do
-- 		table.insert(names, group_items[i].name)
-- 	end
-- 	table.insert(custom_items_names, group_items.i, names)
-- end

-- Assuming `ui_handler` is defined elsewhere or meant to be a global
-- for the purpose of accessing UI elements. For a standalone script,
-- you might need to define these UI elements directly using ui_lib.new()

-- Placeholder for ui_handler. This needs to be defined if it's not provided by the Gamesense environment.
-- For example:
-- ui_handler = {
--     Visuals = {
--         customindicators = ui_lib.new_checkbox("VISUALS", "Other ESP", "Custom Indicators Toggle", false),
--         custom_types = ui_lib.new_multiselect("VISUALS", "Other ESP", "Custom Indicators", custom_items_names),
--         custom_color = ui_lib.new_color_picker("VISUALS", "Other ESP", "Custom Indicators Color", 255, 255, 255, 255)
--     }
-- }
-- You may need to adjust the path ("VISUALS", "Other ESP") based on your Gamesense menu structure.
-- If `ui_handler` is indeed a global provided by Gamesense, then this comment can be ignored,
-- but the issue might be that the specific UI elements it tries to reference (like customindicators)
-- don't exist or are named differently in your Gamesense setup.

client_set_event_callback("paint", function()
    if not entity_is_alive(entity_get_local_player()) then return end

    -- Assuming ui_handler and its properties are correctly initialized/available
    -- If ui_handler.Visuals.customindicators is not defined, it will cause an error.
    -- Ensure you have defined UI elements for `customindicators`, `custom_types`, and `custom_color`
    -- in your Gamesense configuration or within this script if they are not globals.
    -- Example placeholder:
    local ui_handler = ui_handler or {}
    ui_handler.Visuals = ui_handler.Visuals or {}
    ui_handler.Visuals.customindicators = ui_handler.Visuals.customindicators or {get = function() return true end} -- Default to true for testing if not defined
    -- Note: ui_handler.Visuals.custom_types will likely cause an error if custom_items_names is empty or nil due to removal of custom_items table
    ui_handler.Visuals.custom_types = ui_handler.Visuals.custom_types or {get = function() return {} end} -- Default to empty table if not defined
    ui_handler.Visuals.custom_color = ui_handler.Visuals.custom_color or {get = function() return 255, 255, 255, 255 end} -- Default to white if not defined


    -- Check if the main checkbox for custom indicators is enabled.
    -- If it's not, nothing will be drawn.
    if not ui_handler.Visuals.customindicators:get() then return end

    -- All indicators will now draw if ui_handler.Visuals.customindicators is true.

    local y_pos = 10 -- Starting Y position for the first set of indicators

    -- Automatically include ALL bool_items (Built-in indicators)
    -- This section will always run if ui_handler.Visuals.customindicators is true,
    -- effectively enabling all 'bool_items' automatically without needing 'additional_indicators' UI element.
    local active_bool_items_names = {}
    -- Вставка элементов в активный список в заданном порядке
    table.insert(active_bool_items_names, " DT")
    table.insert(active_bool_items_names, " PING")
    table.insert(active_bool_items_names, " MD")
    table.insert(active_bool_items_names, " FS")
    table.insert(active_bool_items_names, " DUCK")
    table.insert(active_bool_items_names, " OSAA")
    table.insert(active_bool_items_names, " FORCE BODY")


    if #active_bool_items_names > 0 then
        -- Use renderer_indicator to get the starting Y position for additional indicators
        y_pos = renderer_indicator(255, 255, 255, 0, "Built-in Indicators") -- Changed text for clarity

        for _, item_name_to_draw in ipairs(active_bool_items_names) do
            local item = nil
            -- Find the item in bool_items based on its 'text' field (which contains the symbol + name)
            for _, bool_item in pairs(bool_items) do
                if bool_item.text == item_name_to_draw then
                    item = bool_item
                    break
                end
            end

            if item then
                local enabled = true
                for j = 1, #item.references do
                    local value = item.references[j]:get()
                    if not value or (type(value) == "table" and #value == 0) then
                        enabled = false
                        break
                    end
                end

                -- Alpha animation for appearance/disappearance
                item.alpha = item.alpha or 0
                local target_alpha = enabled and 255 or 0
                item.alpha = math_floor(math_lerp(item.alpha, target_alpha, 0.1))


                if item.alpha > 0 then
                    local r, g, b = 255, 255, 255 -- Default white color

                    -- Specific colors for certain indicators
                    if item.text == " PING" then
                        r, g, b = 126, 195, 12 -- Green for Ping
                    elseif item.text == " FORCE BODY" then
                        r, g, b = 255, 255, 0 -- Yellow for Force Body
                    end

                    if item.width == nil or item.height == nil then
                        item.width, item.height = renderer_measure_text("+", item.text)
                    end
                    renderer_text(10, y_pos, r, g, b, item.alpha, "+", 0, item.text)
                    y_pos = y_pos + item.height + 2
                end
            end
        end
    end

    ---
    --- Custom Indicators (Will not draw anything as custom_items table is removed)
    ---

    local screen_width, screen_height = client_screen_size()
    local x, y_pos_custom = dragging_indicators:get() -- Use a separate y_pos for custom indicators
    local align_right = x > screen_width / 2
    local margin = 3
    local types = ui_handler.Visuals.custom_types:get() -- Assuming ui_handler.Visuals.custom_types
    local items_drawn, text_width = {}, 0

    -- This loop will not add any items to items_drawn because custom_items is removed.
    -- for i = 1, #custom_items do
    --     local item = custom_items[i]
    --     local should_draw_item = false

    --     if item.group ~= nil then
    --         if table_contains(types, item.group) then
    --             should_draw_item = item.get_should_draw == nil or item:get_should_draw()
    --         end
    --     else
    --         should_draw_item = table_contains(types, item.name) and (item.get_should_draw == nil or item:get_should_draw())
    --     end

    --     if should_draw_item then
    --         item.width, item.height = item:get_size(item:get_text_width())
    --         text_width = math_max(text_width, item.width)
    --         table.insert(items_drawn, item)
    --     end
    -- end

    -- This block will not execute if items_drawn is empty.
    if #items_drawn > 0 then
        text_width = math_max(text_width+30, bar_min_width)
        local total_height = 12 + #items_drawn*12 - 2

        local r, g, b, a = ui_handler.Visuals.custom_color:get()

        draw_container(x, y_pos_custom, text_width+20, total_height+10, 255, true, true)

        local inner_x = x + 10
        local current_y = y_pos_custom + 15

        for i = 1, #items_drawn do
            local item = items_drawn[i]

            -- Alpha animation for each custom indicator
            local should_show = item.get_should_draw and item:get_should_draw()
            local target_alpha = should_show and 255 or 0
            item.alpha = item.alpha or 0 -- Initialize alpha for custom items
            local current_alpha = math_floor(math_lerp(item.alpha, target_alpha, 0.1))
            item.alpha = current_alpha -- Update item's alpha


            -- Apply common color or item-specific color
            local item_r, item_g, item_b = r, g, b

            -- Logic for Double Tap — color change
            if item.name == "Double tap" then
                local local_player = entity_get_local_player()
                local weapon = entity_get_player_weapon(local_player)
                if weapon and entity_is_alive(local_player) then
                    local next_attack = math_max(entity_get_prop(weapon, "m_flNextPrimaryAttack") or 0, entity_get_prop(local_player, "m_flNextAttack") or 0)
                    if globals_curtime() > next_attack then
                        dt_r = math_floor(math_lerp(dt_r, 126, 0.1))
                        dt_g = math_floor(math_lerp(dt_g, 195, 0.1))
                        dt_b = math_floor(math_lerp(dt_b, 12, 0.1)) -- Green
                    else
                        dt_r = math_floor(math_lerp(dt_r, 230, 0.1))
                        dt_g = math_floor(math_lerp(dt_g, 230, 0.1))
                        dt_b = math_floor(math_lerp(dt_b, 39, 0.1)) -- Yellow
                    end
                else
                    dt_r = math_floor(math_lerp(dt_r, 255, 0.1)) -- White
                    dt_g = math_floor(math_lerp(dt_g, 255, 0.1)) -- White
                    dt_b = math_floor(math_lerp(dt_b, 255, 0.1)) -- White
                end
                item_r, item_g, item_b = dt_r, dt_g, dt_b
            end
            -- Apply item's own alpha
            local item_alpha = current_alpha

            item:draw(inner_x, current_y, item.width, item.height, align_right, item:get_text_width(), item_r, item_g, item_b, item_alpha)
            current_y = current_y + 12
        end
    end
end) 

local ui_handler = {} -- Предположим, что ui_handler содержит ваши UI элементы
ui_handler.Visuals = {}

-- Здесь ui_handler.Visuals.customindicators должен быть вашей переменной чекбокса
-- Например, если вы определяете чекбокс так:
-- ui_handler.Visuals.customindicators = group1:checkbox("󰋑 Custom Indicators")
-- То для проверки его состояния нужно использовать .active (или аналогичное свойство)
local customIndicatorsCheckbox = ui_handler.Visuals.customindicators -- Предполагаем, что это ссылка на объект чекбокса

if customIndicatorsCheckbox and customIndicatorsCheckbox.active then
    client.delay_call(0.5, function()
        notify.new_bottom(0, 180, 255, { { ' AimSense |' }, { " Disable Skeet Indicators Manually" } })
    end)
end

