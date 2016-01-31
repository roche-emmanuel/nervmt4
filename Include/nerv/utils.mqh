#include <nerv/core.mqh>

double nvSigmoid(double val, double lambda = 1.0)
{
  return 1.0/(1.0 + MathExp(-lambda*val));
}

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

// Retrieve a given bid price:
double nvGetBidPrice(string symbol, datetime time = 0)
{
  // Retrieve the target time from the manager if needed:
  if(time==0) {
    time = TimeCurrent();
  }

  // If the target time happens to be the server time, then this means we can use the latest tick available
  if(time == TimeCurrent())
  {
    // Use the latest tick data:
    MqlTick last_tick;
    // Note that the following code may fail if we are on the week end,
    // And connected to a server, and we didn't receive anything yet:
    if(SymbolInfoTick(symbol,last_tick)) {
      return last_tick.bid;
    }
    else {
      logWARN("Cannot retrieve the latest tick from server")
    }
  }

  // Fallback implementation:
  // Use the bar history:
  MqlRates rates[];
  CHECK_RET(CopyRates(symbol,PERIOD_M1,time,1,rates)==1,false,"Cannot copy the rates at time: "<<time);

  // For now we just return the typical price during that minute:
  // Prices definition found on: https://www.mql5.com/en/docs/constants/indicatorconstants/prices
  // double price = (rates[0].high + rates[0].low + rates[0].close)/3.0;

  double price = (time - rates[0].time) < 30 ? rates[0].open : rates[0].close;
  return price;      
}

double nvGetAsk(string symbol)
{
  MqlTick tick;
  CHECK_RET(SymbolInfoTick(symbol,tick),0.0,"Cannot retrieve latest tick for symbol "<<symbol)
  return tick.ask;
}

double nvGetAskPrice(string symbol, datetime time = 0)
{
  // Retrieve the target time from the manager if needed:
  if(time==0) {
    time = TimeCurrent();
  }

  // If the target time happens to be the server time, then this means we can use the latest tick available
  if(time == TimeCurrent())
  {
    // Use the latest tick data:
    MqlTick last_tick;
    // Note that the following code may fail if we are on the week end,
    // And connected to a server, and we didn't receive anything yet:
    if(SymbolInfoTick(symbol,last_tick)) {
      return last_tick.ask;
    }
    else {
      logWARN("Cannot retrieve the latest tick from server")
    }
  }

  // Fallback implementation:
  // Use the bar history:
  MqlRates rates[];
  CHECK_RET(CopyRates(symbol,PERIOD_M1,time,1,rates)==1,false,"Cannot copy the rates at time: "<<time);

  // For now we just return the typical price during that minute:
  // Prices definition found on: https://www.mql5.com/en/docs/constants/indicatorconstants/prices
  // double price = (rates[0].high + rates[0].low + rates[0].close)/3.0;

  // Instead of returning a typical price we can return the open price if we are close enough to the opening of the bar:
  // This is a valid approximation as long as we keep working with a resolution of 1 minute:
  double price = (time - rates[0].time) < 30 ? rates[0].open : rates[0].close;
  return price+rates[0].spread*nvGetPointSize(symbol);      
}

double nvGetSpread(string symbol)
{
  MqlTick tick;
  CHECK_RET(SymbolInfoTick(symbol,tick),0.0,"Cannot retrieve latest tick for symbol "<<symbol)
  return tick.ask-tick.bid;
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
    double bid = nvGetBid(symbol);
    price = otype==OP_BUY ? nvGetAsk(symbol) : bid;
    if(sl!=0.0)
    {
      sl = otype==OP_BUY ? bid-sl : bid+sl;
    }
    if(tp!=0.0)
    {
      tp = otype==OP_BUY ? bid+tp : bid-tp;
    }
  }

  int numd = (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);

  price = NormalizeDouble(price,numd);
  sl = NormalizeDouble(sl,numd);
  tp = NormalizeDouble(tp,numd);
  lot = nvNormalizeVolume(lot,symbol);

  color col = clrNONE;
  if(otype==OP_BUY || otype==OP_SELL)
  {
    col = otype==OP_BUY ? clrBlue : clrRed;
  }

  int magic = 12345;
  
  int ticket = OrderSend(symbol,otype,lot,price,slippage,sl,tp,NULL,magic,0,col);
  if(ticket<0)
  {
    int errno = GetLastError();
    logERROR("OpenPosition produced error code: "<<errno<<" ("<<ErrorDescription(errno)<<"), lot="<<lot);
    logERROR("price="<<price<<", sl="<<sl<<", tp="<<tp);
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

bool nvIsPosPending(int ticket)
{
  if(OrderSelect(ticket,SELECT_BY_TICKET))
  {
    int otype = OrderType();
    return otype==OP_BUYLIMIT || otype==OP_BUYSTOP || otype==OP_SELLSTOP || otype==OP_SELLLIMIT;
  }

  return false;
}

bool nvIsPosValid(int ticket)
{
  return OrderSelect(ticket,SELECT_BY_TICKET);
}

bool nvIsPosRunning(int ticket)
{
  if(OrderSelect(ticket,SELECT_BY_TICKET))
  {
    int otype = OrderType();
    return (otype==OP_BUY || otype==OP_SELL) && OrderCloseTime()==0;
  }

  return false;
}

bool nvIsPosClosed(int ticket)
{
  if(OrderSelect(ticket,SELECT_BY_TICKET))
  {
    return OrderCloseTime()!=0;
  }

  // Return true by default:
  return false;  
}

// Retrieve the ticket profit:
double nvGetPositionProfit(int ticket)
{
  if(OrderSelect(ticket,SELECT_BY_TICKET))
  {
    return OrderProfit();
  }

  return 0.0;
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

  color col = otype==OP_BUY ? clrBlue : clrRed;
  bool res = OrderClose(ticket,lot,price,slippage,col);
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

// Check if a given symbol is valid:
bool nvIsSymbolValid(string symbol)
{
  int num = SymbolsTotal(false);
  for(int i=0;i<num;++i)
  {
    if(symbol==SymbolName(i,false))
    {
      return true;
    }
  }

  return false;
}

double nvConvertPrice(double price, string srcCurrency, string destCurrency, datetime time=0)
{
  int srcDigits = 2;
  if(srcCurrency=="JPY") {
    srcDigits = 0;
  }

  // Convert the input price given the number of digit precision:
  price = NormalizeDouble( price, srcDigits );

  if(srcCurrency==destCurrency)
    return price;

  if(time==0) {
    time = TimeCurrent();
  }

  int destDigits = 2;
  if(destCurrency=="JPY") {
    destDigits = 0;
  }

  // If the currencies are not the same, we have to do the convertion:
  string symbol1 = srcCurrency+destCurrency;
  string symbol2 = destCurrency+srcCurrency;

  if(nvIsSymbolValid(symbol1))
  {
    // Then we retrieve the current symbol1 value:
    double bid = nvGetBidPrice(symbol1,time);

    // we want to convert into the "quote" currency here, so we should get the smallest value out of it,
    // And thus ise the bid price:
    return NormalizeDouble(price * bid, destDigits);
  }
  else if(nvIsSymbolValid(symbol2))
  {
    // Then we retrieve the current symbol2 value:
    double ask = nvGetAskPrice(symbol2,time);

    // we want to buy the "base" currency here so we have to divide by the ask price in that case:
    return NormalizeDouble(price / ask, destDigits); // ask is bigger than bid, so we get the smallest value out of it.
  }
  
  THROW("Unsupported currency names: "<<srcCurrency<<", "<<destCurrency);
  return 0.0;  
}

// Retrieve the balance value in a given currency:
double nvGetBalance(string currency = "")
{
  if(currency=="")
    currency = nvGetAccountCurrency();
      
  double balance = AccountInfoDouble(ACCOUNT_BALANCE);
  
  // convert from account currency to the given currency:
  balance = nvConvertPrice(balance,nvGetAccountCurrency(),currency);
  return balance;    
}

// Retrieve the balance value in a given currency:
double nvGetEquity()
{
  double balance = AccountInfoDouble(ACCOUNT_EQUITY);
  return balance;    
}

// Compute the mean of a sample array
double nvGetMeanEstimate(double &x[])
{
  int num = ArraySize( x );
  CHECK_RET(num>0,0.0,"Invalid sample size.");

  double mean = 0.0;
  for(int i=0;i<num;++i)
  {
    mean += x[i];
  }

  mean /= num;
  return mean;
}

// Compute the estimated standard deviation of a sample array
// when its mean is provided:
double nvGetStdDevEstimate(double &x[], double mean)
{
  int num = ArraySize( x );
  CHECK_RET(num>1,0.0,"Invalid sample size.");

  double sig = 0.0;
  for(int i=0;i<num;++i)
  {
    sig += (x[i] - mean)*(x[i] - mean);
  }

  sig /= (num-1);

  return MathSqrt(sig);
}

// Compute the estimated standard deviation of a sample array:
double nvGetStdDevEstimate(double &x[])
{
  return nvGetStdDevEstimate(x,nvGetMeanEstimate(x));
}

// Compute the covariance between 2 samples array:
double nvGetCovarianceEstimate(double &x[], double &y[])
{
  int num = ArraySize( x );
  int num2 = ArraySize( y );
  CHECK_RET(num == num2,0.0, "Mismatch in length for covariance computation: " << num<<"!="<<num2);

  double cov = 0.0;
  double m1 = nvGetMeanEstimate(x);
  double m2 = nvGetMeanEstimate(y);

  for (int i = 0; i < num; ++i)
  {
    cov += (x[i]-m1)*(y[i]-m2);
  }

  cov /= (num - 1.0);

  return cov;
}

// Compute the correlation between 2 samples array:
double nvGetCorrelationEstimate(double &x[], double &y[])
{
  double cov = nvGetCovarianceEstimate(x,y);
  double dev1 = nvGetStdDevEstimate(x);
  double dev2 = nvGetStdDevEstimate(y);
  CHECK_RET(dev1>0.0 && dev2>0.0,0.0, "Invalid deviation value for correlation computation.");
  return cov/(dev1*dev2);
}

// Retrieve the account currency:
string nvGetAccountCurrency()
{
  return AccountInfoString(ACCOUNT_CURRENCY);
}

// Method called to compute the value of 1 point in a symbol trading given a fixed lot size:
// Note that the point value is given in the quote currency.
double nvGetPointValue(string symbol, double lot = 1.0)
{
  double point = SymbolInfoDouble(symbol,SYMBOL_POINT);
  return nvGetContractValue(symbol,lot)*point;
}

// Retrieve a contract value in the margin currency:
double nvGetContractValue(string symbol, double lot)
{
  // We need to check what is the contract size for this symbol:
  double csize = SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
  return lot*csize;
}

double nvEvaluateLotSize(string symbol, double numLostPoints, double risk, double weight, double confidence)
{
  CHECK_RET(0.0<=weight && weight <= 1.0,0.0,"Invalid trader weight: "<<weight);

  // First we need to convert the current balance value in the desired profit currency:
  string quoteCurrency = nvGetQuoteCurrency(symbol);
  double balance = nvGetBalance(quoteCurrency);

  // Now we determine what fraction of this balance we can risk:
  double VaR = balance * risk * weight * MathAbs(confidence); // This is given in the quote currency.

  // Now we can compute the final lot size:
  // The worst lost we will achieve in the quote currency is:
  // VaR = lost = lotsize*contract_size*num_point
  // thus we need lotsize = VaR/(contract_size*numPoints) = VaR / (point_value * numPoints)
  // Also: we should prevent the lost point value to go too low !!
  double lotsize = VaR/(nvGetPointValue(symbol)*MathMax(numLostPoints,1.0));
  
  // finally we should normalize the lot size:
  lotsize = nvNormalizeVolume(lotsize,symbol);

  return lotsize;
}

// Metohd used to retrieve the profit currency from a given symbol:
string nvGetQuoteCurrency(string symbol)
{
  CHECK_RET(StringLen(symbol)==6,"","Invalid symbol length.");
  return StringSubstr(symbol,3);
}

// Metohd used to retrieve the base currency from a given symbol:
string nvGetBaseCurrency(string symbol)
{
  CHECK_RET(StringLen(symbol)==6,"","Invalid symbol length.");
  return StringSubstr(symbol,0,3);
}

void nvCloseAllPending(string symbol)
{
  // Remove all pending positions on a symbol:
  int tickets[];

  int num = OrdersTotal();
  int i;
  for(i =0;i<num;++i)
  {
    if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
    {
      // Ticket was selected, check if this is for the proper symbol:
      int otype = OrderType();

      if(OrderSymbol() == symbol && (otype == OP_BUYLIMIT || otype == OP_SELLLIMIT || otype == OP_BUYSTOP || otype == OP_SELLSTOP))
      {
        int ticket = OrderTicket();
        nvAppendArrayElement(tickets,ticket);
      }
    }
  }

  // Now delete the tickets we found:
  num = ArraySize(tickets);
  for(i = 0;i<num;++i)
  {
    CHECK(OrderDelete(tickets[i],clrNONE),"Cannot delete ticket "<<tickets[i]);
  }
}
void nvRemoveObjects(int chart_id, int type = -1, int win = -1)
{
  ObjectsDeleteAll(chart_id,win,type);
}