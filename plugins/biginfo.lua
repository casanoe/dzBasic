--[[
name : biginfo.lua
version: 1.0

description: useful information updated every day.

Return: create global variables (variables named BI_*)

Based on today's date and longitude/latitude recorded in Domoticz

$BI_ISHOLIDAYS ==> true/false
$BI_GEOLATITUDE ==> number
$BI_HOLIDAYS ==> text (for country code = fr)
$BI_SCHOOLZONE ==> text (for country code = fr)
$BI_ISWE ==> true/false
$BI_ISLEAPYEAR ==> true/false
$BI_GEOLONGITUDE ==> number
$BI_GEOMUNICIPALITY ==> text
$BI_GEOCOUNTRY ==> text
$BI_GEONAME ==> text
$BI_ISPUBHOLIDAYS ==> true/false (for country code = fr)
$BI_GEONUMDEPT ==> number
$BI_JULIANDATE ==> number
$BI_MOONAGE ==> number
$BI_GEOCOUNTRYCODE ==> text
$BI_MOON ==> text
$BI_GEOPOSTCODE ==> number
$BI_GEOSTATE ==> text
$BI_SEASON ==> text
$BI_PUBHOLIDAYS ==> text (for country code = fr)
$BI_GEOCOUNTY ==> text
$BI_SCHOOLYEAR ==> text (for country code = fr)

author : casanoe
creation : 16/04/2021
update : 05/05/2021

--]]

-- Script description
local scriptName = 'biginfo'
local scriptVersion = '1.0'

-- Dzvents
return {
    on = {
        customEvents = { 'onstart_dzBasic', 'biginfo' },
        timer = { '00:01' },
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

        local dayOfYear, year, month, day, geo, TIMEOUT, context
        local args = {}

        if triggeredItem.trigger == 'biginfo' then
            context = dzBasicCall_getData('biginfo')
            args = context['args']
            TIMEOUT = 60 * 60
            geo = geoLoc(args['addr'], args['lat'], args['lon'])
        else
            geo = geoLoc()
        end

        year = args['year'] or tonumber(os.date("%Y"))
        month = args['month'] or tonumber(os.date("%m"))
        day = args['day'] or tonumber(os.date("%d"))
        dayOfYear = tonumber(os.date("%j", os.time{year = year, month = month, day = day}))

        ----------------------

        DZ_LANG = DZ_LANG or geo['address']['country_code'] or 'fr'

        local lang = DZ_LANG
        local countrycode = geo['address']['country_code']

        local isLeapYear = function(y)
            if ( y % 4 == 0) then
                if (y % 100 == 0)then
                    if ( y % 400 == 0) then
                        return true
                    end
                else
                    return true
                end
            end
            return false
        end

        local season = function(d, m, y)
            local s = {
                fr = { 'Eté', 'Printemps', 'Automne', 'Hiver' },
                en = {'Summer', 'Spring', 'Autumn', 'Winter'}
            }
            local dy = tonumber(os.date("%j", os.time{year = y, month = m, day = d}))
            local ly = isLeapYear(y) and 1 or 0
            return
            (dy > 354 + ly or dy < 80 + ly) and s[lang][4] or
            (dy >= 80 + ly and dy <= 171 + ly) and s[lang][2] or
            (dy >= 172 + ly and dy <= 263 + ly) and s[lang][1] or
            (dy >= 264 + ly and dy <= 354 + ly) and s[lang][3]
        end

        local julianDate = function(d, m, y)
            local mm, yy, k1, k2, k3, j
            yy = y - math.floor((12 - m) / 10)
            mm = m + 9
            if (mm >= 12) then
                mm = mm - 12
            end
            k1 = math.floor(365.25 * (yy + 4712))
            k2 = math.floor(30.6001 * mm + 0.5)
            k3 = math.floor(math.floor((yy / 100) + 49) * 0.75) - 38
            j = k1 + k2 + d + 59
            if (j > 2299160) then
                j = j - k3
            end
            return j
        end

        local moonAge = function(d, m, y)
            local j, ip, ag
            j = julianDate(d, m, y)
            ip = (j + 4.867) / 29.53059
            ip = ip - math.floor(ip)
            if (ip < 0.5) then
                ag = ip * 29.53059 + 29.53059 / 2
            else
                ag = ip * 29.53059 - 29.53059 / 2
            end
            return ag
        end

        local theMoon = function(d, m, y)
            local mo = {
                fr = { 'Dernier croissant', 'Dernier quartier', 'Gibbeuse décroisssante', 'Pleine lune', 'Gibbeuse croissante', 'Premier quartier', 'Premier croissant'},
                en = {'Waning crescent', 'Third quarter', 'Waning gibbous', 'Full moon', 'Waxing gibbous', 'First quarter', 'Waxing crescent'}
            }
            local a = moonAge(d, m, y)
            return
            a > 23 and mo[lang][1] or
            a > 22 and mo[lang][2] or
            a > 15 and mo[lang][3] or
            a > 13 and mo[lang][4] or
            a > 8 and mo[lang][5] or
            a > 6 and mo[lang][6] or
            a > 1 and mo[lang][7]
        end

        local easterDate = function(y)
            local a = math.floor(y / 100)
            local b = math.fmod(y, 100)
            local c = math.floor((3 * (a + 25)) / 4)
            local d = math.fmod((3 * (a + 25)), 4)
            local e = math.floor((8 * (a + 11)) / 25)
            local f = math.fmod((5 * a + b), 19)
            local g = math.fmod((19 * f + c - e), 30)
            local h = math.floor((f + 11 * g) / 319)
            local j = math.floor((60 * (5 - d) + b) / 4)
            local k = math.fmod((60 * (5 - d) + b), 4)
            local m = math.fmod((2 * j - k-g + h), 7)
            local n = math.floor((g - h + m + 114) / 31)
            local p = math.fmod((g - h + m + 114), 31)
            local day = p + 1
            local month = n
            return os.time{year = year, month = month, day = day, hour = 12, min = 0}
        end

        local globals = {
            BI_ISWE = os.date('%w') == '6' or os.date('%w') == '0',
            BI_ISLEAPYEAR = isLeapYear(year),
            BI_JULIANDATE = julianDate(day, month, year),
            BI_SEASON = season(day, month, year),
            BI_MOON = theMoon(day, month, year),
            BI_MOONAGE = moonAge(day, month, year),
            BI_GEOLATITUDE = geo['lat'],
            BI_GEOLONGITUDE = geo['lon'],
            BI_GEOCOUNTRY = geo['address']['country'],
            BI_GEOCOUNTY = geo['address']['county'], -- fr: departement
            BI_GEONAME = geo['name'],
            BI_GEOSTATE = geo['address']['state'], -- fr: region
            BI_GEOPOSTCODE = geo['address']['postcode'],
            BI_GEOCOUNTRYCODE = geo['address']['country_code'],
            BI_GEOMUNICIPALITY = geo['address']['municipality']
        }

        ---- FRANCE
        if countrycode == 'fr' then

            local pubHolidays = function(d, m, y)
                local today = tostring(d)..'-'..tostring(m)
                local epochPaques = easterDate(y)
                local ph = {
                    ['Vendredi Saint'] = os.date("%d-%m", epochPaques - 172800),
                    ['Pâques'] = os.date("%d-%m", epochPaques + 86400),
                    ['Ascension'] = os.date("%d-%m", epochPaques + 3369600),
                    ['Pentecôte'] = os.date("%d-%m", epochPaques + 4233600),
                    ['Nouvel an'] = '1-1',
                    ['Fête du travail'] = '1-5',
                    ['Fin de la 2nde Guerre'] = '8-5',
                    ['Fête nationale'] = '14-7',
                    ['Assomption'] = '15-8',
                    ['Toussaint'] = '1-11',
                    ['Armistice 1918'] = '11-11',
                    ['Noël'] = '25-12'
                }
                for k, v in pairs(ph) do
                    if today == v then return true, k end
                end
                return false, ''
            end

            local getSchoolZone = function(dc)
                local schoolZone = {
                    A = {"1", "3", "7", "15", "16", "17", "19", "21", "23", "24", "25", "26", "33", "38", "39", "40", "42", "43", "47", "58", "63", "64", "69D", "69M", "70", "71", "73", "74", "79", "86", "87", "89", "90"},
                    B = {"2", "4", "5", "6", "8", "10", "13", "14", "18", "22", "27", "28", "29", "35", "36", "37", "41", "44", "45", "49", "50", "51", "52", "53", "54", "55", "56", "57", "59", "60", "61", "62", "67", "68", "72", "76", "80", "83", "84", "85", "88"},
                    C = {"11", "12", "30", "31", "32", "34", "46", "48", "65", "66", "75", "77", "78", "81", "82", "91", "92", "93", "94", "95"},
                    Corse = {}, -- TODO
                    Outremer = {} -- TODO
                }
                for k, v in pairs(schoolZone) do
                    for _, x in pairs(v) do
                        if dc == x then return k end
                    end
                end
                return '?'
            end

            local getHolidays = function(d, m, y, z)
                local u = simpleCurl(string.format('"http://domogeek.entropialux.com/schoolholiday/%s/%0.2d-%0.2d-%d"', z, d, m, y))
                return u ~= 'False', u
            end

            globals['BI_GEONUMDEPT'] = string.sub(globals['BI_GEOPOSTCODE'] or '', 1, 2)
            globals['BI_SCHOOLZONE'] = getSchoolZone(globals['BI_GEONUMDEPT'])
            globals['BI_SCHOOLYEAR'] = dayOfYear > 244 and (year..'-'..(year + 1)) or ((year - 1)..'-'..year)
            globals['BI_ISPUBHOLIDAYS'], globals['BI_PUBHOLIDAYS'] = pubHolidays(day, month, year)
            globals['BI_ISHOLIDAYS'], globals['BI_HOLIDAYS'] = getHolidays(day, month, year, globals['BI_SCHOOLZONE'])

        end
        ----

        if triggeredItem.trigger == 'biginfo' then
            dzBasicCall_return('biginfo', globals, TIMEOUT)
        else
            for k, v in pairs(globals) do set_globalvars(k, v) end
        end

    end
}
