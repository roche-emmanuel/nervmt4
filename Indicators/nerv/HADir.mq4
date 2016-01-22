
//+------------------------------------------------------------------+
//|                                        Heiken_Ashi_direction.mq5 |
//|                        Copyright 2009, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "2009, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"

#include <nerv/core.mqh>

//--- indicator settings
#property indicator_separate_window
#property indicator_buffers    1
#property indicator_color1     LightSeaGreen

//--- indicator buffers
double ExtColorBuffer[];
double ExtOBuffer[];
double ExtHBuffer[];
double ExtLBuffer[];
double ExtCBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
  IndicatorBuffers(5);
  SetIndexBuffer(1,ExtOBuffer);
  SetIndexBuffer(2,ExtHBuffer);
  SetIndexBuffer(3,ExtLBuffer);
  SetIndexBuffer(4,ExtCBuffer);

  SetIndexDrawBegin(0,0);

  // Main indicator line:
  SetIndexStyle(0,DRAW_LINE);
  SetIndexBuffer(0,ExtColorBuffer);

  string short_name = "Heiken Ashi Dir";
  IndicatorShortName(short_name);
  SetIndexLabel(0,short_name);
  //--- initialization done
  return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Heiken Ashi                                                      |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
  int i,limit;
  ArraySetAsSeries(ExtColorBuffer,false);
  ArraySetAsSeries(ExtLBuffer,false);
  ArraySetAsSeries(ExtHBuffer,false);
  ArraySetAsSeries(ExtOBuffer,false);
  ArraySetAsSeries(ExtCBuffer,false);
  ArraySetAsSeries(open,false);
  ArraySetAsSeries(high,false);
  ArraySetAsSeries(low,false);
  ArraySetAsSeries(close,false);

  //--- preliminary calculations
  if(prev_calculated==0)
  {
    //--- set first candle
    ExtLBuffer[0]=low[0];
    ExtHBuffer[0]=high[0];
    ExtOBuffer[0]=open[0];
    ExtCBuffer[0]=close[0];
    limit=1;
  }
  else 
    limit=prev_calculated-1;

  //--- the main loop of calculations
  for(i=limit;i<rates_total && !IsStopped();i++)
  {
    double haOpen=(ExtOBuffer[i-1]+ExtCBuffer[i-1])/2;
    double haClose=(open[i]+high[i]+low[i]+close[i])/4;
    double haHigh=MathMax(high[i],MathMax(haOpen,haClose));
    double haLow=MathMin(low[i],MathMin(haOpen,haClose));

    ExtLBuffer[i]=haLow;
    ExtHBuffer[i]=haHigh;
    ExtOBuffer[i]=haOpen;
    ExtCBuffer[i]=haClose;

    // logDEBUG("" << (datetime)time[i] << ": open="<<open[i]<<", high="<<high[i]<<", low="<<low[i]<<", close="<<close[i]);

    //--- set candle color
    if(haOpen<haClose) {
      // logDEBUG(time[i]<<": nervHA dir: "<<0.0)
      ExtColorBuffer[i]=1.0; // set color DodgerBlue
    }
    else {
      // logDEBUG(time[i]<<": nervHA dir: "<<1.0)
      ExtColorBuffer[i]=0.0; // set color Red
    }
    
    // MqlDateTime dts;
    // TimeToStruct(time[i],dts);

    // ExtColorBuffer[i] = (dts.min==0) ? 1.0 : 0.0;           
  }
  
  return(rates_total);
}
//+------------------------------------------------------------------+

