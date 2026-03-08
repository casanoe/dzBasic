--[[
name : tgmbot.lua
version: 1.0

description: speak with a bot
Warning: check message every minute only (only last message is taken into account)

optional arguments: bot (api token), chat (chat id), users (list of allowed user_id separated by a ',')

Return: if a new message arrived (boolean)

Global variables created :
$TGMBOT_TRIGGER => if a new message has arrived since the previous one : true or false
$TGMBOT_MSG     => new message received or ""

author : casanoe
creation : 23/10/2025
update : -

--]]

-- Script description
local scriptName = 'tgmbot'
local scriptVersion = '1.0'

-- Dzvents
return {
    on = {
        customEvents = { 'tgmbot' },
        timer = { 'every minute' }
    },
    data = {
        telegram = { initial = {id = 0} }
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

        -----------------------------------------

        local args = {}
        if triggeredItem.trigger == 'tgmbot' then
            local context = dzBasicCall_getData('tgmbot')
            args = context['args']
        end
        local token = args['bot'] or dz.variables('telegram_bot_appid').value
        local chatid = args['chat'] or dz.variables('telegram_chat_id').value
        local _u = args['users'] or dz.variables('telegram_allowed_users').value or ""
        _u = '['.._u..']'
        local users = fromData(_u)
        local msg = args['msg'] or nil
        
        local msgtimeout = 180
        
        local url_root = 'https://api.telegram.org/bot'
        local url_textsend = url_root..token..'/sendMessage?chat_id='..chatid
        local url_textrecv = url_root..token..'/getUpdates?offset=-1'
        local url_imgsend = url_root..token..'/sendPhoto?chat_id='..chatid

        function telegram_sendText(str)
            local out = curl(url_textsend, ' --data parse_mode=Markdown --data-urlencode text="'..str..'"')
            return fromData(out)
        end

        function telegram_read(timeout)
            timeout = timeout or msgtimeout or 0
            local out = curl(url_textrecv)
            local settings = fromData(out)
            if settings and settings['result'][1] then
                local h = settings['result'][1]['message']['message_id']
                local d = os.time() - settings['result'][1]['message']['date']
                if (h ~= dz.data.telegram.id) then
                    if (timeout == 0 or d <= timeout) and (users == {} or table.find(users, settings['result'][1]['message']['from']['first_name'])) then
                        dz.data.telegram.id = h
                        return settings['result'][1]['message']
                    end
                end
            end
            return false
        end

        local t 
        if msg then
            t = telegram_sendText(msg)
            dzBasicCall_return('tgmbot', t, nil)
        else
            t = telegram_read(0)
            set_globalvars("TGMBOT_TRIGGER", t ~= false)
            set_globalvars("TGMBOT_MSG", (t and t['text']) or "(none)")
            if t then 
                local r = telegram_sendText(string.format("Ok, message '%s' received", t['text'])) 
            end
            if triggeredItem.trigger == 'tgmbot' then
                dzBasicCall_return('tgmbot', t, nil)
            end
        end
        
        

    end
}
