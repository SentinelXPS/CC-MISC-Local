#!/usr/bin/env lua
--------------------------------------------------------------------------------
-- MISC BUNDLED: Complete Single-File Minecraft CC: Tweaked System
-- All-in-one: Server + Terminal for single computer (no modem required)
-- Original system: https://github.com/SentinelXPS/CC-MISC-Local
-- Bundled version: Includes all core components in one file
--------------------------------------------------------------------------------

-- ====== COMMON LIBRARY =====================================================
local common = {}

function common.saveTableToFile(file, table, compact, repetitions)
  if type(compact) == "nil" then compact = true end
  local f = fs.open(file, "w")
  if not f then return false end
  f.write(textutils.serialise(table, {compact=compact, allow_repetitions = repetitions}))
  f.close()
  return true
end

function common.loadTableFromFile(file)
  local f = fs.open(file, "r")
  if not f then return nil end
  local t = textutils.unserialise(f.readAll())
  f.close()
  return t
end

function common.printf(s, ...)
  print(s:format(...))
end

function common.enforceType(value, argPos, ...)
  for _, targetType in ipairs({...}) do
    if targetType == "integer" then
      if type(value) == "number" and math.ceil(value) == math.floor(value) then return end
    elseif type(value) == targetType then
      return
    end
  end
  error(("Argument #%u invalid, expected %s, got %s"):format(argPos,
    textutils.serialise({...},{compact=true}), type(value)), 2)
end

-- ====== LOCAL COMMUNICATION LIBRARY (localLib) =============================
local localLib = {}
local _iface

function localLib.setup(interface)
  _iface = interface
  interface.addInventoryUpdateHandler(function(list)
    os.queueEvent("update", list)
  end)
end

function localLib.connect()
end

local function call(method, ...)
  assert(_iface, "localLib not set up. Call localLib.setup(interface) first.")
  return _iface.callMethod(method, table.pack(...))
end

function localLib.list()
  return call("list")
end

function localLib.listCraftables()
  return call("listCraftables")
end

function localLib.requestCraft(name, count)
  return call("requestCraft", name, count)
end

function localLib.pushItems(async, targetInventory, name, amount, toSlot, nbt, options)
  return call("pushItems", async, targetInventory, name, amount, toSlot, nbt, options)
end

function localLib.pullItems(async, fromInventory, fromSlot, amount, toSlot, nbt, options)
  return call("pullItems", async, fromInventory, fromSlot, amount, toSlot, nbt, options)
end

function localLib.performTransfer()
  return call("performTransfer")
end

function localLib.startCraft(jobID)
  return call("startCraft", jobID)
end

function localLib.cancelCraft(jobID)
  return call("cancelCraft", jobID)
end

function localLib.addGridRecipe(name, produces, recipe, shaped)
  return call("addGridRecipe", name, produces, recipe, shaped)
end

function localLib.removeGridRecipe(name)
  return call("removeGridRecipe", name)
end

function localLib.getUsage()
  return call("getUsage")
end

function localLib.getCraftStatus()
  return call("getCraftStatus")
end

function localLib.getConfig()
  return call("getConfig")
end

function localLib.setConfigValue(module, setting, value)
  return call("setConfigValue", module, setting, value)
end

function localLib.subscribe()
  while true do
    os.pullEvent()
  end
end

setmetatable(localLib, {
  __index = function(t, k)
    return function(...)
      return call(k, ...)
    end
  end
})

-- ====== ESSENTIAL MODULES =================================================

-- Minimal inventory module (simplified)
local inventoryModule = {
  id = "inventory",
  version = "1.2.4",
  config = {
    inventories = {
      type = "table",
      description = "List of storage peripherals to use",
      default = {},
    },
    inventoryAddPatterns = {
      type = "table",
      description = "List of lua patterns to match peripherals",
      default = {"minecraft:chest_.+"},
    },
    inventoryRemovePatterns = {
      type = "table",
      description = "Patterns to exclude from storage",
      default = {"minecraft:furnace_.+"},
    },
  },
  init = function(loaded, config)
    local inventories = {}
    for i, v in ipairs(config.inventory.inventories.value) do
      inventories[i] = v
    end
    
    local attachedInventories = {}
    for _, v in ipairs(peripheral.getNames()) do
      if peripheral.hasType(v, "inventory") then
        table.insert(attachedInventories, v)
      end
    end
    
    for _, v in ipairs(attachedInventories) do
      for _, pattern in ipairs(config.inventory.inventoryAddPatterns.value) do
        if v:match(pattern) then
          inventories[#inventories + 1] = v
        end
      end
    end
    
    for i = #inventories, 1, -1 do
      for _, pattern in ipairs(config.inventory.inventoryRemovePatterns.value) do
        if string.match(inventories[i], pattern) then
          table.remove(inventories, i)
        end
      end
    end
    
    local storage = {}
    local items = {}
    
    function storage.list()
      items = {}
      for _, invName in ipairs(inventories) do
        local inv = peripheral.wrap(invName)
        if inv then
          for slot, item in pairs(inv.list()) do
            if item then
              local key = item.name .. ":" .. (item.nbt or "")
              if not items[key] then
                items[key] = {
                  name = item.name,
                  nbt = item.nbt or "",
                  count = 0,
                  maxCount = item.maxCount or 64,
                  displayName = item.displayName or item.name,
                  enchantments = {},
                }
              end
              items[key].count = items[key].count + item.count
            end
          end
        end
      end
      local list = {}
      for _, item in pairs(items) do
        table.insert(list, item)
      end
      return list
    end
    
    function storage.pushItems(targetInventory, name, amount, toSlot)
      amount = amount or 64
      for _, invName in ipairs(inventories) do
        if invName == targetInventory then
          local inv = peripheral.wrap(invName)
          if inv then
            local pushed = 0
            for slot, item in pairs(inv.list()) do
              if item and item.name == name and pushed < amount then
                local canPush = math.min(item.maxCount - item.count, amount - pushed)
                inv.pullItems(invName, slot, canPush, toSlot or slot)
                pushed = pushed + canPush
              end
            end
            return pushed
          end
        end
      end
      return 0
    end
    
    function storage.pullItems(fromInventory, fromSlot, amount, toSlot)
      amount = amount or 64
      for _, invName in ipairs(inventories) do
        if invName == fromInventory then
          local inv = peripheral.wrap(invName)
          if inv then
            return inv.pullItems(fromInventory, fromSlot, amount, toSlot or fromSlot)
          end
        end
      end
      return 0
    end
    
    function storage.defrag()
      -- Simplified defrag
    end
    
    function storage.performTransfer()
      -- No-op for bundled version
    end
    
    function storage.getUsage()
      local total = 0
      local used = 0
      for _, invName in ipairs(inventories) do
        local inv = peripheral.wrap(invName)
        if inv and inv.size then
          local size = inv.size()
          total = total + size
          local count = 0
          for _ in pairs(inv.list()) do count = count + 1 end
          used = used + count
        end
      end
      return { used = used, total = total, free = total - used }
    end
    
    storage.start = function() end
    
    return storage
  end,
  dependencies = {},
}

-- Interface module (bridges server and client)
local interfaceModule = {
  id = "interface",
  version = "1.4.0",
  config = {},
  init = function(loaded, config)
    local genericInterface = {}
    
    function genericInterface.pushItems(async, targetInventory, name, amount, toSlot, nbt, options)
      return loaded.inventory.pushItems(targetInventory, name, amount, toSlot)
    end
    
    function genericInterface.pullItems(async, fromInventory, fromSlot, amount, toSlot, nbt, options)
      return loaded.inventory.pullItems(fromInventory, fromSlot, amount, toSlot)
    end
    
    function genericInterface.list()
      return loaded.inventory.list()
    end
    
    function genericInterface.performTransfer()
      return loaded.inventory.performTransfer()
    end
    
    function genericInterface.listCraftables()
      return {}
    end
    
    function genericInterface.requestCraft(name, count)
      return { success = false, jobId = "" }
    end
    
    function genericInterface.startCraft(jobID)
      return false
    end
    
    function genericInterface.cancelCraft(jobID)
      return false
    end
    
    function genericInterface.addGridRecipe(name, produces, recipe, shaped)
      return false
    end
    
    function genericInterface.removeGridRecipe(name)
      return false
    end
    
    function genericInterface.listCraftJobs()
      return {}
    end
    
    function genericInterface.getCraftStatus()
      return { jobs = 0, tasks = 0 }
    end
    
    function genericInterface.getUsage()
      return loaded.inventory.getUsage()
    end
    
    function genericInterface.getModules()
      return { inventory = "1.2.4", interface = "1.4.0" }
    end
    
    function genericInterface.getConfig()
      return config
    end
    
    function genericInterface.setConfigValue(module, setting, value)
      if config[module] and config[module][setting] then
        return config[module][setting].set(config[module][setting], value)
      end
      return false
    end
    
    local interface = {}
    local inventoryUpdateHandlers = {}
    
    function interface.addInventoryUpdateHandler(handler)
      table.insert(inventoryUpdateHandlers, handler)
    end
    
    function interface.callMethod(method, args)
      local desiredMethod = genericInterface[method]
      assert(desiredMethod, method .. " is not a valid method")
      return desiredMethod(table.unpack(args, 1, args.n))
    end
    
    function interface.start()
      while true do
        local e = {os.pullEvent()}
        if e[1] == "inventoryUpdate" then
          local list = genericInterface.list()
          for _, f in pairs(inventoryUpdateHandlers) do
            f(list)
          end
        end
      end
    end
    
    return { interface = interface }
  end,
  dependencies = { inventory = { min = "1.1" } },
}

-- ====== CONFIGURATION SYSTEM ==============================================
local function initializeConfig(modules)
  local config = {}
  local unorderedModules = {}
  local loaded = {}
  
  for _, mod in ipairs(modules) do
    table.insert(unorderedModules, mod)
    loaded[mod.id] = mod
    config[mod.id] = mod.config or {}
    for name, info in pairs(config[mod.id]) do
      config[mod.id][name].value = info.default
    end
  end
  
  -- Topological sort for dependencies
  local moduleInitOrder = {}
  local function visit(module)
    if module.permanant then return end
    if module.temporary then error("Cyclic dependency tree") end
    module.temporary = true
    
    for id, info in pairs(module.dependencies or {}) do
      local dep = loaded[id]
      if dep then
        visit(dep)
      elseif not info.optional then
        error(("Module %s requires %s"):format(module.id, id))
      end
    end
    
    module.temporary = nil
    module.permanant = true
    table.insert(moduleInitOrder, module)
  end
  
  for _, v in pairs(unorderedModules) do
    if not v.permanant then visit(v) end
  end
  
  for _, v in pairs(unorderedModules) do
    v.permanant = nil
  end
  
  -- Initialize modules
  local moduleExecution = {}
  local moduleIds = {}
  
  for _, mod in ipairs(moduleInitOrder) do
    if mod.init then
      loaded[mod.id].interface = mod.init(loaded, config)
      if loaded[mod.id].interface and loaded[mod.id].interface.start then
        table.insert(moduleExecution, coroutine.create(loaded[mod.id].interface.start))
        table.insert(moduleIds, mod.id)
      end
      common.printf("Initialized %s v%s", mod.id, mod.version)
    end
  end
  
  return { loaded = loaded, config = config, execution = moduleExecution, ids = moduleIds }
end

-- ====== SERVER LOOP ========================================================
local function serverLoop(execution, moduleIds, moduleFilters)
  while true do
    local e = table.pack(os.pullEvent())
    for i, co in ipairs(execution) do
      if not moduleFilters[co] or moduleFilters[co] == "" or moduleFilters[co] == e[1] then
        local ok, filter = coroutine.resume(co, table.unpack(e, 1, e.n))
        if not ok then
          term.setTextColor(colors.red)
          print("Module errored: " .. tostring(filter))
          error(filter)
        end
        moduleFilters[co] = filter
      end
    end
  end
end

-- ====== TERMINAL INTERFACE =================================================
local function terminalLoop(lib)
  settings.define("misc.local", { description = "Run terminal on same computer as server", type = "boolean" })
  settings.define("misc.turtle", { description = "Should this terminal be in turtle mode?", type = "boolean" })
  settings.set("misc.local", true)
  settings.set("misc.turtle", settings.get("misc.turtle") ~= nil and settings.get("misc.turtle") or false)
  settings.save()
  
  local w, h = term.getSize()
  local display = window.create(term.current(), 1, 1, w, h)
  term.redirect(display)
  
  local inventory = {}
  local modes = { "SEARCH", "CRAFT", "CONFIG", "SYSINFO" }
  local mode = "SEARCH"
  
  local function setColors(fg, bg)
    display.setTextColor(fg)
    display.setBackgroundColor(bg)
  end
  
  local function clearLine(y)
    display.setCursorPos(1, y)
    display.clearLine()
  end
  
  local function text(x, y, t)
    display.setCursorPos(math.floor(x), math.floor(y))
    display.write(t)
  end
  
  local function drawSearch()
    setColors(colors.white, colors.black)
    display.clear()
    
    -- Menu bar
    setColors(colors.white, colors.black)
    clearLine(1)
    text(1, 1, "MISC Terminal - SEARCH  CRAFT  CONFIG  SYSINFO")
    
    -- Header
    setColors(colors.white, colors.black)
    clearLine(2)
    text(1, 2, "Inventory Items:")
    
    -- List items
    inventory = lib.list()
    for i, item in ipairs(inventory) do
      if i > h - 3 then break end
      setColors(colors.white, colors.black)
      clearLine(2 + i)
      text(1, 2 + i, string.format("%-30s x%d", item.displayName, item.count))
    end
  end
  
  local function drawCraft()
    setColors(colors.white, colors.black)
    display.clear()
    clearLine(1)
    text(1, 1, "MISC Terminal - SEARCH  CRAFT  CONFIG  SYSINFO")
    clearLine(2)
    text(1, 2, "Crafting: No craftables available in bundled mode")
  end
  
  local function drawConfig()
    setColors(colors.white, colors.black)
    display.clear()
    clearLine(1)
    text(1, 1, "MISC Terminal - SEARCH  CRAFT  CONFIG  SYSINFO")
    clearLine(2)
    text(1, 2, "Configuration:")
    clearLine(3)
    text(1, 3, "Local mode: ENABLED")
    clearLine(4)
    text(1, 4, "No modem required")
  end
  
  local function drawSysinfo()
    setColors(colors.white, colors.black)
    display.clear()
    clearLine(1)
    text(1, 1, "MISC Terminal - SEARCH  CRAFT  CONFIG  SYSINFO")
    
    local usage = lib.getUsage()
    local status = lib.getCraftStatus()
    
    clearLine(2)
    text(1, 2, string.format("Storage: %d/%d used", usage.used, usage.total))
    clearLine(3)
    text(1, 3, string.format("Free slots: %d", usage.free))
    clearLine(4)
    text(1, 4, string.format("Crafting jobs: %d", status.jobs))
    clearLine(5)
    text(1, 5, string.format("Crafting tasks: %d", status.tasks))
  end
  
  -- Main terminal loop
  while true do
    if mode == "SEARCH" then
      drawSearch()
    elseif mode == "CRAFT" then
      drawCraft()
    elseif mode == "CONFIG" then
      drawConfig()
    elseif mode == "SYSINFO" then
      drawSysinfo()
    end
    
    local e = {os.pullEvent()}
    if e[1] == "key" and e[2] == keys.tab then
      local modeIndex = 1
      for i, m in ipairs(modes) do
        if m == mode then
          modeIndex = i + 1
          break
        end
      end
      if modeIndex > #modes then modeIndex = 1 end
      mode = modes[modeIndex]
    elseif e[1] == "update" then
      inventory = e[2]
    end
  end
end

-- ====== MAIN PROGRAM =======================================================
print("Starting MISC in local bundled mode...")
print("Server and terminal are running together on one computer.")
print("")

-- Initialize modules
local initResult = initializeConfig({inventoryModule, interfaceModule})
local loaded = initResult.loaded
local config = initResult.config
local moduleExecution = initResult.execution
local moduleIds = initResult.ids
local moduleFilters = {}

-- Setup local communication
assert(loaded.interface and loaded.interface.interface,
  "The 'interface' module must be loaded to use local mode.")
localLib.setup(loaded.interface.interface)

-- Run server and terminal in parallel
parallel.waitForAny(
  function() serverLoop(moduleExecution, moduleIds, moduleFilters) end,
  function() terminalLoop(localLib) end
)

print("Stopped.")
