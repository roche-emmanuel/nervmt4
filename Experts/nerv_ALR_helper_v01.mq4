/*
Implementation of Advanced Lost Recovery helper
*/

#property copyright "Copyright 2015, Nervtech"
#property link      "http://www.nervtech.org"

#property version   "1.00"

#include <stdlib.mqh>
#include <nerv/core.mqh>
#include <nerv/utils.mqh>
#include <nerv/trading/ALRBasket.mqh>
#include <nerv/math/SimpleRNG.mqh>

nvALRBasket* basket = NULL;

datetime lastTime = 0;
SimpleRNG rnd;

void createButton(string bname, int x, int y, int width, int height, int corner, color col)
{
  long chart_id=ChartID();
  CHECK(chart_id!=-1,"Invalid chart ID")

  // create a buy button:  
  CHECK(ObjectCreate(chart_id,bname,OBJ_BUTTON,0,0,0),"Cannot create button")

  // Button position:
  ObjectSetInteger(chart_id,bname,OBJPROP_XDISTANCE,x); 
  ObjectSetInteger(chart_id,bname,OBJPROP_YDISTANCE,y); 

  // Button size 
  ObjectSetInteger(chart_id,bname,OBJPROP_XSIZE,width); 
  ObjectSetInteger(chart_id,bname,OBJPROP_YSIZE,height); 

  // Set the chart's corner:
  ObjectSetInteger(chart_id,bname,OBJPROP_CORNER,corner);

  // Set the text:
  ObjectSetString(chart_id,bname,OBJPROP_TEXT,bname); 
  ObjectSetInteger(chart_id,bname,OBJPROP_COLOR,col); 
}

void destroyButton(string bname)
{
  long chart_id=ChartID();
  CHECK(chart_id!=-1,"Invalid chart ID")
  CHECK(ObjectDelete(chart_id,bname),"Cannot remove button.")
}

void createHLine(string lname, double price, color col)
{
  long chart_id=ChartID();
  CHECK(chart_id!=-1,"Invalid chart ID")

  CHECK(ObjectCreate(chart_id,lname,OBJ_HLINE,0,0,price),"Cannot create hline")
  ObjectSetInteger(chart_id,lname,OBJPROP_COLOR,col);
  ObjectSetInteger(chart_id,lname,OBJPROP_SELECTABLE,1);
  ObjectSetInteger(chart_id,lname,OBJPROP_WIDTH,1); 
}

void setupPendingOrder(int otype)
{
  // Close any previous pending order:
  nvCloseAllPending(_Symbol);

  logDEBUG("Setting up pending order for "<<_Symbol)

  // Retrieve the current ATR for the current chart:
  // We will use this as an offset when placing the order:
  double atr = iATR(_Symbol,_Period,14,1);

  double psize = nvGetPointSize(_Symbol);
  double price = nvGetBid(_Symbol);
  if(otype == OP_BUYLIMIT || otype == OP_SELLSTOP)
  {
    price -= atr;
  }
  else
  {
    price += atr;
  }

  double tp = 25.0;

  if(IsTesting())
  {
    tp = MathMax(nvGetSpread(_Symbol)/psize+20.0,tp);
  }

  if(otype == OP_BUYLIMIT || otype == OP_BUYSTOP)
  {
    tp = price + tp*psize;
  }
  else
  {
    tp = price - tp*psize;
  }

  double lot = 1.0;
  logDEBUG("Opening position type="<<otype<<" at price: "<<price<<" with lot="<<lot<<", tp="<<tp)
  nvOpenPosition(_Symbol, otype, lot, 0.0, tp, price, 30);
}

// Initialization method:
int OnInit()
{    
  logDEBUG("Initializing ALRHelper for symbol " << _Symbol)

  nvLogManager* lm = nvLogManager::instance();
  string fname = "nerv_alr_helper_" + _Symbol +".log";
  nvFileLogger* logger = new nvFileLogger(fname);
  lm.addSink(logger);

  //  Retrieve the chart ID:
  createButton("BuyStop", 10, 20, 100, 20, CORNER_LEFT_UPPER, clrGreen);
  createButton("BuyLimit", 10, 50, 100, 20, CORNER_LEFT_UPPER, clrGreen);
  createButton("SellLimit", 10, 80, 100, 20, CORNER_LEFT_UPPER, clrRed);
  createButton("SellStop", 10, 110, 100, 20, CORNER_LEFT_UPPER, clrRed);
  createButton("Clear", 10, 140, 100, 20, CORNER_LEFT_UPPER, clrBlue);

  // Create the recovery basket:
  basket = new nvALRBasket(_Symbol);

  rnd.SetSeed(123);

  return 0;
}

void clearLines()
{
  // logDEBUG("Removing lines...")
  int cid = ChartID();
  ObjectDelete("target_high");
  ObjectDelete("target_low");
  ObjectDelete("zone_high");
  ObjectDelete("zone_low");

  ChartRedraw();
}

// Uninitialization:
void OnDeinit(const int reason)
{
  RELEASE_PTR(basket);

  destroyButton("BuyStop");
  destroyButton("BuyLimit");
  destroyButton("SellLimit");
  destroyButton("SellStop");
  destroyButton("Clear");

  logDEBUG("Uninitializing ALRHelper for " << _Symbol)
}

// OnTick handler:
void OnTick()
{
  basket.update();

  if(basket.isRunning())
  {
    return; // do not do anything here.
  }

  if(IsTesting())
  {
    datetime ctime = TimeCurrent();
    // if(lastTime==0)
    //   lastTime = ctime;

    // From time to time place an order:
    if((ctime - lastTime)>(60.0*1.0))
    {
      lastTime = ctime;
      int ott = (rnd.GetUniform()-0.5) > 0 ? OP_BUY : OP_SELL;
      setupPendingOrder(ott);
    }
  }

  // Remove all the previous lines:
  // nvRemoveObjects(ChartID(),OBJ_HLINE);
  clearLines();
  ChartRedraw();


  // Check if we entered a BUY or SELL position:
  int num = OrdersTotal();
  int i;
  for(i =0;i<num;++i)
  {
    if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
    {
      // Ticket was selected, check if this is for the proper symbol:
      int otype = OrderType();

      if(OrderSymbol() == _Symbol && (otype == OP_BUY || otype == OP_SELL))
      {
        logDEBUG(_Symbol<<": Detected new position of type "<< (otype==OP_BUY ? "LONG" : "SHORT"))

        int ticket = OrderTicket();
        
        // update the _zoneWidth using the take profit value:
        double tp = OrderTakeProfit();
        CHECK(tp>0.0,"Invalid take profit value.")

        double zw = MathAbs(nvGetBid(_Symbol) - tp);
        double psize = nvGetPointSize(_Symbol);
        
        basket.setZoneWidth(zw);
        basket.setPositiveBreakEvenWidth(zw);
        basket.setNegativeBreakEvenWidth(zw);
        basket.setProfitWidth(10.0*psize);
        basket.setTakeProfitOffset(5.0*psize);
        basket.setWarningLevel(5);
        basket.setStopLevel(10);

        basket.setDecayLevel(8);
        basket.setTakeProfitDecay(5.0*psize);

        basket.setBreakEvenPoints(25.0*psize);
        basket.setTrailStep(5.0*psize);
        basket.setSlippage(10);
        
        basket.setTakeProfitDrift(0.0*psize);

        basket.setForceTakeProfit(25.0);

        // Create the hlines:
        double bid = nvGetBid(_Symbol);
        double zoneHigh,zoneLow,targetHigh, targetLow;

        if(OrderType()==OP_BUY)
        {
          zoneHigh = bid;
          zoneLow = zoneHigh - zw;
        }
        else
        {
          zoneLow = bid;
          zoneHigh = zoneLow + zw;
        }
        
        targetHigh = zoneHigh + zw;
        targetLow = zoneLow - zw;

        createHLine("target_high",targetHigh,clrDodgerBlue);
        createHLine("target_low",targetLow,clrDodgerBlue);
        createHLine("zone_high",zoneHigh,clrOrange);
        createHLine("zone_low",zoneLow,clrOrange);

        // Enter the ALR basket with this ticket.
        // But first we need to setup the recovery zone appropriately:
        basket.enter(ticket);

        return;
      }
    }
  }
}

void OnChartEvent(const int id,         // Event ID 
                  const long& lparam,   // Parameter of type long event 
                  const double& dparam, // Parameter of type double event 
                  const string& sparam)
{
  long chart_id=ChartID();

  if(id==CHARTEVENT_OBJECT_CLICK)
  {
    logDEBUG("Received click event lp="<<lparam<<", dp="<<dparam<<", sp="<<sparam);
    
    int otype = -1;
    if(sparam=="BuyLimit")
    {
      logDEBUG("Buy limit order.");
      otype = OP_BUYLIMIT;
    }  
    if(sparam=="BuyStop")
    {
      logDEBUG("Buy stop order.");
      otype = OP_BUYSTOP;
    }  
    if(sparam=="SellLimit")
    {
      logDEBUG("Sell limit order.");
      otype = OP_SELLLIMIT;
    }  
    if(sparam=="SellStop")
    {
      logDEBUG("Sell stop order.");
      otype = OP_SELLSTOP;
    }  
    if(sparam=="Clear")
    {
      logDEBUG("Clearing state");
      // nvRemoveObjects(ChartID(),OBJ_HLINE);
      clearLines();
      basket.close();
    }  

    if(otype>0)
    {
      setupPendingOrder(otype);
    }

    // Restore the stat of that button
    Sleep(50);
    ObjectSetInteger(chart_id,sparam,OBJPROP_STATE,false);
    ChartRedraw();
  }
}
