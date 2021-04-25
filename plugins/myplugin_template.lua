--[[
name : myplugin_template.lua
version: 1.0

description: my plugin for dzbasic

author : myname
creation : 16/04/2021
update : 16/04/2021

--]]

-- Script description
local scriptName = 'myplugin'
local scriptVersion = '1.0'

-- Dzvents
return {
    on = {
        customEvents = { 'myplugin' }
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
        -- time to live of the data result (seconds)
        -- 0 : infinite ; nil : update always
        local TIMEOUT = 60 * 30
        local context = dzBasicCall_getData('myplugin')
        local args = context['args']

        -- plugin code
        print(args['message'])
        local r = "pong from myplugin"
        -- end of plugin code

        dzBasicCall_return('myplugin', r, TIMEOUT)
    end
}
