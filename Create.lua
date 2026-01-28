-- STATUS BOARD (30x10) - Big Clock (with seconds) + Weather (Celsius)
-- Monitor: right
-- No touch, no # characters used for graphics.

local mon = peripheral.wrap("right")
if not mon then error("Monitor 'right' nicht gefunden") end

mon.setTextScale(1)
local W, H = mon.getSize() -- expected 30x10

-- ========= CONFIG =========
-- Set your location (default: Berlin)
local LAT, LON = 52.52, 13.405

-- If your displayed time is off by 1 hour, adjust here:
-- 0=UTC, 3600=CET, 7200=CEST
local TZ_OFFSET = 3600

local WEATHER_REFRESH_SEC = 600 -- 10 min

-- ========= 7-seg font (3x5) using █ =========
local SEG = {
  ["0"] = {"███","█ █","█ █","█ █","███"},
  ["1"] = {"  █","  █","  █","  █","  █"},
  ["2"] = {"███","  █","███","█  ","███"},
  ["3"] = {"███","  █","███","  █","███"},
  ["4"] = {"█ █","█ █","███","  █","  █"},
  ["5"] = {"███","█  ","███","  █","███"},
  ["6"] = {"███","█  ","███","█ █","███"},
  ["7"] = {"███","  █","  █","  █","  █"},
  ["8"] = {"███","█ █","███","█ █","███"},
  ["9"] = {"███","█ █","███","  █","███"},
}

local function clamp(x,a,b) if x<a then return a elseif x>b then return b else return x end end

local function padRight(s, n)
  s = tostring(s or "")
  if #s >= n then return s:sub(1,n) end
  return s .. string.rep(" ", n-#s)
end

local function at(x,y,txt,fg,bg)
  if x < 1 or y < 1 or x > W or y > H then return end
  if bg then mon.setBackgroundColor(bg) end
  if fg then mon.setTextColor(fg) end
  mon.setCursorPos(x,y)
  mon.write(txt:sub(1, math.max(0, W - x + 1)))
end

local function cls()
  mon.setBackgroundColor(colors.black)
  mon.setTextColor(colors.white)
  mon.clear()
end

local function box(x1,y1,x2,y2,fg)
  fg = fg or colors.gray
  local tl, tr, bl, br = "┌","┐","└","┘"
  local hz, vt = "─","│"
  at(x1,y1, tl .. string.rep(hz, x2-x1-1) .. tr, fg)
  for y=y1+1, y2-1 do
    at(x1,y, vt, fg)
    at(x2,y, vt, fg)
  end
  at(x1,y2, bl .. string.rep(hz, x2-x1-1) .. br, fg)
end

local function drawDigit(ch, x, y, fg)
  local g = SEG[ch]
  if not g then return end
  for i=1,5 do
    at(x, y+i-1, g[i], fg)
  end
end

local function drawColon(x, y, on, fg)
  -- 1-char wide colon, centered in 5-high digit area
  fg = fg or colors.cyan
  at(x, y+1, on and "█" or " ", fg)
  at(x, y+3, on and "█" or " ", fg)
end

-- ========= WEATHER via Open-Meteo =========
local weather = {
  ok=false, temp=nil, wind=nil, code=nil, label="NO DATA", updated=0, err=nil
}

local function codeToLabel(code)
  local m = {
    [0]="Clear",
    [1]="Mostly clr",[2]="Partly",[3]="Overcast",
    [45]="Fog",[48]="Fog",
    [51]="Drizzle",[53]="Drizzle",[55]="Drizzle",
    [56]="Freezing",[57]="Freezing",
    [61]="Rain",[63]="Rain",[65]="Rain",
    [66]="Fz rain",[67]="Fz rain",
    [71]="Snow",[73]="Snow",[75]="Snow",
    [77]="Snow",
    [80]="Showers",[81]="Showers",[82]="Showers",
    [85]="Sn shwr",[86]="Sn shwr",
    [95]="Storm",[96]="Storm",[99]="Storm"
  }
  return m[code] or ("Code "..tostring(code))
end

local function fetchWeather()
  local url = ("https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&current_weather=true&windspeed_unit=kmh&temperature_unit=celsius")
    :format(tostring(LAT), tostring(LON))

  local h = http.get(url, {["User-Agent"]="CC StatusBoard"})
  if not h then
    weather.ok=false
    weather.err="http.get failed"
    return
  end

  local body = h.readAll()
  h.close()

  local data = textutils.unserializeJSON(body)
  if not data or not data.current_weather then
    weather.ok=false
    weather.err="bad JSON"
    return
  end

  local cw = data.current_weather
  weather.ok=true
  weather.err=nil
  weather.temp = cw.temperature
  weather.wind = cw.windspeed
  weather.code = cw.weathercode
  weather.label = codeToLabel(cw.weathercode)
  weather.updated = os.epoch("utc")/1000
end

local function ageSec()
  if weather.updated == 0 then return 9999 end
  return math.floor(os.epoch("utc")/1000 - weather.updated)
end

-- ========= RENDER =========
local lastFetch = 0

local function render()
  cls()

  -- Frame layout:
  -- Top big clock area: rows 1..6 (boxed)
  -- Bottom weather area: rows 7..10 (boxed)
  box(1,1,30,6, colors.gray)
  box(1,7,30,10, colors.gray)

  -- Big clock draw (HH:MM:SS) with 3x5 digits
  local t = os.epoch("utc")/1000 + TZ_OFFSET
  local hh = os.date("%H", t)
  local mm = os.date("%M", t)
  local ss = os.date("%S", t)

  local blink = (tonumber(ss) % 2 == 0)

  -- Fit positions in 30 wide:
  -- digits at x: 3,7, (colon 11), 13,17, (colon 21), 23,27
  local y0 = 2
  local cDigit = colors.white
  local cColon = colors.cyan

  drawDigit(hh:sub(1,1), 3,  y0, cDigit)
  drawDigit(hh:sub(2,2), 7,  y0, cDigit)
  drawColon(11, y0, blink, cColon)
  drawDigit(mm:sub(1,1), 13, y0, cDigit)
  drawDigit(mm:sub(2,2), 17, y0, cDigit)
  drawColon(21, y0, blink, cColon)
  drawDigit(ss:sub(1,1), 23, y0, cDigit)
  drawDigit(ss:sub(2,2), 27, y0, cDigit)

  -- Small header info in top frame
  local tzName = (TZ_OFFSET==0 and "UTC") or (TZ_OFFSET==3600 and "CET") or (TZ_OFFSET==7200 and "CEST") or ("+"..tostring(TZ_OFFSET/3600))
  at(3,1, "STATUS BOARD", colors.white)
  at(20,1, padRight(tzName, 9), colors.gray)

  -- Weather area
  at(3,7, "WEATHER", colors.yellow)

  if weather.ok and weather.temp ~= nil then
    local tempStr = string.format("%.1f C", weather.temp)
    local lbl = padRight(weather.label, 12)
    local windStr = string.format("%d km/h", math.floor(weather.wind or 0))
    local age = ageSec()

    -- color based on weather code rough: snow/rain = cyan, storm = red, clear = lime
    local wc = colors.white
    if weather.code == 0 then wc = colors.lime
    elseif weather.code and weather.code >= 95 then wc = colors.red
    elseif weather.code and (weather.code >= 61 and weather.code <= 82) then wc = colors.cyan
    elseif weather.code and (weather.code >= 71 and weather.code <= 86) then wc = colors.lightBlue end

    at(3,8, "Temp:", colors.gray)
    at(9,8, padRight(tempStr, 8), wc)

    at(18,8, "Wind:", colors.gray)
    at(24,8, padRight(windStr, 7), colors.white)

    at(3,9, "Now :", colors.gray)
    at(9,9, lbl, colors.white)

    at(18,9, "Age :", colors.gray)
    at(24,9, padRight(tostring(age).."s", 7), colors.gray)
  else
    at(3,8, "No weather data.", colors.red)
    at(3,9, padRight(weather.err or "unknown error", 26), colors.gray)
  end

  -- Subtle animated dots (bottom right)
  local phase = (math.floor(os.clock()*4) % 4)
  local dots = ({".  ",".. ","..."," .."})[phase+1]
  at(26,10, dots, colors.gray)
end

-- ========= MAIN LOOP =========
while true do
  local now = os.epoch("utc")/1000
  if lastFetch == 0 or (now - lastFetch) >= WEATHER_REFRESH_SEC then
    local ok, err = pcall(fetchWeather)
    if not ok then
      weather.ok=false
      weather.err=tostring(err)
    end
    lastFetch = now
  end

  render()
  sleep(0.2)
end
