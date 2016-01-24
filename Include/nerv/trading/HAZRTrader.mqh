#include <nerv/core.mqh>
#include <nerv/trading/SecurityTrader.mqh>
#include <nerv/trading/ALRBasket.mqh>
#include <nerv/trading/HASignal.mqh>
#include <nerv/trading/MASlopeSignal.mqh>
#include <nerv/trading/RangeSignal.mqh>

/*
Class: nvHAZRTrader

Base class representing a trader 
*/
class nvHAZRTrader : public nvSecurityTrader {
protected:
  nvALRBasket* _basket;
  nvHASignal* _pHA;
  nvMASlopeSignal* _maSlope;
  nvRangeSignal* _entryRanges[];

  // list of current open position:
  int _tickets[];
  double _stopLoss;

  double _maxRange;
  double _trail;
  bool _needAveraging;
  double _entryPrice;
  int _averagingCount;
  double _volatility;
  double _lotSize;

  ENUM_TIMEFRAMES _atrPeriod;
  ENUM_TIMEFRAMES _maPeriod;
  int _sigLevel;

public:
  /*
    Class constructor.
  */
  nvHAZRTrader(string symbol, 
    ENUM_TIMEFRAMES phaPeriod = PERIOD_D1,
    ENUM_TIMEFRAMES maPeriod = PERIOD_H1,
    ENUM_TIMEFRAMES atrPeriod = PERIOD_H4)
    : nvSecurityTrader(symbol)
  {
    logDEBUG("Creating HAZRTrader")  
    _maxRange = 50.0*nvGetPointSize(_symbol);
    _maPeriod = maPeriod;

    _basket = new nvALRBasket(_symbol);
    _basket.setZoneWidth(_maxRange);
    //_basket.setBreakEvenWidth(3.0*_maxRange);
    _basket.setProfitWidth(0.1*_maxRange);
    _basket.setWarningLevel(5);
    _basket.setStopLevel(8);

    _pHA = new nvHASignal(symbol,phaPeriod);
    _maSlope = new nvMASlopeSignal(symbol,maPeriod, 500, 5);
    
    int rcount = 2;
    ArrayResize(_entryRanges,rcount);
    for(int i=0;i<rcount;++i)
    {
      _entryRanges[i] = new nvRangeSignal(_symbol,20.0 + i*20.0);  
    }
    
    _sigLevel = 0;
    _stopLoss = 0.0;
    _trail = 0.0;
    _atrPeriod = atrPeriod;
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
    int len = ArraySize(_entryRanges);
    for(int i=0;i<len;++i)
    {
      RELEASE_PTR(_entryRanges[i]);
    }
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

  // Retrieve the number of open positions:
  int getNumPositions()
  {
    return ArraySize(_tickets);
  }

  // Check if we current have a position:
  bool hasPositions()
  {
    return getNumPositions()>0;
  }

  // Check if we are in a long position:
  bool isLong()
  {
    if(hasPositions())
    {
      return nvGetPositionType(_tickets[0])==OP_BUY;
    }
    return false;
  }

  // Check if we are in a short position:
  bool isShort()
  {
    if(hasPositions())
    {
      return nvGetPositionType(_tickets[0])==OP_SELL;
    }
    return false;
  }

  // Retrieve the current profit for all opened positions:
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

  // retrieve the current entry signal:
  double getEntrySignal()
  {
    return _entryRanges[0].getSignal();
  }

  double getSubSignal()
  {
    int len = ArraySize(_entryRanges);
    if(_sigLevel>=len)
      return 0.0; // No more possibility.

    CHECK_RET(_sigLevel>=0,0.0,"Invalid sig level")

    if(_averagingCount==5)
    {
      return 0.0;
    }

    CHECK_RET(hasPositions(),0.0,"Should have a position here.")

    double sig = _entryRanges[_sigLevel].getSignal();
    if((isLong() && sig>0.0) || (isShort() && sig<0.0))
    {
      logDEBUG("Signaling sub signal "<<_sigLevel)
      _sigLevel++;
      return sig;
    }

    return 0.0;
  }

  void startTrailingStop(double trail)
  {
    if(_stopLoss>0.0)
    {
      return; // already trailing stop.
    }

    CHECK(hasPositions(),"Cannot start trail stop with no positions.")

    _trail = trail;
    _stopLoss = nvGetBid(_symbol) + (isLong() ? -_trail : _trail);
  }

  // Check where the price is compared to the stop loss:
  void checkTrailingStop()
  {
    if(_stopLoss==0.0)
      return; // nothing to check.

    CHECK(hasPositions(),"Cannot check stop loss with no positions.")

    double bid = nvGetBid(_symbol);
    if((isLong() && bid<=_stopLoss) || (isShort() && bid>=_stopLoss))
    {
      // Close all the current positions:
      closePositions();
    }
    else {
      double nsl = bid + (isLong() ? -_trail : _trail);
      if(isLong() && nsl > _stopLoss)
      {
        _stopLoss = nsl;
      }
      if(isShort() && nsl < _stopLoss)
      {
        _stopLoss = nsl;
      }
    }
  }

  void checkLongPositions(double bid, double esig, double profit)
  {
    // the entry signal is inverted, and we already have
    // some positive profit:
    if(esig < 0.0)
    {
      if(profit>0.0)
      {
        // In that case we start trailing stop:
        startTrailingStop(nvGetSpread(_symbol));        
      }
      else
      {
        // If we are not in profit, then we need to check if we can improve 
        // our position:
        _needAveraging = true;
      }
    }

    if(esig > 0.0 && _needAveraging && profit <= 0.0
       && (_entryPrice - bid)> _averagingCount*_volatility/5.0)
    {
      performCostAveraging();
    }

    if(getSubSignal()>0.0) {
      logDEBUG("Performing dollar cost averaging for sub signal")
      performCostAveraging(_sigLevel/3.0);
    }

    // Check if we need to enter into recovery mode:
    if(_entryPrice-bid >= _volatility)
    {
      _basket.enter(OP_SELL,_tickets);

      // Now we should remove the current tickets as the
      // basket will take ownership of these:
      ArrayResize(_tickets,0);
    }
  }

  void checkShortPositions(double bid, double esig, double profit)
  {
    // the entry signal is inverted, and we already have
    // some positive profit:
    if(esig > 0.0)
    {
      if(profit>0.0)
      {
        // In that case we start trailing stop:
        startTrailingStop(nvGetSpread(_symbol));        
      }
      else
      {
        // If we are not in profit, then we need to check if we can improve 
        // our position:
        _needAveraging = true;
      }
    }

    if(esig < 0.0 && _needAveraging && profit <= 0.0
       && (bid - _entryPrice)> _averagingCount*_volatility/5.0)
    {
      performCostAveraging();
    }

    if(getSubSignal()<0.0) {
      logDEBUG("Performing dollar cost averaging for sub signal")
      performCostAveraging(_sigLevel/3.0);
    }

    // Check if we need to enter into recovery mode:
    if(bid-_entryPrice >= _volatility)
    {
      _basket.enter(OP_BUY,_tickets);

      // Now we should remove the current tickets as the
      // basket will take ownership of these:
      ArrayResize(_tickets,0);
    }

  }

  /*
  Function: getPriceIndication
  
  Check what is the current price position with respect to the Moving
  Average, will return 1.0 if we are above the MA or -1 if we are under it
  */
  double getPriceIndication()
  {
    double ma = iMA(_symbol,_maPeriod,20,0,MODE_EMA,PRICE_CLOSE,1);

    MqlTick latest_price;
    CHECK_RET(SymbolInfoTick(_symbol,latest_price),0.0,"Cannot retrieve latest price.")

    return latest_price.bid - ma > 0 ? 1.0 : -1.0;
  }

  virtual void onTick()
  {
    _basket.update();

    if(_basket.isRunning())
    {
      // Wait for the basket to complete:
      return;
    }

    // Check the current stop loss status:
    checkTrailingStop();

    double bid = nvGetBid(_symbol);

    double pdir = getPrimaryDirection();
    double trend = getMarketTrend();
    double esig = getEntrySignal();
    double pind = getPriceIndication();

    if(hasPositions())
    {
      // We already have opened positions,
      // So we check how we handle them:
      double profit = getCurrentProfit();

      if(isLong())
      {
        // logDEBUG("Checking long positions with bid="<<bid<<", esig="<<esig<<", profit="<<profit)
        checkLongPositions(bid,esig,profit);
      }
      else
      {
        // logDEBUG("Checking short positions with bid="<<bid<<", esig="<<esig<<", profit="<<profit)
        checkShortPositions(bid,esig,profit); 
      }
    }
    else
    {
      // We are not in a position yet, so check if we should enter:
      double vol = getVolatilityRange();

      if(pdir>0.0 && trend > 0.3 && pind>0.0 && esig>0.0)
      {
        // place a buy order:
        logDEBUG("Opening Long position with vol="<<vol)
        openPosition(OP_BUY,vol);
      }
      
      if(pdir<0.0 && trend < -0.3 && pind<0.0 && esig<0.0)
      {
        // place a sell order:
        logDEBUG("Opening short position with vol="<<vol)
        openPosition(OP_SELL,vol);
      }
    }
  }

protected:
  
  /*
  Function: getVolatilityRange
  
  Retrieve the current volatility range value
  */
  double getVolatilityRange()
  {
    double atr = iATR(_symbol,_atrPeriod,14,1);
    return MathMin(_maxRange,atr);
  }

  void openPosition(int otype, double volatility)
  {
    double totalLot = evaluateLotSize(volatility/nvGetPointSize(_symbol),1.0);
    double lot = nvNormalizeVolume(totalLot/5.0,_symbol);

    CHECK(_stopLoss==0.0,"Should not open a position when we have a stop loss set.")

    // if(lot<0.01) {
    //   logDEBUG("Detected too small lot size: "<<lot)
    //   lot = 0.01;
    // }
    // force a lot size of 0.02 for now:
    // lot = 0.02;
    lot = 0.1;

    _sigLevel = 0;
    _volatility = volatility;
    _entryPrice = otype==OP_BUY ? nvGetAsk(_symbol) : nvGetBid(_symbol);
    _lotSize = lot;

    logDEBUG(TimeCurrent() << ": Entry price: " << _entryPrice << ", lot="<<lot)

    // reset averaging count:
    _averagingCount = 1;

    int ticket = nvOpenPosition(_symbol, otype, lot);
    CHECK(ticket>=0,"Invalid ticket.")
    nvAppendArrayElement(_tickets,ticket);
  }

  // Close all the currently opened positions:
  void closePositions()
  {
    int len = ArraySize(_tickets);
    for(int i = 0; i<len; ++i)
    {
      logDEBUG("Closing ticket "<<_tickets[i])
      nvClosePosition(_tickets[i]);
    }

    _stopLoss = 0.0;
    ArrayResize(_tickets,0);
  }

  /*
  Function: evaluateLotSize
  
  Main method of this class used to evaluate the lot size that should be used for a potential trade.
  */
  double evaluateLotSize(double numLostPoints, double confidence)
  {
    return nvEvaluateLotSize(_symbol, numLostPoints, _riskLevel, _traderWeight, confidence);
  }

  // Perform cost averaging:
  void performCostAveraging(double added = 0.0)
  {
    // Do nothing for now:
    if(true) { //_averagingCount==5) {
      // logDEBUG("Cannot perform dollar cost averaging anymore.")
      return;
    }

    CHECK(hasPositions(),"cost averaging with no open position ??")

    _needAveraging = false;

    // increment the averaging count:
    _averagingCount++;

    logDEBUG(TimeCurrent() << ": Applying dollar cost averaging " << _averagingCount)

    // Add to the currently opened position:
    int otype = isLong() ? OP_BUY : OP_SELL;

    double lot = nvNormalizeVolume((1.0+added)*_lotSize,_symbol);

    int ticket = nvOpenPosition(_symbol, otype, lot);
    CHECK(ticket>=0,"Invalid ticket.")
    nvAppendArrayElement(_tickets,ticket);
  }
};
