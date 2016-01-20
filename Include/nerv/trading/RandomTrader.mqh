#include <nerv/core.mqh>
#include <nerv/trading/SecurityTrader.mqh>

/*
Class: nvRandomTrader

Base class representing a trader 
*/
class nvRandomTrader : public nvSecurityTrader {
public:
  /*
    Class constructor.
  */
  nvRandomTrader(string symbol)
    : nvSecurityTrader(symbol)
  {
    logDEBUG("Creating RandomTrader")
  }

  /*
    Class destructor.
  */
  ~nvRandomTrader()
  {
    logDEBUG("Deleting RandomTrader")
  }

  virtual void update(datetime ctime)
  {

  }
  
  virtual void onTick()
  {
    
  }
};
