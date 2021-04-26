
<!-- omit in toc -->
# DzBasic examples
Documentation is good, examples are better.

<!-- omit in toc -->
## Table of contents

<!-- TOC -->

- [Ex1 - Turn off device after 5 min](#ex1---turn-off-device-after-5-min)
- [Ex2 - Turn off device after 5 min if motion sensors are off](#ex2---turn-off-device-after-5-min-if-motion-sensors-are-off)
- [Ex3 - Turn off device after 5 min if motion sensors are off from 2 min](#ex3---turn-off-device-after-5-min-if-motion-sensors-are-off-from-2-min)
- [Ex4 - If a switch is turned on, do something](#ex4---if-a-switch-is-turned-on-do-something)
- [Ex5 - Create events based on outdoor sensor](#ex5---create-events-based-on-outdoor-sensor)
- [Ex6 - Be notified if outdoor event is on for a number of minutes](#ex6---be-notified-if-outdoor-event-is-on-for-a-number-of-minutes)
- [Ex7 - Be notified if device is on since 5 min](#ex7---be-notified-if-device-is-on-since-5-min)
- [Ex8 - Auto off device at a specific time](#ex8---auto-off-device-at-a-specific-time)
- [Ex9 - Gradually increase every 2 min the level of the light from 0 to 50%, by step 5%.](#ex9---gradually-increase-every-2-min-the-level-of-the-light-from-0-to-50%-by-step-5%)
- [Ex10 - Blink/flash a switch](#ex10---blinkflash-a-switch)
- [Ex11 - Switch on 2 switches if they are off.](#ex11---switch-on-2-switches-if-they-are-off)
- [Ex12 - Update different types of devices.](#ex12---update-different-types-of-devices)
- [Ex12 - Change the icon of the device](#ex12---change-the-icon-of-the-device)
- [Ex13 - Display the day of the week as an icon](#ex13---display-the-day-of-the-week-as-an-icon)

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

## Ex3 - Turn off device after 5 min if motion sensors are off from 2 min

```lua
dzbasic
auto off when minutesago >= 5, state "motion sensor nb %d" = alloff , minutesago "motion sensor nb %d" >=2
```

## Ex4 - If a switch is turned on, do something

```lua
dzbasic
on dz_switchon
  print "Hello world"
endon
```

## Ex5 - Create events based on outdoor sensor  
These event are visible from everywhere:
```lua
dzbasic
-- The event is updated every minute.
event ev_outdoor1 when %%temperature%% < 10 or %%temperature%% > 30
event ev_outdoor2 when %%temperature%% < 5, time = "7:00-9:00"
-- The event is updated every 5 minutes.
after 5: event ev_outdoor3 when %%humidity%% > 50
```

## Ex6 - Be notified if outdoor event is on for a number of minutes
Reuse of ev_outdoor1 event declared in Ex5
```lua
dzbasic
on ev_outdoor1 duration >= 5
  notification "Outdoor temp ", FREQUENCY = 60, QUIET = "22:00-08:00", SUBSYSTEMS = "PROWL"
endon
```

## Ex7 - Be notified if device is on since 5 min

```lua
dzbasic
on state = on, minutesago >= 5: notification "%%name%% on > 5 min", FREQUENCY = 30
```

## Ex8 - Auto off device at a specific time

```lua
dzbasic
auto off at "01:00 on monday"
```

## Ex9 - Gradually increase every 2 min the level of the light from 0 to 50%, by step 5%.

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
dzBasic
switch on , "myswitch1,myswitch2", checkfirst
```

## Ex12 - Update different types of devices.

```lua
dzBasic
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
dzBasic
icon 110
```

## Ex13 - Display the day of the week as an icon

```lua
dzBasic
on time "00:00"
  $ICONS = 100,200,300,400,500,600,700
  icon $ICONS[@date("%w")-1]
endon
```
