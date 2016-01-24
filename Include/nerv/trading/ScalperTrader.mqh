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
  double _psize;

public:
  /*
    Class constructor.
  */
  nvScalperTrader(string symbol, ENUM_TIMEFRAMES period = PERIOD_M1)
    : nvSecurityTrader(symbol), _period(period)
  {
    logDEBUG("Creating ScalperTrader")
    _ticket = -1;
    _psize = nvGetPointSize(_symbol);
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
    if(!nvIsPositionClosed(_ticket))
    {
      // Already in a position, so we keep it;
      return;
    }

    datetime ctime = TimeCurrent();
    MqlDateTime dts;
    TimeToStruct(ctime,dts);

    bool tok = dts.hour >= 7 && dts.hour <= 21;
    if(!tok) {
      // Do not trade at that time:
      return;
    }

    // Check the entry conditions:
    double sma377 = iMA(_symbol,_period,377,0,MODE_SMMA,PRICE_CLOSE,0);
    double sma55 = iMA(_symbol,_period,55,0,MODE_SMMA,PRICE_CLOSE,0);

    double dev = 2.5;
    double btop = iBands(_symbol,_period,20,dev,0,PRICE_CLOSE,MODE_UPPER,0);
    double bdown = iBands(_symbol,_period,20,dev,0,PRICE_CLOSE,MODE_LOWER,0);

    double rsi = iRSI(_symbol,_period,14,PRICE_CLOSE,0);

    double sto = iStochastic(_symbol,_period,5,3,3,MODE_SMA,0,MODE_MAIN,0);

    double bid = nvGetBid(_symbol);

    // Check sell conditions: 
    bool s1 = sma55 < sma377;
    bool s2 = bid > btop;
    bool s3 = rsi > 65.0;
    bool s4 = sto > 80.0;

    double sl = 4.0;
    double tp = 30.0;

    if(s1 && s2 && s3 && s4)
    {
      _ticket = nvOpenPosition(_symbol,OP_SELL,0.01,bid+sl*10.0*_psize,bid-tp*10.0*_psize);
    }

    // check buy conditions:
    bool b1 = sma55 > sma377;
    bool b2 = bid < bdown;
    bool b3 = rsi < 30.0;
    bool b4 = sto < 20.0;

    if(b1 && b2 && b3 && b4)
    {
      _ticket = nvOpenPosition(_symbol,OP_BUY,0.01,bid-sl*10.0*_psize,bid+tp*10.0*_psize);
    }
  }
};
