#include <nerv/core.mqh>

// Retrieve a period duration in number of Seconds
int nvGetPeriodDuration(ENUM_TIMEFRAMES period)
{
  switch (period)
  {
  case PERIOD_M1: return 60;
  case PERIOD_M2: return 60 * 2;
  case PERIOD_M3: return 60 * 3;
  case PERIOD_M4: return 60 * 4;
  case PERIOD_M5: return 60 * 5;
  case PERIOD_M6: return 60 * 6;
  case PERIOD_M10: return 60 * 10;
  case PERIOD_M12: return 60 * 12;
  case PERIOD_M15: return 60 * 15;
  case PERIOD_M20: return 60 * 20;
  case PERIOD_M30: return 60 * 30;
  case PERIOD_H1: return 3600;
  case PERIOD_H2: return 3600 * 2;
  case PERIOD_H3: return 3600 * 3;
  case PERIOD_H4: return 3600 * 4;
  case PERIOD_H6: return 3600 * 6;
  case PERIOD_H8: return 3600 * 8;
  case PERIOD_H12: return 3600 * 12;
  case PERIOD_D1: return 3600 * 24;
  case PERIOD_W1: return 3600 * 24 * 7; 
  }
 
  THROW("Unsupported period value " << EnumToString(period));
  return 0;
}

// Generic method to append a content to an array:
// Take an optional max size argument, will prevent the array from
// getting bigger that the specified size in that case.
template<typename T>
void nvAppendArrayElement(T &array[], T& val, int maxsize = -1)
{
  int num = ArraySize( array );
  if(maxsize < 0 || num <maxsize)
  {
    ArrayResize( array, num+1 );
    array[num] = val;
  }
  else {
    // T old = array[0];
    CHECK(ArrayCopy( array, array, 0, 1, num-1 )==num-1,"Invalid result for array copy operation");
    array[num-1] = val;
  }
}

double nvGetBid(string symbol)
{
  MqlTick tick;
  CHECK_RET(SymbolInfoTick(symbol,tick),0.0,"Cannot retrieve latest tick for symbol "<<symbol)
  return tick.bid;
}

double nvGetAsk(string symbol)
{
  MqlTick tick;
  CHECK_RET(SymbolInfoTick(symbol,tick),0.0,"Cannot retrieve latest tick for symbol "<<symbol)
  return tick.ask;
}

// Method called to normalize a lot size given its symbol.
double nvNormalizeVolume(double lot, string symbol)
{
  double maxlot = SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
  double step = SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
  lot = MathFloor( lot/step ) * step;
  return MathMin(maxlot,lot);
}

// Method used to send an order:
int nvOpenPosition(string symbol, int otype, double lot, 
  double sl = 0.0, double tp = 0.0, double price = 0.0, 
  int slippage = 0)
{
  if(price==0.0)
  {
    // Use the current market bid or ask price:
    price = otype==OP_BUY ? nvGetAsk(symbol) : nvGetBid(symbol);
  }

  int numd = (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);

  price = NormalizeDouble(price,numd);
  sl = NormalizeDouble(sl,numd);
  tp = NormalizeDouble(tp,numd);
  lot = nvNormalizeVolume(lot,symbol);

  int ticket = OrderSend(symbol,otype,lot,price,slippage,sl,tp);
  if(ticket<0)
  {
    int errno = GetLastError();
    logERROR("OpenPosition produced error code: "<<errno<<"("<<ErrorDescription(errno)<<")");
  }

  return ticket;
}

// Retrieve the tiket order type:
int nvGetPositionType(int ticket)
{
  if(OrderSelect(ticket,SELECT_BY_TICKET))
  {
    return OrderType();
  }

  return -1;
}

// Method used to close an order:
bool nvClosePosition(int ticket, double lot = 0.0, double price = 0.0, int slippage = 0)
{
  if(!OrderSelect(ticket,SELECT_BY_TICKET))
  {
    logDEBUG("Cannot close ticket "<<ticket)
    return false;
  }

  if(lot == 0.0)
  {
    lot = OrderLots();
  }

  if(price == 0.0)
  {
    int otype = OrderType();
    string symbol = OrderSymbol();
    price = otype==OP_BUY ? nvGetBid(symbol) : nvGetAsk(symbol);    
  }

  bool res = OrderClose(ticket,lot,price,slippage,Red);
  if(!res)
  {
    int errno = GetLastError();
    logERROR("ClosePosition produced error code: "<<errno<<"("<<ErrorDescription(errno)<<")");    
  }
  return res;
}

// Retrieve the point size for a given symbol:
double nvGetPointSize(string symbol)
{
  return SymbolInfoDouble(symbol,SYMBOL_POINT);
}
