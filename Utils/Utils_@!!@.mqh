//+------------------------------------------------------------------+
//|                                           IncludeRiskManager.mqh |
//|                                       Copyright 2026, ALEX GOMEZ |
//|                                                 https://mql5.com |
//| 13.01.2026 - Initial release                                     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, ALEX GOMEZ"
#property link      "https://mql5.com"

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