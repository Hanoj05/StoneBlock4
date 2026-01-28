-- ENERGY FLOW WALL
-- Monitor: right (30x10)
-- Touch-only UI, keine Anbindung
-- Touch:
--   Links  = Flow runter
--   Mitte  = Boost
--   Rechts = Flow hoch

local mon = peripheral.wrap("right")
if not mon then error("Monitor 'right' nicht gefunden") end

mon.setTextScale(1)

local W, H = mon.getSize()
-- Erwartet: 30 x 10

-- State
local flow = 5        -- 1..10
local boost = false
local tick = 0
local arrowOffset = 0
local pulse = 0
local pulseDir = 1

-- Farben je nach Flow
local function flowColor()
  if boost then return colors.orange end
  if flow <= 3 then return colors.lime end
  if flow <= 7 then return colors.yellow end
  return colors.red
end

local function cls()
  mon.setBackgroundColor(colors.black)
  mon.clear()
end

local function at(x,y,text,fg,bg)
  if bg then mon.setBackgroundColor(bg) end
  if fg then mon.setTextColor(fg) end
  mon.setCursorPos(x,y)
  mon.write(text)
end

-- Zeichnet bewegte Pfeilreihe
local function drawArrows(y, dir)
  local arrows = ">>>"
  local space = "   "
  local pattern = arrows .. space
  local line = ""

  for i=1, W do
    local idx = ((i + arrowOffset) % #pattern) + 1
    line = line .. pattern:sub(idx,idx)
  end

  if dir == -1 then
    line = line:reverse()
  end

  at(1, y, line:sub(1,W), flowColor())
end

local function draw()
  cls()

  -- Titel
  at(1,1," ENERGY FLOW SYSTEM ", colors.white)

  -- Pfeile oben
  drawArrows(2, 1)

  -- Core
  local coreWidth = 10 + pulse
  local coreX = math.floor((W - coreWidth) / 2)
  local coreY = 4

  at(coreX, coreY, string.rep("█", coreWidth), flowColor())

  at(coreX + 2, coreY + 1, boost and "BOOST" or " CORE ", colors.black, flowColor())

  -- Pfeile unten
  drawArrows(7, -1)

  -- Statuszeile
  local status = "FLOW "..flow
  if boost then status = status .. "  BOOST" end
  at(1,9,status, flowColor())

  -- Touch-Hints (dezent)
  at(1,10,"<  DOWN        BOOST        UP  >", colors.gray)
end

-- Animation Thread
local function animator()
  while true do
    tick = tick + 1
    arrowOffset = (arrowOffset + flow) % 6

    pulse = pulse + pulseDir
    if pulse >= 2 then pulseDir = -1 end
    if pulse <= 0 then pulseDir = 1 end

    draw()
    sleep(0.15)
  end
end

-- Touch Thread
local function touchHandler()
  while true do
    local _, side, x, y = os.pullEvent("monitor_touch")

    if side ~= "right" then
      -- ignore
    else
      if x <= 10 then
        flow = math.max(1, flow - 1)
        boost = false
      elseif x >= 21 then
        flow = math.min(10, flow + 1)
        boost = false
      else
        boost = not boost
      end
    end
  end
end

parallel.waitForAny(animator, touchHandler)
