class PeriodicTimer :
  SURVEY_PERIOD/int := 60
  period_/Duration  := ?
  task_             := null  // Variable for store task
  is_running_/bool  := false

  constructor .SURVEY_PERIOD :
    period_     = Duration --s=SURVEY_PERIOD
    task_       = null  // Variable for store task
    is_running_ = false

  set_survey_period survey_period/int -> none :
    period_ = Duration --s=survey_period

  // Method for start timer
  start callback/Lambda -> none :
    if is_running_: return  // No run if timer already running
    is_running_ = true
    // Run task
    task_ = task:: 
      while is_running_:
        //print "Timer tick -- ($time)"
        sleep period_
        callback.call
        //sleep period_  // Wait 1s

  // Method for stop timer
  final -> none :
    if not is_running_ : return
    is_running_ = false
    task_.cancel
    task_ = null  // Clear task
    print "Timer deleted"
