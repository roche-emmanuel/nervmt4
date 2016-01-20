/*
Implementation of Multi trader.

This trader will read the prediction data from a csv file
and then use those predictions to place orders.
*/

#property copyright "Copyright 2015, Nervtech"
#property link      "http://www.nervtech.org"

#property version   "1.00"

#include <nerv/core.mqh>
#include <stdlib.mqh>

// #define USE_TIMER

#ifdef USE_TIMER
input int   gTimerPeriod=1;  // Timer period in seconds
#endif

// nvMultiTrader* mtrader = NULL;

// Initialization method:
int OnInit()
{    
  logDEBUG("Initializing Nerv Multi Expert.")

  nvLogManager* lm = nvLogManager::instance();
  string fname = "nerv_ea_v01.log";
  nvFileLogger* logger = new nvFileLogger(fname);
  lm.addSink(logger);

#ifdef USE_TIMER
  // Initialize the timer:
  CHECK_RET(EventSetTimer(gTimerPeriod),0,"Cannot initialize timer");
#endif

  return 0;
}

// Uninitialization:
void OnDeinit(const int reason)
{
  logDEBUG("Uninitializing Nerv Multi Expert.")
#ifdef USE_TIMER
  EventKillTimer();
#endif

  // // Destroy the trader:
  // RELEASE_PTR(mtrader);
}

// OnTick handler:
void OnTick()
{

}

void OnTimer()
{
  logDEBUG(TimeCurrent() << ": In Timer")
}
