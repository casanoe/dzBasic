--[[
name : meteofrance.lua
version: 1.0

description: meteofrance plugin for dzbasic ; no longer works ?

author : casanoe
creation : 16/04/2021
update : 16/04/2021

--]]

-- Script description
local scriptName = 'meteofrance'
local scriptVersion = '1.0'

-- Dzvents
return {
    on = {
        customEvents = { 'meteofrance' }
    },

    execute = function(dz, triggeredItem, info)

        local dzu = dz.utils

        dz.helpers.load_dzBasicLibs(dz)

        local TIMEOUT = 30 * 60

        local city = '281400'
        local afterhour = 1

        -----------------------------------------

        local context = dzBasicCall_getData('meteofrance')
        local args = context['args']
        city = args['city'] and args['city'] or city
        afterhour = args['afterhour'] and args['afterhour'] or afterhour

        local Time = require('Time')
        local hour = dz.time.hour
        local hour1 = dz.time.addHours(afterhour).hour
        local r = {}

        local t = {'01-04', '01-04', '04-07', '07-10', '10-13', '13-16', '16-19', '19-22', '22-01'}
        local t1 = {'02-05', '02-05', '05-08', '08-11', '11-14', '14-17', '17-20', '20-23', '23-03'}
        local coul = { 'vert', 'jaune', 'orange', 'rouge' }
        local vigi = {'vent violent', 'pluie inondation', 'orages', 'inondations', 'neige-verglas', 'canicule', 'grand froid', 'avalanche', 'vagues-submersion'}

        local x = t[math.ceil(hour1 / 3) + 1]
        local x1 = t1[math.ceil(hour1 / 3) + 1]

        local out1 = curl('http://ws.meteofrance.com/ws/getDetail/france/'..city..'.json')
        aprint(out1)
        local data1 = fromData(out1)
        local dept = data1['result']['ville']['numDept']

        r = data1['result']['previsions48h']['0_'..x] or data1['result']['previsions48h']['1_'..x] or
        data1['result']['previsions48h']['0_'..x1] or data1['result']['previsions48h']['1_'..x1]
        r['meteodujour'] = data1['result']['resumes']['0_resume']['description'] or
        data1['result']['resumes']['1_resume']['description']

        -- VIGILANCES
        local out2 = curl('http://vigilance2019.meteofrance.com/data/NXFR33_LFPW_.xml')
        local data2 = fromData(out2)
        for k, v in pairs(data2['CV']['DV']) do
            if v['_attr']['dep'] == dept then
                r['vigicouleur'] = coul[tonumber(v['_attr']['coul'])]
                r['vigilance'] = ''
                if v['risque'] then
                    if #v['risque'] == 1 then
                        r['vigilance'] = vigi[tonumber(v['risque']['_attr']['val'])]
                    else
                        for x, y in pairs(v['risque']) do
                            r['vigilance'] = r['vigilance']..vigi[tonumber(y['_attr']['val'])]..', '
                        end
                    end
                end
                break
            end
        end

        dzBasicCall_return('meteofrance', r, TIMEOUT)

    end
}
