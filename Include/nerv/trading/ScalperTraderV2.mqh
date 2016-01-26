#include <nerv/core.mqh>
#include <nerv/trading/SecurityTrader.mqh>
#include <nerv/trading/HighLowSignal.mqh>

/*
Class: nvScalperTraderV2

Base class representing a trader 
*/
class nvScalperTraderV2 : public nvSecurityTrader {
protected:
  int _ticket;
  ENUM_TIMEFRAMES _period;

  datetime _lastTime;
  int _dur;

  nvHighLowSignal* _hl;
  
public:
  /*
    Class constructor.
  */
  nvScalperTraderV2(string symbol, ENUM_TIMEFRAMES period = PERIOD_M5)
    : nvSecurityTrader(symbol), _period(period)
  {
    logDEBUG("Creating ScalperTrader")
    _ticket = -1;
    
    _dur = nvGetPeriodDuration(period);
    _lastTime = 0;

    _hl = new nvHighLowSignal(symbol,period,25);
  }

  /*
    Class destructor.
  */
  ~nvScalperTraderV2()
  {
    logDEBUG("Deleting ScalperTrader")
    RELEASE_PTR(_hl);
  }

  virtual void update(datetime ctime)
  {

  }
  
  virtual void onTick()
  {
    if(nvIsPosRunning(_ticket))
    {
      // Just wait for completion.
      return;
    }

    double sig = _hl.getSignal();
    double sl = 20*_psize;
    double tp = 10*_psize;
    double lot = 0.1;

    if(sig>0.0)
    {
      logDEBUG("Entering LONG position.");
      _ticket = nvOpenPosition(_symbol,OP_BUY,lot,sl,tp);
    }

    if(sig<0.0)
    {
      logDEBUG("Entering SHORT position.");
      _ticket = nvOpenPosition(_symbol,OP_SELL,lot,sl,tp);
    }
  }
};
