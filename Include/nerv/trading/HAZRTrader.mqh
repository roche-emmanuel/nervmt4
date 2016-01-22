#include <nerv/core.mqh>
#include <nerv/trading/SecurityTrader.mqh>
#include <nerv/trading/ALRBasket.mqh>
#include <nerv/trading/HASignal.mqh>
#include <nerv/math/SimpleRNG.mqh>

/*
Class: nvHAZRTrader

Base class representing a trader 
*/
class nvHAZRTrader : public nvSecurityTrader {
protected:
  nvALRBasket* _basket;
  nvHASignal* _pHA;

  // Number of MA values kept for statistics:
  int _maCount;
  double _maVals[];
  ENUM_TIMEFRAMES _maPeriod;
  double _maSlopes[];
  int _fastMACount;
  double _fastMASlopes[];
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

    _maPeriod = maPeriod;
    _maCount = 500;
    _fastMACount = 5;
    ArrayResize(_maVals, _maCount);
    ArrayResize(_maSlopes, _maCount-1);
    ArrayResize(_fastMASlopes, _fastMACount);
  }

  /*
    Class destructor.
  */
  ~nvHAZRTrader()
  {
    logDEBUG("Deleting HAZRTrader")
    RELEASE_PTR(_basket);
    RELEASE_PTR(_pHA);
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
    int i;
    
    for(i=0;i<_maCount;++i)
    {
      _maVals[i] = iMA(_symbol,_maPeriod,20,0,MODE_EMA,PRICE_CLOSE,1+i);
    }

    // Prepare the slope array:
    for(i=0;i<(_maCount-1);++i)
    {
      // Keep in mind that the EMA array is accessed as time serie:
      _maSlopes[i] = _maVals[i] - _maVals[i+1];
    }

    // compute the mean and devs of the slope:
    double slopeMean = nvGetMeanEstimate(_maSlopes);
    double slopeDev = nvGetStdDevEstimate(_maSlopes);

    // Now we consider only the slope mean from the previous n timeframes:
    for(i=0;i<_fastMACount;++i)
    {
      _fastMASlopes[i] = _maSlopes[i];
    }

    double slope = nvGetMeanEstimate(_fastMASlopes);
    
    // Normalize the slope value:
    slope = (slope - slopeMean)/slopeDev;

    //  Take sigmoid to stay in the range [-1,1]:
    return (nvSigmoid(slope)-0.5)*2.0;  
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
