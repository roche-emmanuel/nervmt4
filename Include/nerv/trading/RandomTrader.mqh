#include <nerv/core.mqh>
#include <nerv/trading/SecurityTrader.mqh>
#include <nerv/math/SimpleRNG.mqh>

/*
Class: nvRandomTrader

Base class representing a trader 
*/
class nvRandomTrader : public nvSecurityTrader {
protected:
  int _ticket;

  // Random generator:
  SimpleRNG rnd;
  datetime _lastTime;
  int _delay;

public:
  /*
    Class constructor.
  */
  nvRandomTrader(string symbol)
    : nvSecurityTrader(symbol)
  {
    logDEBUG("Creating RandomTrader")
    _ticket = -1;
    
    // rnd.SetSeedFromSystemTime();
    rnd.SetSeed(123);

    _lastTime = 0;
    _delay = 120 + 3600*rnd.GetUniform();
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
    datetime ctime = TimeCurrent();
    if((ctime-_lastTime)<_delay)
      return;

    _delay = 120 + 3600*rnd.GetUniform();
    _lastTime = ctime;

    // Close th current position if any:
    if(_ticket>=0)
    {
      closePosition(_ticket);
    }

    // if we are not in a position, we open a new one randomly:
    int otype = (rnd.GetUniform()-0.5) > 0 ? OP_BUY : OP_SELL;
    _ticket = openPosition(otype,0.01);
  }
};
