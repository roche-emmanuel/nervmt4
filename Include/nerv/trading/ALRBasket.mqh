#include <nerv/core.mqh>
#include <nerv/core/Object.mqh>

/*
Class: nvALRBasket

Class representing an ALZ backet capable of managing hedge trades
*/
class nvALRBasket : public nvObject {
protected:
  // Array of opened tickets so far:
  int _tickets[];

  string _symbol;

  double _zoneWidth;
  double _breakEvenWidth;
  double _profitWidth;
  double _trail;

  double _zoneHigh;
  double _zoneLow;

  double _longLots;
  double _shortLots;

  double _stopLoss;

  int _currentSide;

public:
  /*
    Class constructor.
  */
  nvALRBasket(string symbol)
    : _symbol(symbol)
  {
    logDEBUG("Creating ALRBasket")
    setZoneWidth(500.0);
    setBreakEvenWidth(3.0*500.0);
    setProfitWidth(100.0);
    _currentSide = -1;
    _zoneLow = 0.0;
    _zoneHigh = 0.0;
    _longLots = 0.0;
    _shortLots = 0.0;
    _stopLoss = 0.0;
  }

  /*
    Class destructor.
  */
  ~nvALRBasket()
  {
    logDEBUG("Deleting ALRBasket")
  }
  
  // Set the zone width in number of points
  void setZoneWidth(double width)
  {
    _zoneWidth = width*nvGetPointSize(_symbol);
  }

  // Set the breakeven width in number of points:
  void setBreakEvenWidth(double width)
  {
    _breakEvenWidth = width*nvGetPointSize(_symbol);
  }

  // Set te profit width in number of points
  void setProfitWidth(double width)
  {
    _profitWidth = width*nvGetPointSize(_symbol);
    _trail = _profitWidth*0.5;
  }

  /*
  Check if this Basket is currently running:
  */
  bool isRunning()
  {
    return ArraySize(_tickets)>0;
  }

  /*
  Enter this basket with a given trade and initial lot size.

  */
  void enter(int otype, double lot)
  {
    _longLots = 0.0;
    _shortLots = 0.0;
    _stopLoss = 0.0;

    if(otype==OP_BUY) 
    {
      // We are on the top of the zone:
      _zoneHigh = nvGetBid(_symbol);
      _zoneLow = _zoneHigh - _zoneWidth;
    }
    else
    {
      // We are at the bottom of the zone:
      _zoneLow = nvGetBid(_symbol);
      _zoneHigh = _zoneLow + _zoneWidth;
    }

    openPosition(otype,lot);
  }

  virtual void update()
  {
    if(!isRunning())
      return; // nothing to update;

    // Check what is the position of the bid:
    double bid = nvGetBid(_symbol);
    if(_currentSide==OP_BUY)
    {
      if(_stopLoss == 0.0 && bid > (_zoneHigh + _breakEvenWidth + _profitWidth))
      {
        // Initialize the stop loss:
        _stopLoss = bid - _trail;
      }

      // check if we already have a stop lost:
      if(_stopLoss>0.0)
      {
        if(bid<=_stopLoss) {
          // close this basket:
          close();
        }
        else {
          // check if we should update the stop loss:
          _stopLoss = MathMax(_stopLoss,bid - _trail);
        }
      }

      // We also need to check if we are going under the zone:
      if(bid<=_zoneLow)
      {
        // flip the current side!
        openPosition(OP_SELL,getNextLotSize());
      }
    }
    else 
    {
      if(_stopLoss == 0.0 && bid < (_zoneLow - _breakEvenWidth - _profitWidth))
      {
        // Initialize the stop loss:
        _stopLoss = bid + _trail;
      }

      // check if we already have a stop lost:
      if(_stopLoss>0.0)
      {
        if(bid>=_stopLoss) {
          // close this basket:
          close();
        }
        else {
          // check if we should update the stop loss:
          _stopLoss = MathMin(_stopLoss,bid + _trail);
        }
      }

      // We also need to check if we are going under the zone:
      if(bid>=_zoneHigh)
      {
        // flip the current side!
        openPosition(OP_BUY,getNextLotSize());
      }
    }
  }

  // Close all the current positions
  void close()
  {
    int len = ArraySize(_tickets);
    logDEBUG("Closing basked of "<<len<<" positions.")
    
    // Close the trades in reverse order for a better balance display :-)
    for(int i=0;i<len;++i)
    {
      nvClosePosition(_tickets[len-1-i]);
    }

    ArrayResize(_tickets,0);
  }

protected:
  // Compute the appropriate next lot size:
  double getNextLotSize()
  {
    // Compute the long and short values:
    double lot = 0.0;
    
    if(_currentSide==OP_BUY)
    {
      // We are about to go short now
      // So check how much we will loose because of the long lots:
      // lost = _longLots * (_zoneWidth+_breakEvenWidth);

      // How much will we get with the shortLots:
      // double win = (_shortLots + lot) * _breakEvenWidth;
      // we want win == lost on the break even line, thus:
      // (_shortLots + lot ) = _longLots * (_zonWidth+_breakEvenWidth)/_breakEvenWidth
      // and this:
      lot = _longLots * (_zoneWidth+_breakEvenWidth)/_breakEvenWidth - _shortLots;
    }
    else
    {
      // We are going to be long, so we compute the lost due to the short lots:
      // lost = _shortLots * (_zoneWidth + _breakEvenWidth);

      // What we win is:
      // double win = (_longLots + lot) * _breakEvenWidth;
      // On breakeven we want win == lost, and thus:
      // (_longLots + lot) * _breakEvenWidth = _shortLots * (_zoneWidth + _breakEvenWidth);
      lot = _shortLots * (_zoneWidth+_breakEvenWidth)/_breakEvenWidth - _longLots;
    }

    // We need to round the lot value to a ceil:
    double step = SymbolInfoDouble(_symbol,SYMBOL_VOLUME_STEP);
    lot = MathCeil( lot/step ) * step;

    //  return computed value:
    return lot;
  }

  int openPosition(int otype, double lot)
  {
    if(otype==OP_BUY) 
    {
      _longLots += lot;
    }
    else
    {
      _shortLots += lot;
    }

    _currentSide = otype;
    int ticket = nvOpenPosition(_symbol,otype,lot);
    CHECK_RET(ticket>=0,-1,"Invalid ticket for ALRBasket")
    nvAppendArrayElement(_tickets,ticket);

    int len = ArraySize(_tickets);
    logDEBUG("Opened basked position " << len<< " with "<<lot<<" lots.")

    return ticket;
  }  
};
