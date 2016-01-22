#include <nerv/core.mqh>
#include <nerv/utils.mqh>
#include <nerv/core/Object.mqh>

/*
Class: nvRangeSignal
*/
class nvRangeSignal : public nvObject {
protected:
  // symbol name
  string _symbol;

  double _lastPrice;
  double _range; 

public:
  /*
    Class constructor.
  */
  nvRangeSignal(string symbol, double range)
    : _symbol(symbol)
  {
    logDEBUG("Creating Range Signal with range "<< range);

    _lastPrice = 0;
    _range = range*nvGetPointSize(_symbol);
  }

  /*
    Class destructor.
  */
  ~nvRangeSignal()
  {
    logDEBUG("Deleting RangeSignal")
  }

  // Get the current slope signal
  double getSignal()
  {
    double bid = nvGetBid(_symbol);
    if(_lastPrice==0.0) {
      _lastPrice = bid;
      logDEBUG("RangeSignal initial price: "<<_lastPrice)
    }
      

    double delta = (bid - _lastPrice);
    double sig = 0.0;
    
    if(delta>_range)
    {
      sig = 1.0;
      _lastPrice += MathFloor(delta/_range)*_range; 
      // logDEBUG("Sending range signal 1.0 at new price "<<_lastPrice)
    }
    
    if(delta<-_range)
    {
      sig = -1.0;
      _lastPrice -= MathFloor(-delta/_range)*_range;
      // logDEBUG("Sending range signal -1.0 at new price "<<_lastPrice)
    }

    // if(sig==0.0)
    // {
    //   logDEBUG("No range signal.")
    // }
    return sig;
  }
};
