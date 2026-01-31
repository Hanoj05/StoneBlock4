-- WAY SIGN + INTERACTIVE MAP (retro + cyberpunk)
-- CC:Tweaked monitor UI with touch navigation
-- Monitor side: "right" by default

local MON_SIDE = "right"  -- change if needed (e.g. "monitor_0", "top", etc.)

local mon = peripheral.wrap(MON_SIDE)
if not mon then error("Monitor nicht gefunden auf: "..tostring(MON_SIDE)) end

mon.setTextScale(1)
local W, H = mon.getSize()

-- ---------- Theme ----------
local C_BG       = colors.black
local C_FRAME    = colors.gray
local C_TEXT     = colors.white
local C_NEON     = colors.cyan
local C_NEON2    = colors.magenta
local C_WARN     = colors.orange
local C_OK       = colors.lime
local C_DIM      = colors.lightGray

-- ---------- Utilities ----------
local function clamp(x,a,b) if x<a then return a elseif x>b then return b else return x end end
local function padR(s,n) s=tostring(s or ""); if #s>=n then return s:sub(1,n) end return s..string.rep(" ", n-#s) end

local function cls()
  mon.setBackgroundColor(C_BG)
  mon.setTextColor(C_TEXT)
  mon.clear()
end

local function at(x,y,txt,fg,bg)
  if x < 1 or y < 1 or x > W or y > H then return end
  if bg then mon.setBackgroundColor(bg) end
  if fg then mon.setTextColor(fg) end
  mon.setCursorPos(x,y)
  mon.write(txt:sub(1, math.max(0, W - x + 1)))
end

local function box(x1,y1,x2,y2,fg)
  fg = fg or C_FRAME
  local tl,tr,bl,br = "┌","┐","└","┘"
  local hz,vt = "─","│"
  at(x1,y1, tl..string.rep(hz, x2-x1-1)..tr, fg)
  for y=y1+1, y2-1 do
    at(x1,y, vt, fg)
    at(x2,y, vt, fg)
  end
  at(x1,y2, bl..string.rep(hz, x2-x1-1)..br, fg)
end

local function button(x1,y1,x2,y2,label,active)
  local fg = active and C_BG or C_TEXT
  local bg = active and C_NEON or colors.black
  box(x1,y1,x2,y2, active and C_NEON or C_FRAME)
  local cx = x1 + math.floor((x2-x1+1-#label)/2)
  local cy = y1 + math.floor((y2-y1)/2)
  at(cx, cy, label, fg, bg)
  -- fill inside slightly
  for y=y1+1,y2-1 do
    at(x1+1,y, string.rep(" ", x2-x1-1), nil, bg)
  end
  at(cx, cy, label, fg, bg)
end

local function inRect(x,y,x1,y1,x2,y2)
  return x>=x1 and x<=x2 and y>=y1 and y<=y2
end

-- ---------- Map Data ----------
-- Simple "world grid" map. Coordinates are arbitrary (like blocks).
-- Add your POIs here. icon should be 1 char.
local POI = {
  {name="BASE",   x=0,   y=0,   icon="B", color=C_OK},
  {name="FARM",   x=35,  y=8,   icon="F", color=C_LIME or C_OK},
  {name="MINE",   x=-22, y=18,  icon="M", color=C_WARN},
  {name="DEPOT",  x=10,  y=-15, icon="D", color=C_NEON},
  {name="PORTAL", x=-40, y=-6,  icon="P", color=C_NEON2},
}

-- Player position (manual by default). Can be updated via GPS if you implement it.
local player = {x=0, y=0}

-- Viewport center (for panning)
local view = {cx=0, cy=0}

-- ---------- Optional GPS Hook ----------
-- If you have CC GPS network, you can enable this.
-- It requires a modem and gps hosts in the world.
local USE_GPS = false

local function tryGPS()
  if not USE_GPS then return false end
  if gps == nil then return false end
  local x,y,z = gps.locate(1.0)  -- timeout 1s
  if x then
    -- map uses x,z as 2D
    player.x = math.floor(x+0.5)
    player.y = math.floor(z+0.5)
    return true
  end
  return false
end

-- ---------- Screens ----------
local screen = "SIGN" -- "SIGN" or "MAP"
local tick = 0

-- SIGN render (retro sign + cyber accent)
local function renderSign()
  cls()
  box(1,1,W,H, C_FRAME)

  -- top header with "worn" look
  local title = " WAYFINDER "
  at(3,2, title, C_TEXT)
  at(3+#title,2, "v2", C_DIM)

  -- scanline / glitch accent
  local phase = (math.floor(os.clock()*6) % 6)
  local glow = (phase==0 or phase==1) and C_NEON or C_NEON2
  at(3,3, "┄┄┄┄┄┄┄┄┄┄┄┄", glow)

  -- directional hints
  at(3,5, "→ BASE", C_TEXT)
  at(3,6, "→ FARM", C_TEXT)
  at(3,7, "→ MINE", C_TEXT)
  at(3,8, "→ DEPOT", C_TEXT)

  -- cyber footer
  local t = os.epoch("utc")/1000
  local timeStr = os.date("%H:%M:%S", t)
  at(3,H-2, "STATUS: ONLINE", C_OK)
  at(W-10,H-2, timeStr, C_DIM)

  -- CTA button
  local bx1,by1,bx2,by2 = W-10, 2, W-2, 4
  button(bx1,by1,bx2,by2,"MAP", true)

  at(3,H-1, "Tippe MAP für Übersicht", C_DIM)
end

-- MAP render (grid + markers + UI)
local function renderMap()
  cls()
  box(1,1,W,H,C_FRAME)

  -- Title
  at(3,2, "MAP OVERVIEW", C_TEXT)
  local gpsOk = tryGPS()
  at(W-12,2, USE_GPS and (gpsOk and "GPS OK" or "GPS ..") or "MANUAL", C_DIM)

  -- UI buttons
  button(3,3, 10,4, "BACK", false)
  button(12,3, 20,4, "CENTER", true)
  button(22,3, W-2,4, "SET HERE", true)

  -- Map area
  local mapX1, mapY1 = 3, 5
  local mapX2, mapY2 = W-2, H-2
  box(mapX1-1,mapY1-1,mapX2+1,mapY2+1, C_FRAME)

  local mapW = mapX2-mapX1+1
  local mapH = mapY2-mapY1+1

  -- draw subtle grid / scanline style
  for y=0,mapH-1 do
    for x=0,mapW-1 do
      local gx = view.cx + (x - math.floor(mapW/2))
      local gy = view.cy + (y - math.floor(mapH/2))
      local ch = " "
      local fg = C_DIM
      -- dotted grid every 5
      if (gx % 5 == 0) and (gy % 5 == 0) then
        ch = "·"
        fg = (tick % 2 == 0) and C_DIM or C_FRAME
      end
      at(mapX1+x, mapY1+y, ch, fg, C_BG)
    end
  end

  -- draw POIs
  for _,p in ipairs(POI) do
    local sx = mapX1 + (p.x - view.cx) + math.floor(mapW/2)
    local sy = mapY1 + (p.y - view.cy) + math.floor(mapH/2)
    if sx>=mapX1 and sx<=mapX2 and sy>=mapY1 and sy<=mapY2 then
      at(sx, sy, p.icon, p.color, C_BG)
    end
  end

  -- draw player
  local px = mapX1 + (player.x - view.cx) + math.floor(mapW/2)
  local py = mapY1 + (player.y - view.cy) + math.floor(mapH/2)
  if px>=mapX1 and px<=mapX2 and py>=mapY1 and py<=mapY2 then
    at(px, py, "@", C_NEON, C_BG)
  end

  -- legend
  at(3,H-1, "@=YOU  Tap map edges to pan", C_DIM)
end

-- ---------- Touch Handling ----------
local function handleTouch(x,y)
  if screen == "SIGN" then
    -- MAP button area
    if inRect(x,y, W-10,2, W-2,4) then
      screen = "MAP"
      view.cx, view.cy = player.x, player.y
      return
    end
  else
    -- BACK
    if inRect(x,y, 3,3,10,4) then
      screen = "SIGN"
      return
    end
    -- CENTER
    if inRect(x,y, 12,3,20,4) then
      view.cx, view.cy = player.x, player.y
      return
    end
    -- SET HERE (manual set): sets player to current view center
    if inRect(x,y, 22,3, W-2,4) then
      player.x, player.y = view.cx, view.cy
      return
    end

    -- Panning: tap edges of map frame
    -- map box from (2,4) to (W-1,H-1) roughly, we use edges for direction:
    if y >= 5 and y <= H-2 then
      if x <= 4 then view.cx = view.cx - 3 return end
      if x >= W-3 then view.cx = view.cx + 3 return end
    end
    if x >= 3 and x <= W-2 then
      if y <= 6 then view.cy = view.cy - 2 return end
      if y >= H-3 then view.cy = view.cy + 2 return end
    end
  end
end

-- ---------- Main ----------
cls()

while true do
  tick = tick + 1
  W, H = mon.getSize()

  if screen == "SIGN" then
    renderSign()
  else
    renderMap()
  end

  -- wait for either touch or a small tick to animate
  local ev = { os.pullEvent() }
  if ev[1] == "monitor_touch" then
    local side, x, y = ev[2], ev[3], ev[4]
    if side == MON_SIDE then
      handleTouch(x,y)
    end
  elseif ev[1] == "timer" then
    -- not used
  end
end
