//+------------------------------------------------------------------+
//|                                           IncludeRiskManager.mqh |
//|                                       Copyright 2026, ALEX GOMEZ |
//|                                                 https://mql5.com |
//| 13.01.2026 - Initial release                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, ALEX GOMEZ"
#property link      "https://mql5.com"

double CalculateLot(double entry, double sl) {
   double balance = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = balance * (RiskPerTrade / 100.0);
   double slDistance = MathAbs(entry - sl);

   if (slDistance <= 0) return 0.0;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   double lot = riskAmount / ((slDistance / tickSize) * tickValue);

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathFloor(lot / lotStep) * lotStep;

   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;

   return lot;
}