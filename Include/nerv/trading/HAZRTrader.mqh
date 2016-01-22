#include <nerv/core.mqh>
#include <nerv/trading/SecurityTrader.mqh>
#include <nerv/trading/ALRBasket.mqh>
#include <nerv/trading/HASignal.mqh>
#include <nerv/trading/MASlopeSignal.mqh>

/*
Class: nvHAZRTrader

Base class representing a trader 
*/
class nvHAZRTrader : public nvSecurityTrader {
protected:
  nvALRBasket* _basket;
  nvHASignal* _pHA;
  nvMASlopeSignal* _maSlope;

public:
  /*
    Class constructor.
  */
  nvHAZRTrader(string symbol, 
    ENUM_TIMEFRAMES phaPeriod = PERIOD_D1,
    ENUM_TIMEFRAMES maPeriod = PERIOD_H1)
    : nvSecurityTrader(symbol)
  {
    logDEBUG("Creating HAZRTrader")    
    _basket = new nvALRBasket(_symbol);
    _pHA = new nvHASignal(symbol,phaPeriod);
    _maSlope = new nvMASlopeSignal(symbol,maPeriod, 500, 5);
  }

  /*
    Class destructor.
  */
  ~nvHAZRTrader()
  {
    logDEBUG("Deleting HAZRTrader")
    RELEASE_PTR(_basket);
    RELEASE_PTR(_pHA);
    RELEASE_PTR(_maSlope);
  }

  virtual void update(datetime ctime)
  {

  }
  
  /*
  Function: getPrimaryDirection
  
  Retrieve the primary direction of the market
  */
  double getPrimaryDirection()
  {
    return _pHA.getSignal(1);
  }

  /*
  Function: getMarketTrend
  
  Retrieve the current market trend as a normalized value
  basically between [-6,6], but because of the sigmoid transformation
  we get into the range (-1,1)
  */
  double getMarketTrend()
  {
    return _maSlope.getSignal();
  }

  virtual void onTick()
  {
    _basket.update();

    if(_basket.isRunning())
    {
      // Wait for the basket to complete:
      return;
    }

    // Just get the primary direction:
    double pdir = getPrimaryDirection();
    double trend = getMarketTrend();
    double lot = 0.02;

    if(pdir>0.0 && trend > 0.3)
    {
      // place a buy order:
      _basket.enter(OP_BUY,lot);
    }
    
    if(pdir<0.0 && trend < -0.3)
    {
      // place a sell order:
      _basket.enter(OP_SELL,lot);
    }
  }
};
