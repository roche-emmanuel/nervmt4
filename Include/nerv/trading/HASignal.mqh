#include <nerv/core.mqh>
#include <nerv/utils.mqh>
#include <nerv/core/Object.mqh>

/*
Class: nvHASignal

Class representing an ALZ backet capable of managing hedge trades
*/
class nvHASignal : public nvObject {
protected:
  // symbol name
  string _symbol;
  ENUM_TIMEFRAMES _period;

  datetime _lastTime;
  int _dur;

  // cached signal value:
  double _signal;
public:
  /*
    Class constructor.
  */
  nvHASignal(string symbol, ENUM_TIMEFRAMES period)
    : _symbol(symbol), _period(period)
  {
    logDEBUG("Creating HASignal with period "<< EnumToString(period));

    _lastTime = 0;
    _dur = nvGetPeriodDuration(period);
    _signal = 0.0;

    // _handle = iCustom(symbol,period,"nerv\\HADir",0,1);
    // CHECK(_handle>=0,"Invalid Heiken Ashi direction handle");
  }

  /*
    Class destructor.
  */
  ~nvHASignal()
  {
    logDEBUG("Deleting HASignal")
  }

  // Get the current heiken ashi signal:
  double getSignal(int mean = 1)
  {
    datetime ctime = TimeCurrent();
    if((ctime - _lastTime)<_dur) {
      return _signal;
    }
    _lastTime = ctime;

    CHECK_RET(mean>=1,0.0,"Invalid mean value: "<<mean)

    double vals[];
    ArrayResize(vals,mean);

    for(int i = 0;i<mean; ++i)
    {
      vals[i] = iCustom(_symbol,_period,"nerv\\HADir",0,1+i);
    }

    double sig = nvGetMeanEstimate(vals);
    sig = (sig-0.5)*2.0;

    if((sig < 0.0 && vals[0]==1.0) || (sig>0.0 && vals[0]==0.0))
      sig = 0.0;

    _signal = sig;  
    return _signal;    
  }
};
