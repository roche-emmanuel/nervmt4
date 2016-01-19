/*
Implementation of Multi trader.

This trader will read the prediction data from a csv file
and then use those predictions to place orders.
*/

#property copyright "Copyright 2015, Nervtech"
#property link      "http://www.nervtech.org"

#property version   "1.00"

#include <nerv/core.mqh>

input int   gTimerPeriod=60;  // Timer period in seconds

// nvMultiTrader* mtrader = NULL;

// Initialization method:
int OnInit()
{
  return 0;
}

// Uninitialization:
void OnDeinit(const int reason)
{
  // logDEBUG("Uninitializing Nerv Multi Expert.")
  // EventKillTimer();

  // // Destroy the trader:
  // RELEASE_PTR(mtrader);
}

// OnTick handler:
void OnTick()
{

}

void OnTimer()
{

}
