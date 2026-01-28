-- COOL PANEL (Create Display / Monitor) 6x3
-- Keine Anbindung: nur Style, Animation, "Buttons" per Tastendruck im Terminal
-- Keys:
--   1-4  = Modus
--   A/D  = Dial links/rechts
--   Space= Toggle ARM
--   Q    = Quit

local mon = peripheral.find("monitor")
if not mon then error("Kein Monitor/Display gefunden. Prüfe peripheral.getNames().") end

-- 6x3: große Textscale, damit es wie ein echtes Panel wirkt
-- Wenn bei dir Texte abgeschnitten sind: 0.5 -> 1.0 -> 2.0 ausprobieren.
mon.setTextScale(2)

local w,h = mon.getSize()
-- Falls dein Display wirklich 6x3 ist, sollte w=6, h=3 sein.
-- Wir machen trotzdem dynamisch.
local function cls(bg, fg)
  mon.setBackgroundColor(bg or colors.black)
  mon.setTextColor(fg or colors.white)
  mon.clear()
end

local function at(x,y,txt,fg,bg)
  if bg then mon.setBackgroundColor(bg) end
  if fg then mon.setTextColor(fg) end
  mon.setCursorPos(x,y)
  mon.write(txt:sub(1, math.max(0, w - x + 1)))
end

local function pad6(s)
  s = tostring(s)
  if #s >= w then return s:sub(1,w) end
  return s .. string.rep(" ", w-#s)
end

-- State
local mode = 1
local modes = {
  {name="IDLE",     color=colors.gray},
  {name="START",    color=colors.lime},
  {name="DRIVE",    color=colors.orange},
  {name="LOCK",     color=colors.red},
}
local arm = false
local dial = 0 -- 0..9
local t0 = os.clock()
local tick = 0
local progress = 0
local dir = 1

local spinner = {"|","/","-","\\"}
local bars = {"▱▱▱","▰▱▱","▰▰▱","▰▰▰"}

-- draw functions
local function draw()
  w,h = mon.getSize()
  local m = modes[mode]

  -- Background per mode
  cls(colors.black, colors.white)

  -- Line 1: MODE + spinner
  local sp = spinner[(tick % #spinner) + 1]
  local title = m.name .. sp
  if #title < w then title = title .. string.rep(" ", w-#title) end
  at(1,1, title, m.color)

  -- Line 2: ARM + Dial + warning blink
  local armTxt = arm and "ARM" or "SAFE"
  local warn = ""
  if mode == 4 and (tick % 2 == 0) then warn = "!" else warn = " " end

  -- dial glyph: 0..9
  local d = tostring(dial)
  local mid = armTxt .. warn .. "D" .. d
  at(1,2, pad6(mid), arm and colors.lime or colors.gray)

  -- Line 3: progress bar / pulse
  local barIndex = math.floor((progress/100)*3) + 1
  barIndex = math.max(1, math.min(4, barIndex))
  local bar = bars[barIndex]

  local tail = ""
  if mode == 3 then tail = ">>" elseif mode == 2 then tail = ">" elseif mode == 4 then tail = "XX" else tail = ".." end
  local l3 = bar .. tail
  at(1,3, pad6(l3), (mode==4 and colors.red) or colors.white)
end

-- input loop (keyboard in terminal)
term.clear()
term.setCursorPos(1,1)
print("COOL PANEL running.")
print("Keys: 1-4 mode | A/D dial | Space ARM | Q quit")

local function update()
  tick = tick + 1

  -- progress animation
  if mode == 1 then
    -- idle: slow pulse
    progress = (math.sin((os.clock()-t0)*2) + 1) * 50
  elseif mode == 2 then
    progress = progress + 7
    if progress >= 100 then progress = 0 end
  elseif mode == 3 then
    progress = progress + 14
    if progress >= 100 then progress = 0 end
  elseif mode == 4 then
    -- lockdown: sawtooth + jitter
    progress = progress + (dir * 25)
    if progress >= 100 then progress = 100; dir = -1 end
    if progress <= 0 then progress = 0; dir = 1 end
  end
end

draw()

while true do
  -- non-blocking key read with short timeout
  local ev, p1 = os.pullEventTimeout("key", 0.15)
  if ev == "key" then
    local k = p1

    -- number keys 1-4
    if k == keys.one then mode = 1
    elseif k == keys.two then mode = 2
    elseif k == keys.three then mode = 3
    elseif k == keys.four then mode = 4
    elseif k == keys.a then dial = (dial - 1) % 10
    elseif k == keys.d then dial = (dial + 1) % 10
    elseif k == keys.space then arm = not arm
    elseif k == keys.q then break
    end
  end

  update()
  draw()
end

term.clear()
term.setCursorPos(1,1)
print("COOL PANEL stopped.")
