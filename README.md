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



