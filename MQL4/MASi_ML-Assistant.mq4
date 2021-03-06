//+---------------------------------------------------------------------------+
//|                                                 MASi_ML-Assistant.mq4.mq4 |
//|                                         Copyright 2017, Terentyev Aleksey |
//|                                 https://www.mql5.com/ru/users/terentjew23 |
//+---------------------------------------------------------------------------+
#property copyright     "Copyright 2017, Terentyev Aleksey"
#property link          "https://www.mql5.com/ru/users/terentjew23"
#property description   "The script helps to prepare data for machine learning and to read forecast files."
#property version       "1.2"
#property strict

#include                "MASh_Include.mqh"

//---------------------Indicators---------------------------------------------+
#property indicator_separate_window
#property indicator_height  50
#property indicator_minimum -1.1
#property indicator_maximum 1.1
#property indicator_buffers 6
#property indicator_plots   6
//--- plot
#property indicator_label1  "Signal Buy"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3
#property indicator_label2  "Signal Sell"
#property indicator_type2   DRAW_HISTOGRAM
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  3
#property indicator_label3  "Order Buy"
#property indicator_type3   DRAW_HISTOGRAM
#property indicator_color3  clrLightSeaGreen
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1
#property indicator_label4  "Order Sell"
#property indicator_type4   DRAW_HISTOGRAM
#property indicator_color4  clrMediumVioletRed
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1
#property indicator_label5  "Forecast Buy"
#property indicator_type5   DRAW_HISTOGRAM
#property indicator_color5  clrDodgerBlue
#property indicator_style5  STYLE_SOLID
#property indicator_width5  2
#property indicator_label6  "Forecast Sell"
#property indicator_type6   DRAW_HISTOGRAM
#property indicator_color6  clrDarkViolet
#property indicator_style6  STYLE_SOLID
#property indicator_width6  2
//--- indicator buffers
double      SignalBBuffer[];
double      SignalSBuffer[];
double      OrderBBuffer[];
double      OrderSBuffer[];
double      ForecastBBuffer[];
double      ForecastSBuffer[];

//-----------------Global variables-------------------------------------------+
//---
input string            SECTION1 = "======= General ========";//======= General ========
input OptimizationType  OPTIMIZE = Simple;              // Optimization type
input int               F_DEPTH = 1;                    // Depth of forecast ( |Bar[0]|->n )
input int               F_SIZE = 100;                   // Size history of forecast
input IndicatorType     INDICATOR = ThreeScreens_v1_1;  // Chose Indicator for work
input int               EMA_D1 = 26;                    // EMA Display #1
input int               MACD_FAST = 12;                 // MACD Fast
input int               MACD_SLOW = 26;                 // MACD Slow
input int               MACD_SIGNAL = 9;                // MACD Signal
input string            SECTION2 = "====== Additionally ======";//====== Additionally ======
input bool              ON_TIME = true;                 // Enable time data
input bool              ON_MARKET = true;               // Enable market data
input bool              ON_MACD = false;                // Enable MACD Histogram level
input bool              ON_EMA = false;                 // Enable EMA levels
input string            EMA_LEVELS = "13, 26, 65, 130"; // EMA levels (Integer numbers separated by commas)
input bool              ON_FIBOEMA = false;             // Enable Fibonacci EMA levels
input int               FIBO_START = 3;                 // Start position first Fibonacci number
input int               FIBO_COUNT = 7;                 // Count Fibonacci numbers
input bool              ON_HISTORY = false;             // Enable signals from mql5 order history
input string            HISTORY_FILE = "";              // Csv file history
input string            SECTION3 = "======== System ========";//======== System ========
input string            DIRECTORY = "ML-Assistant";     // Path to all files ({$MetaTrader4}/MQL4/Files/../)
input string            PREFIX = "";                    // Prefix (PrefixXXXYYYPeriod_x.csv)
input string            POSTFIX = "";                   // Postfix (XXXYYYPeriodPostfix_x.csv)
input string            SEPARATOR = ";";                // Csv file separator
input int               FORECAST_FACTOR = 5;            // Forecast factor
//---
string                  trainX, trainY;
string                  forecastX, forecastY;
string                  orderFile, emaLevelsS[];
int                     emaCount, emaLevels[];

//+---------------------------------------------------------------------------+
int OnInit()
{
    SetIndexBuffer( 0, SignalBBuffer );
    SetIndexBuffer( 1, SignalSBuffer );
    SetIndexBuffer( 2, OrderBBuffer );
    SetIndexBuffer( 3, OrderSBuffer );
    SetIndexBuffer( 4, ForecastBBuffer );
    SetIndexBuffer( 5, ForecastSBuffer );
    SetIndexShift( 4, F_DEPTH );
    SetIndexShift( 5, F_DEPTH );
    //SetIndexDrawBegin( 4, F_SIZE );
    //SetIndexDrawBegin( 5, F_SIZE );
    if( EMA_D1 <= 1 || MACD_FAST <= 1 || MACD_SLOW <= 1 || MACD_SIGNAL <= 1 || MACD_FAST >= MACD_SLOW ) {
        Print( "Wrong input parameters" );
        return INIT_FAILED;
    }
    //string  str = "";
    //if( ON_EMA ) { str += "EMA ( " + EMA_LEVELS + " ); "; }
    //if( ON_FIBOEMA ) { str += "FiboEMA ( " + (string)FIBO_START + ", " + (string)FIBO_COUNT + " ); "; }
    //if( ON_HISTORY ) { str += "Orders History;"; }
    IndicatorShortName( "ML-Assistant ( " + GetIndicatorString(INDICATOR) + " )" );
    orderFile = StringConcatenate( (StringLen(DIRECTORY) > 1 ? DIRECTORY + "/" : ""), HISTORY_FILE );
    if( StringFind( orderFile, ".csv" ) == -1 )
        StringConcatenate( orderFile, ".csv" ); 
    trainX = StringConcatenate( DIRECTORY, "/", Symbol(), Period(), "_x.csv" );
    trainY = StringConcatenate( DIRECTORY, "/", Symbol(), Period(), "_y.csv" );
    forecastX = StringConcatenate( DIRECTORY, "/", Symbol(), Period(), "_xx.csv" );
    forecastY = StringConcatenate( DIRECTORY, "/", Symbol(), Period(), "_yy.csv" );
    emaCount = StringSplit( EMA_LEVELS, ',', emaLevelsS );
    ArrayResize( emaLevels, emaCount );
    for( int idx = 0; idx < emaCount; idx++ ) {
        emaLevels[idx] = StringToInteger( emaLevelsS[idx] );
    }
    return INIT_SUCCEEDED;
}

//+---------------------------------------------------------------------------+
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
    if( OptimizedSkip(OPTIMIZE) )
        return rates_total - 1;
    int limit = rates_total - prev_calculated;
    if( prev_calculated > 0 ) {
        limit++;
    }
    for( int idx = limit-1; idx >= 0; idx-- ) {
        double tmp = 0.0;
        SignalBBuffer[idx] = 0.0;
        SignalSBuffer[idx] = 0.0;
        switch( INDICATOR ) {
            case Impulse:           tmp = Impulse( idx, Symbol(), Period(), EMA_D1, MACD_FAST, MACD_SLOW, MACD_SIGNAL ); break;
            case EMAForce:          tmp = EMAForce( idx, Symbol(), Period(), 3, 9, MODE_EMA, PRICE_CLOSE ); break;
            case MACDHist:          tmp = iMACDHist( Symbol(), Period(), MACD_FAST, MACD_SLOW, MACD_SIGNAL, PRICE_CLOSE, MODE_EMA, idx ); break;
            case ThreeScreens_v1_0: tmp = ThreeScreens_v1_0( idx, Symbol(), Period(), EMA_D1, MACD_FAST, MACD_SLOW, MACD_SIGNAL ); break;
            case ThreeScreens_v1_1: tmp = ThreeScreens_v1_1( idx, Symbol(), Period(), EMA_D1, MACD_FAST, MACD_SLOW, MACD_SIGNAL ); break;
            case ThreeScreens_v1_2: tmp = ThreeScreens_v1_2( idx, Symbol(), Period(), EMA_D1, MACD_FAST, MACD_SLOW, MACD_SIGNAL ); break;
            case ThreeScreens_v2_0: tmp = ThreeScreens_v2_0( idx, Symbol(), Period(), EMA_D1, MACD_FAST, MACD_SLOW, MACD_SIGNAL ); break;
            default: break;
        }
        if( tmp > 0 )
            SignalBBuffer[idx] = tmp;
        if( tmp < 0 )
            SignalSBuffer[idx] = tmp;
    }
    ReadForecastToIndicator( Symbol(), Period(), forecastY, ForecastBBuffer, ForecastSBuffer );
    if( tickCount <= 1 && ON_HISTORY ) {    // Analyse history orders
        ReadHistoryToIndicator( Symbol(), Period(), orderFile, OrderBBuffer, OrderSBuffer );
    }
    if( NewBar() ) {                        // Save Training data
        WriteData( Symbol(), Period(), iBars(Symbol(),Period())-1, F_SIZE/2, F_DEPTH, trainX, trainY );
    }
    if( true ) {                            // Save Forecast data
        WriteData( Symbol(), Period(), F_SIZE-1, 0, 0, forecastX );
    }
    return rates_total;
}

//+---------------------------------------------------------------------------+
void WriteData(const string symbol, const int period,
               const int begin, const int end, const int shift,
               const string fileX, const string fileY = "")
{   // Main data file
    string  lineBuffer;
    ushort  csvSep = StringGetChar( SEPARATOR, 0 );
    int     digits = (int)MarketInfo( symbol, MODE_DIGITS );
    int     handleX = FileOpen( fileX, FILE_WRITE | FILE_CSV | FILE_SHARE_WRITE, csvSep );
    for( int idx = begin; idx >= end+shift; idx-- ) {
        lineBuffer = "";
        if( ON_TIME ) {
            lineBuffer = StringConcatenate( IntegerToString( TimeYear(iTime( symbol, period, idx )) ), SEPARATOR,
                                            IntegerToString( TimeMonth(iTime( symbol, period, idx )) ), SEPARATOR,
                                            IntegerToString( TimeDay(iTime( symbol, period, idx )) ), SEPARATOR,
                                            IntegerToString( TimeDayOfWeek(iTime( symbol, period, idx )) ), SEPARATOR,
                                            IntegerToString( TimeDayOfYear(iTime( symbol, period, idx )) ), SEPARATOR,
                                            IntegerToString( TimeHour(iTime( symbol, period, idx )) ), SEPARATOR,
                                            IntegerToString( TimeMinute(iTime( symbol, period, idx )) ) );
        }
        if( ON_MARKET ) {
            if( ON_TIME ) { lineBuffer += SEPARATOR; }
            lineBuffer = StringConcatenate( DoubleToStr( iOpen(  symbol, period, idx ), digits ), SEPARATOR,
                                            DoubleToStr( iHigh(  symbol, period, idx ), digits ), SEPARATOR,
                                            DoubleToStr( iLow(   symbol, period, idx ), digits ), SEPARATOR,
                                            DoubleToStr( iClose( symbol, period, idx ), digits ) );
        }
        if( ON_MACD ) {
            if( ON_TIME || ON_MARKET ) { lineBuffer += SEPARATOR; }
            lineBuffer = StringConcatenate( DoubleToStr( iMACDHist( symbol, period, MACD_FAST, MACD_SLOW, MACD_SIGNAL, PRICE_CLOSE, MODE_EMA, idx), digits+1 ) );
        }
        if( ON_EMA ) {
            if( ON_TIME || ON_MARKET ) { lineBuffer += SEPARATOR; }
            for( int jdx = 0; jdx < emaCount; jdx++ ) {
                lineBuffer += DoubleToStr( iMA(symbol, period, emaLevels[jdx], 0, MODE_EMA, PRICE_CLOSE, idx), digits );
                lineBuffer += (jdx < emaCount-1 ? SEPARATOR : "");
            }
        }
        if( ON_FIBOEMA ) {
            if( ON_TIME || ON_MARKET || ON_EMA ) lineBuffer += SEPARATOR;
            for( int jdx = FIBO_START; jdx < FIBO_START+FIBO_COUNT; jdx++ ) {
                lineBuffer += DoubleToStr( iMA(symbol, period, Fibonacci(jdx), 0, MODE_EMA, PRICE_CLOSE, idx), digits );
                lineBuffer += (jdx < FIBO_START+FIBO_COUNT-1 ? SEPARATOR : "");
            }
        }
        FileWrite( handleX, lineBuffer );
    }
    FileClose( handleX );
    if( fileY == "" )
        return;
    // Answers data file
    int     handleY = FileOpen( fileY, FILE_WRITE | FILE_CSV | FILE_SHARE_WRITE, csvSep );
    for( int idx = begin-shift; idx >= end; idx-- ) {
        lineBuffer = "";
        for( int jdx = 0; jdx < shift; jdx++ ) {
            lineBuffer += DoubleToStr( SignalBBuffer[idx-jdx]+SignalSBuffer[idx-jdx], digits+1 );
            lineBuffer += (jdx != 0 ? SEPARATOR : "");
        }
        FileWrite( handleY, lineBuffer );
    }
    FileClose( handleY );
};

void ReadForecastToIndicator(const string symbol, const int period,
                             const string file,
                             double &positivBuff[], double &negativeBuff[])
{
    ushort  csvSep = StringGetChar( SEPARATOR, 0 );
    int     handle = FileOpen( file, FILE_READ | FILE_CSV, csvSep );
    for( int idx = F_SIZE-1; idx >= 0; idx-- ) {
        double tmp = 0.0;
        positivBuff[idx] = 0.0;
        negativeBuff[idx] = 0.0;
        for( int jdx = 0; jdx < F_DEPTH; jdx++ ) {
            tmp = StringToDouble( FileReadString( handle ) ) * FORECAST_FACTOR;
        }
        if( tmp > 0 )
            positivBuff[idx] = tmp;
        if( tmp < 0 )
            negativeBuff[idx] = tmp;
        if( FileIsEnding( handle ) ) {
            //Print( "Forecast read OK!" );
            break;
        }
    }
    FileClose( handle );
};

void ReadHistoryToIndicator(const string symbol, const int period,
                            const string file,
                            double &positivBuff[], double &negativeBuff[],
                            const bool sorted = true)
{
    bool    header;
    string  bTime, bType, bVol, bSym, bPrice, bStop, bTake, bTime2, bPrice3, bComsn, bSwap, bProfit, bComm;
    datetime readedT;
    ushort  csvSep = StringGetChar( SEPARATOR, 0 );
    int     handle = FileOpen( file, FILE_READ | FILE_CSV, csvSep );
    if( handle == INVALID_HANDLE ) {
        Print( "Open file error: " + (string)GetLastError() );
        return;
    }
    // Read first line
    ReadHistoryLine( handle, bTime, bType, bVol, bSym,
                            bPrice, bStop, bTake, bTime2, 
                            bPrice3, bComsn, bSwap, bProfit, bComm );
    if( StringFind(bTime, "Time") >= 0 ) { 
        header = true;  // This header. Read first data
        ReadHistoryLine( handle, bTime, bType, bVol, bSym,
                                bPrice, bStop, bTake, bTime2, 
                                bPrice3, bComsn, bSwap, bProfit, bComm );
    }
    readedT = StringToTime(bTime);
    while( !FileIsEnding( handle ) )  { // Main cicle
        if( bType == "Buy" ) {
            positivBuff[iBarShift( symbol, period, readedT )] = 0.5;
        } else if( bType == "Sell" ) {
            negativeBuff[iBarShift( symbol, period, readedT )] = -0.5;
        }
        ReadHistoryLine( handle, bTime, bType, bVol, bSym,
                                bPrice, bStop, bTake, bTime2, 
                                bPrice3, bComsn, bSwap, bProfit, bComm );
        readedT = StringToTime(bTime);
    }
    FileClose( handle );
};

void ReadHistoryLine(const int handle,
                     string &b0, string &b1, string &b2, string &b3,
                     string &b4, string &b5, string &b6, string &b7,
                     string &b8, string &b9, string &b10, string &b11, string &b12)
{
    b0 = FileReadString(handle); b1 = FileReadString(handle); b2 = FileReadString(handle); b3 = FileReadString(handle);
    b4 = FileReadString(handle); b5 = FileReadString(handle); b6 = FileReadString(handle); b7 = FileReadString(handle);
    b8 = FileReadString(handle); b9 = FileReadString(handle); b10 = FileReadString(handle); b11 = FileReadString(handle);
    b12 = FileReadString(handle);
};

