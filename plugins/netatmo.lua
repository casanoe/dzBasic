--[[
name : netatmo.lua
version: 1.0

description: netatmo plugin for dzbasic

5 uservariables to be created :
'netatmo_homeid'
'netatmo_appid'
'netatmo_appsecret'
'netatmo_username'
'netatmo_passwd'

author : casanoe
creation : 16/04/2021
update : 16/04/2021

--]]

-- Script description
local scriptName = 'netatmo'
local scriptVersion = '1.0'

-- Dzvents
return {
    on = {
        customEvents = { 'netatmo' },
        shellCommandResponses = { 'netatmo*' }
    },
    logging = {
        -- level    =   domoticz.LOG_DEBUG,
        -- level    =   domoticz.LOG_INFO,
        -- level    =   domoticz.LOG_ERROR,
        -- level    =   domoticz.LOG_MODULE_EXEC_INFO,
        marker = scriptName..' v'..scriptVersion
    },
    data = {
        token = { initial = {} }
    },

    execute = function(dz, triggeredItem, info)

        local TIMEOUT = nil

        local home_id = dz.variables('netatmo_homeid').value
        local app_id = dz.variables('netatmo_appid').value
        local app_secret = dz.variables('netatmo_appsecret').value
        local username = dz.variables('netatmo_username').value
        local password = dz.variables('netatmo_passwd').value
        local scope = 'read_station read_thermostat write_thermostat read_camera write_camera access_camera read_presence access_presence write_presence read_homecoach'

        local dzu = dz.utils

        dz.helpers.load_dzBasicLibs(dz)

        local now = os.time(os.date('*t'))

        -----------------------------------------

        local trigger = triggeredItem.trigger

        if trigger == 'netatmo' then
            if not dz.data.token['expires'] or dz.data.token['expires'] < now then
                print('>>>> NETATMO GET AUTH')
                curl('https://api.netatmo.net/oauth2/token', {
                    headers = { 'Content-type: application/x-www-form-urlencoded;charset=UTF-8' },
                    data = {
                        grant_type = 'password',
                        client_id = app_id,
                        client_secret = app_secret,
                        username = username,
                        password = password,
                        scope = scope
                    },
                    method = 'POST',
                    callback = 'netatmo_auth'
                })
            else
                print('>>>> NETATMO AUTH NOT EXPIRED')
                trigger = 'netatmo_auth'
            end
        end

        if trigger == 'netatmo_auth' then
            if triggeredItem.ok and triggeredItem.isJSON then
                print('>>>> NETATMO UPDATE AUTH TOKEN')
                data = dzu.fromJSON(triggeredItem.data, '')
                dz.data.token = data
                aprint(data)
                dz.data.token['expires'] = data['expires_in'] + now
            else
                print('>>>> NETATMO TOKEN AUTH OK')
                data = dz.data.token
            end
            print('>>>> NETATMO GET DATA')
            curl('https://api.netatmo.com/api/gethomedata', {
                headers = { 'accept: application/json', 'Authorization: Bearer '..data['access_token'] },
                data = {
                    size = 0,
                    home_id = home_id
                },
                callback = 'netatmo_data'
            })
        end

        if trigger == 'netatmo_data' then
            if triggeredItem.ok and triggeredItem.isJSON then
                --print(triggeredItem.data)
                args = dzBasicCall_getData('netatmo')['args']
                aprint('ARG = '..args['msg'])
                print('>>>> NETATMO CALL BACK')

                dzBasicCall_return('netatmo', triggeredItem.json, TIMEOUT)

            end
        end

    end
}
