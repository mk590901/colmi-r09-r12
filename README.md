# Introduction

This repository contains an application in the __Toit__ language allows the __ESP32-S3__ μ-controller to find the nearby __COLMI R09__ BLE smart ring, connect to it several times, measure the __heart rate__, __SpO2__, __blood pressure__, __temperature__, __HRV__, __stress__ and __blood sugar__.

## Precondition

The __COLMI Rx__ smart rings are one of the few whose protocol is more or less well-known. At least, the __GadgetBridge__ app (https://codeberg.org/Freeyourgadget/Gadgetbridge) describes commands for measuring the ring's __battery level__, __heart rate__, and also for obtaining a dataset of measurements taken during continuous monitoring. It also describes how to power off the ring (a completely pointless command, in my opinion). Unfortunately, the GadgetBridge app doesn't yet describe the command format for measuring __temperature__, __stress__, __HRV__, and __SpO2__. I'm not particularly interested in the monitoring data, so I've limit myself to measuring __heart rate__ on the first stage.

Next, after some weeks, inside __Colmi_r02_client__ repository (https://github.com/tahnok/colmi_r02_client) in one of the project files (_real_time.py_), I found a hint on how to measure __SpO2__, __HRV__, and __stress__. It turned out that the heart rate measurement code described in Gadgetbridge is just a special case of the general manual measurement system, and three additional parameters can also be measured. Moreover, assuming that the command table could be expanded, I was able to reconstruct the __temperature__ measurement method and also discovered hidden, never-advertised __heart pressure__ measurement commands and something completely exotic: __blood sugar__.

I also found there's no fundamental difference between __R09__ and __R12__, and the app can be used for __R12__ as well. Just need to change the device search tag.

> R09

<img width="1204" height="1600" alt="colmi_r09" src="https://github.com/user-attachments/assets/be903474-dc77-4162-9d2f-128261299725" />

> R12

<img width="1204" height="1600" alt="colmi_r12" src="https://github.com/user-attachments/assets/02bee4c7-57cd-477a-a4c1-e26c795e3e93" />

## Inside application

The application searches for devices by name, done connect (up 8 attempts) and measures their charge.

### Search devices

```toit
device/ble.RemoteScannedDevice := find-with-name central DEVICE-NAME
```

### Connect device
```toit
  connect_device central/ble.Central identifier -> none :

    // Connection logic
    
    try :
    
      error := catch --trace=false :
        remote-device = central.connect identifier
        print "connection to $identifier ok"

    // Discover the service.
        services := remote-device.discover-services [SERVICE_UUID]
        service/ble.RemoteService := services.first

    // Discover the write characteristic.
        write-characteristics := service.discover-characteristics [WRITE_CHAR_UUID]
        write-characteristic/ble.RemoteCharacteristic := write-characteristics.first
        w-characteristic_ = write-characteristic

    // Discover the read characteristic.
        read-characteristics := service.discover-characteristics [READ_CHAR_UUID]
        read-characteristic/ble.RemoteCharacteristic  := read-characteristics.first
        r-characteristic_ = read-characteristic

    // Subscribe
        subscribe read-characteristic
        
        requestBatteryLevel write-characteristic

      if error :
        print "------- $error -------"
        throw "Failed to connect"
 ```   


After connecting, need measuring the battery level:

```toit
requestBatteryLevel write-characteristic
```

### Measurements

The following steps must be performed during the parameter measurement process:

* access the main service "6e40fff0-b5a3-f393-e0a9-e50e24dcca9e"
* access the command writing service "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
* access the data reading service "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
* subscribe to receive data
* send a command to the writing service

The measurement process can take some time. It is accompanied by the transmission of data, which is caught by the listener (implemented by reader_task_ task::). The measurement process is complete when the data stops arriving. The key is to catching of this moment. The algorithm is simple: a command for the measurement is sent and a periodic timer is simultaneously started. When data is received, the data counter is incremented. The timer resets the data counter incoming. The process is complete when the data counter is no longer changes. This triggers the measured data presentation/saving procedure.

## Trace

```
[jaguar] INFO: program 2b3700ca-54ad-dd61-9d30-f827725d94e7 started
connect [bp]
connection to #[0x00, 0x30, 0x38, 0x47, 0x31, 0x08, 0x03] ok
[1] connect_device -- completed
battery level: [98% [false]]
observation: 1
observation: 0
Timer deleted
bp: [0/0 mmHg]
bp: [0/0 mmHg]
...
bp: [116/78 mmHg]
bp: [116/78 mmHg]
observation: 6
observation: 0
Timer deleted
@CB[stop-measure]
{name: R09_0803, rssi: -87, mac: 30:38:47:31:08:03, ca: 1, battery: 98% [false], bp: 116/78 mmHg, time: 2026/01/29 12:41:42.672}
BleHelper is disposed
@wait 10s ...
connect [hr]
------- BLE connection failed -------
connection to #[0x00, 0x30, 0x38, 0x47, 0x31, 0x08, 0x03] ok
[2] connect_device -- completed
battery level: [98% [false]]
observation: 1
observation: 0
Timer deleted
hr: [0 bpm]
hr: [0 bpm]
...
hr: [60 bpm]
hr: [59 bpm]
hr: [59 bpm]
observation: 6
observation: 0
Timer deleted
@CB[stop-measure]
{name: R09_0803, rssi: -93, mac: 30:38:47:31:08:03, ca: 2, battery: 98% [false], hr: 59 bpm, time: 2026/01/29 12:42:40.422}
BleHelper is disposed
@wait 10s ...
connect [spo2]
------- BLE connection failed -------
connection to #[0x00, 0x30, 0x38, 0x47, 0x31, 0x08, 0x03] ok
[2] connect_device -- completed
battery level: [98% [false]]
observation: 1
observation: 0
Timer deleted
spo2: [0 %]
spo2: [0 %]
'''
spo2: [99 %]
spo2: [99 %]
spo2: [97 %]
observation: 5
observation: 0
Timer deleted
@CB[stop-measure]
{name: R09_0803, rssi: -84, mac: 30:38:47:31:08:03, ca: 2, battery: 98% [false], spo2: 97 %, time: 2026/01/29 12:43:42.173}
BleHelper is disposed
@wait 10s ...
connect [temp]
------- BLE connection failed -------
connection to #[0x00, 0x30, 0x38, 0x47, 0x31, 0x08, 0x03] ok
[2] connect_device -- completed
battery level: [98% [false]]
observation: 1
observation: 0
Timer deleted
temp: [0 °C]
...
temp: [35.399999999999998579 °C]
temp: [35.399999999999998579 °C]
observation: 6
observation: 0
Timer deleted
@CB[stop-measure]
{name: R09_0803, rssi: -87, mac: 30:38:47:31:08:03, ca: 2, battery: 98% [false], temp: 35.399999999999998579 °C, time: 2026/01/29 12:44:43.323}
BleHelper is disposed
@wait 10s ...
connect [bs]
------- BLE connection failed -------
------- BLE connection failed -------
------- BLE connection failed -------
connection to #[0x00, 0x30, 0x38, 0x47, 0x31, 0x08, 0x03] ok
[4] connect_device -- completed
battery level: [98% [false]]
observation: 1
observation: 0
Timer deleted
bs: [0 mg/dL]
bs: [0 mg/dL]
...
bs: [99 mg/dL]
bs: [92 mg/dL]
observation: 6
observation: 0
Timer deleted
@CB[stop-measure]
{name: R09_0803, rssi: -89, mac: 30:38:47:31:08:03, ca: 4, battery: 98% [false], bs: 92 mg/dL, time: 2026/01/29 12:45:47.922}
BleHelper is disposed
@wait 10s ...
connect [hrv]
connection to #[0x00, 0x30, 0x38, 0x47, 0x31, 0x08, 0x03] ok
[1] connect_device -- completed
battery level: [98% [false]]
observation: 1
observation: 0
Timer deleted
hrv: [0 ms]
hrv: [0 ms]
...
hrv: [0 ms]
hrv: [46 ms]
observation: 5
observation: 0
Timer deleted
@CB[stop-measure]
{name: R09_0803, rssi: -81, mac: 30:38:47:31:08:03, ca: 1, battery: 98% [false], hrv: 46 ms, time: 2026/01/29 12:47:13.345}
BleHelper is disposed
@wait 10s ...
connect [stress]
connection to #[0x00, 0x30, 0x38, 0x47, 0x31, 0x08, 0x03] ok
[1] connect_device -- completed
battery level: [98% [false]]
observation: 1
observation: 0
Timer deleted
stress: [0 ]
stress: [0 ]
...
stress: [42 ]
stress: [40 ]
stress: [40 ]
observation: 6
observation: 0
Timer deleted
@CB[stop-measure]
{name: R09_0803, rssi: -72, mac: 30:38:47:31:08:03, ca: 1, battery: 98% [false], stress: 40 , time: 2026/01/29 12:48:10.482}
BleHelper is disposed
[jaguar] INFO: program 2b3700ca-54ad-dd61-9d30-f827725d94e7 stopped
```

## Notes

> App using the ntp package (https://docs.toit.io/tutorials/misc/date-time)

> Command to run app:
```
micrcx@micrcx-desktop:~/toit/colmi_r09-r12$ jag run -d basic colmi_runner.toit
Scanning for device with name: 'basic'
Running 'colmi_runner.toit' on 'basic' ...
Success: Sent 61KB code to 'basic' in 2.38s
micrcx@micrcx-desktop:~/toit/colmi_r09-r12$ 
```

