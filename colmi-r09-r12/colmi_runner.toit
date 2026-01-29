import ble
import ntp
import esp32 show adjust-real-time-clock
import encoding.json
import .periodic_timer
import .ble_utils
import .core_utils
import .ble_helper

DEVICE-NAME           ::= "R09_0803"  //  "COLMI R12_4503"//
SCAN-DURATION         ::= Duration --s=30
MAX_CONNECT_ATTEMPTS  ::= 8
SLEEP_NEXT            ::= 10000

MAX_MEASUREMENT_ATTEMPTS  ::= sequence.size

_adapter/ble.Adapter? := ?
_central/ble.Central? := ?
_helper/BleHelper?    := ?

measurements_counter  := 0

find-with-name central/ble.Central device_name/string -> ble.RemoteScannedDevice :
  central.scan --duration=SCAN-DURATION : | device/ble.RemoteScannedDevice |
    if device.data.name == device_name :
      return device
  throw "No device found"

main :

  //connect_db
  //sync_time
  //save_label "start app"
  //sleep --ms=500

  _adapter  = ble.Adapter
  _central  = _adapter.central

  helper/BleHelper := BleHelper _central :: | p | call_back p
  _helper = helper

  connect _central sequence[measurements_counter]

// save_label parameter/string :
//   print "------- save label DB [$parameter] -------"
//   test/Map := {"time": "$time", "device": "R09 803", "parameter": parameter}
//   keep_measure test

call_back p/any :
  print "@CB[$p]"

/*  
  if (p == "stop-battery-level") :
    task::
      _helper.measureHeartRate

  // if (p == "stop-heart-rate-measure") :
  //   task::
  //     //powerOff _runner
  //     _helper.dispose
  //     _central.close
  //     _adapter.close
  //     _runner.stop
*/
  if (p == "stop-measure") :
    measurements_counter++

    task::

      sleep --ms=500
      sendData _helper.data
      _helper.dispose

      if (measurements_counter < MAX_MEASUREMENT_ATTEMPTS) :
      //  Save results  ///////////////////////////////////////////
        print "@wait $(SLEEP_NEXT/1000)s ..."
        sleep --ms=SLEEP_NEXT
        connect _central sequence[measurements_counter]
      else :  
        _central.close
        _adapter.close
        //close_connect

  if (p == "stop-app") :
    task::
      _helper.dispose
      _central.close
      _adapter.close
      //close_connect

sendData result/Map :
  result["time"] = "$time"
  print "$result"
  //keep_measure result

////////////////////////////////////////////////////////////

connect central sub-type/int :

  print "connect [$(parameter-name sub-type)]"

  _helper.current-sub-type = sub-type

  error/bool := false;

  try :

    e := catch --trace=false :  
      device/ble.RemoteScannedDevice := find-with-name central DEVICE-NAME
      mac_address := conv-to-mac-address "$device.identifier"
      _helper.connect (BleAppliance device.rssi device.data.name mac_address device.identifier)

    if e :
      error = true;
      print "Exception: $e"
      task::
        call_back "stop-app"
  
  finally :

////////////////////////////////////////////////////////////
// sync_time :
//   now := Time.now
//   if now < (Time.parse "2022-01-10T00:00:00Z"):
//     result ::= ntp.synchronize
//     if result:
//       adjust-real-time-clock result.adjustment
//       print "Set time to $Time.now by adjusting $result.adjustment"
//     else:
//       print "ntp: synchronization request failed"
//   else:
//     print "We already know the time is $now"
