--[[
name : waze.lua
version: 1.0

description: plugin for dzbasic; calculate travel time with Waze

4 optional arguments:
- start_long, start_lat : latitude and longitude of starting point (default: domoticz localisation)
- dest_long, dest_lat : latitude and longitude of arrival (default: Eiffel Tower)

Return a table with 2 values:
- routeName
- totalRouteTime : travel time in minutes

author : casanoe
creation : 16/04/2021
update : 16/04/2021

--]]

-- Script description
local scriptName = 'waze'
local scriptVersion = '1.0'

-- Dzvents
return {
    on = {
        customEvents = { 'waze' }
    },
    logging = {
        -- level    =   domoticz.LOG_DEBUG,
        -- level    =   domoticz.LOG_INFO,
        -- level    =   domoticz.LOG_ERROR,
        -- level    =   domoticz.LOG_MODULE_EXEC_INFO,
        marker = scriptName..' v'..scriptVersion
    },
    execute = function(dz, triggeredItem, info)
        dz.helpers.load_dzBasicLibs(dz)

        local TIMEOUT = nil
        local context = dzBasicCall_getData('waze')
        local args = context['args']

        local startlon = args['start_long'] or dz.settings.location.longitude
        local startlat = args['start_lat'] or dz.settings.location.latitude
        local destlon = args['dest_long'] or "2.294481"
        local destlat = args['dest_lat'] or "48.858370"

        local out = osCommand('/usr/bin/curl --referer https://www.waze.com "https://www.waze.com/row-RoutingManager/routingRequest?from=x%3A'..startlon..'+y%3A'..startlat..'&to=x%3A'..destlon..'+y%3A'..destlat..'&returnJSON=true&timeout=6000&nPaths=1&options=AVOID_TRAILS%3At%2CALLOW_UTURNS"')
        local data = fromData(out)

        local r = {}
        local routeTotalTimeSec = tonumber(data['response']['totalRouteTime'])
        r['totalRouteTime'] = routeTotalTimeSec / 60 - ((routeTotalTimeSec%60) / 60)
        r['routeName'] = data['response']['routeName']

        dzBasicCall_return('waze', r, TIMEOUT)
    end
}
