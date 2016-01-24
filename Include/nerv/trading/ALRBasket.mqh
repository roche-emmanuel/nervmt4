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
  double _posBreakEvenWidth;
  double _negBreakEvenWidth;
  double _profitWidth;
  double _trailStep;

  double _zoneHigh;
  double _zoneLow;

  double _longLots[];
  double _longEntries[];

  double _shortLots[];
  double _shortEntries[];

  double _stopLoss;

  int _currentSide;

  int _warningLevel;
  int _stopLevel;

  int _numBounce;

  // Number of positive points we should reach before the 
  // trailing stop loss system kicks in:
  double _breakEvenPoints;

  // Current entry of this basket:
  double _entryPrice;

  // slippage value:
  int _slippage;

  // force take profit value:
  double _forceTakeProfit;

  // specify the target profit drift
  double _takeProfitDrift;

  // Type of entry for this basket:
  int _entryType;
   
  double _buyTarget;
  double _sellTarget;

  double _takeProfitOffset;

  double _takeProfitDecay;
  int _decayLevel;

public:
  /*
    Class constructor.
  */
  nvALRBasket(string symbol)
    : _symbol(symbol)
  {
    logDEBUG("Creating ALRBasket")
    double psize = nvGetPointSize(_symbol);
    
    setZoneWidth(500.0*psize);
    setPositiveBreakEvenWidth(2000.0*psize);
    setNegativeBreakEvenWidth(1500.0*psize);
    setProfitWidth(0.0*psize);
    setTakeProfitOffset(50.0*psize);
    setWarningLevel(0);
    setStopLevel(20);

    setDecayLevel(8);
    setTakeProfitDecay(50.0*psize);

    setBreakEvenPoints(250.0*psize);
    setTrailStep(50.0*psize);
    setSlippage(30);
    setTakeProfitDrift(50.0*psize);

    setForceTakeProfit(25.0);

    _currentSide = -1;
    _numBounce = 0;
    _zoneLow = 0.0;
    _zoneHigh = 0.0;
    _stopLoss = 0.0;
    _buyTarget = 0.0;
    _sellTarget = 0.0;
  }

  /*
    Class destructor.
  */
  ~nvALRBasket()
  {
    logDEBUG("Deleting ALRBasket")
  }
  
  void setDecayLevel(int level)
  {
    _decayLevel = level;
  }

  void setTakeProfitDecay(double val)
  {
    _takeProfitDecay = val;
  }

  // Set the slippage value:
  void setSlippage(int val)
  {
    _slippage = val;
  }

  void setTakeProfitOffset(double val)
  {
    _takeProfitOffset = val;
  }

  // Specify the take profit drift:
  void setTakeProfitDrift(double points)
  {
    _takeProfitDrift = points;
  }

  // Set the profit on which we just close this basket:
  void setForceTakeProfit(double profit)
  {
    _forceTakeProfit = profit;
  }

  // Set Warning level:
  void setWarningLevel(int level)
  {
    _warningLevel = level;
  }

  // Set the stop level for this basket:
  void setStopLevel(int level)
  {
    _stopLevel = level;
  }

  // Set the zone width in price delta
  void setZoneWidth(double width)
  {
    _zoneWidth = width;
  }

  // Set the positive breakeven width in price delta:
  // "positive" means in the direction of the initial trade
  // for this basket
  void setPositiveBreakEvenWidth(double width)
  {
    _posBreakEvenWidth = width;
  }

  void setNegativeBreakEvenWidth(double width)
  {
    _negBreakEvenWidth = width;
  }

  // Set te profit width in price delta
  void setProfitWidth(double width)
  {
    _profitWidth = width;
  }

  // Set the trail step in number of points:
  void setTrailStep(double points)
  {
    _trailStep = points;
  }

  // Number of points we should reach before the trailing stop
  // kicks in:
  void setBreakEvenPoints(double points)
  {
    _breakEvenPoints = points;
  }

  /*
  Check if this Basket is currently running:
  */
  bool isRunning()
  {
    return getNumPosition()>0;
  }

  // Retrieve the number of positions in this basket:
  int getNumPosition()
  {
    return ArraySize(_tickets);
  }

  // Retrieve the number of bounce for this basket
  int getNumBounce()
  {
    return _numBounce;
  }

  /*
  Enter this basket with a given trade and initial lot size.

  */
  void enter(int otype, double lot)
  {
    CHECK(_numBounce==0,"Cannot enter a running basket.")

    _stopLoss = 0.0;
    _entryPrice = nvGetBid(_symbol);
    _entryType = otype;

    if(otype==OP_BUY) 
    {
      // We are on the top of the zone:
      _zoneHigh = _entryPrice;
      _zoneLow = _zoneHigh - _zoneWidth;
    }
    else
    {
      // We are at the bottom of the zone:
      _zoneLow = _entryPrice;
      _zoneHigh = _zoneLow + _zoneWidth;
    }

    setupTargets();

    openPosition(otype,lot);
  }

  void enter(int otype, int &tickets[])
  {
    int len = ArraySize(tickets);
    for(int i=0;i<len;++i)
    {
      addPosition(tickets[i]);
    }

    _currentSide = otype == OP_BUY ? OP_SELL : OP_BUY;
    _entryType = otype;

    CHECK(_numBounce == 0,"Invalid number of bounce");

    // Compute the appropriate lot size:
    double lot = getNextLotSize();
    logDEBUG("Entering basket with initial lot size="<<lot)
    enter(otype,lot);
  }

  void updateLongState(double bid)
  {
    double vBuyTarget = _buyTarget;
    if(_decayLevel>=0 && _numBounce>_decayLevel)
    {
      vBuyTarget -= (_numBounce-_decayLevel)*_takeProfitDecay;
    }

    if(bid > (_zoneHigh + vBuyTarget))
    {
      // logDEBUG("Closing LONG because bid="<<bid<<">"<<(_zoneHigh+_buyTarget))
      close();
      return;
    }

    if(_stopLoss == 0.0)
    {
      if((_stopLevel>0 && _numBounce>=_stopLevel)
         || (_numBounce==1 && bid >= (_zoneHigh+_breakEvenPoints)))
      {
        // Initialize the stop loss:
        _stopLoss = bid - _breakEvenPoints;      
      }
    }

    // check if we already have a stop lost:
    if(_stopLoss>0.0)
    {
      if(bid<=_stopLoss) {
        // close this basket:
        close();
        return;
      }
      else if ((bid-_breakEvenPoints) > (_stopLoss+_trailStep)) {
        // check if we should update the stop loss:
        _stopLoss += _trailStep;
      }
    }

    // We also need to check if we are going under the zone:
    if(bid<=_zoneLow)
    {
      // flip the current side!
      openPosition(OP_SELL,getNextLotSize());
    }
  }

  void updateShortState(double bid)
  {
    double vSellTarget = _sellTarget;
    if(_decayLevel>=0 && _numBounce>_decayLevel)
    {
      vSellTarget -= (_numBounce-_decayLevel)*_takeProfitDecay;
    }

    if(bid < (_zoneLow - vSellTarget))
    {
      close();
      return;
    }

    if(_stopLoss == 0.0)
    {
      if((_stopLevel>0 && _numBounce>=_stopLevel)
         || (_numBounce==1 && bid < (_zoneLow - _breakEvenPoints)))
      {
        // Initialize the stop loss:
        _stopLoss = bid + _breakEvenPoints; 
      }
    }

    // check if we already have a stop lost:
    if(_stopLoss>0.0)
    {
      if(bid>=_stopLoss) {
        // close this basket:
        close();
        return;
      }
      else if ((bid+_breakEvenPoints) < (_stopLoss-_trailStep)) {
        // check if we should update the stop loss:
        _stopLoss -= _trailStep;
      }
    }

    // We also need to check if we are going under the zone:
    if(bid>=_zoneHigh)
    {
      // flip the current side!
      openPosition(OP_BUY,getNextLotSize());
    }
  }

  virtual void update()
  {
    if(!isRunning())
      return; // nothing to update;

    // Check if we should close due to current force take profit value:
    if(_numBounce>1 && _forceTakeProfit>0.0 && (nvGetEquity() - nvGetBalance()) > _forceTakeProfit)
    {
      close();
      return;
    }

    // Check what is the position of the bid:
    double bid = nvGetBid(_symbol);

    if(_currentSide==OP_BUY)
    {
      updateLongState(bid);
    }
    else 
    {
      updateShortState(bid);
    }
  }

  // Close all the current positions
  void close()
  {    
    int len = ArraySize(_tickets);
    double profit = getCurrentProfit();

    logDEBUG("Closing basked of "<<len<<" positions with profit="<<profit)
    
    // Close the trades in reverse order for a better balance display :-)
    for(int i=0;i<len;++i)
    {
      nvClosePosition(_tickets[len-1-i]);
    }

    ArrayResize(_tickets,0);

    _numBounce = 0;
  }

  // Method used to retrieve the overall profit of the current positions
  // in this basket:
  double getCurrentProfit()
  {
    double profit = 0.0;
    int len = ArraySize(_tickets);
    for(int i=0;i<len;++i)
    {
      profit += nvGetPositionProfit(_tickets[i]);
    }

    return profit;
  }

protected:

  void addPosition(int ticket)
  {
    CHECK(ticket>=0,"Invalid ticket for ALRBasket")
    nvAppendArrayElement(_tickets,ticket);
  }

  // Compute the lotpoint profit for all opened position
  // At a given target price:
  double getPointProfit(double target)
  {
    int len = ArraySize(_tickets);
    double result = 0.0;
    for(int i=0;i<len;++i)
    {
      if(OrderSelect(_tickets[i],SELECT_BY_TICKET))
      {
        if(OrderType()==OP_BUY)
        {
          result += OrderLots()*(target - OrderOpenPrice());
        }
        else
        {
          // When selling we have the also take into account the current
          // spread: The open price was the bid price, but then
          // We buy at the ask price, which we can estimate with the current 
          // mean spread.
          // For the moment we simply use the instant spread:
          double spread = nvGetSpread(_symbol);
          result += OrderLots()*(OrderOpenPrice() - target - spread) ;
        }
      }
    }

    return result;
  }

  // Compute the appropriate next lot size:
  double getNextLotSize()
  {
    // Compute the long and short values:
    double lot = 0.0;
    double target, np, range;

    setupTargets();

    if(_currentSide==OP_BUY)
    {
      // We are about to go short now
      // So the breakEven price will be:
      target = _zoneLow-_sellTarget;
      range = nvGetAsk(_symbol) - target;

      // it could happen that we are jumping out of the recovery band
      // sometimes (during the weekends!)
      // And in that case the profit might still be negative while the range
      // would also be negative...
      if(range <= 0)
      {
        logWARN("Perform zone relocation for SELL.")

        // We can try to relocate the zone so that the current bid price 
        // would correspond to the new zoneLow:
        _zoneLow = nvGetBid(_symbol);
        _zoneHigh = _zoneLow + _zoneWidth;

        // Recompute target and range:
        target = _zoneLow-_sellTarget;
        range = nvGetAsk(_symbol) - target;
      }

      CHECK_RET(range>0.0,0.0,"Detected invalid SELL range: "<<range);

      np = getPointProfit(target);

      // Now compute what is missing to break even:
      CHECK_RET(np <= 0,0.0,"Point profit was positive : "<<np);

      // lot = np/(nvGetBid(_symbol) - target + spread)
      lot = -np/(range-_takeProfitOffset);

      // So check how much we will loose because of the long lots:
      // lost = _longLots * (_zoneWidth+_breakEvenWidth);

      // How much will we get with the shortLots:
      // double win = (_shortLots + lot) * _breakEvenWidth;
      // we want win == lost on the break even line, thus:
      // (_shortLots + lot ) = _longLots * (_zoneWidth+_breakEvenWidth)/_breakEvenWidth
      // and this:
      // lot = _longLots * (_zoneWidth+_breakEvenWidth)/_breakEvenWidth - _shortLots;
    }
    else
    {
      // We are about to go long now
      // So the breakEven price will be:
      target = _zoneHigh+_buyTarget;
      range = target - nvGetAsk(_symbol);

      // it could happen that we are jumping out of the recovery band
      // sometimes (during the weekends!)
      // And in that case the profit might still be negative while the range
      // would also be negative...
      if(range <= 0)
      {
        logWARN("Perform zone relocation for BUY.")

        // We can try to relocate the zone so that the current bid price 
        // would correspond to the new zoneHigh:
        _zoneHigh = nvGetBid(_symbol);
        _zoneLow = _zoneHigh - _zoneWidth;

        // Recompute target and range:
        target = _zoneHigh+_buyTarget;
        range = target - nvGetAsk(_symbol);
      }
      CHECK_RET(range>0.0,0.0,"Detected invalid BUY range: "<<range
        <<", target="<<target
        <<", ask="<<nvGetAsk(_symbol)
        <<", bid="<<nvGetBid(_symbol));

      // Now compute the point profit :
      np = getPointProfit(target);
      // Now compute what is missing to break even:
      CHECK_RET(np <= 0,0.0,"Point profit was positive : "<<np);


      // lot = np/(target - spread - nvGetBid(_symbol));
      // lot = np/(target - (Ask - Bid) - nvGetBid(_symbol));
      lot = -np/(range-_takeProfitOffset);

      // We are going to be long, so we compute the lost due to the short lots:
      // lost = _shortLots * (_zoneWidth + _breakEvenWidth);

      // What we win is:
      // double win = (_longLots + lot) * _breakEvenWidth;
      // On breakeven we want win == lost, and thus:
      // (_longLots + lot) * _breakEvenWidth = _shortLots * (_zoneWidth + _breakEvenWidth);
      // lot = _shortLots * (_zoneWidth+_breakEvenWidth)/_breakEvenWidth - _longLots;
    }

    logDEBUG("Computed next lot size="<<lot<<", np="<<np<<", range="<<range<<" for bounce="<<_numBounce)

    // We need to round the lot value to a ceil:
    double step = SymbolInfoDouble(_symbol,SYMBOL_VOLUME_STEP);
    lot = MathCeil( lot/step ) * step;

    //  return computed value:
    return lot;
  }

  int openPosition(int otype, double lot)
  {
    _currentSide = otype;
    int ticket = nvOpenPosition(_symbol,otype,lot,0.0,0.0,0.0,_slippage);
    if(ticket<0)
    {
      logWARN("Cannot open position with lot="<<lot<<", bounce="<<_numBounce);
      return ticket;
    }

    addPosition(ticket);

    _numBounce++;

    int len = ArraySize(_tickets);
    logDEBUG("Opened basked position " << len<< " with "<<lot<<" lots.")

    return ticket;
  }

  void setupTargets()
  {
    // Update the range target:
    if(_entryType==OP_BUY)
    {
      _buyTarget = _posBreakEvenWidth-_numBounce*_takeProfitDrift;
      _sellTarget = _negBreakEvenWidth-_numBounce*_takeProfitDrift;
    }
    else
    {
      _buyTarget = _negBreakEvenWidth-_numBounce*_takeProfitDrift;
      _sellTarget = _posBreakEvenWidth-_numBounce*_takeProfitDrift;
    }

    logDEBUG("At bounce "<<_numBounce<<": buyTarget="<<_buyTarget<<", sellTarget="<<_sellTarget);
  }  
};
