-- ULTRA LOOK v2 (BT3 PC port) - anime/HDR cinematic look, drawn by the renderer.
-- Adds bloom, filmic tonemap, sharpen, depth of field, vignette, grain and chromatic aberration
-- to the port's look pass (bt3.look), plus a few layers the mod draws itself (impact flash, warm grade,
-- letterbox, camera punch).
-- Everything is per-frame and cosmetic: fights, replays and online play are unchanged.

local RIM_COLOURS = {
    0xFFECD6FF, -- blanco calido
    0xD8ECFFFF, -- blanco frio
    0xFFD27AFF, -- dorado
    0x8FD8FFFF, -- cian
    0xFF8A5CFF, -- naranja
}

local function slider(id, label, default, tip)
    return { id = id, label = label, type = "slider", min = 0, max = 100, step = 5, default = default, tip = tip }
end

-- estado entre blanks
local lastFrame = nil
local prevHit = { 0, 0 }
local prevMessageSeq = 0
local flash = 0.0
local flashCol = { 255, 255, 255 }
local shake = 0.0

local function dt_of(game)
    if lastFrame == nil then
        lastFrame = game.frame
        return 0.0
    end
    local n = game.frame - lastFrame
    lastFrame = game.frame
    if n < 0 or n > 4 then return 0.0 end
    return n / 60.0
end

local function watch_impacts(game)
    local total = 0
    if game.battle and game.fighters then
        for s = 1, 2 do
            local f = game.fighters[s]
            if f then
                local seq = f.hit_seq or 0
                if seq > prevHit[s] then total = total + (seq - prevHit[s]) end
                prevHit[s] = seq
            else
                prevHit[s] = 0
            end
        end
        local ms = game.message_seq or 0
        if ms > prevMessageSeq then
            local m = game.message
            if m == 1 then -- MAX POWER
                flashCol = { 255, 210, 90 }
                flash = math.min(1.0, flash + 0.55)
                shake = math.min(1.0, shake + 0.45)
            elseif m == 4 then -- BOOST
                flashCol = { 120, 200, 255 }
                flash = math.min(1.0, flash + 0.30)
            end
        end
        prevMessageSeq = ms
    else
        prevHit[1], prevHit[2] = 0, 0
        prevMessageSeq = 0
    end

    if total > 0 then
        flashCol = { 255, 255, 255 }
        flash = math.min(1.0, flash + 0.35 + math.min(total, 4) * 0.10)
        shake = math.min(1.0, shake + 0.20 + math.min(total, 4) * 0.08)
    end
end

local function decay(dt)
    if flash > 0.0 then flash = math.max(0.0, flash - dt * 4.5) end
    if shake > 0.0 then shake = math.max(0.0, shake - dt * 6.0) end
end

-- capas dibujadas por el mod ------------------------------------------------

local function grade(hud, warmth)
    if warmth <= 0 then return end
    local a = math.floor(warmth * 0.30)
    if a <= 0 then return end
    hud.fill(0, 0, hud.w, hud.h, bt3.rgba(255, 176, 96, a))
end

local function letterbox(hud, on)
    if not on then return end
    local bar = math.floor(hud.h * 0.055)
    hud.fill(0, 0, hud.w, bar, bt3.rgba(0, 0, 0, 255))
    hud.fill(0, hud.h - bar, hud.w, bar, bt3.rgba(0, 0, 0, 255))
end

local function impact(hud, alpha)
    if alpha <= 0 then return end
    local a = math.floor(alpha * 110)
    if a <= 0 then return end
    hud.fill(0, 0, hud.w, hud.h, bt3.rgba(flashCol[1], flashCol[2], flashCol[3], a))
end

return {
    name = "Ultra Look",
    version = "2.0",
    author = "tú",
    description = "Look anime/HDR: cel-shading, rim, AO, bloom real, tonemap, sharpen, DOF, viñeta, grano y flashes.",
    settings = {
        -- look del renderer
        slider("shading", "Anime shading", 100, "Sombras de dos tonos con borde suave en los luchadores."),
        slider("rim", "Rim light", 80, "Luz en el contorno de los luchadores."),
        { id = "rim_colour", label = "Rim light colour", type = "choice",
          choices = { "Blanco calido", "Blanco frio", "Dorado", "Cian", "Naranja" }, default = 1 },
        slider("vivid", "Vivid colours", 100, "Colores mas vivos y balance neutro."),
        slider("ambient", "Ambient shadows", 100, "Sombras suaves en rincones y contactos."),
        slider("energy", "Brighter energy", 60, "Ki, rayos y chispas mas fuertes y saturados."),
        slider("energy_light", "Energy light", 0, "La energia ilumina el entorno. Si parpadea, dejalo en 0."),
        -- post-proceso nuevo
        slider("bloom", "Bloom", 70, "Brillo real en luces, auras y explosiones."),
        slider("bloom_threshold", "Bloom threshold", 55, "Mas alto: solo lo mas brillante hace bloom."),
        slider("tonemap", "Tonemap ACES", 50, "Altas luces con rolloff de cine en vez de quemarse."),
        slider("sharpen", "Sharpen", 25, "Nitidez extra para la imagen reescalada."),
        slider("dof", "Depth of field", 0, "Desenfoca el fondo lejano; los luchadores quedan nitidos."),
        slider("vignette", "Viñeta (shader)", 25, "Oscurece las esquinas sin tocar el HUD."),
        slider("grain", "Film grain", 5, "Grano de pelicula sutil."),
        slider("ca", "Chromatic aberration", 15, "Separacion de color en los bordes."),
        -- capas del mod
        slider("warm", "Grade calido", 15, "Tinte calido sutil."),
        slider("impact", "Flash de impacto", 70, "Destello al conectar golpes."),
        slider("punch", "Punch de camara", 0, "Sacudida de camara al impactar."),
        { id = "letterbox", label = "Barras de cine", type = "toggle", default = false },
    },

    on_frame = function(game)
        local dt = dt_of(game)
        watch_impacts(game)
        decay(dt)

        bt3.look {
            shading = bt3.setting("shading"),
            rim = bt3.setting("rim"),
            rim_color = RIM_COLOURS[bt3.setting("rim_colour")] or RIM_COLOURS[1],
            vivid = bt3.setting("vivid"),
            ambient = bt3.setting("ambient"),
            energy = bt3.setting("energy"),
            energy_light = bt3.setting("energy_light"),
            bloom = bt3.setting("bloom"),
            bloom_threshold = bt3.setting("bloom_threshold"),
            tonemap = bt3.setting("tonemap"),
            sharpen = bt3.setting("sharpen"),
            dof = bt3.setting("dof"),
            vignette = bt3.setting("vignette"),
            grain = bt3.setting("grain"),
            ca = bt3.setting("ca"),
        }
    end,

    on_hud = function(hud, game)
        if not game.battle then return end
        letterbox(hud, bt3.setting("letterbox"))
        if game.hud_shown then
            grade(hud, bt3.setting("warm"))
            impact(hud, flash * (bt3.setting("impact") / 100))
        end
    end,

    on_camera = function(cam, game)
        local p = bt3.setting("punch")
        if p <= 0 or shake <= 0 or not game.battle then return end
        local amp = shake * (p / 100) * 0.6
        cam.pos.x = cam.pos.x + (math.random() * 2 - 1) * amp
        cam.pos.y = cam.pos.y + (math.random() * 2 - 1) * amp
        cam.pos.z = cam.pos.z + (math.random() * 2 - 1) * amp
    end,
}
