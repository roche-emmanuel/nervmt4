#include <nerv/core.mqh>
#include <nerv/trading/SecurityTrader.mqh>
/*
Class: nvScalperTrader

Base class representing a trader 
*/
class nvScalperTrader : public nvSecurityTrader {
protected:
  int _ticket;
  ENUM_TIMEFRAMES _period;

public:
  /*
    Class constructor.
  */
  nvScalperTrader(string symbol, ENUM_TIMEFRAMES period = PERIOD_M1)
    : nvSecurityTrader(symbol), _period(period)
  {
    logDEBUG("Creating ScalperTrader")
    _ticket = -1;
  }

  /*
    Class destructor.
  */
  ~nvScalperTrader()
  {
    logDEBUG("Deleting ScalperTrader")
  }

  virtual void update(datetime ctime)
  {

  }
  
  virtual void onTick()
  {
    if(!nvIsPositionClosed(ticket))
    {
      // Already in a position, so we keep it;
      return;
    }

    // Check the entry conditions:
    
  }
};
