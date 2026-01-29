import ble
import .ble_utils
import .core_utils
import .periodic_timer

MAX_CONNECT_ATTEMPTS  ::= 8

SERVICE_UUID    ::= ble.BleUuid "6e40fff0-b5a3-f393-e0a9-e50e24dcca9e"
WRITE_CHAR_UUID ::= ble.BleUuid "6e400002-b5a3-f393-e0a9-e50e24dcca9e"
READ_CHAR_UUID  ::= ble.BleUuid "6e400003-b5a3-f393-e0a9-e50e24dcca9e"

CMD_BATTERY                 ::= 0x03
CMD_POWER_OFF               ::= 0x08
CMD_MANUAL_MEASUREMENT      ::= 0x69
NOTIFICATION_BATTERY_LEVEL  ::= 0x0c

class BleHelper :
  
  central/ble.Central?
  cb/Lambda?       

  next_step_/string := "none"

  connect_attempts/int  := 0

  current-sub-type/int  := 0

  reader_task_      := null  // Variable for store task
  is_running_/bool  := false

  appliance_/BleAppliance? := null

  data_/Map := {:}

  process_timer_/PeriodicTimer := PeriodicTimer 3
  process_counter_ := 0

  remote-device/ble.RemoteDevice?             := null
  
  w-characteristic_/ble.RemoteCharacteristic? := null
  r-characteristic_/ble.RemoteCharacteristic? := null

  lookup_table_ := {:}

  constructor .central .cb :
    createLookupTable

  next_step :
    return next_step_

  data :
    return data_

  handleBatteryLevel p/any -> none :
    bl/any := impBatteryLevel p
    print "battery level: [$bl]"
    data_["battery"] = bl

  handleMeasurement p/any -> none :
    value/any := impManualMeasure p
    parameter_name/string := parameter-name p[1] 
    print "$parameter_name: [$value]"
    data_[parameter_name] = value

  handlePowerOff p/any -> none :
    print "handlePowerOff: $p"

  handle data/any :
    key := data[0]
    if not lookup_table_.contains key :
      print "handle [$key] failed"
      return
    fun/Lambda := lookup_table_[key]
    fun.call data 

  createLookupTable :
    lookup_table_[CMD_BATTERY]            = :: | p | handleBatteryLevel p
    lookup_table_[CMD_POWER_OFF]          = :: | p | handlePowerOff p
    lookup_table_[CMD_MANUAL_MEASUREMENT] = :: | p | handleMeasurement p

  connect appliance/BleAppliance :

    identifier := appliance.identifier

    data_ = {:}

    connected := false
    connect_attempts = 0

    // Retry connect_device up to MAX_CONNECT_ATTEMPTS5 times
    while not connected and connect_attempts < MAX_CONNECT_ATTEMPTS :
      connect_attempts++
      
      try :

        error := catch --trace=false :
          
          connect_device central identifier
          connected   = true
          appliance_  = appliance

          data_["name"] = appliance.name
          data_["rssi"] = appliance.rssi
          data_["mac"]  = appliance.mac_address

        if error == "Failed to connect" :
          if connect_attempts == MAX_CONNECT_ATTEMPTS:
            data_["ca"] = connect_attempts
            throw "Failed to connect after $MAX_CONNECT_ATTEMPTS attempts"
            
      finally :

    if not connected:
      throw "@Failed to connect after $MAX_CONNECT_ATTEMPTS attempts"
    else :
      print "[$connect_attempts] connect_device -- completed"
      data_["ca"] = connect_attempts
  

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
    
    finally :

  subscribe r-characteristic/ble.RemoteCharacteristic :
    is_running_ = true
    reader_task_ = task::
      r-characteristic.subscribe
      while is_running_ :
        if is_running_ :
          incoming-data := r-characteristic.wait-for-notification          
          handle incoming-data
          process_counter_++
          //sleep --ms=1

  observation :

    print "observation: $process_counter_"
    if (process_counter_ == 0) :
      process_timer_.final
      if (next_step_ == "stop-battery-level") :
        task::
          measure current-sub-type
      else :  
        cb.call next_step_
    else :
      process_counter_= 0

  requestPowerOff w-characteristic/ble.RemoteCharacteristic -> none :
    next_step_ = "stop-app"
    //packet/ByteArray := build_packet [CMD_POWER_OFF,0x01]
    w-characteristic.write power_off //packet
    process_counter_ = 0
    process_timer_.start ::observation

  requestBatteryLevel w-characteristic/ble.RemoteCharacteristic -> none :
    next_step_ = "stop-battery-level"
    //packet/ByteArray := build_packet [CMD_BATTERY]
    w-characteristic.write battery_level //packet
    process_counter_ = 0
    process_timer_.start ::observation

  powerOff :
    requestPowerOff w-characteristic_

  measure sub-type/int -> none :
    requestToMeasute w-characteristic_ sub-type

  requestToMeasute w-characteristic/ble.RemoteCharacteristic sub-type/int -> none :
    next_step_ = "stop-measure"
    packet/ByteArray := parameter-cmd sub-type //build_packet [CMD_MANUAL_HEART_RATE,0x01]
    w-characteristic.write packet
    process_counter_ = 0
    process_timer_.start ::observation

  dispose :
    if not is_running_ : return
    
    try :
      error := catch --trace=false :
        r-characteristic_.unsubscribe
      if error :
        print "unsubscribe->$error"  
    finally :  
      is_running_ = false
      reader_task_.cancel
      reader_task_ = null  // Clear task
      remote-device.close
      print "BleHelper is disposed"
