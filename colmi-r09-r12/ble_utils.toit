/// Measurement sub types

HR/int              ::= 0x01
BLOOD_PRESSURE/int  ::= 0x02
SPO2/int            ::= 0x03
FATIGUE/int         ::= 0x04 // stress

// HEALTH_CHECK/int    ::= 0x05
// ECG/int             ::= 0x07
// PRESSURE/int        ::= 0x08

BLOOD_SUGAR/int     ::= 0x09

HRV/int             ::= 0x0A
TEMPERATURE/int     ::= 0x0B

names/Map ::= {HR: "hr",  BLOOD_PRESSURE: "bp", SPO2: "spo2", FATIGUE: "stress", HRV: "hrv", TEMPERATURE: "temp", BLOOD_SUGAR: "bs"}
units/Map ::= {HR: "bpm", BLOOD_PRESSURE: "mmHg", SPO2: "%", FATIGUE: "", HRV: "ms", TEMPERATURE: "°C", BLOOD_SUGAR: "mg/dL"}
m_cmd/Map ::= {HR:            #[0x69,0x01,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x6b],
               SPO2:          #[0x69,0x03,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x6d],
               TEMPERATURE:   #[0x69,0x0b,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x75],
               BLOOD_PRESSURE:#[0x69,0x02,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x6c],
               HRV:           #[0x69,0x0a,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x74],
               FATIGUE:       #[0x69,0x04,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x6e],
               BLOOD_SUGAR:   #[0x69,0x09,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x73]
}

battery_level/ByteArray ::=   #[0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x03]
power_off/ByteArray     ::=   #[0x08,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x09]

sequence/List := [BLOOD_PRESSURE,HR,SPO2,TEMPERATURE,BLOOD_SUGAR,HRV,FATIGUE]

parameter-name code/int -> string :
  result/string := ""
  if names.contains code :
    result = names[code]
  return result  

parameter-unit code/int -> string :
  result/string := ""
  if units.contains code :
    result = units[code]
  return result  

parameter-cmd code/int -> ByteArray :
  result/ByteArray := #[]
  if m_cmd.contains code :
    result = m_cmd[code]
  return result  

conv-to-mac-address str/string -> string :

  clean := str[2 .. str.size - 1].trim
  parts := clean.split ", "

  mac-address/string := ""

  parts.size.repeat: | i |
    part := parts[i].trim
    if part.size < 3 or part[0..2] != "0x" :
      throw "Invalid hex part: $part"
    hex-str := part[2..]
    if (i > 0) :
      suffix/string := i < (parts.size - 1) ? ":" : ""
      mac-address += "$hex-str$suffix"

  return mac-address

time -> string :
  time := Time.now.local
  ms := time.ns / Duration.NANOSECONDS_PER_MILLISECOND
  precise_ms := "$(%04d time.year)/$(%02d time.month)/$(%02d time.day) $(%02d time.h):$(%02d time.m):$(%02d time.s).$(%03d ms)"
  return precise_ms

time_short -> string :
  time := Time.now.local
  ms := time.ns / Duration.NANOSECONDS_PER_MILLISECOND
  precise_ms := "$(%02d time.h):$(%02d time.m):$(%02d time.s).$(%03d ms)"
  return precise_ms

impBatteryLevel value/ByteArray -> any :
  if value.size < 2:
    return "Invalid battery packet: too short"

  level := value[1] & 0xff  // Level 0-100%
  charging := value.size > 2 and value[2] == 1  // Charging (1 = yes)

  return "$level% [$charging]"


impManualMeasure value/ByteArray -> any :
  if value.size < 4:
    return "Invalid measurement response packet: too short"

  subtype := value[1] 
  error_code := value[2]
  response := value[3] & 0xff
  systolic := value[4] & 0xff

  if subtype == TEMPERATURE :
    response = response < 11 ? 0 : response.to_float/10 + 20
  else :
    if subtype == FATIGUE :
      response = response >> 1
    else :
      if subtype == BLOOD_PRESSURE :
        response = "$systolic/$response"
      else :
        if subtype == BLOOD_SUGAR :
          response = (18*response.to_float/10).round  

  if error_code == 0 :
    return "$response $(parameter-unit subtype)"
  else if error_code == 1 :
    print "Live $(parameter-name subtype) error code $error_code received from ring"
    return "Measure error"
  else if error_code == 2 :
    return "Missing data"
  else :
    return "Unknown Measure error"
