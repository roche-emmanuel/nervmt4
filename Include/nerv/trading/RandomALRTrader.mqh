#include <nerv/core.mqh>
#include <nerv/trading/SecurityTrader.mqh>
#include <nerv/trading/ALRBasket.mqh>
#include <nerv/math/SimpleRNG.mqh>

/*
Class: nvRandomALRTrader

Base class representing a trader 
*/
class nvRandomALRTrader : public nvSecurityTrader {
protected:
  int _ticket;

  nvALRBasket* _basket;

  // Random generator:
  SimpleRNG rnd;

  double _initialBalance;

public:
  /*
    Class constructor.
  */
  nvRandomALRTrader(string symbol)
    : nvSecurityTrader(symbol)
  {
    logDEBUG("Creating RandomTrader")
    _ticket = -1;
    
    // rnd.SetSeedFromSystemTime();
    rnd.SetSeed(123);

    _basket = new nvALRBasket(_symbol);

    _initialBalance = nvGetBalance();
  }

  /*
    Class destructor.
  */
  ~nvRandomALRTrader()
  {
    logDEBUG("Deleting RandomTrader")
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

    // if we are not in a position, we open a new one randomly:
    int otype = (rnd.GetUniform()-0.5) > 0 ? OP_BUY : OP_SELL;
    
    double lot = 0.1; //MathMin(0.1,0.02*nvGetBalance()/_initialBalance);
    _basket.enter(otype,lot);
  }
};
