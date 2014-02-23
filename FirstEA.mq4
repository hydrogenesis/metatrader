//+------------------------------------------------------------------+
//|                                                    MyFirstEA.mq4 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
#property strict

#define kUpTrend 1
#define kDownTrend (-1)

//---- Includes
#include <stdlib.mqh>
//---- Trades limits
extern double    StopLoss=10000;
extern double    TakeProfit=300000;
extern double    Lots=1;
extern int       Slippage=5;
//--- External options
extern int       CurrentBar=1;
extern bool      UseClose=true;
//--- Indicators settings
extern int       MaMode=1; /* MODE_SMA 0   MODE_EMA 1  MODE_SMMA 2 MODE_LWMA 3 */
extern int       MaShift=0;
extern int       ShortEma=6;
extern int       LongEma=12;

extern double MACDOpenLevel =3;
extern double MACDCloseLevel=2;

//--- Global variables
int      MagicNumber = 19871010;
int      last_processed_bar = 0;
string   EAComment = "EMA Simple Cross";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   // Make sure we do not encounter error 130 in OrderSend()
   double stop_level = MarketInfo(Symbol(), MODE_STOPLEVEL);
   if (StopLoss < stop_level) StopLoss = stop_level;
   if (TakeProfit < stop_level) TakeProfit = stop_level;
   Print("StopLoss: ", StopLoss, ", TakeProfit: ", TakeProfit, ", StopLevel: ", stop_level);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  if (Bars < 100) {
    Print("Bars less than 100.");
    return;
  }

//--- Simple as it is!
  if (last_processed_bar == Bars) {
    return;
  }
  if (GetTrend() == kUpTrend) {
    CloseAllOpenOrders();
    OpenOrder(kUpTrend);
    last_processed_bar = Bars;
  } else if (GetTrend() == kDownTrend) {
    CloseAllOpenOrders();
    OpenOrder(kDownTrend);
    last_processed_bar = Bars;
  }
}

//+------------------------------------------------------------------+
bool CloseOrder(int type) 
{
  if (OrderMagicNumber() == MagicNumber) {
    if(type==OP_BUY)
      return(OrderClose(OrderTicket(),OrderLots(),Bid,Slippage,Green));
    if(type==OP_SELL)
      return(OrderClose(OrderTicket(),OrderLots(),Ask,Slippage,Red));
  }
  return false;
}

void CloseAllOpenOrders() {
  int total = OrdersTotal();
  for (int i = 0; i < total; ++i) {
    OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
    CloseOrder(OrderType());
  }
}

int OpenOrder(int trend) {
  int ticket = -1;
  if (trend == kUpTrend) {
    Print("Buy: ", Ask-StopLoss*Point,", ",Ask,", ",Ask+TakeProfit*Point);
    ticket=OrderSend(Symbol(),OP_BUY,Lots,Ask,Slippage,Ask-StopLoss*Point,Ask+TakeProfit*Point,EAComment,MagicNumber,0,Green);
  } else if (trend == kDownTrend) {
    Print("Sell: ", Bid+StopLoss*Point,", ",Bid,", ",Bid-TakeProfit*Point);
    ticket=OrderSend(Symbol(),OP_SELL,Lots,Bid,Slippage,Bid+StopLoss*Point,Bid-TakeProfit*Point,EAComment,MagicNumber,0,Red);
  }
  int err = GetLastError();
  if (err != 0) {
    Print("Error: ", err);
  }
  return ticket;
}

int GetTrend() {
  return Crossed();
}

int Crossed() {
  return CrossedKDJ();
  int trend = CrossedEMA() + CrossedMACD() + CrossedKDJ();
  if (trend > 1) return kUpTrend;
  if (trend < -1) return kDownTrend;
  return 0;
}

int CrossedEMA()
{
   double EmaLongPrevious=iMA(NULL,0,LongEma,MaShift,MaMode, PRICE_CLOSE, CurrentBar+1);
   double EmaLongCurrent=iMA(NULL,0,LongEma,MaShift,MaMode, PRICE_CLOSE, CurrentBar);
   double EmaShortPrevious=iMA(NULL,0,ShortEma,MaShift,MaMode, PRICE_CLOSE, CurrentBar+1);
   double EmaShortCurrent=iMA(NULL,0,ShortEma,MaShift,MaMode, PRICE_CLOSE, CurrentBar);
//----
   if (EmaShortPrevious<EmaLongPrevious && EmaShortCurrent>EmaLongCurrent)    return(kUpTrend); //up trend
   if (EmaShortPrevious>EmaLongPrevious && EmaShortCurrent<EmaLongCurrent)    return(kDownTrend); //down trend
//----
   return(0); //elsewhere
}

int CrossedMACD() {
   double MacdCurrent=iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_MAIN,0);
   double MacdPrevious=iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_MAIN,1);
   double SignalCurrent=iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_SIGNAL,0);
   double SignalPrevious=iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_SIGNAL,1);
   if (MacdCurrent<0 && MacdCurrent>SignalCurrent && MacdPrevious<SignalPrevious && 
         MathAbs(MacdCurrent)>(MACDOpenLevel*Point)) return(kUpTrend);
   if (MacdCurrent>0 && MacdCurrent<SignalCurrent && MacdPrevious>SignalPrevious && 
         MacdCurrent>(MACDOpenLevel*Point)) return(kDownTrend);
   return(0); // No trends
}

int CrossedKDJ() {
   double kline[3];
   double dline[3];
   bool crossedup = false;
   bool crosseddown = false;
   for(int i = 0;i < 3;i++)
   {
      kline[i] = iStochastic(NULL, Period(), 8, 3, 3, MaMode, 0, MODE_MAIN, i);
      dline[i] = iStochastic(NULL, Period(), 8, 3, 3, MaMode, 0, MODE_SIGNAL, i);
   }
   if ((kline[1] < dline[1]) && (kline[2] > dline[2])) crosseddown = true;
   else if ((kline[1] > dline[1]) && (kline[2] < dline[2])) crossedup = true;
   else return(0);  // No trends;
   if (crossedup && (kline[1] < 20.0)) return(kUpTrend);
   if (crosseddown && (kline[1] > 80.0)) return(kDownTrend);
   return(0);
}