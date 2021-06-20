--[[
name : vigilance.lua
version: 1.1

description: meteofrance vigilance plugin for dzbasic

1 optional argument: dept (departement number in France, default 28)

Return: table
 txtcol     = vigilance color level (text)
 col        = vigilance color level (number)
 vigilance  = text describing the weather event

author : casanoe
creation : 16/04/2021
update : 02/06/2021

--]]

-- Script description
local scriptName = 'vigilance'
local scriptVersion = '1.1'

-- Dzvents
return {
    on = {
        customEvents = { 'vigilance' }
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

        local context = dzBasicCall_getData('vigilance')
        local args = context['args']
        local dept = args['dept'] or "28"

        local r = {}

        local vigi = {'vent violent', 'pluie inondation', 'orages', 'inondations', 'neige-verglas', 'canicule', 'grand froid', 'avalanche', 'vagues-submersion'}
        local coul = { 'vert', 'jaune', 'orange', 'rouge' }

        local out2 = curl('http://vigilance2019.meteofrance.com/data/NXFR33_LFPW_.xml')
        local data2 = fromData(out2)

        for k, v in pairs(data2['CV']['DV']) do
            if v['_attr']['dep'] == tostring(dept) then
                r['txtcol'] = coul[tonumber(v['_attr']['coul'])]
                r['col'] = tonumber(v['_attr']['coul'])
                r['vigilance'] = ''
                r['vigilances'] = {}
                if v['risque'] then
                    if v['risque']['_attr'] then
                        r['vigilances'][1] = vigi[tonumber(v['risque']['_attr']['val'])]
                    else
                        for x, y in pairs(v['risque']) do
                            r['vigilances'][#r['vigilances'] + 1] = vigi[tonumber(y['_attr']['val'])]
                        end
                    end
                    r['vigilance'] = table.concat(r['vigilances'], ',')
                end
                break
            end
        end

        dzBasicCall_return('vigilance', r, TIMEOUT)

    end
}
