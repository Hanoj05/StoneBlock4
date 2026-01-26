-- Mekanism Energy Dashboard
-- Graph: gespeicherte Energie (0–100%) eingerahmt
-- Zahl: Netto-Flow (FE/s), gruen bei rein, rot bei raus
-- Uhr: feste Zeitzone ueber Offset
-- Peripheral: advancedEnergyCube_0

local mon = peripheral.find("monitor")
if not mon then error("Kein Monitor gefunden") end

local cube = peripheral.wrap("advancedEnergyCube_0")
if not cube then error("Energy Cube nicht gefunden") end

mon.setTextScale(0.5)

-- =============================
-- ZEITZONE
-- =============================
-- 0    = UTC
-- 3600 = CET  (UTC+1)
-- 7200 = CEST (UTC+2)
local TZ_OFFSET = 3600

-- =============================
-- HILFSFUNKTIONEN
-- =============================
local function clamp(x,a,b)
  if x < a then return a end
  if x > b then return b end
  return x
end

local function fmt(n)
  local units = {"","k","M","G","T","P"}
  local sign = n < 0 and "-" or ""
  local x = math.abs(n)
  local i = 1
  while x >= 1000 and i < #units do
    x = x / 1000
    i = i + 1
  end
  local s
  if x >= 100 then s = string.format("%.0f", x)
  elseif x >= 10 then s = string.format("%.1f", x)
  else s = string.format("%.2f", x) end
  return sign .. s .. units[i]
end

local function drawBox(l,t,r,b,color)
  mon.setTextColor(color or colors.gray)
  for x=l,r do
    mon.setCursorPos(x,t) mon.write("-")
    mon.setCursorPos(x,b) mon.write("-")
  end
  for y=t,b do
    mon.setCursorPos(l,y) mon.write("|")
    mon.setCursorPos(r,y) mon.write("|")
  end
  mon.setCursorPos(l,t) mon.write("+")
  mon.setCursorPos(r,t) mon.write("+")
  mon.setCursorPos(l,b) mon.write("+")
  mon.setCursorPos(r,b) mon.write("+")
end

-- =============================
-- VERLAUF / FLOW
-- =============================
local history = {}
local lastEnergy = cube.getEnergy()
local lastTime   = os.epoch("utc") / 1000

-- =============================
-- MAIN LOOP
-- =============================
while true do
  local w,h = mon.getSize()

  local energy = cube.getEnergy()
  local cap    = cube.getMaxEnergy()
  local pct    = (cap > 0) and (energy / cap * 100) or 0

  -- Flow (FE/s)
  local now = os.epoch("utc") / 1000
  local dt  = now - lastTime
  local flow = 0
  if dt > 0 then
    flow = (energy - lastEnergy) / dt
  end
  lastEnergy = energy
  lastTime   = now

  -- Layout
  local yTitle = 1
  local yLine  = 2
  local yInfo1 = 4
  local yInfo2 = 5
  local yInfo3 = 6
  local yInfo4 = 7
  local yBar   = 9

  local boxLeft   = 1
  local boxRight  = w
  local boxTop    = 12
  local boxBottom = h

  local gLeft   = boxLeft + 1
  local gRight  = boxRight - 1
  local gTop    = boxTop + 1
  local gBottom = boxBottom - 1
  local gW = gRight - gLeft + 1
  local gH = gBottom - gTop + 1

  -- History (Fuellstand in %)
  history[#history+1] = pct
  while #history > gW do table.remove(history,1) end

  -- Screen vorbereiten
  mon.setBackgroundColor(colors.black)
  mon.setTextColor(colors.white)
  mon.clear()

  -- Header
  mon.setCursorPos(1,yTitle)
  mon.write("MEKANISM ENERGY STATUS")
  mon.setCursorPos(1,yLine)
  mon.setTextColor(colors.gray)
  mon.write(string.rep("-", w))
  mon.setTextColor(colors.white)

  -- Zahlen
  mon.setCursorPos(1,yInfo1)
  mon.write("Stored:   "..fmt(energy).."FE")

  mon.setCursorPos(1,yInfo2)
  mon.write("Capacity: "..fmt(cap).."FE")

  local flowColor = colors.gray
  if flow > 0 then flowColor = colors.lime
  elseif flow < 0 then flowColor = colors.red end

  mon.setTextColor(flowColor)
  mon.setCursorPos(1,yInfo3)
  mon.write("Flow:     "..fmt(flow).."FE/s")
  mon.setTextColor(colors.white)

  mon.setCursorPos(1,yInfo4)
  mon.write(string.format("Fill:     %.2f%%", pct))

  -- Balken
  local filled = clamp(math.floor((pct/100)*w + 0.5), 0, w)
  mon.setCursorPos(1,yBar)
  mon.setBackgroundColor(colors.lime)
  mon.setTextColor(colors.black)
  mon.write(string.rep(" ", filled))
  mon.setBackgroundColor(colors.gray)
  mon.write(string.rep(" ", w-filled))
  mon.setBackgroundColor(colors.black)
  mon.setTextColor(colors.white)

  -- Graph-Rahmen
  drawBox(boxLeft, boxTop, boxRight, boxBottom, colors.gray)

  -- Skala
  mon.setTextColor(colors.gray)
  mon.setCursorPos(2, boxTop)
  mon.write("100%")
  mon.setCursorPos(2, boxBottom)
  mon.write("0%")

  -- Graph (Energieverlauf)
  if gW >= 5 and gH >= 5 then
    local lastP = history[1] or pct
    for i=1,#history do
      local p = history[i]
      local x = gLeft + (i-1)
      local y = gTop + math.floor((100 - p)/100 * (gH-1) + 0.5)
      y = clamp(y, gTop, gBottom)

      if p > lastP then
        mon.setTextColor(colors.lime)
      elseif p < lastP then
        mon.setTextColor(colors.red)
      else
        mon.setTextColor(colors.gray)
      end

      mon.setCursorPos(x,y)
      mon.write("x")
      lastP = p
    end
  end

  -- Uhr (konfigurierbare Zeitzone)
  mon.setTextColor(colors.gray)
  mon.setCursorPos(w-8,1)
  mon.write(os.date("%H:%M:%S", os.epoch("utc")/1000 + TZ_OFFSET))

  sleep(1)
end
