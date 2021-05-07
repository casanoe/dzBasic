--[[
name : global_data.lua
version: 1.0 beta

author : casanoe
creation : 16/04/2021
update : 05/05/2021

TODO : ?

--]]

return {
    data = {
        managedEvent = { initial = {} },
        globalvars = { initial = {} },
        managedContext = { initial = {} },
        managedDevices = { initial = {} }
    },
    helpers = {

        load_dzBasicLibs = function(dz, options)

            --------------------
            --      LIBS      --
            --------------------

            local dzu = dz.utils
            local lodash = dzu._

            --------------------
            --      VARS      --
            --------------------

            C_GARBAGE_EVENT_FREQ = 7 * 24 * 3600 -- every 7 days

            DZB_TIMEOUT = 2
            DZ_BATTERY_THRESHOLD = 10
            DZ_SIGNAL_THRESHOLD = 10
            DZ_LANG = 'fr'

            --------------------
            --      TOOLS     --
            --------------------

            function table_merge(t1, t2)
                local r = {}
                for k, v in pairs(t1) do r[k] = v end
                for k, v in pairs(t2) do r[k] = v end
                return r
            end

            function table_clone(t)
                local r = {}
                for k, v in pairs(t) do r[k] = v end
                return r
            end

            function aprint(...)
                lodash.print(...)
            end

            function tprint(t)
                for k, v in pairs(t) do print(k..' ==> '..(tostring(v) or 'nil')) end
            end

            function dzlog(s, l)
                aprint('### '..(l or 'INFO'):upper()..' >>> '..s, l and dz['LOG_'..l:upper()])
            end

            function trim(s)
                return s:match'^()%s*$' and '' or s:match'^%s*(.*%S)'
            end

            function constrain(x, a, b)
                if (not x or x < a) then return a
                elseif (x > b) then return b
                else return x end
            end

            function strFind(s, f)
                return string.find('|'..s:lower()..'|', '|'..tostring(f):lower()..'|', 1, true) ~= nil
            end

            --------------------
            --      GEO       --
            --------------------

            function geoLoc(addr, lat, lon)
                local u
                if not addr or addr == '' then
                    lat = lat or tostring(dz.settings.location.latitude)
                    lon = lon or tostring(dz.settings.location.longitude)
                    u = simpleCurl('"https://nominatim.openstreetmap.org/reverse?lat='..lat..'&lon='..lon..'&format=jsonv2&zoom=10"')
                    return fromData(u)
                else
                    u = simpleCurl('"https://nominatim.openstreetmap.org/search?q='..dzu.urlEncode(addr)..'&format=jsonv2&addressdetails=1"')
                    return fromData(u)[1]
                end
            end

            --------------------
            --      TIME      --
            --------------------

            function timeRule(r)
                return (r == nil or r == "" or dz.time.matchesRule(r))
            end

            function at(r, func, ...)
                if timeRule(r) then func(...) end
            end

            function secondsFromNow(last)
                local now = os.time(os.date('*t'))
                return last and math.abs(now - last) or 0
            end

            --------------------
            --   GLOBALDATA   --
            --------------------

            function init_globalData()
                dz.globalData.initialize('managedEvent')
                dz.globalData.initialize('managedContext')
                dz.globalData.initialize('globalvars')
                dz.globalData.initialize('managedDevices')
            end

            function get_globalvars(k)
                return dz.globalData.globalvars[k]
            end

            function set_globalvars(k, v)
                dz.globalData.globalvars[k] = v
            end

            function is_globalvars(k)
                return dz.globalData.globalvars[k] ~= nil
            end

            --------------------
            --      NOTIF     --
            --------------------

            function sendNotification(message, settings)
                if not settings['QUIET'] or not timeRule(settings['QUIET']) then
                    local subsystems = settings['SUBSYSTEMS'] or ''
                    subsystems = subsystems:gsub('([^,]+)', function(x) return dz['NSS_'..x] end)
                    local subject = settings['SUBJECT'] or 'domoticz'
                    local priority = dz['PRIORITY_'..(settings['PRIORITY'] or 'NORMAL')]
                    if settings['FREQUENCY'] then
                        local n1 = managedEvent(message) and managedEvent(message)['nb']
                        local n2 = managedEvent(message, n1 ~= settings['FREQUENCY'])['nb']
                        if n2 > 0 then
                            return false
                        end
                    end
                    dz.notify(subject, message, priority, nil, nil, subsystems)
                    return true
                end
            end

            --------------------
            --     REQUEST    --
            --------------------

            function fromData(data)
                return (dzu.isJSON(data) and dzu.fromJSON(data, data)) or
                (dzu.isXML(data) and dzu.fromXML(data, data)) or
                data
            end

            function httpRequest(url, settings)
                local method = "GET"
                local headers = settings.headers or {['Content-Type'] = "text/html"}
                if settings.postdata ~= nil then
                    method = "POST"
                    if dzu.isJSON(settings.postdata) then
                        headers = settings.headers or {['Content-Type'] = 'application/json'}
                    elseif dzu.isXML(settings.postdata) then
                        headers = settings.headers or {['Content-Type'] = "text/xml"}
                    end
                end
                dz.openURL(
                    {
                        url = url,
                        method = method,
                        callback = settings.callback,
                        headers = headers,
                        postData = settings.postdata
                    }
                )
            end

            function osCommand(cmd, timeout)
                if timeout then
                    cmd = '/usr/bin/timeout '..timeout..'s'..' --preserve-status '..cmd
                end
                return dzu.osCommand(cmd)
            end

            function executeScript(cmd, callback, timeout)
                if callback then
                    dz.executeShellCommand(
                        {
                            command = cmd,
                            callback = (type(callback) == 'string') and callback,
                            timeout = timeout or 5,
                        }
                    )
                else return osCommand(cmd, timeout) end
            end

            function curl(url, settings)
                local cmd = '/usr/bin/curl "'..url..'" '
                if type(settings) == 'table' then
                    if settings['headers'] then
                        for _, v in pairs(settings['headers']) do
                            cmd = cmd..' -H "'..v..'"'
                        end
                    end
                    if settings['data'] then
                        cmd = cmd..' -d "'
                        for k, v in pairs(settings['data'] ) do
                            cmd = cmd..k..'='..dzu.urlEncode(v)..'&'
                        end
                        cmd = cmd..'" '
                    end
                    cmd = cmd..'-X '..(settings['method'] or 'GET')
                    if not settings['callback'] and settings['timeout'] then
                        cmd = cmd..' '..'--connect-timeout '..tostring(settings['timeout'])
                    else
                        return executeScript(cmd, settings['callback'], settings['timeout'])
                    end
                end
                return executeScript(cmd)
            end

            function simpleCurl(args, callback, timeout)
                return executeScript('/usr/bin/curl '..args, callback, timeout)
            end

            --------------------
            --      EVENTS    --
            --------------------

            function managedEvent(id, f)
                local now = os.time(os.date('*t'))
                local e = dz.globalData.managedEvent[id] or { nb = 0, last = now, first = 0 }
                e.nb = (f == true and e.nb + 1) or (f == false and 0) or e.nb
                --e.last = (f == true and now) or (f == false and 0) or e.last
                e.last = now
                --e.first = (e.nb == 0 and 0) or (e.nb == 1 and now) or e.first
                e.first = (f == true and e.nb <= 1 and now) or (e.nb == 0 and 0) or e.first
                dz.globalData.managedEvent[id] = e
                return e
            end

            function is_managedEvent(id)
                return id and dz.globalData.managedEvent[id] ~= nil
            end

            function state_managedEvent(id)
                return is_managedEvent(id) and dz.globalData.managedEvent[id].nb > 0
            end

            function sendCustomEvent(e, context)
                dz.emitEvent(e, context or {})
            end

            --------------------
            --    CONTEXT     --
            --------------------

            function managedContext(id, context, t)
                local now = os.time(os.date('*t'))
                if context == false then
                    dz.globalData.managedContext[id] = nil
                    return
                elseif context then
                    dz.globalData.managedContext[id] = {
                        context = context,
                        last = now,
                        timeout = t
                    }
                end
                return dz.globalData.managedContext[id]
            end

            function garbage_managed()
                dzlog('Garbage managed data in progress')
                for k, v in pairs(dz.globalData.managedEvent) do
                    if secondsFromNow(v.last) > C_GARBAGE_EVENT_FREQ then
                        dz.globalData.managedEvent[k] = nil
                    end
                end
            end

            at('00:01', garbage_managed)

            function dzBasicCall_getData(id)
                local c = managedContext(id)
                return c and c['context'] or nil
            end

            function dzBasicCall_isvalidData(id)
                local c = managedContext(id)
                return c and c['timeout'] and (c['timeout'] == 0 or secondsFromNow(c['last']) < c['timeout'])
            end

            function dzBasicCall_setData(id, context, t)
                managedContext(id, context, t)
            end

            function dzBasicCall_return(id, r, t)
                if dz.globalData.managedContext[id] then
                    local c = dz.globalData.managedContext[id]['context']
                    if c['microbasic'] then
                        c['returnval'] = r
                        managedContext(id, c, t)
                        sendCustomEvent('dzBasic_customevent', c)
                    end
                end
            end

            --------------------
            --    DZB TOOLS   --
            --------------------

            function getItem(id)
                return
                (dzu.deviceExists(id) and dz.devices(id)) or
                (dzu.groupExists(id) and dz.groups(id)) or
                (dzu.sceneExists(id) and dz.scenes(id)) or
                (dzu.variableExists(id) and dz.variables(id)) or
                nil
            end

            function dzbformat(s, dv)
                -- %%devname#property%% or %%property%%
                local a, b = string.gsub(s, '%%%%([^%%#\n\r\t]+#?[%w_]*)%%%%',
                    function(w)
                        local d = dzu.stringSplit(w, '#')
                        r = #d > 1 and getItem(d[1]) or getItem(dv)
                        return #d > 1 and tostring(r[d[2]]) or tostring(r[d[1]])
                    end
                )
                return a
            end

            function dzbswitch(id, c, settings)
                local haschanged = false
                c = c:sub(1, 1):upper()..c:sub(2):lower()
                settings = settings or {}
                group(id,
                    function(d)
                        haschanged = haschanged or (d.state ~= c)
                        if c == 'Flash' then
                            d.setState('Toggle').forSec(1).repeatAfterSec(1, 5)
                        elseif settings['checkfirst'] and d.state == c then
                            return
                        elseif settings['silent'] then
                            d.setState(c).silent()
                        else
                            d.setState(c)
                        end
                    end
                )
                return haschanged
            end

            function dzbupdate(id, v, n, settings)
                local haschanged = false
                group(id,
                    function(d)
                        if d.switchType == 'Dimmer' and type(v) == 'number' then
                            haschanged = haschanged or (d.level ~= v)
                            d.dimTo(constrain(v, 0, 100))
                        elseif d.switchType == 'Selector' then
                            haschanged = haschanged or (d.levelName ~= v)
                            d.switchSelector(v)
                        else
                            haschanged = haschanged or (d.sValue ~= v)
                            if n then haschanged = haschanged or (d.nValue ~= n) end
                            d.setValues(n, dzu.urlEncode(v))
                        end
                    end
                )
                return haschanged
            end

            function group(filter, func, b)
                local r = {}
                local filters
                if type(filter) == 'table' and filter['idx'] then filters = { filter.idx }
                elseif type(filter) == 'table' then filters = filter
                elseif type(filter) == 'number' then filters = { filter }
                elseif type(filter) == 'string' then filters = dzu.stringSplit(filter, ',')
                else return end
                for _, f in ipairs(filters) do
                    if type(f) == 'number' or b == false then
                        if func then func(getItem(f)) end
                        table.insert(r, f)
                    else
                        for _, z in ipairs({'devices', 'groups', 'scenes'}) do
                            dz[z]().forEach(
                                function(d)
                                    if string.find(d.name, '^'..f) then
                                        if func then func(d) end
                                        table.insert(r, d.idx)
                                    end
                                end
                            )
                        end
                    end
                end
                return r
            end

            function _cmp(x, y, op)
                if op == '>' then return x > y
                elseif op == '<' then return x < y
                elseif op == '>=' then return x >= y
                elseif op == '<=' then return x <= y
                elseif op == '~' or op == '~=' or op == '<>' then return x ~= y
                elseif op == '=' or op == '==' or not op then return x == y
                else return false
                end
            end

            function group_cmp(filter, x, y, op)
                local b = true
                group(filter,
                    function(d)
                        local v = d
                        if type(x) == 'table' then v = d[x[1]] x = x[2] end
                        if v and v[x] ~= nil and type(v[x]) ~= 'table' then
                            b = b and _cmp(v[x], y, op)
                        end
                    end
                )
                return b
            end

        end

    }
}
