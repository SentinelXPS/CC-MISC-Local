-- install.lua
-- Simple wget installer for MISC Bundled.

local function download(url, filepath)
  term.write("Downloading " .. filepath .. "... ")
  local response = http.get(url)
  if not response then
    print("FAILED")
    return false
  end
  local f = fs.open(filepath, "w")
  f.write(response.readAll())
  f.close()
  response.close()
  print("OK")
  return true
end

term.clear()
term.setCursorPos(1, 1)
print("MISC Bundled Installer")
print("===================================")
print()

if not http then
  print("ERROR: HTTP not available. Add a wired/WiFi modem and retry.")
  return
end

local repo = "https://raw.githubusercontent.com/SentinelXPS/CC-MISC-Local/master"

print("Downloading misc_bundled.lua...")
if not download(repo .. "/misc_bundled.lua", "misc_bundled.lua") then
  print("Download failed. Check internet/modem.")
  return
end

print()
term.write("Create startup.lua (auto-run on reboot)? [y/n] ")
local event, key = os.pullEvent("key")
local answer = (key == keys.y)
if answer then
  local f = fs.open("startup.lua", "w")
  f.write("shell.run('misc_bundled.lua')\n")
  f.close()
  print("startup.lua created.")
else
  print("startup.lua not created. Run manually with: lua misc_bundled.lua")
end

print()
print("Install complete!")
print("Use: lua misc_bundled.lua")