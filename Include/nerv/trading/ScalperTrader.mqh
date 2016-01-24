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
  int _dur;
  datetime _lastTime;
  int _maxDuration;

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
    _dur = nvGetPeriodDuration(period);
    _lastTime = 0;
    _maxDuration = 3600.0*24.0;
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
    datetime ctime = TimeCurrent();
    MqlDateTime dts;
    TimeToStruct(ctime,dts);

    if(!nvIsPositionClosed(_ticket))
    {
      // Close the position if it is too old:
      datetime otime = OrderOpenTime();
      double profit = OrderProfit();
      if((ctime - otime) > _maxDuration)
      {
        nvClosePosition(_ticket);
      }

      // Do not keep a position at the end of the week:
      // if(dts.day_of_week==5 && dts.hour==22)
      // {
      //   logDEBUG("Closing position at end of week.")
      //   nvClosePosition(_ticket);
      // }

      // Already in a position, so we keep it;
      return;
    }


    if((ctime - _lastTime)<_dur)
    {
      return;
    }

    _lastTime = ctime;

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

    // double sl = 1200.0;
    double tp = 5.0;

    if(s1 && s2 && s3 && s4)
    {
      logDEBUG("Entering SELL with bid="<<bid<<", btop="<<btop<<", rsi="<<rsi<<", sto="<<sto<<", sma55="<<sma55<<", sma377="<<sma377);
      // _ticket = nvOpenPosition(_symbol,OP_SELL,0.1,bid+sl*10.0*_psize,bid-tp*10.0*_psize);
      _ticket = nvOpenPosition(_symbol,OP_SELL,0.1,0.0,bid-tp*10.0*_psize);
      // _ticket = nvOpenPosition(_symbol,OP_BUY,0.1,0.0,bid+tp*10.0*_psize);
    }

    // check buy conditions:
    bool b1 = sma55 > sma377;
    bool b2 = bid < bdown;
    bool b3 = rsi < 30.0;
    bool b4 = sto < 20.0;

    if(b1 && b2 && b3 && b4)
    {
      logDEBUG("Entering BUY with bid="<<bid<<", bdown="<<bdown<<", rsi="<<rsi<<", sto="<<sto<<", sma55="<<sma55<<", sma377="<<sma377);
      // _ticket = nvOpenPosition(_symbol,OP_BUY,0.1,bid-sl*10.0*_psize,bid+tp*10.0*_psize);
      _ticket = nvOpenPosition(_symbol,OP_BUY,0.1,0.0,bid+tp*10.0*_psize);
      // _ticket = nvOpenPosition(_symbol,OP_SELL,0.1,0.0,bid-tp*10.0*_psize);
    }
  }
};
