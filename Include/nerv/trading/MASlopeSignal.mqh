#include <nerv/core.mqh>
#include <nerv/utils.mqh>
#include <nerv/core/Object.mqh>

/*
Class: nvMASlopeSignal
*/
class nvMASlopeSignal : public nvObject {
protected:
  // symbol name
  string _symbol;
  ENUM_TIMEFRAMES _period;

  datetime _lastTime;
  int _dur;

  // cached signal value:
  double _signal;

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
  nvMASlopeSignal(string symbol, ENUM_TIMEFRAMES period, 
    int statCount, int fastCount)
    : _symbol(symbol), _period(period)
  {
    logDEBUG("Creating HASignal with period "<< EnumToString(period));

    _lastTime = 0;
    _dur = nvGetPeriodDuration(period);
    _signal = 0.0;

    _maPeriod = period;
    _maCount = statCount;
    _fastMACount = fastCount;

    ArrayResize(_maVals, _maCount);
    ArrayResize(_maSlopes, _maCount-1);
    ArrayResize(_fastMASlopes, _fastMACount);
  }

  /*
    Class destructor.
  */
  ~nvMASlopeSignal()
  {
    logDEBUG("Deleting HASignal")
  }

  // Get the current slope signal
  double getSignal()
  {
    datetime ctime = TimeCurrent();
    if((ctime - _lastTime)<_dur) {
      return _signal;
    }
    _lastTime = ctime;

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
    _signal = (nvSigmoid(slope)-0.5)*2.0;  
    return _signal;    
  }
};
