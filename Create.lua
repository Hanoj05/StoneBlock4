-- COOL PANEL (6x3) - Fake Create-Control-Display
-- Monitor/Display: peripheral "right"
-- Controls:
--   1-4  Mode
--   A/D  Dial links/rechts
--   Space Toggle ARM
--   Q    Quit

local mon = peripheral.wrap("right")
if not mon then error("Kein Monitor auf 'right' gefunden") end

-- Für 6x3 sieht TextScale 2 meist gut aus. Bei Bedarf ändern: 1, 0.5, 3
mon.setTextScale(2)

local function getWH()
  return mon.getSize()
end

local function cls(bg, fg)
  mon.setBackgroundColor(bg or colors.black)
  mon.setTextColor(fg or colors.white)
  mon.clear()
end

local function at(x, y, txt, fg, bg)
  local w, h = getWH()
  if y < 1 or y > h then return end
  if bg then mon.setBackgroundColor(bg) end
  if fg then mon.setTextColor(fg) end
  mon.setCursorPos(x, y)
  mon.write(txt:sub(1, math.max(0, w - x + 1)))
end

local function padToW(s)
  local w = getWH()
  s = tostring(s)
  if #s >= w then return s:sub(1, w) end
  return s .. string.rep(" ", w - #s)
end

-- Panel State
local mode = 1
local modes = {
  {name="IDLE",  color=colors.gray},
  {name="BOOT",  color=colors.lime},
  {name="DRV",   color=colors.orange},
  {name="LOCK",  color=colors.red},
}
local arm = false
local dial = 0

local tick = 0
local progress = 0
local dir = 1
local t0 = os.clock()

local spinner = {"|","/","-","\\"}
local bars = {"▱▱▱","▰▱▱","▰▰▱","▰▰▰"} -- 3-seg bar

local function update()
  tick = tick + 1

  if mode == 1 then
    progress = (math.sin((os.clock() - t0) * 2) + 1) * 50
  elseif mode == 2 then
    progress = progress + 10
    if progress >= 100 then progress = 0 end
  elseif mode == 3 then
    progress = progress + 18
    if progress >= 100 then progress = 0 end
  elseif mode == 4 then
    progress = progress + (dir * 30)
    if progress >= 100 then progress = 100; dir = -1 end
    if progress <= 0 then progress = 0; dir = 1 end
  end
end

local function draw()
  local w, h = getWH()
  local m = modes[mode]

  cls(colors.black, colors.white)

  -- Line 1: MODE + spinner
  local sp = spinner[(tick % #spinner) + 1]
  local l1 = m.name .. sp
  at(1, 1, padToW(l1), m.color)

  -- Line 2: ARM/SAFE + blink + dial
  local armTxt = arm and "ARM" or "SAFE"
  local warn = " "
  if mode == 4 and (tick % 2 == 0) then warn = "!" end
  local l2 = armTxt .. warn .. "D" .. tostring(dial)
  at(1, 2, padToW(l2), arm and colors.lime or colors.gray)

  -- Line 3: Progress + tail
  local barIndex = math.floor((progress / 100) * 3) + 1
  barIndex = math.max(1, math.min(4, barIndex))
  local bar = bars[barIndex]

  local tail = ".."
  if mode == 2 then tail = " >"
  elseif mode == 3 then tail = ">>"
  elseif mode == 4 then tail = "XX"
  end

  local l3 = bar .. tail
  local l3c = (mode == 4 and colors.red) or colors.white
  at(1, 3, padToW(l3), l3c)
end

-- Terminal hints
term.clear()
term.setCursorPos(1,1)
print("COOL PANEL on 'right' running.")
print("Keys: 1-4 mode | A/D dial | Space ARM | Q quit")

local running = true

local function animator()
  while running do
    update()
    draw()
    sleep(0.15)
  end
end

local function inputLoop()
  while running do
    local _, key = os.pullEvent("key")

    if key == keys.one then mode = 1
    elseif key == keys.two then mode = 2
    elseif key == keys.three then mode = 3
    elseif key == keys.four then mode = 4
    elseif key == keys.a then dial = (dial - 1) % 10
    elseif key == keys.d then dial = (dial + 1) % 10
    elseif key == keys.space then arm = not arm
    elseif key == keys.q then
      running = false
      break
    end
  end
end

parallel.waitForAny(animator, inputLoop)

term.clear()
term.setCursorPos(1,1)
print("COOL PANEL stopped.")
