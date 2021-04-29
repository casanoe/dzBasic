
<!-- omit in toc -->
# DzBasic examples
Documentation is good, examples are better.

<!-- omit in toc -->
## Table of contents

<!-- TOC -->

- [Table of contents](#table-of-contents)
- [Ex1 - Turn off device after 5 min](#ex1---turn-off-device-after-5-min)
- [Ex2 - Turn off device after 5 min if motion sensors are off](#ex2---turn-off-device-after-5-min-if-motion-sensors-are-off)
- [Ex3 - Turn off device after 5 min if motion sensors are off from 2 min](#ex3---turn-off-device-after-5-min-if-motion-sensors-are-off-from-2-min)
- [Ex4 - If a switch is turned on, do something](#ex4---if-a-switch-is-turned-on-do-something)
- [Ex5 - Create custom events](#ex5---create-custom-events)
- [Ex6 - Be notified if a custom event is on for a number of minutes](#ex6---be-notified-if-a-custom-event-is-on-for-a-number-of-minutes)
- [Ex7 - Be notified if device is on since 5 min or more](#ex7---be-notified-if-device-is-on-since-5-min-or-more)
- [Ex8 - Auto off device at a specific time](#ex8---auto-off-device-at-a-specific-time)
- [Ex9 - Gradually increase every 2 min the level of the light from the last level to 50%, by step 5%.](#ex9---gradually-increase-every-2-min-the-level-of-the-light-from-the-last-level-to-50%-by-step-5%)
- [Ex10 - Blink/flash a switch](#ex10---blinkflash-a-switch)
- [Ex11 - Switch on 2 switches if they are off.](#ex11---switch-on-2-switches-if-they-are-off)
- [Ex12 - Update different types of devices.](#ex12---update-different-types-of-devices)
- [Ex12 - Change the icon of the device](#ex12---change-the-icon-of-the-device)
- [Ex13 - Display the day of the week as an icon](#ex13---display-the-day-of-the-week-as-an-icon)
- [Ex14 - Updates every 5 min the public ip address in a text device](#ex14---updates-every-5-min-the-public-ip-address-in-a-text-device)
- [Ex15 - Execute a long http request with a timeout of 5s, and catch the result](#ex15---execute-a-long-http-request-with-a-timeout-of-5s-and-catch-the-result)
- [Ex16 - Call meteo (Openweathermap) plugin and update 4 text devices](#ex16---call-meteo-openweathermap-plugin-and-update-4-text-devices)
- [Ex17 - Be notified when a lamp is on and no one is at home](#ex17---be-notified-when-a-lamp-is-on-and-no-one-is-at-home)
- [Ex18 - Interact with a Telegram bot](#ex18---interact-with-a-telegram-bot)
- [Ex19 - French holidays](#ex19---french-holidays)
- [Ex20 - Be notified if the public ip address change](#ex20---be-notified-if-the-public-ip-address-change)

<!-- /TOC -->

## Ex1 - Turn off device after 5 min

```lua
dzbasic
auto off after 5
```

## Ex2 - Turn off device after 5 min if motion sensors are off

```lua
dzbasic
auto off when minutesago >= 5, state "motion1,motion2" = alloff
```

## Ex3 - Turn off devices after 5 min if motion sensors are off from 2 min
_"motion%d"_ refers to all devices named motion1, motion2, motion3...
```lua
dzbasic
auto off when minutesago >= 5, state "motion%d" = alloff , minutesago "motion%d" >=2
```

## Ex4 - If a switch is turned on, do something

```lua
dzbasic
on dz_switchon
  print "Hello world"
endon
```

## Ex5 - Create custom events
These events are updated every minute and are visible from everywhere:
```lua
dzbasic
event ev_outdoor1 when %%temperature%% < 10 or %%temperature%% > 30
event ev_outdoor2 when %%temperature%% < 5, time = "7:00-9:00"
event ev_outdoor3 when %%sensorhum#humidity%% > 50
```

## Ex6 - Be notified if a custom event is on for a number of minutes
Reuse of ev_outdoor1 event declared in Ex5
```lua
dzbasic
on ev_outdoor1 duration >= 5
  notification "Outdoor temp ", FREQUENCY = 60, QUIET = "22:00-08:00", SUBSYSTEMS = "PROWL"
endon
```

## Ex7 - Be notified if device is on since 5 min or more

```lua
dzbasic
on state = on, minutesago >= 5: notification "%%name%% on > 5 min", FREQUENCY = 30
```

## Ex8 - Auto off device at a specific time

```lua
dzbasic
auto off at "01:00 on monday"
```

## Ex9 - Gradually increase every 2 min the level of the light from the last level to 50%, by step 5%.
Starts as soon as the light is turned on.
```lua
dzbasic
auto dim 5, 50 after 2
```

## Ex10 - Blink/flash a switch
Blink 5 times every second
```lua
dzbasic
switch flash
```

## Ex11 - Switch on 2 switches if they are off.

```lua
dzbasic
switch on , "myswitch1,myswitch2", checkfirst
```

## Ex12 - Update different types of devices.

```lua
dzbasic
-- update value of a text device
update "hello world", "my_text_device"
update "A text"
-- update level% of a dimmer light
update 60, "my_dimmer_light"
-- update the temperature value of a sensor
update "21", "my_temp_sensor"
-- update values of a temp/hum sensor
update "21,50,0", "my_temp_hum_sensor"
-- update the level of a selector
update "Level", "my_selector"
```

## Ex12 - Change the icon of the device

```lua
dzbasic
icon 110
```

## Ex13 - Display the day of the week as an icon
We assume that the values 100 to 700 correspond to the icon number in Domoticz.
```lua
dzbasic
on time "00:00"
  $ICONS = 100,200,300,400,500,600,700
  icon $ICONS[@date("%w")+1]
endon
```

## Ex14 - Updates every 5 min the public ip address in a text device

```lua
dzbasic
after 5: update @url("https://api.ipify.org")
```

## Ex15 - Execute a long http request with a timeout of 5s, and catch the result

```lua
dzbasic
at "10:00" : url "https://longtimeresult.com/returnvalue", cb, 5
on dz_url : print "The site return "..$$
```

## Ex16 - Call meteo (Openweathermap) plugin and update 4 text devices
Appid can also be in a user variable named `openweathermap_appid`.
Meteo plugin uses latitude and longitude recorded in domoticz configuration.
```lua
dzbasic
on minutesago >= 30
  call meteo, appid="xxxxxxxxxxx"
  --print "Meteo plugin return: ", $$
  update $$["prevision"][2]["meteo"], "Meteo tomorrow"
  update $$["rain"], "Rain today (mm)"
  update $$["%rain"][1], "Rain % in 1h"
  update $$["meteo"]
endon
```

## Ex17 - Be notified when a lamp is on and no one is at home
Reminder: _"Light"_ refers to all devices whose name begins with _Light_
and _"Presence"_ refers to all devices whose name begins with _Presence_.
```lua
dzbasic
-- At least one device "Light" is on; and all devices "Presence" are off
on state "Light" = on, state "Presence" = alloff
  notification "Lights turned off, nobody is at home"
  switch off, "Light"
endon
```

## Ex18 - Interact with a Telegram bot
We assumed that an external script updates a text device with the Telegram messages
```lua
dzbasic
on dz_update
  -- drop accents and unnecessary spaces
  $text = @cleanstr("%%text%%")
  if $text == "alarm on": switch on "Alarm"
  if $text == "alarm off": switch off "Alarm"
  if $text == "lights off": switch off "Lights"
  notification "Ok, well received '%%text%%' command", SUBSYSTEMS = "TELEGRAM"
endon
```

## Ex19 - French holidays

```lua
on time = "1:00"
  url "http://domogeek.entropialux.com/schoolholiday/B/now/"
  if $$ == "False"
    switch off, checkfirst
  else
    switch on, checkfirst
  endif
endon
```

## Ex20 - Be notified if the public ip address change

```lua
dzBasic
on minutesago > 30
  url "https://api.ipify.org"
  if %%text%% ~= $$ : notification "New IP= "..$$
  update $$
endon
```


## Changelog
- 26/04/21 : Creation
- 27/04/21 : Addon, corrections (Ex5, Ex13, Ex9)
- 27/04/21 : Addon, corrections (Ex5, Ex6)
- 28/04/21 : Addon, improve explication, corrections
- 29/04/21 : Addon, corrections
