-- Solana DEF CON Badge - Radio Scanner
-- Wi-Fi scan + BLE status
-- BLE nearby-device scanning requires a firmware API
-- that is not currently exposed by the documented Lua SDK.

local wifi = badge.wifi
local ble = badge.ble
local gfx = badge.gfx

local page = 1
local networks = {}
local selected = 1
local scanning = false
local scan_elapsed = 0
local message = "Starting Wi-Fi scan..."

local function scan_wifi()
    if wifi.scanning() then
        message = "Scan already running"
        return
    end

    local ok = wifi.scan()
    if ok then
        scanning = true
        scan_elapsed = 0
        message = "Scanning..."
    else
        message = "Could not start scan"
    end
end

function on_start()
    scan_wifi()
end

function on_update(dt)
    if scanning then
        scan_elapsed = scan_elapsed + dt

        if not wifi.scanning() then
            networks = wifi.networks() or {}
            scanning = false
            selected = math.max(
                1, math.min(selected, #networks)
            )
            message = tostring(#networks) .. " networks found"
        elseif scan_elapsed > 20 then
            scanning = false
            message = "Scan timed out - press SELECT"
        end
    end
end

function on_button(key, pressed)
    if not pressed then return end

    if key == "b" then
        badge.system.exit()
    elseif key == "left" then
        page = 1
    elseif key == "right" then
        page = 2
    elseif key == "up" and page == 1 then
        selected = math.max(1, selected - 1)
    elseif key == "down" and page == 1 then
        selected = math.min(#networks, selected + 1)
    elseif key == "a" then
        if page == 1 then
            scan_wifi()
        end
    end
end

local function header(title)
    gfx.fill_rect(0, 0, 320, 32, gfx.SOLANA_PURPLE)
    gfx.text(title, 10, 9, gfx.WHITE, 2)
    gfx.line(0, 33, 320, 33, gfx.SOLANA_GREEN)
end

function on_draw()
    gfx.clear(gfx.BG)

    if page == 1 then
        header("Wi-Fi Scanner")

        gfx.text(message, 10, 42, gfx.SOLANA_TEAL, 1)

        if #networks == 0 and not scanning then
            gfx.text("No networks found", 10, 72, gfx.MUTED, 1)
        end

        for i, net in ipairs(networks) do
            local y = 66 + (i - selected) * 25

            if i >= selected and i < selected + 6 then
                if i == selected then
                    gfx.fill_round_rect(
                        6, y - 3, 308, 23, 4, gfx.PANEL
                    )
                end

                local ssid = net.ssid or "(hidden)"
                if #ssid > 22 then
                    ssid = string.sub(ssid, 1, 19) .. "..."
                end

                local color = i == selected
                    and gfx.SOLANA_GREEN or gfx.WHITE

                gfx.text(ssid, 12, y, color, 1)
                gfx.text_right(
                    tostring(net.rssi or "?") .. " dBm",
                    308, y, gfx.CYAN, 1
                )

                local security = net.encrypted
                    and "SECURE" or "OPEN"

                gfx.text(
                    security, 14, y + 11, gfx.MUTED, 1
                )
            end
        end

        gfx.line(0, 213, 320, 213, gfx.BORDER)
        gfx.text("UP/DOWN: Select", 8, 220, gfx.WHITE, 1)
        gfx.text("SELECT: Rescan", 158, 220, gfx.SOLANA_GREEN, 1)

    else
        header("Bluetooth LE")

        gfx.text("BLE radio status", 12, 48, gfx.SOLANA_GREEN, 2)
        gfx.text(
            "Advertising: " .. tostring(ble.enabled()),
            12, 83, gfx.WHITE, 1
        )
        gfx.text(
            "Connected: " .. tostring(ble.connected()),
            12, 105, gfx.WHITE, 1
        )

        local addr = ble.address() or "Unavailable"
        gfx.text("Badge BLE address:", 12, 137, gfx.MUTED, 1)
        gfx.text(addr, 12, 157, gfx.CYAN, 1)

        gfx.text("Nearby BLE scan:", 12, 183, gfx.WHITE, 1)
        gfx.text(
            "Not exposed by current Lua SDK",
            12, 199, gfx.ORANGE, 1
        )
        gfx.text("LEFT: Wi-Fi", 10, 220, gfx.SOLANA_GREEN, 1)
    end
end
