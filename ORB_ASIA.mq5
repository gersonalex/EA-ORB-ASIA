//+------------------------------------------------------------------+
//|                                                    ORB_ASIA.mq5  |
//|                                       Copyright 2026, ALEX GOMEZ |
//|                          https://www.instagram.com/alexgerson__/ |
//| 07.01.2026 - Initial release                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, ALEX GERSON GOMEZ"
#property link      "https://www.instagram.com/alexgerson__/"
#property version   "1.00"
#property description "COMO USAR:\n\
1. Arrastrar el EA al gráfico.\n\
2. Utilizar timeframe M15.\n\
3. Configurar las horas del rango de Asia (UTC-3).\n\
4. Configurar las horas de la Zona de Decisión (UTC-3).\n\
5. El EA opera solamente durante la Zona de Decisión.\n\
6. Se utiliza el tiempo del broker."

#include <Trade/Trade.mqh>
#include "RiskManager/RiskManager.mqh"

CTrade trade;

input group "----------------- RANGO DE ASIA -----------------";
input int RangeStartHour            = 21;    // Hora de inicio de horario de Asia
input int RangeStartMin             = 0;     // Minuto de inicio de horario de Asia
input int RangeEndHour              = 4;     // Hora de fin de horario de Asia
input int RangeEndMin               = 0;    // Minuto de fin de horario de Asia

input group "----------------- ZONA DE DECISIÓN -----------------";
input int DecisionZoneStartHour     = 3;     // Hora de inicio de la zona de decisión
input int DecisionZoneStartMin      = 15;    // Minuto de inicio de la zona de decisión
input int DecisionZoneEndHour       = 4;     // Hora de fin de la zona de decisión
input int DecisionZoneEndMin        = 0;     // Minuto de fin de la zona de decisión

input group "----------------- HORARIO DE NUEVA YORK -----------------";
input int NewYorkOpenHour           = 10;    // Hora de apertura de Nueva York
input int NewYorkOpenMin            = 0;     // Minuto de apertura de Nueva York
input int NewYorkCloseHour          = 18;    // Hora de cierre de Nueva York
input int NewYorkCloseMin           = 0;     // Minuto de cierre de Nueva York

input group "----------------- CONFIGURACIÓN DE OPERACIONES -----------------";
input double RiskRewardRatio        = 3.0;   // Ratio de Riesgo/Beneficio
input double RiskPerTrade           = 1.5;     // Riesgo por trade (en %)

input group "----------------- CONFIGURACIÓN GENERAL-----------------";
input bool UseManualOffsetInTester  = true;  // Usar desfase manual en el strategy tester
input int ManualTimeOffset          = 5;     // Desfase horario manual en horas (solo en el strategy tester)
input int MagicNumber               = 1234;  // Magic Number de las operaciones del EA

double rangeHigh, rangeLow, rangeMid;
datetime rangeTimeStart, rangeTimeEnd;
int rangeStartHour, rangeStartMin, rangeEndHour, rangeEndMin;
int decisionZoneStartHour, decisionZoneStartMin, decisionZoneEndHour, decisionZoneEndMin;
int newYorkOpenHour, newYorkCloseHour, newYorkOpenMin, newYorkCloseMin;

int lastDayNumber = -1;

int OnInit(){
   trade.SetExpertMagicNumber(MagicNumber);
   SetServerTime();
   printf("Server time setted");
   printf("range start hour %d:%d", rangeStartHour, rangeStartMin);
   printf("range end hour %d:%d", rangeEndHour, rangeEndMin);
   printf("decision zone start hour %d:%d", decisionZoneStartHour, decisionZoneStartMin);
   printf("decision zone end hour %d:%d", decisionZoneEndHour, decisionZoneEndMin);
   printf("new york open hour %d:%d", newYorkOpenHour, newYorkOpenMin);
   printf("new york close hour %d:%d", newYorkCloseHour, newYorkCloseMin);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   ObjectsDeleteAll(0, 0, OBJ_RECTANGLE);
   ObjectsDeleteAll(0, 0, OBJ_TREND);
}

void OnTick(){
   static datetime lastCandle = 0;
   datetime currentCandle = iTime(_Symbol, PERIOD_M15, 0);
   if (currentCandle != lastCandle) {
      lastCandle = currentCandle;
      CalculateRange();
      CheckEntry();
      ClosePosition();
      RemoveOrderIfNotOpen();
   }
}

void ClosePosition() {
   datetime serverTime = TimeTradeServer();

   MqlDateTime dt;
   TimeToStruct(serverTime, dt);

   dt.hour = newYorkCloseHour;
   dt.min = newYorkCloseMin;
   dt.sec = 0;

   datetime nyCloseTime = StructToTime(dt);

   if (serverTime >= nyCloseTime) {
      for (int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong ticket = PositionGetTicket(i);
         if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if (PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         trade.PositionClose(ticket, 20);
      }
   }
}

void RemoveOrderIfNotOpen() {
   datetime serverTime = TimeTradeServer();

   MqlDateTime dt;
   TimeToStruct(serverTime, dt);

   dt.hour = newYorkOpenHour;
   dt.min = newYorkOpenMin;
   dt.sec = 0;

   datetime nyOpenTime = StructToTime(dt);

   if (serverTime >= nyOpenTime) {
      RemoveOrder();
   }
}

void RemoveOrder() {
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);

      if (!OrderSelect(ticket)) continue;
      if (OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if (OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;

      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      if (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT) {
         trade.OrderDelete(ticket);
      }
   }
}

bool HasOpenPosition() {
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);

      if (!PositionSelectByTicket(ticket))
         continue;
      if (PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         return true;
   }

   return false;
}

bool HasPendingOrder() {
   for (int i = 0; i < OrdersTotal(); i++) {
      if (OrderGetTicket(i)) {
         if (OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == MagicNumber)
            return true;
      }
   }
   return false;
}

void CheckEntry() {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int currentMinutes = dt.hour * 60 + dt.min;
   int startMinutes = decisionZoneStartHour * 60 + decisionZoneStartMin;
   int endMinutes = decisionZoneEndHour * 60 + decisionZoneEndMin;

   if (HasOpenPosition()) return;

   if (!HasPendingOrder()) {
      if (currentMinutes >= startMinutes && currentMinutes <= endMinutes) {
         if (iClose(_Symbol, PERIOD_M15, 1) > rangeMid) {
            PlaceBuyLimit();
         } else {
            PlaceSellLimit();
         }
      }
   }
   else if (HasPendingOrder() && currentMinutes == endMinutes){
      int pendingOrderType = GetPendingOrderType();
      Print(iClose(_Symbol, PERIOD_M15, 1));
      if (pendingOrderType == ORDER_TYPE_BUY_LIMIT && iClose(_Symbol, PERIOD_M15, 1) < rangeMid) {
         Print("ORDER TYPE CHANGED FROM BUY LIMIT TO SELL LIMIT");
         RemoveOrder();
         PlaceSellLimit();
      }

      if (pendingOrderType == ORDER_TYPE_SELL_LIMIT && iClose(_Symbol, PERIOD_M15, 1) > rangeMid) {
         Print("ORDER TYPE CHANGED FROM SELL LIMIT TO BUY LIMIT");
         RemoveOrder();
         PlaceBuyLimit();
      }
   }
}

int GetPendingOrderType() {
   for (int i = 0; i < OrdersTotal(); i++) {
      ulong ticket = OrderGetTicket(i);

      if (ticket > 0) {
         if (OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == MagicNumber) {
            return (int)OrderGetInteger(ORDER_TYPE);
         }
      }
   }
   return -1;
}

double CalculateTP(ENUM_ORDER_TYPE type) {
   if (type == ORDER_TYPE_BUY_LIMIT)
      return rangeHigh + (rangeHigh - rangeMid);
   return rangeLow - (rangeMid - rangeLow);
}

double CalculateSL(ENUM_ORDER_TYPE type, double entry, double tp) {
   if (type == ORDER_TYPE_BUY_LIMIT)
      return entry - ((tp - entry) / 2.0);
   return entry + ((entry - tp) / 2.0);
}

double RecalculateTP(ENUM_ORDER_TYPE type, double entry, double tp, double sl) {
   if (type == ORDER_TYPE_BUY_LIMIT)
      return entry + (entry - sl) * RiskRewardRatio;
   return entry - (sl - entry) * RiskRewardRatio;
}

// double CalculateLot(double entry, double sl) {
//    double balance = AccountInfoDouble(ACCOUNT_EQUITY);
//    double riskAmount = balance * (RiskPerTrade / 100.0);
//    double slDistance = MathAbs(entry - sl);

//    if (slDistance <= 0) return 0.0;

//    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
//    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

//    double lot = riskAmount / ((slDistance / tickSize) * tickValue);

//    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
//    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
//    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

//    lot = MathFloor(lot / lotStep) * lotStep;

//    if(lot < minLot) lot = minLot;
//    if(lot > maxLot) lot = maxLot;

//    return lot;
// }

void PlaceBuyLimit() {
   double entry   = rangeLow;
   double ask     = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double tp      = CalculateTP(ORDER_TYPE_BUY_LIMIT);
   double sl      = CalculateSL(ORDER_TYPE_BUY_LIMIT, entry, tp);
   double lot     = CalculateLot(entry, sl);
   tp             = RecalculateTP(ORDER_TYPE_BUY_LIMIT, entry, tp, sl);

   if(entry >= ask) return;

   trade.BuyLimit(
      lot,
      entry,
      _Symbol,
      sl,
      tp,
      ORDER_TIME_GTC,
      MagicNumber,
      "Buy Limit"
   );
}

void PlaceSellLimit() {
   double entry   = rangeHigh;
   double bid     = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tp      = CalculateTP(ORDER_TYPE_SELL_LIMIT);
   double sl      = CalculateSL(ORDER_TYPE_SELL_LIMIT, entry, tp);
   double lot     = CalculateLot(entry, sl);
   tp             = RecalculateTP(ORDER_TYPE_SELL_LIMIT, entry, tp, sl);

   if(entry <= bid) return;

   trade.SellLimit(
      lot,
      entry,
      _Symbol,
      sl,
      tp,
      ORDER_TIME_GTC,
      MagicNumber,
      "Sell Limit"
   );
}

void CalculateRange() {
   DrawRange();
   DrawMidRange();
   DrawDecisionZone();
}

void DrawRange() {
   MqlDateTime dt;
   TimeCurrent(dt);

   dt.hour = rangeStartHour;
   dt.min  = rangeStartMin;
   dt.sec  = 0;

   rangeTimeStart = StructToTime(dt);

   dt.hour = rangeEndHour;
   dt.min  = rangeEndMin;
   dt.sec  = 0;

   rangeTimeEnd = StructToTime(dt);

   if (rangeStartHour > rangeEndHour) {
      rangeTimeStart -= 86400;
   }

   double arrHigh[], arrLow[];
   CopyHigh(_Symbol, PERIOD_M15, rangeTimeStart, rangeTimeEnd, arrHigh);
   CopyLow(_Symbol, PERIOD_M15, rangeTimeStart, rangeTimeEnd, arrLow);

   if (ArraySize(arrHigh) == 0 || ArraySize(arrLow) == 0) return;

   int indexHighest = ArrayMaximum(arrHigh, 0, WHOLE_ARRAY);
   int indexLowest = ArrayMinimum(arrLow, 0, WHOLE_ARRAY);

   rangeHigh = arrHigh[indexHighest];
   rangeLow = arrLow[indexLowest];
   rangeMid = (rangeHigh + rangeLow) / 2.0;

   string rangeName = "ASIA_RANGE" + TimeToString(rangeTimeStart, TIME_DATE);

   if (ObjectFind(0, rangeName) == -1) {
      ObjectCreate(0, rangeName, OBJ_RECTANGLE, 0, rangeTimeStart, rangeHigh, rangeTimeEnd, rangeLow);
      ObjectSetInteger(0, rangeName, OBJPROP_COLOR, clrWhite);
   } else {
      ObjectSetDouble(0, rangeName, OBJPROP_PRICE, 0, rangeHigh);
      ObjectSetDouble(0, rangeName, OBJPROP_PRICE, 1, rangeLow);
   }
}

void DrawMidRange() {
   string midLineName = "ASIA_MID_RANGE" + TimeToString(rangeTimeStart, TIME_DATE);

   if (ObjectFind(0, midLineName) == -1) {
      ObjectCreate(0, midLineName, OBJ_TREND, 0, rangeTimeStart, rangeMid, rangeTimeEnd, rangeMid);
      ObjectSetInteger(0, midLineName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, midLineName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, midLineName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, midLineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, midLineName, OBJPROP_RAY_LEFT, false);
   } else {
      ObjectSetInteger(0, midLineName, OBJPROP_TIME, 0, rangeTimeStart);
      ObjectSetDouble(0, midLineName, OBJPROP_PRICE, 0, rangeMid);
      ObjectSetInteger(0, midLineName, OBJPROP_TIME, 1, rangeTimeEnd);
      ObjectSetDouble(0, midLineName, OBJPROP_PRICE, 1, rangeMid);
   }
}

void DrawDecisionZone() {
   MqlDateTime dt;
   TimeCurrent(dt);

   dt.hour = decisionZoneStartHour;
   dt.min  = decisionZoneStartMin;
   dt.sec  = 0;

   datetime decisionZoneStart = StructToTime(dt);

   dt.hour = decisionZoneEndHour;
   dt.min  = decisionZoneEndMin;
   dt.sec  = 0;

   datetime decisionZoneEnd = StructToTime(dt);

   if (decisionZoneStartHour > decisionZoneEndHour) {
      decisionZoneStart -= 86400;
   }

   string decisionZone = "DECISION_ZONE" + TimeToString(rangeTimeStart, TIME_DATE);

   if (ObjectFind(0, decisionZone) == -1) {
      ObjectCreate(0, decisionZone, OBJ_RECTANGLE, 0, decisionZoneStart, rangeHigh, decisionZoneEnd, rangeLow);
      ObjectSetInteger(0, decisionZone, OBJPROP_FILL, true);
      ObjectSetInteger(0, decisionZone, OBJPROP_BACK, true);
      ObjectSetInteger(0, decisionZone, OBJPROP_COLOR, clrDarkSlateGray);
   } else {
      ObjectSetDouble(0, decisionZone, OBJPROP_PRICE, 0, rangeHigh);
      ObjectSetDouble(0, decisionZone, OBJPROP_PRICE, 1, rangeLow);
   }
}

void SetServerTime() {
   MqlDateTime dt;
   datetime serverTime = TimeTradeServer(dt);
   datetime localTime = TimeLocal(dt);
   int offset = (int)(serverTime - localTime) / 3600;

   if (MQLInfoInteger(MQL_TESTER) && UseManualOffsetInTester)
      offset = ManualTimeOffset;

   rangeStartHour = (RangeStartHour + offset + 24) % 24;
   rangeEndHour   = (RangeEndHour   + offset + 24) % 24;
   rangeStartMin = RangeStartMin;
   rangeEndMin = RangeEndMin;

   decisionZoneStartHour = (DecisionZoneStartHour + offset + 24) % 24;
   decisionZoneEndHour   = (DecisionZoneEndHour   + offset + 24) % 24;
   decisionZoneStartMin = DecisionZoneStartMin;
   decisionZoneEndMin = DecisionZoneEndMin;

   newYorkOpenHour = (NewYorkOpenHour + offset) % 24;
   newYorkCloseHour = (NewYorkCloseHour + offset) % 24;
   newYorkOpenMin = NewYorkOpenMin;
   newYorkCloseMin = NewYorkCloseMin;
}