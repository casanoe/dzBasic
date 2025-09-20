--[[
name : meteo.lua
version: 1.0

description: openweathermap meteo plugin for dzbasic

To be created: a custom variable "openweathermap_appid" with your api token

5 optional arguments:
- lat: latitude, lon: longitude (default: domoticz localisation)
- lang: language (default: fr)
- addr: address of a place
- appid : openweathermap api token (default: value of custom variable "openweathermap_appid")

Return: table

author : casanoe
creation : 16/04/2021
update : 05/05/2021

--]]

-- Script description
local scriptName = 'meteo'
local scriptVersion = '1.0'

-- Dzvents
return {
    on = {
        customEvents = { 'meteo' }
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

        local TIMEOUT = 30 * 60

        -----------------------------------------

        local context = dzBasicCall_getData('meteo')
        local args = context['args']

        local addr, loc, appid, lang

        if args['addr'] then
            addr = geoLoc(args['addr'])
            args['lon'] = addr['lon']
            args['lat'] = addr['lat']
        end

        loc = 'lat='..(args['lat'] or dz.settings.location.latitude)
        loc = loc ..'&lon='..(args['lon'] or dz.settings.location.longitude)
        lang = args['lang'] or DZ_LANG
        appid = args['appid'] or dz.variables('openweathermap_appid').value

        local r = {}

        local out1 = curl('http://api.openweathermap.org/data/3.0/onecall?'..loc..'&units=metric&lang='..lang..'&exclude=minutely&appid='..appid, {timeout = 5})
        local data1 = fromData(out1)

        r['clouds'] = data1['current']['clouds']
        r['wind'] = data1['current']['wind_speed']
        r['temperature'] = data1['current']['temp']
        r['humidity'] = data1['current']['humidity']
        r['rain'] = data1['daily'][1]['rain'] or 0
        r['%rain'] = {}
        for k, v in pairs(data1['hourly']) do
            r['%rain'][k] = v['pop'] * 100 or 0
        end
        r['meteo'] = data1['current']['weather'][1]['description']
        r['vigilance'] = data1['alert'] or 'RAS'
        r['prevision'] = {}
        for k, v in pairs(data1['daily']) do
            r['prevision'][k] = {}
            r['prevision'][k]['clouds'] = v['clouds']
            r['prevision'][k]['wind'] = v['wind_speed']
            r['prevision'][k]['temperature'] = v['temp']['day']
            r['prevision'][k]['humidity'] = v['humidity']
            r['prevision'][k]['rain'] = v['rain'] or 0
            r['prevision'][k]['%rain'] = v['pop'] * 100 or 0
            r['prevision'][k]['snow'] = v['snow'] or 0
            r['prevision'][k]['meteo'] = v['weather'][1]['description']
        end

        dzBasicCall_return('meteo', r, TIMEOUT)

    end
}
