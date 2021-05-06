--[[
name : dzBasic.lua
version: 1.0 beta 3

author : casanoe
creation : 16/04/2021
update : 05/05/2021

CHANGELOG (dzBasic + global_data):
* 1.0 beta 1: first version
* 1.0 beta 2: add support of uservariable 'dzBasic' (content interpreted by dzBasic)
* 1.0 beta 3: event system improvement and corrections, add geoloc function

--]]

-- Script description
local scriptName = 'dzBasic'
local scriptVersion = '1.0 beta'

-- Dzvents
return {
    active = true,
    on = {
        timer = { 'every minute' },
        devices = { '*' },
        groups = { '*' },
        scenes = { '*' },
        variables = { 'dzBasic' },
        httpResponses = { 'dzBasic*' },
        customEvents = { 'dzBasic*' },
        shellCommandResponses = { 'dzBasic*' },
        system = { '*' }
    },
    logging = {
        -- level    =   domoticz.LOG_DEBUG,
        -- level    =   domoticz.LOG_INFO,
        -- level    =   domoticz.LOG_ERROR,
        -- level    =   domoticz.LOG_MODULE_EXEC_INFO,
        marker = scriptName..' v'..scriptVersion
    },

    execute = function(dz, triggeredItem, info)

        --------------------
        --   VARS & LIBS  --
        --------------------

        local dzu = dz.utils
        local lodash = dzu._

        dz.helpers.load_dzBasicLibs(dz)

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
            microbasic.logdevicetime = 'dzBasictime'
            microbasic.TOKENS = {
                {'"([^"]*)"', 'STRING'},
                {"'([^']*)'", 'STRING'},
                {'(%.%.)', 'ARITH'},
                {'(%-?%d+%.%d)', 'NUMBER'},
                {'(%-?%d+)', 'NUMBER'},
                {'%$([%a%$_][%w_]*)', 'IDENT'},
                {'@(%a[%w_]*)', 'FUNC'},
                {'(%a[%w_]*#(%w+))', 'ALPHAX'},
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
            dzlog(string.format('[%s](%d) WARNING - %s', microbasic.marker, microbasic.curtok, s), 'info')
        end

        function err(s)
            dzlog(string.format('[%s](%d) ERROR - %s', microbasic.marker, microbasic.curtok, s), 'error')
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
            --local b, e, s, t
            local f, s, x
            local toks = {}
            while #code > 0 do
                for i, v in ipairs(microbasic.TOKENS) do
                    --b, e, s = string.find(code, '^'..v[1])
                    f = table.pack(string.find(code, '^'..v[1]))
                    s = f[3]
                    x = lodash.slice(f, 4)
                    if f[2] then
                        t = v[2]
                        if _G['t_'..t] then s, t = _G['t_'..t](s, #toks) end
                        if s and t ~= 'SPACE' then table.insert(toks, {t, s, x}) end
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
            if not string.find(code, '^'..microbasic.starter..'%s*\n') then return end
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
            elseif strFind('not', s:lower()) then return ' '..s..' ', 'UNIOP'
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
            local n2 = (n1[1] == 'dim' and need('NUMBER', '?,', 'NUMBER')) or
            (n1[1] == 'level' and need('ALPHA|NUMBER|STRING')) or
            (n1[1] == 'update' and need('EXPR')) or {}
            local n3 = need('STRING?', 'at|after|when?')
            local n4 = (n3[2] == 'at' and need('STRING')) or (n3[2] == 'when' and won()) or need('NUMBER?')

            local b = false
            if event('dz_timer') and n3[2] == 'at' then
                b = timeRule(n4[1])
            elseif n3[2] == 'when' then
                b = n4
            elseif event('dz_timer') then
                b = microbasic.curdev.lastUpdate.minutesAgo >= (n4[1] or 1)
            end

            if n1[1] == 'onoff' then
                dzbswitch(microbasic.curdev.idx, b and 'on' or 'off', {checkfirst = true})
            elseif b then
                if n1[1] == 'dim' and microbasic.curdev.switchType == "Dimmer" and microbasic.curdev.active then
                    local l = constrain(microbasic.curdev.level + (tonumber(n2[1]) or 10), 0, n2[3] or 100)
                    if l ~= microbasic.curdev.level then microbasic.curdev.dimTo(l) end
                elseif n1[1] == 'level' then
                    if microbasic.curdev.levelName ~= n2[1] and microbasic.curdev.level ~= n2[1] then
                        microbasic.curdev.switchSelector(n2[1])
                    end
                elseif n1[1] == 'update' then
                    dzbupdate(microbasic.curdev.idx, n2[1])
                else
                    dzbswitch(microbasic.curdev.idx, n1[1], {checkfirst = true})
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
            local h = dzbupdate(n[3] or microbasic.curdev.idx, n[1])
            if not n[3] then event('dz_selfchange', h) end
        end

        function w_switch()
            local n1 = need('on|off|toggle|flash', ',?', 'STRING|NUMBER?', ',?')
            local c = n1[1]:sub(1, 1):upper()..n1[1]:sub(2)
            local n2 = ((n1[2] and not n1[3]) or n1[4]) and need_list_args()
            local h = dzbswitch(n1[3] or microbasic.curdev.idx, c, n2)
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
            if n[2] then settings = table_merge(settings, need_list_args()) end
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
                aprint("<DZB> Initialize global datas")
                init_globalData()
            elseif n[1] == 'printglobaldata' then
                aprint("<DZB> Global datas:")
                tprint(dz.globalData.globalvars)
            elseif n[1] == 'printeventdump' then
                aprint("<DZB> DUMP event "..n[2])
                aprint("STATE= "..tostring(mevent(n[2]) or false), managedEvent(n[2]))
            elseif n[1] == 'printallevents' then
                aprint("<DZB> DUMP events ")
                aprint(dz.globalData.managedEvent)
            elseif n[1] == 'clearallevents' then
                microbasic.events = {}
                dz.globalData.initialize('managedEvent')
                aprint("<DZB> Clear all events")
            elseif n[1] == 'clearallvars' then
                microbasic.vars = {}
                dz.globalData.initialize('globalvars')
                aprint("<DZB> Clear local vars and initialize global datas")
            elseif n[1] == 'printdevicedump' then
                d = n[2] and getItem(n[2]) or microbasic.curdev
                aprint("<DZB> DUMP device "..d.name)
                d.dump()
            elseif n[1] == 'moveback' then
                microbasic.curtok = microbasic.curtok - (tonumber(n[2]) or 1)
            elseif n[1] == 'moveforward' then
                microbasic.curtok = microbasic.curtok + (tonumber(n[2]) or 1)
            elseif n[1] == 'printlextable' then
                aprint("<DZB> Lex table of "..microbasic.curdev.name)
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
            local code = device.description or "dzbasic\n\r"..device.value or ''
            interpret(dzbformat(code, microbasic.curdev.idx), context)
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

        if triggeredItem.isDevice or triggeredItem.isScene or triggeredItem.isGroup then
            context['events']['dz_update'] = true
            context['events']['dz_switchon'] = triggeredItem.active
            context['events']['dz_switchoff'] = not triggeredItem.active
            if triggeredItem.levelName then
                context['events']['dz_level_'..triggeredItem.levelName] = true
                context['events']['dz_switchlevel'] = true
            end
            start(triggeredItem, context)
        elseif triggeredItem.isHTTPResponse or triggeredItem.isShellCommandResponse then
            context['events']['dz_url'] = triggeredItem.isHTTPResponse
            context['events']['dz_script'] = triggeredItem.isShellCommandResponse
            context['vars']['$'] = fromData(trim(triggeredItem.data)) or ''
            start(getItem(tonumber(string.match(triggeredItem.trigger, "%d+$"))), context)
        elseif triggeredItem.isCustomEvent then
            context = triggeredItem.json['microbasic'] or context
            context['events']['dz_user'] = true
            context['events'][triggeredItem.json['event']] = true
            context['vars']['$'] = triggeredItem.json['returnval']
            group(triggeredItem.json['device'], function(d) start(d, context) end)
        elseif triggeredItem.isSystemEvent and triggeredItem.type ~= 'start' and triggeredItem.type ~= 'stop' then
            if triggeredItem.type == 'resetAllEvents' then
                init_globalData()
                set_globalvars('DZ_URL', dz.settings.url)
                sendCustomEvent('onstart_dzBasic')
            end
        elseif triggeredItem.isVariable then
            start(triggeredItem, context)
            triggeredItem.set('').silent()
        else
            if triggeredItem.isSystemEvent then
                context['events']['dz_sys'] = true
                context['events']['dz_sys_'..triggeredItem.type] = true
                context['vars']['DZ_SYSEVENT'] = triggeredItem.type
                sendCustomEvent('onstart_dzBasic')
            end
            context['events']['dz_timer'] = true
            dz.devices().forEach(function(d) start(d, context) end)
            dz.groups().forEach(function(d) start(d, context) end)
            dz.scenes().forEach(function(d) start(d, context) end)
        end

        dzbupdate(microbasic.logdevicetime, (os.clock() - microbasic.startclock) * 1000)

    end
}
