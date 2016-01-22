#include <nerv/core.mqh>
#include <nerv/trading/SecurityTrader.mqh>
#include <nerv/trading/ALRBasket.mqh>
#include <nerv/math/SimpleRNG.mqh>

/*
Class: nvHAZRTrader

Base class representing a trader 
*/
class nvHAZRTrader : public nvSecurityTrader {
protected:
  nvALRBasket* _basket;

public:
  /*
    Class constructor.
  */
  nvHAZRTrader(string symbol)
    : nvSecurityTrader(symbol)
  {
    logDEBUG("Creating HAZRTrader")    
    _basket = new nvALRBasket(_symbol);
  }

  /*
    Class destructor.
  */
  ~nvHAZRTrader()
  {
    logDEBUG("Deleting HAZRTrader")
    RELEASE_PTR(_basket);
  }

  virtual void update(datetime ctime)
  {

  }
  
  virtual void onTick()
  {
    _basket.update();

    if(_basket.isRunning())
    {
      // Wait for the basket to complete:
      return;
    }
  }
};
