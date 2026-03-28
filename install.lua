-- install.lua
-- Single-line wget installer for MISC Bundled
-- Usage: wget https://raw.githubusercontent.com/SentinelXPS/CC-MISC-Local/master/install.lua
-- Then: lua install.lua

local function download(url, filepath)
  term.write("Downloading " .. filepath .. "...")
  local response = http.get(url)
  if not response then
    print(" FAILED")
    return false
  end
  local f = fs.open(filepath, "w")
  f.write(response.readAll())
  f.close()
  response.close()
  print(" OK")
  return true
end

term.clear()
term.setCursorPos(1, 1)
print("MISC Bundled Installer")
print("======================")
print()

if not http then
  print("ERROR: This computer needs internet access.")
  print("Add a modem to access the network and retry.")
  return
end

local repo = "https://raw.githubusercontent.com/SentinelXPS/CC-MISC-Local/master"

print("Installing MISC Bundled...")
print()

if download(repo .. "/misc_bundled.lua", "misc_bundled.lua") then
  print()
  print("Installation complete!")
  print()
  print("To start the system, run:")
  print("  lua misc_bundled.lua")
  print()
  
  term.write("Create startup script? [y/n]: ")
  local _, key = os.pullEvent("key")
  if key == keys.y then
    local f = fs.open("startup.lua", "w")
    f.write("shell.run('misc_bundled.lua')\n")
    f.close()
    print("yes")
    print("Created startup.lua - system will start on boot")
  else
    print("no")
  end
  
  print()
  print("Attach your inventories and restart!")
else
  print()
  print("Installation failed. Check your internet connection.")
end
