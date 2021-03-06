//+---------------------------------------------------------------------------+
//|                                                           MAS_Include.mqh |
//|                                         Copyright 2017, Terentyev Aleksey |
//|                                 https://www.mql5.com/ru/users/terentjew23 |
//+---------------------------------------------------------------------------+
#property copyright     "Copyright 2017, Terentyev Aleksey"
#property link          "https://www.mql5.com/ru/users/terentjew23"
#property strict

//+---------------------------------------------------------------------------+
//| Includes                                                                  |
//+---------------------------------------------------------------------------+
#include                <MovingAverages.mqh>

//+---------------------------------------------------------------------------+
//| Defines                                                                   |
//+---------------------------------------------------------------------------+
enum OptimizationType {
    Off=0,
    Simple = 2,
    Medium = 5,
    Hard = 10
};

enum IndicatorType {
    None,
    Impulse,
    EMAForce,
    MACDHist,
    ThreeScreens_v1_0,
    ThreeScreens_v1_1,
    ThreeScreens_v1_2,
    ThreeScreens_v2_0
};
//+---------------------------------------------------------------------------+
//| Global variables                                                          |
//+---------------------------------------------------------------------------+
ulong       tickCount = 0;

//+---------------------------------------------------------------------------+
//| Functions                                                                 |
//+---------------------------------------------------------------------------+
//+
//+---------------------------------------------------------------------------+
//| System                                                                    |
//+---------------------------------------------------------------------------+
bool NewBar(const int tf = PERIOD_CURRENT)
{
    static datetime lastTime = 0;
    if( tickCount <= 1 )
        return true;
    if( lastTime != iTime( Symbol(), tf, 0 ) ) {      
        lastTime = iTime( Symbol(), tf, 0 );
        return true;
    }
    return false;
};

bool OptimizedSkip(const int skipPeriod = 0)
{
    if( skipPeriod > 0 ) {
        if( tickCount % skipPeriod != 0 ) {
            tickCount++;
            return true;
        } else {
            tickCount++;
        }
    }
    return false;
};

string GetIndicatorString(const IndicatorType type)
{
    switch( type ) {
        case Impulse:           return "Impulse";
        case EMAForce:          return "EMA Force";
        case MACDHist:          return "MACD Histogram";
        case ThreeScreens_v1_0: return "ThreeScreens v1.0";
        case ThreeScreens_v1_1: return "ThreeScreens v1.1";
        case ThreeScreens_v1_2: return "ThreeScreens v1.2";
        case ThreeScreens_v2_0: return "ThreeScreens v2.0";
        default:                return NULL;
    }
};

int SymbolsList(const bool selected, string &symbols[])
{
    string symbolsFileName;
    int symbolsNumber, offset;
    if( selected ) 
        symbolsFileName = "symbols.sel";
    else
        symbolsFileName = "symbols.raw";
    int hFile = FileOpenHistory( symbolsFileName, FILE_BIN|FILE_READ );
    if( hFile < 0 ) 
        return -1;
    if( selected ) {
        symbolsNumber = ( (int)FileSize(hFile) - 4 ) / 128;
        offset = 116;
    } else { 
        symbolsNumber = (int)FileSize(hFile) / 1936;
        offset = 1924;
    }
    ArrayResize( symbols, symbolsNumber );
    if( selected )
        FileSeek( hFile, 4, SEEK_SET );
    for( int i = 0; i < symbolsNumber; i++ ) {
        symbols[i] = FileReadString( hFile, 12 );
        FileSeek( hFile, offset, SEEK_CUR );
    }
    FileClose( hFile );
    return symbolsNumber;
};

//+---------------------------------------------------------------------------+
//| Indicators                                                                |
//+---------------------------------------------------------------------------+
double iMACDHist(const string symbol, const int timeframe,
                 const int fast_ema_period, const int slow_ema_period, const int signal_period,
                 const int applied_price, const int ma_method,
                 const int shift )
{	// Return traditional MACD Histogram
    if( ma_method == MODE_SMA ) {
        return iMACD( symbol, timeframe, fast_ema_period, slow_ema_period, signal_period, applied_price, MODE_MAIN, shift ) - 
                iMACD( symbol, timeframe, fast_ema_period, slow_ema_period, signal_period, applied_price, MODE_SIGNAL, shift );
    }
    if( ma_method == MODE_EMA ) {
        double bufferMACD[], bufferSignal[];
        int bSize = signal_period * 3;
        ArrayResize( bufferMACD, bSize );
        ArrayResize( bufferSignal, bSize );
        bufferSignal[bSize-1] = iMACD( symbol, timeframe, fast_ema_period, slow_ema_period, signal_period, applied_price, MODE_MAIN, shift+bSize-1);
        for( int idx = bSize-2; idx >= 0; idx-- ) {
            bufferMACD[idx] = iMACD( symbol, timeframe, fast_ema_period, slow_ema_period, signal_period, applied_price, MODE_MAIN, shift+idx );
            bufferSignal[idx] = ExponentialMA( idx, signal_period, bufferSignal[idx+1], bufferMACD );
        }
        return bufferMACD[0] - bufferSignal[0];
    }
    return EMPTY_VALUE;
};

double Impulse(const int bar, 
               const string symbol = NULL, const int period = PERIOD_CURRENT,
               const int pEMA = 13, const int pMACD_F = 12, 
               const int pMACD_S = 26, const int pMACD_Sig = 9)
{   // Impulse indicator.  ©Alexander Elder
    double ema0 = iMA( symbol, period, pEMA, 0, MODE_EMA, PRICE_CLOSE, bar );
    double ema1 = iMA( symbol, period, pEMA, 0, MODE_EMA, PRICE_CLOSE, bar+1 );
    double macd0 = iMACDHist( symbol, period, pMACD_F, pMACD_S, pMACD_Sig, PRICE_CLOSE, MODE_EMA, bar );
    double macd1 = iMACDHist( symbol, period, pMACD_F, pMACD_S, pMACD_Sig, PRICE_CLOSE, MODE_EMA, bar+1 );
    if( ema1 < ema0 && macd1 < macd0 )
        return 1.0;         // Impulse Up
    if( ema1 > ema0 && macd1 > macd0 )
        return -1.0;        // Impulse Down
    return 0.0;
};

double EMAForce(const int bar, 
                const string symbol = NULL, const int period = PERIOD_CURRENT,
                const int fiboBegin = 3, const int fiboCount = 10,
                const ENUM_MA_METHOD method = MODE_EMA, const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
{   // Indicator EMA Force. ©Aleksey Terentyev (not ended)
    static int  fiboPref = 1;
    double      fiboArray[20], result = 0.0;
    while( Fibonacci(fiboPref) < fiboBegin ) {
        fiboPref++;
    }
    for( int idx = 1; idx < fiboCount; idx++ ) {
        result += iMACD( symbol, period, Fibonacci( fiboPref + idx - 1 ), Fibonacci( fiboPref + idx ),
                         Fibonacci( fiboPref + idx - 2 ), price, MODE_MAIN, bar );
        //fiboArray[idx] = iMA( symbol, period, GetFibonacci( fiboPref + idx ), 0, method, price, bar );
        //if( idx == 1 && fiboArray[0] > fiboArray[idx] )
        //    result += 0.1;
        //if( idx == 1 && fiboArray[0] < fiboArray[idx] )
        //    result -= 0.1;
        //if( idx > 0 && fiboArray[0] > fiboArray[idx] && result > 0.0 )
        //    result += 0.1;
        //if( idx > 0 && fiboArray[0] < fiboArray[idx] && result < 0.0 )
        //    result -= 0.1;
    }
    return result;
};

double ThreeScreens_v1_0(const int bar, 
                         const string symbol = NULL, const int period = PERIOD_CURRENT,
                         const int pEMA_D1 = 26, // const int pEMA_D2 = 13,
                         const int pMACD_F = 12, const int pMACD_S = 26, const int pMACD_Sig = 9)
{   // Three Screens system indicator.  ©Alexander Elder
    // Display #1
    int periodD1 = GetMorePeriodX5( (ENUM_TIMEFRAMES)period );
    int barD1 = GetIndexFromTime( iTime(symbol, period, bar), symbol, periodD1 );
    double impulseD1 = Impulse( barD1, symbol, periodD1, pEMA_D1, pMACD_F, pMACD_S, pMACD_Sig );
    // Display #2 (Main)
    double impulseD2 = Impulse( bar, symbol, period, pEMA_D1, pMACD_F, pMACD_S, pMACD_Sig );
    double macdD2 = iMACD( symbol, period, pMACD_F, pMACD_S, pMACD_Sig, PRICE_CLOSE, MODE_MAIN, bar );
    if( impulseD1 > 0.0 && macdD2 <= 0.0 ) {
        if( impulseD2 >= 0.0 ) {
            return 1.0;     // Signal Buy
        } else {
            return 0.5;
        }
    }
    if( impulseD1 < 0.0 && macdD2 >= 0.0 ) {
        if( impulseD2 <= 0.0 ) {
            return -1.0;    // Signal Sell
        } else {
            return -0.5;
        }
    }
    return 0.0;
};

double ThreeScreens_v1_1(const int bar, 
                         const string symbol = NULL, const int period = PERIOD_CURRENT,
                         const int pEMA_D1 = 26, // const int pEMA_D2 = 13, 
                         const int pMACD_F = 12, const int pMACD_S = 26, const int pMACD_Sig = 9)
{   // Three Screens system indicator.  ©Alexander Elder
    // Display #1
    int periodD1 = GetMorePeriodX5( (ENUM_TIMEFRAMES)period );
    int barD1 = GetIndexFromTime( iTime(symbol, period, bar), symbol, periodD1 );
    double impulseD1 = Impulse( barD1, symbol, periodD1, pEMA_D1, pMACD_F, pMACD_S, pMACD_Sig );
    // Display #2 (Main)
    double impulseD2 = Impulse( bar, symbol, period, pEMA_D1, pMACD_F, pMACD_S, pMACD_Sig );
    double macdD2 = iMACDHist( symbol, period, pMACD_F, pMACD_S, pMACD_Sig, PRICE_CLOSE, MODE_EMA, bar );
    if( impulseD1 > 0.0 && macdD2 <= 0.0 ) {
        if( impulseD2 >= 0.0 ) {
            return 1.0;     // Signal Buy
        } else {
            return 0.5;
        }
    }
    if( impulseD1 < 0.0 && macdD2 >= 0.0 ) {
        if( impulseD2 <= 0.0 ) {
            return -1.0;    // Signal Sell
        } else {
            return -0.5;
        }
    }
    return 0.0;
};

double ThreeScreens_v1_2(const int bar, 
                         const string symbol = NULL, const int period = PERIOD_CURRENT,
                         const int pEMA_D1 = 26, // const int pEMA_D2 = 13, 
                         const int pMACD_F = 12, const int pMACD_S = 26, const int pMACD_Sig = 9)
{   // Three Screens system indicator.  ©Alexander Elder
    // Display #1
    int periodD1 = GetMorePeriodX5( (ENUM_TIMEFRAMES)period );
    int barD1 = GetIndexFromTime( iTime(symbol, period, bar), symbol, periodD1 );
    double impulseD1 = Impulse( barD1, symbol, periodD1, pEMA_D1, pMACD_F, pMACD_S, pMACD_Sig );
    // Display #2 (Main)
    double impulseD2 = Impulse( bar, symbol, period, pEMA_D1, pMACD_F, pMACD_S, pMACD_Sig );
    double macdLineD2 = iMACD( symbol, period, pMACD_F, pMACD_S, pMACD_Sig, PRICE_CLOSE, MODE_MAIN, bar );
    double macdHistD2 = iMACDHist( symbol, period, pMACD_F, pMACD_S, pMACD_Sig, PRICE_CLOSE, MODE_EMA, bar );
    if( impulseD1 > 0.0 && ( macdLineD2 <= 0.0 || macdHistD2 <= 0.0 ) ) {
        if( impulseD2 >= 0.0 ) {
            return 1.0;     // Signal Buy
        } else {
            return 0.5;
        }
    }
    if( impulseD1 < 0.0 && ( macdLineD2 >= 0.0 || macdHistD2 >= 0.0 ) ) {
        if( impulseD2 <= 0.0 ) {
            return -1.0;    // Signal Sell
        } else {
            return -0.5;
        }
    }
    return 0.0;
};

double ThreeScreens_v2_0(const int bar, 
                         const string symbol = NULL, const int period = PERIOD_CURRENT,
                         const int pEMA_D1 = 26, //const int pEMA_D2 = 13, 
                         const int pMACD_F = 12, const int pMACD_S = 26, const int pMACD_Sig = 9)
{   // Three Screens system indicator.  ©Alexander Elder
    // Display #1
    double ema0 = iMA( symbol, period, pEMA_D1*5, 0, MODE_EMA, PRICE_CLOSE, bar );
    double ema1 = iMA( symbol, period, pEMA_D1*5, 0, MODE_EMA, PRICE_CLOSE, bar+5 );
    double macd0;// = iMACD( symbol, period, pMACD_F*5, pMACD_S*5, pMACD_Sig, PRICE_CLOSE, MODE_MAIN, bar );
    double macd1;// = iMACD( symbol, period, pMACD_F*5, pMACD_S*5, pMACD_Sig, PRICE_CLOSE, MODE_MAIN, bar+5 );
    double impulseD1 = 0.0;
    double bufferD1[];
    double bufferFast[], bufferSlow[];
    double bufferMACD[], bufferMACDEMA[], bufferMACDGist[];
    int bSize = pMACD_S * 2;
    ArrayResize( bufferD1, bSize );
    ArrayResize( bufferFast, bSize );
    ArrayResize( bufferSlow, bSize );
    ArrayResize( bufferMACD, bSize );
    ArrayResize( bufferMACDEMA, bSize );
    ArrayResize( bufferMACDGist, bSize );
    for( int idx = 0; idx < bSize; idx++ ) {
        bufferD1[bSize-idx-1] = iClose( symbol, period, bar + idx * 5 );
    }
    ExponentialMAOnBuffer( bSize, 0, 0, pMACD_F, bufferD1, bufferFast );
    ExponentialMAOnBuffer( bSize, 0, 0, pMACD_S, bufferD1, bufferSlow );
    for( int idx = 0; idx < bSize; idx++ ) {
        bufferMACD[idx] = bufferFast[idx] - bufferSlow[idx];
    }
    ExponentialMAOnBuffer( bSize, 0, 0, pMACD_Sig, bufferMACD, bufferMACDEMA );
    for( int idx = 0; idx < bSize; idx++ ) {
        bufferMACDGist[idx] = bufferMACD[idx] - bufferMACDEMA[idx];
    }
    macd1 = bufferMACDGist[bSize-2]; macd0 = bufferMACDGist[bSize-1];
    if( ema1 < ema0 && macd1 < macd0 ) {
        impulseD1 = 1.0;         // Impulse Up
    }
    if( ema1 > ema0 && macd1 > macd0 ) {
        impulseD1 = -1.0;        // Impulse Down
    }
    // Display #2 (Main)
    double impulseD2 = Impulse( bar, symbol, period, pEMA_D1, pMACD_F, pMACD_S, pMACD_Sig );
    double macdD2 = iMACDHist( symbol, period, pMACD_F, pMACD_S, pMACD_Sig, PRICE_CLOSE, MODE_EMA, bar );
    if( impulseD1 > 0.0 && macdD2 <= 0.0 ) {
        if( impulseD2 >= 0.0 ) {
            return 1.0;     // Signal Buy
        } else {
            return 0.5;
        }
    }
    if( impulseD1 < 0.0 && macdD2 >= 0.0 ) {
        if( impulseD2 <= 0.0 ) {
            return -1.0;    // Signal Sell
        } else {
            return -0.5;
        }
    }
    return 0.0;
};

//+---------------------------------------------------------------------------+
//| Levels                                                                    |
//+---------------------------------------------------------------------------+
double StopBuy(const int bar, const double meanMulty = 3.0,
               const string symbol = NULL, const int period = PERIOD_CURRENT)
{
    if( bar <= -2 || bar + 10 >= iBars( symbol, period ) )
        return EMPTY_VALUE;     // Out off range
    double  breakDown = 0.0, sumBD = 0.0;
    int     countBD = 0;
    for( int idx = 10; idx >= 1; idx-- ) {
        breakDown = iLow( symbol, period, bar+idx+1 ) - iLow( symbol, period, bar+idx );
        if( breakDown > 0 ) {
            sumBD += breakDown;
            countBD++;
        }
    }
    if( countBD == 0 )
        return iLow( symbol, period, bar+1 ) - fabs( breakDown ) * meanMulty;
    return     iLow( symbol, period, bar+1 ) - (sumBD / countBD) * meanMulty;
};

double StopBuyMax(const int bar, const double meanMulty = 3.0,
                  const string symbol = NULL, const int period = PERIOD_CURRENT)
{
    if( bar <= -2 || bar + 13 >= iBars( symbol, period ) )
        return EMPTY_VALUE;     // Out off range
    double bs[3];
    bs[2] = StopBuy( bar+2, meanMulty, symbol, period );
    bs[1] = StopBuy( bar+1, meanMulty, symbol, period );
    bs[0] = StopBuy( bar, meanMulty, symbol, period );
    return bs[0]>bs[1] ? (bs[0]>bs[2] ? bs[0] : bs[2]) : (bs[1]>bs[2] ? bs[1] : bs[2]); // maximum
};

double StopSell(const int bar, const double meanMulty = 3.0,
                const string symbol = NULL, const int period = PERIOD_CURRENT)
{
    if( bar <= -2 || bar + 10 >= iBars( symbol, period ) )
        return EMPTY_VALUE;     // Out off range
    double  breakUp = 0.0, sumBU = 0.0;
    int     countBU = 0;
    for( int idx = 10; idx >= 1; idx-- ) {
        breakUp = iHigh( symbol, period, bar+idx ) - iHigh( symbol, period, bar+idx+1 );
        if( breakUp > 0 ) {
            sumBU += breakUp;
            countBU++;
        }
    }
    if( countBU == 0 )
        return iHigh( symbol, period, bar+1 ) + fabs( breakUp ) * meanMulty;
    return     iHigh( symbol, period, bar+1 ) + (sumBU / countBU) * meanMulty;
};

double StopSellMin(const int bar, const double meanMulty = 3.0,
                   const string symbol = NULL, const int period = PERIOD_CURRENT)
{
    if( bar <= -2 || bar + 13 >= iBars( symbol, period ) )
        return EMPTY_VALUE;     // Out off range
    double ss[3];
    ss[2] = StopSell( bar+2, meanMulty, symbol, period );
    ss[1] = StopSell( bar+1, meanMulty, symbol, period );
    ss[0] = StopSell( bar, meanMulty, symbol, period );
    return ss[0]<ss[1] ? (ss[0]<ss[2] ? ss[0] : ss[2]) : (ss[1]<ss[2] ? ss[1] : ss[2]); // minimum
};

//+---------------------------------------------------------------------------+
//| Mathematic                                                                |
//+---------------------------------------------------------------------------+
int Fibonacci(const int index)
{
    if( index == 1 || index == 2 ) 
        return 1;
    int result = 1;
    int last = 1;
    for( int idx = 3; idx <= index; idx++ ) {
        int tmp = result;
        result += last;
        last = tmp;
    }
    return result;
};

template<typename T>
void MathSwap(T &l,T &r)
{
	T tmp=l;
	l = r;
	r = tmp;
};

//+---------------------------------------------------------------------------+
//| String                                                                    |
//+---------------------------------------------------------------------------+
int StringSplitMAS(const string string_value, const ushort separator, string &result[][64])
{
    if( StringLen( string_value ) <= 0 || string_value == NULL )
        return 0;
    int lastChar = 0, currentChar = 0, size = StringLen(string_value), sizeRes = 0, sepIdxs[50];
    ArrayInitialize( sepIdxs, 0 );
    for( int idx = 0; idx < size; idx++) {
        if( StringGetChar(string_value, idx) == separator ) {
            sepIdxs[sizeRes] = idx;
            sizeRes += 1;
            if( sizeRes >= ArraySize(sepIdxs) )
                ArrayResize( sepIdxs, ArraySize(sepIdxs) + 50 );
        }
    }
    ArrayResize( result, sizeRes + 1 );
    if( sizeRes == 0 ) {
        result[sizeRes][0] = string_value;
        return sizeRes + 1;
    }
    for( int idx = 0; idx <= sizeRes; idx++) {
        if( idx == 0 ) {
            result[idx][0] = StringSubstr( string_value, 0, sepIdxs[idx] );
            continue;
        }
        result[idx][0] = StringSubstr( string_value, sepIdxs[idx-1] + 1, 
                                                     sepIdxs[idx] - sepIdxs[idx-1] - 1 );
    }
    return sizeRes + 1;
};

double StrToDbl(const string str)
{
    int i, k = 1;
    double r = 0, p = 1;
    for( i = 0; i < StringLen(str); i++ ) {
        if( k < 0 )
			p = p * 10;
        if( StringGetChar( str, i ) == '.' )
            k = -k;
        else
            r = r * 10 + ( StringGetChar( str, i ) - '0' );
    }
    return r / p;
};

//+---------------------------------------------------------------------------+
//| Timeseries & Market data                                                  |
//+---------------------------------------------------------------------------+
double Convert(const double value, const string origin, const string target)
{   // Return converted value from origin to target symbol
    if( origin == target ) {
        return value;
    }
    const string prefx = StringSubstr( Symbol(), 6 );
    string symbol = origin + target + prefx;
    if( MarketInfo( symbol, MODE_BID ) > 0.0 ) {
        return value / MarketInfo( symbol, MODE_BID );
    }
    symbol = target + origin + prefx;
    if( MarketInfo( symbol, MODE_BID ) > 0.0 ) {
        return value * MarketInfo( symbol, MODE_BID );
    }
    Print( "Convert error: ", value, " ", origin, " -> ", target, "." );
    return 0.0;
};

int GetIndexFromTime(const datetime time_bar, 
                     const string symbol = NULL, const int period = PERIOD_CURRENT)
{
    int index = 0;
    while( time_bar <= iTime( symbol, period, index ) )
        index++;
    return index;
};

ENUM_TIMEFRAMES GetMorePeriod(const ENUM_TIMEFRAMES period){
    int tmp = period == 0 ? Period() : period;
    switch( tmp ) {
        case PERIOD_M1:  return(PERIOD_M5);
        case PERIOD_M5:  return(PERIOD_M15);
        case PERIOD_M15: return(PERIOD_M30);
        case PERIOD_M30: return(PERIOD_H1);
        case PERIOD_H1:  return(PERIOD_H4);
        case PERIOD_H4:  return(PERIOD_D1);
        case PERIOD_D1:  return(PERIOD_W1);
        case PERIOD_W1:  return(PERIOD_MN1);
        case PERIOD_MN1: return(PERIOD_MN1);
        default:         return(PERIOD_CURRENT);
    }
};

ENUM_TIMEFRAMES GetLessPeriod(const ENUM_TIMEFRAMES period){
    int tmp = period == 0 ? Period() : period;
    switch( tmp ) {
        case PERIOD_M1:  return(PERIOD_M1);
        case PERIOD_M5:  return(PERIOD_M1);
        case PERIOD_M15: return(PERIOD_M5);
        case PERIOD_M30: return(PERIOD_M15);
        case PERIOD_H1:  return(PERIOD_M30);
        case PERIOD_H4:  return(PERIOD_H1);
        case PERIOD_D1:  return(PERIOD_H4);
        case PERIOD_W1:  return(PERIOD_D1);
        case PERIOD_MN1: return(PERIOD_W1);
        default:         return(PERIOD_CURRENT);
    }
};

ENUM_TIMEFRAMES GetMorePeriodX5(const ENUM_TIMEFRAMES period){
    int tmp = period == 0 ? Period() : period;
    switch( tmp ) {
        case PERIOD_M1:  return(PERIOD_M5);
        case PERIOD_M5:  return(PERIOD_M30);
        case PERIOD_M15: return(PERIOD_H1);
        case PERIOD_M30: return(PERIOD_H4);
        case PERIOD_H1:  return(PERIOD_H4);
        case PERIOD_H4:  return(PERIOD_D1);
        case PERIOD_D1:  return(PERIOD_W1);
        case PERIOD_W1:  return(PERIOD_MN1);
        case PERIOD_MN1: return(PERIOD_MN1);
        default:         return(PERIOD_CURRENT);
    }
};

ENUM_TIMEFRAMES GetLessPeriodX5(const ENUM_TIMEFRAMES period){
    int tmp = period == 0 ? Period() : period;
    switch( tmp ) {
        case PERIOD_M1:  return(PERIOD_M1);
        case PERIOD_M5:  return(PERIOD_M1);
        case PERIOD_M15: return(PERIOD_M5);
        case PERIOD_M30: return(PERIOD_M5);
        case PERIOD_H1:  return(PERIOD_M15);
        case PERIOD_H4:  return(PERIOD_H1);
        case PERIOD_D1:  return(PERIOD_H4);
        case PERIOD_W1:  return(PERIOD_D1);
        case PERIOD_MN1: return(PERIOD_W1);
        default:         return(PERIOD_CURRENT);
    }
};

