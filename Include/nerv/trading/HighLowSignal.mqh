#include <nerv/core.mqh>
#include <nerv/utils.mqh>
#include <nerv/core/Object.mqh>

/*
Class: nvHighLowSignal
*/
class nvHighLowSignal : public nvObject {
protected:
  // symbol name
  string _symbol;
  ENUM_TIMEFRAMES _period;

  datetime _lastTime;
  int _dur;

  // Number of sessions:
  int _nsessions;

  // cached signal value:
  double _signal;

  MqlRates _highs[];
  MqlRates _lows[];

public:
  /*
    Class constructor.
  */
  nvHighLowSignal(string symbol, ENUM_TIMEFRAMES period, int nsessions)
    : _symbol(symbol), _period(period)
  {
    logDEBUG("Creating HighLowSignal with period "<< EnumToString(period));

    _nsessions = nsessions;

    _lastTime = 0;
    _dur = nvGetPeriodDuration(period);
    _signal = 0.0;
  }

  /*
    Class destructor.
  */
  ~nvHighLowSignal()
  {
    logDEBUG("Deleting HighLowSignal")
  }

  // Get the current heiken ashi signal:
  double getSignal()
  {
    datetime ctime = TimeCurrent();
    if((ctime - _lastTime)<_dur) {
      return _signal;
    }

    // retrieve the previous bars:
    MqlRates rates[];
    CHECK_RET(CopyRates(_symbol,_period,0,_nsessions,rates)==_nsessions,false,"Cannot copy the rates.");
    ArraySetAsSeries( rates, true );

    _lastTime = rates[0].time;
    logDEBUG("Updating HighLowSignal at time: "<<(string)_lastTime);

    // find the most recent high and low bar indices:
    _highIdx = 0;
    _highValue = MathMax(rates[0].close,rates[0].open);
    _lowIdx = 0;
    _lowValue = MathMin(rates[0].close,rates[0].open);
    
    for(int i=1;i<_nsessions;++i)
    {
      double rmin = MathMin(rates[i].close,rates[i].open);
      double rmax = MathMax(rates[i].close,rates[i].open);

      if(rmax>_highValue)
      {
        _highValue = rmax;
        _highIdx = i;
      }
      if(rmin <_lowValue)
      {
        _lowValue = rmin;
        _lowIdx = i;
      }
    }

    // reset the signal:
    _signal = 0.0;

    // The previous bar contains the highest value in the window
    // and it was bullish, and the next bar is bearish:
    if(_highIdx==2 
        && rates[2].open < rates[2].close
        && rates[1].open > rates[1].close)
    {
      // we should sell in that case:
      _signal = -1.0;
    }

    // The previous bar contains the lowest value in the window
    // and it was bearish, and the next bar is bullish:
    if(_lowIdx==2 
        && rates[2].open > rates[2].close
        && rates[1].open < rates[1].close)
    {
      // we should buy in that case:
      _signal = 1.0;
    }

    return _signal;    
  }
};
