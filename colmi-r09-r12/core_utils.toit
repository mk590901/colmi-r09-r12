class BleAppliance :
  _rssi/int
  _name/string
  _mac_address/string
  _identifier/any

  constructor ._rssi ._name ._mac_address ._identifier :

  mac-address -> string :
    return _mac_address

  identifier :
    return _identifier  

  rssi :
    return _rssi

  name :
    return _name

  to-string -> string :
    return "$_rssi : $_name $_mac_address : $_identifier"

