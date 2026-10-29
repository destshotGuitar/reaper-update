-- @description Update REAPER
-- @author destshotGuitar
-- @version 1.0.0
-- @changelog Initial release
-- @link https://github.com/destshotGuitar/reaper-update
-- @about
--   # Update REAPER
--
--   Checks reaper.fm for a newer REAPER version and installs it in one click:
--   REAPER quits (asking to save projects), the update is downloaded and
--   installed, and REAPER starts again.
--
--   Works on Windows, macOS and Linux. Administrator password is requested
--   only when REAPER is installed in a system folder.
-- @provides
--   [main] .
--   [nomain] reaper-update/update.sh
--   [nomain] reaper-update/update.ps1

local TITLE = "Update REAPER"

local os_name = reaper.GetOS()
local is_win = os_name:match("^Win") ~= nil
local is_mac = os_name:match("^OSX") ~= nil or os_name:match("^macOS") ~= nil

local function quote(s)
  if is_win then return '"' .. s .. '"' end
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- Which download from reaper.fm matches this REAPER.
local function platform()
  local build = reaper.GetAppVersion():match("/(.*)$") or ""
  if is_win then
    if build:match("arm64ec") then return "win-arm64ec" end
    return os_name == "Win64" and "win-x64" or "win-x86"
  elseif is_mac then
    return "mac"
  else
    -- "Linux-x86_64", "Linux-aarch64", "Linux-armv7l", "Linux-i686"
    return "linux-" .. (os_name:match("^Linux%-(.+)$") or "x86_64")
  end
end

-- "7.84", "7.84rc1/linux-x86_64", "7.84+dev1028/x64" -> 7.84
local function version_number(v)
  return tonumber(v:match("^(%d+%.%d+)") or v:match("^(%d+)") or "")
end

local script_dir = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""
local helper_dir = script_dir .. "reaper-update" .. (is_win and "\\" or "/")
local exe_dir = reaper.GetExePath():gsub("[/\\]+$", "")

local function helper(args)
  if is_win then
    return "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "
      .. quote(helper_dir .. "update.ps1") .. " " .. args
  end
  return "/bin/bash " .. quote(helper_dir .. "update.sh") .. " " .. args
end

local res = reaper.ExecProcess(helper("check " .. platform()), 30000)
local code, out = (res or ""):match("^(%-?%d+)\n(.-)%s*$")
local latest = out and out:match("^%d+%.%d+$") and out
local current = reaper.GetAppVersion():match("^[^/]+")

if code ~= "0" or not latest then
  reaper.MB("Could not check for updates.\n\n" .. (out or res or "helper did not start"), TITLE, 0)
  return
end

-- 7.84rc1 and 7.84+dev are pre-releases of 7.84, so 7.84 is still an update
local cur = version_number(current) or 0
local is_prerelease = not current:match("^%d+%.%d+$")
if version_number(latest) < cur or (version_number(latest) == cur and not is_prerelease) then
  reaper.MB("REAPER is up to date (" .. current .. ").", TITLE, 0)
  return
end

local answer = reaper.MB(
  "REAPER " .. latest .. " is available (installed: " .. current .. ").\n\n" ..
  "REAPER will quit (you will be asked to save projects), the update will be " ..
  "installed and REAPER will start again.\n\nUpdate now?",
  TITLE, 4)
if answer ~= 6 then return end

local install = helper("install " .. platform() .. " " .. quote(exe_dir))
-- the updater must survive REAPER quitting
if is_mac then
  install = "/usr/bin/nohup " .. install
elseif not is_win then
  install = "setsid -f " .. install
end
reaper.ExecProcess(install, -1)
reaper.Main_OnCommand(40004, 0) -- File: Quit REAPER
