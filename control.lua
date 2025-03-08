
--[[
 * Converts an RGB color value to HSL. Conversion formula
 * adapted from http://en.wikipedia.org/wiki/HSL_color_space.
 * Assumes r, g, and b are contained in the set [0, 255] and
 * returns h, s, and l in the set [0, 1].
]]
---@param r number [0, 255]
---@param g number [0, 255]
---@param b number [0, 255]
---@param a number? [0, 255]
---@return float, float, float, float
function rgb_to_hsl(r, g, b, a)
    r, g, b = r / 255, g / 255, b / 255

    local max, min = math.max(r, g, b), math.min(r, g, b)
    local h, s, l

    l = (max + min) / 2

    if max == min then
        h, s = 0, 0 -- achromatic
    else
        local d = max - min
        if l > 0.5 then s = d / (2 - max - min) else s = d / (max + min) end
        if max == r then
            h = (g - b) / d
            if g < b then h = h + 6 end
        elseif max == g then
            h = (b - r) / d + 2
        elseif max == b then
            h = (r - g) / d + 4
        end
        h = h / 6
    end

    return h, s, l, a or 255
end

--[[
   * Converts an HSL color value to RGB. Conversion formula
   * adapted from http://en.wikipedia.org/wiki/HSL_color_space.
   * Assumes h, s, and l are contained in the set [0, 1] and
   * returns r, g, and b in the set [0, 255].
]]
---@param h float [0, 1]
---@param s float [0, 1]
---@param l float [0, 1]
---@param a float? [0, 1]
---@return integer, integer, integer, integer
function hsl_to_rgb(h, s, l, a)
    local r, g, b

    if s == 0 then
        r, g, b = l, l, l -- achromatic
    else
        function hue2rgb(p, q, t)
            if t < 0 then t = t + 1 end
            if t > 1 then t = t - 1 end
            if t < 1 / 6 then return p + (q - p) * 6 * t end
            if t < 1 / 2 then return q end
            if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
            return p
        end

        local q
        if l < 0.5 then q = l * (1 + s) else q = l + s - l * s end
        local p = 2 * l - q

        r = hue2rgb(p, q, h + 1 / 3)
        g = hue2rgb(p, q, h)
        b = hue2rgb(p, q, h - 1 / 3)
        a = a or 1
    end

    return r * 255, g * 255, b * 255, a * 255
end

---@param color Color
---@return Color
local function normalize_color(color)
    local r, g, b = color.r, color.g, color.b
    local h, s, l = rgb_to_hsl(r, g, b)
    local new_r, new_g, new_b = hsl_to_rgb(h, .6, .5)
    return { r = new_r, g = new_g, b = new_b }
end

---@param tiles LuaTile[]
---@return LuaTilePrototype
local function get_dominant_tile(tiles)
    local tile_counts = {}
    for _, tile in pairs(tiles) do
        if tile.valid then
            local tile_name = tile.double_hidden_tile or tile.hidden_tile or tile.name
            tile_counts[tile_name] = tile_counts[tile_name] or 0
            tile_counts[tile_name] = tile_counts[tile_name] + 1
        end
    end
    local dominant_tile_name, max_count = nil, 0
    for tile_name, count in pairs(tile_counts) do
        if count > max_count then
            dominant_tile_name = tile_name
            max_count = count
        end
    end
    return prototypes["tile"][dominant_tile_name]
end

---@param entity LuaEntity
---@return Color
local function get_biome_color(entity)
    local tiles = entity.surface.find_tiles_filtered { position = entity.position, radius = 2 }
    local dominant_tile = get_dominant_tile(tiles)
    if not dominant_tile then dominant_tile = entity.surface.get_tile(entity.position.x, entity.position.y).prototype end
    local map_color = dominant_tile.map_color
    local tile_color = { r = map_color.r, g = map_color.g, b = map_color.b }
    final_color = normalize_color(tile_color)
    return final_color
end

---@param event EventData.on_script_trigger_effect
local function on_script_trigger_event(event)
    if event.effect_id ~= "biome-color-combinator" then return end
    local combinator = event.source_entity
    if not (combinator and combinator.valid) then return end
    local control_behavior = combinator.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    if not control_behavior then return end
    local biome_color_section = control_behavior.get_section(1)
    if not biome_color_section then return end
    local biome_color = get_biome_color(combinator)
    biome_color_section.set_slot(1, {
        value = {
            type = "virtual", name = "signal-red", comparator = "=", quality = "normal"
        },
        min = biome_color.r
    })
    biome_color_section.set_slot(2, {
        value = {
            type = "virtual", name = "signal-green", comparator = "=", quality = "normal"
        },
        min = biome_color.g
    })
    biome_color_section.set_slot(3, {
        value = {
            type = "virtual", name = "signal-blue", comparator = "=", quality = "normal"
        },
        min = biome_color.b
    })
end

script.on_event(defines.events.on_script_trigger_effect, on_script_trigger_event)
