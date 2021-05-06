--[[
name : waze.lua
version: 1.0

description: plugin for dzbasic; calculate travel time with Waze

6 optional arguments:
- start_long, start_lat : latitude and longitude of starting point (default: home)
- dest_long, dest_lat : latitude and longitude of arrival (default: home)
- dest_addr and/or start_addr : address of a place (default: home)

Return a table with 2 values:
- routeName
- totalRouteTime : travel time in minutes

author : casanoe
creation : 16/04/2021
update : 05/05/2021

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

        local destaddr, destlon, destlat, startaddr, startlon, startlat, r

        if args['dest_addr'] then
            destaddr = geoLoc(args['dest_addr'])[1]
            destlon = destaddr['lon']
            destlat = destaddr['lat']
        else
            destlon = args['dest_lon'] or dz.settings.location.longitude
            destlat = args['dest_lat'] or dz.settings.location.latitude
        end
        if args['start_addr'] then
            startaddr = geoLoc(args['start_addr'])[1]
            startlon = startaddr['lon']
            startlat = startaddr['lat']
        else
            startlon = args['start_lon'] or dz.settings.location.longitude
            startlat = args['start_lat'] or dz.settings.location.latitude
        end

        if startlon and destlon then
            local out = osCommand('/usr/bin/curl --referer https://www.waze.com "https://www.waze.com/row-RoutingManager/routingRequest?from=x%3A'..startlon..'+y%3A'..startlat..'&to=x%3A'..destlon..'+y%3A'..destlat..'&returnJSON=true&timeout=6000&nPaths=1&options=AVOID_TRAILS%3At%2CALLOW_UTURNS"')
            local data = fromData(out)
            r = {}
            local routeTotalTimeSec = tonumber(data['response']['totalRouteTime'])
            r['totalRouteTime'] = routeTotalTimeSec / 60 - ((routeTotalTimeSec%60) / 60)
            r['routeName'] = data['response']['routeName']
        else r = 'Err' end

        dzBasicCall_return('waze', r, TIMEOUT)
    end
}
