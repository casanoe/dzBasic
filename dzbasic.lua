--[[
name : dzBasic.lua
version: 1.0 beta 5

author : casanoe
creation : 16/04/2021
update : 05/05/2021

CHANGELOG (dzBasic + global_data):
* 1.0 beta 1: first version
* 1.0 beta 2: add support of uservariable 'dzBasic' (content interpreted by dzBasic)
* 1.0 beta 3: event system improvement and corrections, add geoloc function
* 1.0 beta 4: performance improvement (only devices with code in their description are scanned)
* 1.0 beta 5: performance improvement (execute function is executed only for updated devices with dzbasic code)

--]]

-- Script description
local scriptName = 'dzbasic'
local scriptVersion = '1.0 beta'

-- Load data
local ok, f = pcall(loadfile, _G.dataFolderPath..'/__data_'..scriptName..'.lua')
local DZBASIC_DATA = ok and f and f() or { managedDevices = {} }

-- Dzvents
return {
    active = true,
    on = {
        timer = { 'every minute' },
        scenes = DZBASIC_DATA['managedDevices']['scenes'],
        groups = DZBASIC_DATA['managedDevices']['groups'],
        devices = DZBASIC_DATA['managedDevices']['devices'],
        variables = { 'dzBasic' },
        httpResponses = { 'dzBasic*' },
        customEvents = { 'dzBasic*' },
        shellCommandResponses = { 'dzBasic*' },
        system = { 'start', 'stop', 'resetAllDeviceStatus' } -- 'resetAllEvents',
    },
    logging = {
        -- level    =   domoticz.LOG_DEBUG,
        -- level    =   domoticz.LOG_INFO,
        -- level    =   domoticz.LOG_ERROR,
        -- level    =   domoticz.LOG_MODULE_EXEC_INFO,
        marker = scriptName..' v'..scriptVersion
    },
    data = {
        managedDevices = { initial = { devices = {}, scenes = {}, groups = {} } }
    },

    execute = function(dz, triggeredItem, info)

        --------------------
        --   VARS & LIBS  --
        --------------------

        local dzu = dz.utils
        local lodash = dzu._

        dz.helpers.load_dzBasicLibs(dz)

        local TRACKTIME = false -- Performance tracking
        local DZB_TIMEOUT = 2 -- Timeout for dzbasic script

        -----------------
        -- Interpreter --
        -----------------

        local microbasic = {}

        function init()
            raz()
            microbasic.startclock = os.clock()
            microbasic.marker = 'dzBasic'
            microbasic.starter = 'dzbasic'
            microbasic.logdevice = 'dzBasic'
            microbasic.TOKENS = {
                {'"([^"]*)"', 'STRING'},
                {"'([^']*)'", 'STRING'},
                {'(%.%.)', 'ARITH'},
                {'(%-?%d+%.%d)', 'NUMBER'},
                {'(%-?%d+)', 'NUMBER'},
                {'%$([%a%$_][%w_]*)', 'IDENT'},
                {'@(%a[%w_]*)', 'FUNC'},
                {'(%a[%w_]*)', 'ALPHA'},
                {'([ \t]+)', 'SPACE'},
                {'([\n\r][ \t\n\r]*)', 'NEWLINE'},
                {'([:;])', 'COLON'},
                {'%-%-%[%[.*', 'DESC'},
                {'%-%-[^\n\r]*', 'REM'},
                {'([~=<>]=?)', 'COMP'},
                {'([/%*%+%-%%])', 'ARITH'},
                {'([%(%)])', 'PARENTHESE'},
                {'([%[%]])', 'BRACKET'},
                {'#(%a%w*)', 'LABEL'},
                {'(%p)', 'PONC'},
                {'(.)', 'OTHER'}
            }
            microbasic.hide = 'NEWLINE|REM|SPACE|LABEL|COLON'
            microbasic.expr = 'IDENT|FUNC|BOOLOP|UNIOP|CONST|PARENTHESE|BRACKET|ARITH|COMP|NUMBER|STRING'
        end

        function raz()
            microbasic.stop = false
            microbasic.vars = {}
            microbasic.label = {}
            microbasic.loop = {}
            microbasic.expects = {}
            microbasic.lex = {}
            microbasic.curtok = 2
            microbasic.events = {}
        end

        function warning(s)
            print(string.format('<DZB-WARNING> Device "%s" (Token %d) - %s', microbasic.curdev.name, microbasic.curtok, s))
        end

        function info(s)
            print(string.format('<DZB-INFO> %s', s))
        end

        function err(s)
            print(string.format('<DZB-ERROR> Device "%s" (Token %d) - %s', microbasic.curdev.name, microbasic.curtok, s))
            stop()
        end

        function printif(i, ...) if i == microbasic.curdev.idx then aprint(...) end end

        function finish()
            for x, y in pairs(microbasic.expects) do
                if y then err("Syntax error, '"..x.."' expected") end
            end
        end

        function stop() microbasic.stop = true end

        function event(e, b)
            if b ~= nil then microbasic.events[e] = b end
            return microbasic.events[e]
        end

        function mevent(e, b)
            if is_managedEvent(e) then
                managedEvent(e, b)
                return state_managedEvent(e)
            else
                return event(e, b)
            end
        end

        function get_var(k)
            return get_globalvars(k) or microbasic.vars[k]
        end

        function set_var(k, v)
            if is_globalvars(k) then
                set_globalvars(k, v)
            else
                microbasic.vars[k] = v
            end
        end

        function current(i) return microbasic.lex[i or microbasic.curtok] end

        function nexttok(i)
            microbasic.curtok = microbasic.curtok + (i or 1)
            return microbasic.curtok and microbasic.lex[microbasic.curtok]
        end

        function _goto(x, i, b)
            repeat
            until (not current() or strFind(x, current()[i]) == b or not nexttok())
        end

        function gotop(p) microbasic.curtok = p end

        function gotow(w) _goto(w, 2, true) end

        function gotot(t) _goto(t, 1, true) end

        function hide(t) _goto(t or microbasic.hide, 1, false) end

        function expect(s, b)
            microbasic.expects[s] = (b == nil and not microbasic.expects[s]) or b
        end

        function tokenize(code)
            local f, s, x
            local toks = {}
            while #code > 0 do
                for i, v in ipairs(microbasic.TOKENS) do
                    f = table.pack(string.find(code, '^'..v[1]))
                    if f[2] then
                        s = f[3]
                        --x = lodash.slice(f, 4)
                        t = v[2]
                        if _G['t_'..t] then s, t = _G['t_'..t](s, #toks) end
                        if s and t ~= 'SPACE' then table.insert(toks, {t, s}) end
                        code = code:sub(f[2] + 1)
                        break
                    end
                end
            end
            return toks
        end

        function expr()
            local c = 'return '
            local n, t = need_list(false, microbasic.expr)
            if t[1] then
                for k, v in pairs(t) do
                    if v == 'FUNC' then c = c..'f_'..n[k]:lower()
                    elseif v == 'IDENT' then c = c..'get_var("'..n[k]..'")'
                    elseif v == 'STRING' then c = c..'"'..n[k]..'"'
                    else c = c..n[k] end
                end
                local f = load(c)
                local ok, r = pcall(f)
                if not ok then
                    err('Expression parse error :'..r)
                else
                    return ok, r
                end
            end
        end

        function need_list(sep, ...)
            local r1 = {}
            local r2 = {}
            local n, t = need(...)
            local z = #{...}
            local args = sep and {sep, ...} or {...}
            args[1] = '?'..args[1]
            while t[1] do
                table.insert(r1, z == 1 and n[1] or n)
                table.insert(r2, z == 1 and t[1] or t)
                n, t = need(table.unpack(args))
                if sep then
                    table.remove(n, 1)
                    table.remove(t, 1)
                end
            end
            return r1, r2
        end

        function need_list_args(sep)
            local settings = {}
            local n = need_list(sep or ',', 'ALPHA', '?=', 'EXPR')
            for _, v in pairs(n) do settings[v[1]] = v[3] or true end
            return settings
        end

        function need_tok(t)
            local c = current()
            for x in t:gmatch('([^|]+)|?') do
                if tostring(c[2]):lower() == x:lower() or c[1] == x then
                    nexttok()
                    return true, c[2], c[1]
                end
                if x == 'EXPR' and strFind(microbasic.expr, c[1]) then
                    local ok, v = expr()
                    if ok then return ok, v, 'EXPR' end
                end
            end
        end

        function need(...)
            local b, n, t
            local r1 = {}
            local r2 = {}
            for i, v in ipairs({...}) do
                b, n, t = need_tok(v:gsub('%?', ''))
                if not b and v:sub(1, 1) == '?' then break end
                if not b and not v:find('%?') then
                    err('parse error, '..v..' expected (rank '..i..'), '..(t or 'nil')..' found')
                    break
                end
                r1[i] = n
                r2[i] = t
            end
            return r1, r2
        end

        function statement()
            local c = current()
            nexttok()
            if c[1] == 'ALPHA' and _G['w_'..c[2]:lower()] then _G['w_'..c[2]:lower()](c)
            elseif c[1] and _G['wt_'..c[1]] then _G['wt_'..c[1]](c)
            else err('parse error, unknown word: '..c[2]) end
        end

        function survey()
            return (os.clock() - microbasic.startclock) <= DZB_TIMEOUT
        end

        function interpret(code, context)
            raz()
            for k, v in pairs(context) do microbasic[k] = v end
            microbasic.lex = tokenize(code..'\n')
            hide()
            while (microbasic.stop == false and microbasic.curtok <= #microbasic.lex and survey()) do
                statement()
                hide()
            end
            if not survey() then warning('dzbasic take more than '..DZB_TIMEOUT..' s. STOP it.') end
            if not microbasic.stop then finish() end
        end

        -----------------
        --   DZBASIC   --
        --    TOKEN    --
        -----------------

        function t_LABEL(s, p)
            microbasic.label[s] = p + 1
            return s, 'LABEL'
        end

        function t_NUMBER(s, p) return tonumber(s), 'NUMBER' end

        function t_ALPHA(s, p)
            --if _G['w_'..s:lower()] then return s, 'WORD'
            if strFind('or|and', s:lower()) then return ' '..s..' ', 'BOOLOP'
            elseif s:lower() == 'not' then return ' '..s..' ', 'UNIOP'
            elseif strFind('false|true|nil', s:lower()) then return ' '..s..' ', 'CONST'
            else return s, 'ALPHA' end
        end

        -----------------
        --   DZBASIC   --
        --    FUNC     --
        -----------------

        function f_event(s) return mevent(s) end
        function f_string(s) return tostring(s) end
        function f_ucase(s) return s:upper() end
        function f_lcase(s) return s:lower() end
        function f_date(s) return s and os.date(s) or os.time() end
        function f_rnd(s) return math.random(tonumber(s or 1)) end
        function f_cleanstr(s) return s:lower():gsub("^%s*(.-)%s*$", "%1"):gsub('%s+', ' ') end
        function f_int(s) return tonumber(s) end
        function f_script(s) return fromData(executeScript(s)) end
        function f_url(s) return fromData(simpleCurl(s)) end
        function f_curl(s) return f_url(s) end

        -----------------
        --   DZBASIC   --
        --    WORD     --
        -----------------

        -- from token --

        function wt_IDENT() nexttok(-1) w_let() end
        function wt_REM() gotot('NEWLINE') end
        function wt_DESC() stop() end

        -- from word --
        -- standard --

        function w_rem() gotot('NEWLINE') end

        function w_goto()
            local n = need('ALPHA')
            if microbasic.label[n[1]] then gotop(microbasic.label[n[1]])
            else err('unknown label '..n[1]) end
        end

        function w_for()
            local n = need('IDENT', '=', 'EXPR', 'to', 'EXPR', '?step', 'EXPR')
            set_var(n[1], n[3])
            expect('for/next $'..n[1], true)
            microbasic.loop[n[1]] = {microbasic.curtok, n[5], n[7] or 1}
        end

        function w_next()
            local n = need('IDENT')
            if microbasic.loop[n[1]] then
                set_var(n[1], get_var(n[1]) + microbasic.loop[n[1]][3])
                if get_var(n[1]) <= microbasic.loop[n[1]][2] then
                    gotop(microbasic.loop[n[1]][1])
                else
                    expect('for/next $'..n[1])
                    microbasic.loop[n[1]] = nil
                end
            else err('for/next $'..n[1]..' expected') end
        end

        function w_clear()
            local n = need_list(',', 'IDENT')
            for _, v in ipairs(n) do set_var(v, nil) end
        end

        function w_exit() stop() end

        function w_print()
            local n = need_list(',', 'EXPR')
            for _, v in pairs(n) do aprint(v) end
        end

        function w_let()
            local n1 = need('IDENT', '=')
            local n2 = need_list(',', 'EXPR')
            set_var(n1[1], #n2 == 1 and n2[1] or n2)
        end

        function w_else() gotow('endif') end

        function w_endif() expect('if/endif') end

        function w_endon() expect('on/endon') end

        function w_if()
            local n = need('EXPR', ':|then')
            if not n[1] and n[2] == ':' then gotot('NEWLINE')
            elseif not n[1] then gotow('else|endif') end
            if n[2] == 'then' then expect('if/endif') end
        end

        function w_global()
            local n = need('IDENT', '?=', 'EXPR')
            set_globalvars(n[1], n[3] or microbasic.vars[n[1]] or '')
            microbasic.vars[n[1]] = nil
        end

        -- from word --
        --  dzbasic  --

        function w_at()
            local n = need('STRING', ':')
            if not event('dz_timer') or not timeRule(n[1]) then gotot('NEWLINE') end
        end

        function w_after()
            local n = need('NUMBER', ':')
            if not event('dz_timer') or microbasic.curdev.lastUpdate.minutesAgo < n[1] then gotot('NEWLINE') end
        end

        function w_auto()
            local n1 = need('onoff|on|off|toggle|dim|level|update')
            local n2 = {}
            if n1[1] == 'dim' then n2 = need('NUMBER', '?,', 'NUMBER')
            elseif n1[1] == 'level' then n2 = need('ALPHA|NUMBER|STRING')
            elseif n1[1] == 'update' then n2 = need('EXPR')
            end
            local n3 = need('STRING?', 'at|after|when?')
            local n4
            if n3[2] == 'at' then n4 = need('STRING')
            elseif n3[2] == 'when' then n4 = won()
            else n4 = need('NUMBER?')
            end

            local b = false
            if event('dz_timer') and n3[2] == 'at' then
                b = timeRule(n4[1])
            elseif n3[2] == 'when' then
                b = n4
            elseif event('dz_timer') then
                b = microbasic.curdev.lastUpdate.minutesAgo >= (n4[1] or 1)
            end

            if n1[1] == 'onoff' then
                dzbswitch(microbasic.curdev.idx, b and 'on' or 'off', {checkfirst = true, silent = true})
            elseif b then
                if n1[1] == 'dim' and microbasic.curdev.switchType == "Dimmer" and microbasic.curdev.active then
                    local l = constrain(microbasic.curdev.level + (tonumber(n2[1]) or 10), 0, n2[3] or 100)
                    if l ~= microbasic.curdev.level then microbasic.curdev.dimTo(l).silent() end
                elseif n1[1] == 'level' then
                    if microbasic.curdev.levelName ~= n2[1] and microbasic.curdev.level ~= n2[1] then
                        microbasic.curdev.switchSelector(n2[1]).silent()
                    end
                elseif n1[1] == 'update' then
                    dzbupdate(microbasic.curdev.idx, n2[1], nil, {silent = true})
                else
                    dzbswitch(microbasic.curdev.idx, n1[1], {checkfirst = true, silent = true})
                end
            end
        end

        function won(ev)
            local n1, t1, n2, t2, n3
            local x, d
            local op = ''
            local b = true
            repeat
                x = nil
                n1, t1 = need('ALPHA|EXPR')

                if t1[1] == 'EXPR' then
                    x = n1[1] ~= nil and n1[1] ~= false
                elseif n1[1] == 'time' then
                    n2, t2 = need('=', 'STRING')
                    x = timeRule(n2[2])
                elseif n1[1] == 'secondsago' or n1[1] == 'minutesago' then
                    n2, t2 = need('STRING?', 'COMP', 'EXPR')
                    d = n2[1] or microbasic.curdev.idx
                    z = n1[1] == 'secondsago' and 'secondsAgo' or 'minutesAgo'
                    x = group_cmp(d, {'lastUpdate', z}, n2[3], n2[2])
                elseif n1[1] == 'state' then
                    n2, t2 = need('STRING?', '=', 'on|off|allon|alloff')
                    d = n2[1] or microbasic.curdev.idx
                    if n2[3] == 'allon' then x = group_cmp(d, 'active', true)
                    elseif n2[3] == 'alloff' then x = group_cmp(d, 'active', false)
                    elseif n2[3] == 'off' then x = not group_cmp(d, 'active', true)
                    elseif n2[3] == 'on' then x = not group_cmp(d, 'active', false)
                    end
                elseif n1[1] == 'repeat' and ev then
                    n2, t2 = need('COMP', 'EXPR')
                    e = managedEvent(ev)
                    x = _cmp(e.nb, n2[2], n2[1])
                else
                    n3 = need('ALPHA?')
                    if n3[1] == 'repeat' or n3[1] == 'duration' then
                        n2, t2 = need('COMP', 'EXPR')
                        e = managedEvent(n1[1])
                        z = n3[1] == 'duration' and e.last - e.first or n3[1] == 'repeat' and e.nb
                        x = _cmp(z, n2[2], n2[1])
                    elseif not n3[1] then
                        x = (mevent(n1[1]) == true)
                    end
                end

                if x == nil then return err("wrong 'event' syntax") end
                --if op == 'or' then b = b or x else b = b and x end
                b = b and x
                op = need(',?')[1]
            until op == nil
            return b
        end

        function w_event()
            local n = need('ALPHA', '?when|on|off')
            if n[2] == 'when' then
                managedEvent(n[1], won(n[1]))
            else
                mevent(n[1], n[2] ~= 'off')
            end
        end

        function w_on()
            local b = won()
            local n = need('?:')
            if not b and n[1] == ':' then gotot('NEWLINE')
            elseif not b then gotow('endon') end
            if n[1] == nil then expect('on/endon') end
        end

        function w_update()
            local n = need('EXPR', '?,', 'STRING|NUMBER')
            local h = dzbupdate(n[3] or microbasic.curdev.idx, n[1], nil, {silent = n[3] == nil})
            if not n[3] then event('dz_selfchange', h) end
        end

        function w_switch()
            local n1 = need('on|off|toggle|flash', ',?', 'STRING|NUMBER?', ',?')
            local c = n1[1]:sub(1, 1):upper()..n1[1]:sub(2)
            local n2 = ((n1[2] and not n1[3]) or n1[4]) and need_list_args()
            local h = dzbswitch(n1[3] or microbasic.curdev.idx, c, n2, {silent = n1[3] == nil})
            if not n1[3] then event('dz_selfchange', h) end
        end

        function w_notification()
            local n = need('EXPR', '?,')
            local settings = {
                QUIET = get_var('QUIET'),
                SUBSYSTEMS = get_var('SUBSYSTEMS'),
                SUBJECT = get_var('SUBJECT'),
                FREQUENCY = get_var('FREQUENCY'),
                PRIORITY = get_var('PRIORITY')
            }
            if n[2] then settings = table.merge(settings, need_list_args()) end
            if sendNotification(n[1], settings) and get_var('NLOG') then log(n[1]) end
        end

        function w_curl()
            local n = need('EXPR', '?,', 'fg|cb|bg', '?,', 'NUMBER')
            local cb = 
            (n[3] == 'cb') and 'dzBasic_url_'..microbasic.curdev.idx or
            (n[3] == 'bg') and '_dzBasic_nope' or
            nil
            set_var('$', fromData(simpleCurl(n[1], cb, n[5])) )
        end

        function w_log()
            log(need('EXPR')[1])
        end

        function w_url()
            w_curl()
        end

        function w_script()
            local n = need('EXPR', '?,', 'fg|cb|bg', '?,', 'NUMBER')
            local cb = 
            (n[3] == 'cb') and 'dzBasic_script_'..microbasic.curdev.idx or
            (n[3] == 'bg') and '_dzBasic_nope' or
            nil
            set_var('$', fromData(executeScript(n[1], cb, n[5])))
        end

        function w_run()
            local n = need('STRING', 'ALPHA?', ',?')
            local args = n[3] and need_list_args() or {}
            sendCustomEvent('dzBasic_customevent', {
                event = n[2],
                device = n[1],
                microbasic = { vars = args }
            })
        end

        function w_icon()
            local n = need('EXPR', '?,', 'STRING|NUMBER')
            group(n[3] or microbasic.curdev.idx,
                function(dev)
                    dev.setIcon(n[1])
                end
            )
        end

        function w_dzb()
            local d
            local n = need('ALPHA', '?EXPR')
            if n[1] == 'initiglobaldata' then
                info("Initialize global datas")
                init_globalData()
            elseif n[1] == 'printglobaldata' then
                info("Global datas:")
                tprint(dz.globalData.globalvars)
            elseif n[1] == 'printeventdump' then
                info("DUMP event "..n[2])
                info("STATE= "..tostring(mevent(n[2]) or false), managedEvent(n[2]))
            elseif n[1] == 'printallevents' then
                info("DUMP events ")
                aprint(dz.globalData.managedEvent)
            elseif n[1] == 'clearallevents' then
                microbasic.events = {}
                dz.globalData.initialize('managedEvent')
                info("Clear all events")
            elseif n[1] == 'clearallvars' then
                microbasic.vars = {}
                dz.globalData.initialize('globalvars')
                info("Clear local vars and initialize global datas")
            elseif n[1] == 'printdevicedump' then
                d = n[2] and getItem(n[2]) or microbasic.curdev
                info("DUMP device "..d.name)
                d.dump()
            elseif n[1] == 'moveback' then
                microbasic.curtok = microbasic.curtok - (tonumber(n[2]) or 1)
            elseif n[1] == 'moveforward' then
                microbasic.curtok = microbasic.curtok + (tonumber(n[2]) or 1)
            elseif n[1] == 'printlextable' then
                info("Lex table of "..microbasic.curdev.name)
                for i, v in ipairs(microbasic.lex) do print('('..i..') '..v[1]..'\t'..v[2]) end
            end
        end

        function w_call()
            local n1 = need('ALPHA', 'forceupdate?', 'nocallback?', '?,')
            local n2 = n1[4] and need_list_args() or {}
            set_var('$', nil)
            if n1[2] or not dzBasicCall_isvalidData(n1[1]) then
                local context = {
                    device = microbasic.curdev.idx,
                    event = n1[1],
                    args = n2
                }
                if not n1[3] then
                    stop()
                    context['microbasic'] = {
                        curtok = microbasic.curtok,
                        vars = microbasic.vars,
                        events = microbasic.events,
                        expects = microbasic.expects
                    }
                end
                managedContext(n1[1], context)
                sendCustomEvent(n1[1])
            else
                set_var('$', dzBasicCall_getData(n1[1])['returnval'])
            end
        end

        -----------------------
        --     dzBASIC       --
        -----------------------

        function start(device, context)
            microbasic.curdev = device
            microbasic.marker = 'dzBasic - '..microbasic.curdev.name
            dzu.setLogMarker(microbasic.marker)
            context['events']['dz_batterylow'] = device.batteryLevel and (device.batteryLevel <= DZ_BATTERY_THRESHOLD)
            context['events']['dz_timedout'] = device.timedOut
            context['events']['dz_signallow'] = device.signalLevel and (device.signalLevel <= DZ_SIGNAL_THRESHOLD)
            local code = device.description
            interpret(dzbformat(code, microbasic.curdev.idx), context)
        end

        function checkdevices(d, t)
            if string.find(d.description, '^'..microbasic.starter..'%s*\n') then
                table.insert(dz.data.managedDevices[t], d.idx)
            end
        end

        function log(s)
            local d = getItem(microbasic.logdevice)
            if d then d.updateText(s) else err('log cmd: dzBasic (text) device does not exist.') end
        end

        ---------------
        --   Main    --
        ---------------

        context = { events = {}, vars = {} }

        context['vars']['DZ_STARTTIME_SEC'] = dz.startTime.secondsAgo
        context['vars']['DZ_SECURITY'] = dz.security

        init()

        local dzbtype
        local dzbscan = 0

        if triggeredItem.isDevice or triggeredItem.isScene or triggeredItem.isGroup then
            dzbscan = 1
            dzbtype = 'Trigger Device '..triggeredItem.name
            context['events']['dz_update'] = true
            context['events']['dz_switchon'] = triggeredItem.active
            context['events']['dz_switchoff'] = not triggeredItem.active
            if triggeredItem.levelName then
                context['events']['dz_level_'..triggeredItem.levelName] = true
                context['events']['dz_switchlevel'] = true
            end
            start(triggeredItem, context)
        elseif triggeredItem.isHTTPResponse or triggeredItem.isShellCommandResponse then
            dzbtype = 'Trigger Http/Shell '..triggeredItem.trigger
            context['events']['dz_url'] = triggeredItem.isHTTPResponse
            context['events']['dz_script'] = triggeredItem.isShellCommandResponse
            context['vars']['$'] = fromData(string.trim(triggeredItem.data)) or ''
            start(getItem(tonumber(string.match(triggeredItem.trigger, "%d+$"))), context)
            dzbscan = 1
        elseif triggeredItem.isCustomEvent then
            dzbtype = 'Trigger CustomEvent '..triggeredItem.json['event']
            context = triggeredItem.json['microbasic'] or context
            context['events']['dz_user'] = true
            context['events'][triggeredItem.json['event']] = true
            context['vars']['$'] = triggeredItem.json['returnval']
            dzbscan = #group(triggeredItem.json['device'], function(d) start(d, context) end)
        elseif triggeredItem.isSystemEvent and (triggeredItem.type == 'resetAllEvents' or triggeredItem.type == 'resetAllDeviceStatus') then
            info('System event '..triggeredItem.type..', check devices:')
            init_globalData()
            set_globalvars('DZ_URL', dz.settings.url)
            sendCustomEvent('onstart_dzBasic')
            dzbtype = 'Trigger SystemEvent '..triggeredItem.type
            dz.data.initialize('managedDevices')
            dz.devices().forEach(function(d) checkdevices(d, 'devices') end)
            dz.groups().forEach(function(d) checkdevices(d, 'groups') end)
            dz.scenes().forEach(function(d) checkdevices(d, 'scenes') end)
            info(string.format('Managed devices updated: %s', table.concat(dz.data.managedDevices['devices'], ',')))
            info(string.format('Managed scenes updated: %s', table.concat(dz.data.managedDevices['scenes'], ',')))
            info(string.format('Managed groups updated: %s', table.concat(dz.data.managedDevices['groups'], ',')))
        elseif triggeredItem.isVariable then
            dzbtype = 'Variable dzbasic'
            start(triggeredItem, context)
            triggeredItem.set('').silent()
            dzbscan = 1
        else
            dzbtype = 'Trigger System Timer'
            if triggeredItem.isSystemEvent then
                dzbtype = 'Trigger SystemEvent '..triggeredItem.type
                context['events']['dz_sys'] = true
                context['events']['dz_sys_'..triggeredItem.type] = true
                context['vars']['DZ_SYSEVENT'] = triggeredItem.type
                sendCustomEvent('onstart_dzBasic')
            end
            context['events']['dz_timer'] = true
            for x, t in pairs(dz.data.managedDevices) do
                for y, i in pairs(t) do
                    start(dz[x](i), context)
                    dzbscan = dzbscan + 1
                end
            end
        end

        ----- Performance tracking

        if TRACKTIME then
            local timeclock = (os.clock() - microbasic.startclock) * 1000
            dzbtype = dzbtype..' - Scan '..dzbscan..' devices'
            print('----------------')
            print('<DZB-TIMETRACK> TIME '..dzbtype..' = '..timeclock..' ms')
            dz.globalData.dzbench.add(timeclock)
            print('<DZB-TIMETRACK> AVGTIME 10min = '..dz.globalData.dzbench.avgSince('00:10:00')..' ms')
            print('<DZB-TIMETRACK> SUMTIME 1min = '..dz.globalData.dzbench.sumSince('00:01:00')..' ms')
            local item, index = dz.globalData.dzbench.getAtTime('00:01:00')
            print('<DZB-TIMETRACK> NBRECORDS 1min = '..(index or 0))
            print('----------------')
            --dzbupdate('dzBasictime', timeclock)
        end

    end
}
