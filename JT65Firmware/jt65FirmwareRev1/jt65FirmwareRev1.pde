
// Version JT65V006
// 22-November-2013
// Added code is;
// (c) J C Large - W6CQZ internal development use only
//
// This firmware makes Rebel totally remote controlled.
// All but the power and audio volume controls do zero
// zilch nada NOTHING when this is running.
//
// Built on the A0.2 clean firmware with EVERYTHING not
// necessary for this one specific purpose removed.
//
// I *did* leave the defines and variables for lots of
// things not currently used as I have uses for some
// coming up.
//

// Get all the includes up top - seems to fix some strange
// compiler issues if I do it here.
#include <morse.h>
#include <TinyGPS.h>
#include <LCD5110_Basic.h>
#include <Wire.h>
#include <Streaming.h>  // Needed by CmdMessenger
#include <CmdMessenger.h>

// various defines
#define SDATA_BIT                           10          //  keep!
#define SCLK_BIT                            8           //  keep!
#define FSYNC_BIT                           9           //  keep!
#define RESET_BIT                           11          //  keep!
#define FREQ_REGISTER_BIT                   12          //  keep!
#define AD9834_FREQ0_REGISTER_SELECT_BIT    0x4000      //  keep!
#define AD9834_FREQ1_REGISTER_SELECT_BIT    0x8000      //  keep!
#define FREQ0_INIT_VALUE                    0x01320000  //  ?
// flashes when button pressed  for testing  keep!
#define led                                 13   
#define Side_Tone                           3           // maybe to be changed to a logic control
// for a separate side tone gen
#define TX_Dah                              33          //  keep!
#define TX_Dit                              32          //  keep!
#define TX_OUT                              38          //  keep!
#define Band_End_Flash_led                  24          // // also this led will flash every 100/1khz/10khz is tuned
#define Band_Select                         41          // if shorting block on only one pin 20m(1) on both pins 40m(0)
#define Multi_Function_Button               2           //
#define Multi_function_Green                34          // For now assigned to BW (Band width)
#define Multi_function_Yellow               35          // For now assigned to STEP size
#define Multi_function_Red                  36          // For now assigned to USER
#define Select_Button                       5           // 
#define Select_Green                        37          // Wide/100/USER1
#define Select_Yellow                       39          // Medium/1K/USER2
#define Select_Red                          40          // Narrow/10K/USER3
#define Medium_A8                           22          // Hardware control of I.F. filter Bandwidth
#define Narrow_A9                           23          // Hardware control of I.F. filter Bandwidth
#define Wide_BW                             0           // About 2.1 KHZ
#define Medium_BW                           1           // About 1.7 KHZ
#define Narrow_BW                           2           // About 1 KHZ
#define Step_100_Hz                         0
#define Step_1000_hz                        1
#define Step_10000_hz                       2
#define  Other_1_user                       0           // 
#define  Other_2_user                       1           //
#define  Other_3_user                       2           //
#define W6CQZ                               0           // Special functions just for me. 

const int ROMVERSION        = 1001; // Defines this firmware revision level - not bothering with major.minor 0 to max_int_value "should" be enough space. :)

const int RitReadPin        = A0;  // pin that the sensor is attached to used for a rit routine later.
int RitReadValue            = 0;
int RitFreqOffset           = 0;

const int SmeterReadPin     = A1;  // To give a realitive signal strength based on AGC voltage.
int SmeterReadValue         = 0;

const int BatteryReadPin    = A2;  // Reads 1/5 th or 0.20 of supply voltage.
int BatteryReadValue        = 0;

const int PowerOutReadPin   = A3;  // Reads RF out voltage at Antenna.
int PowerOutReadValue       = 0;

const int CodeReadPin       = A6;  // Can be used to decode CW. 
int CodeReadValue           = 0;

const int CWSpeedReadPin    = A7;  // To adjust CW speed for user written keyer.
int CWSpeedReadValue        = 0;            

int TX_key;

int band_sel;                               // select band 40 or 20 meter
int band_set;
int bsm;  

int Step_Select_Button          = 0;
int Step_Select_Button1         = 0;
int Step_Multi_Function_Button  = 0;
int Step_Multi_Function_Button1 = 0;

int Selected_BW                 = 0;    // current Band width 
// 0= wide, 1 = medium, 2= narrow
int Selected_Step               = 0;    // Current Step
int Selected_Other              = 0;    // To be used for anything

//--------------------------------------------------------
// Encoder Stuff 
const int encoder0PinA          = 7;
const int encoder0PinB          = 6;

int val; 
int encoder0Pos                 = 0;
int encoder0PinALast            = LOW;
int n                           = LOW;

//------------------------------------------------------------
// Once tested as viable this will likely change to 9MHz = LO + RX RF for LO range of 2.0 MHz [RX 7.0] ... 1.7 [RX 7.3]
// Or if you'd rather 9-Desired RX = LO = 9-7.0=2 ... 9-7.3=1.7 for low side injection to get RX USB referenced at IF.
// Only works on paper so far.
const long meter_160            = 7162000;
// LOW side injection 160 meter
// range 9 - 1.8 ... 9 - 2.0 -> 7.2 ... 7.0

const long meter_80             = 5424000;
// LOW side injection 80 meter
// range 9 - 3.5 ... 9 - 4.0 -> 5.5 ... 5

const long meter_40             = 1924000;     // IF - Band frequency, LOW Side Inject JT65
// LOW side injection 40 meter 
// range 9 - 7 ... 9 - 7.3 -> 2.0 ... 1.7

const long meter_30             = 1139000;
// LOW side injection 30 meter
// range 10.1 - 9 ... 10.150 - 9 -> 1.1 ... 1.15

const long meter_20             = 5076000;      // Band frequency - IF, LOW Side Inject JT65
// LOW side injection 20 meter 
// range 14 - 9 ... 14.35 - 9 -> 5 ... 5.35

const long meter_17             = 9102000;
// LOW side injection 17 meter
// range 18.068 - 9 ... 18.168 - 9 -> 9.068 ... 9.168

const long meter_15             = 12076000;
// LOW side injection 15 meter
// range 21.000 - 9 ... 21.450 - 9 -> 12 ... 12.45

const long meter_12             = 15917000;
// LOW side injection 15 meter
// range 24.890 - 9 ... 24.990 - 9 -> 15.89 ... 15.99

const long meter_10             = 19076000;
// LOW side injection 10 meter
// range 28.000 - 9 ... 29.700 - 9 -> 19 ... 20.7


const long Reference            = 49999750;     // for ad9834 this may be tweaked in software to fine tune the Radio

long RIT_frequency;
long RX_frequency; 
long save_rec_frequency;
long frequency_step;
long frequency                  = 0;
long frequency_old              = 0;
long frequency_tune             = 0;
long frequency_default          = 0;
unsigned long fcalc0;                               // Tuning word register 0 0 seems to be RX
unsigned long fcalc1;                               // Tuning word register 1 1 seems to be TX
long IF                         = 9.00e6;          //  I.F. Frequency

//------------------------------------------------------------
// Debug Stuff
unsigned long loopCount         = 0;
unsigned long lastLoopCount     = 0;
unsigned long loopsPerSecond    = 0;
unsigned int  printCount        = 0;
unsigned long loopStartTime     = 0;
unsigned long loopElapsedTime   = 0;
float         loopSpeed         = 0;
unsigned long LastFreqWriteTime = 0;

// CWID
LEDMorseSender cqSender(TX_OUT);

// GPS 
#define gps_reset_pin  4  //GPS Reset control
#define GPS Serial    //so we can use Serial 1 if we want
unsigned long fix_age;
TinyGPS tgps;
int year;
byte month, day, hour, minute, second, hundredths;
long lat, lon;
float LAT, LON;
char GPSbyte;
String s_date, s_time, s_month, s_year, s_day, s_hour, s_minute, s_second, s_hundredths;
char A_Z[27] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
char a_z[27] = "abcdefghijklmnopqrstuvwxyz";
String grid_text;
char grid[6];
boolean gps_ok;  // gps data ok flag
int gps_tick = 0;  // GPS timeout 
int gps_altitude;
int gps_timeout = 120;  // 120 seconds to give GPS time to lock
unsigned long time, date, speed, course;
unsigned long chars;
unsigned short sentences, failed_checksum;

// --------------------------------------------
// Glen's GPS routines

bool feedgps(){
  while (GPS.available())
  {
    GPSbyte = GPS.read();
    //Serial.print(GPSbyte); // Uncomment for GPS Message Printout

  if (tgps.encode(GPSbyte))
      return true;
  }
  return 0;
}

void gpsdump(TinyGPS &tgps)
{
  //byte month, day, hour, minute, second, hundredths;
  tgps.get_position(&lat, &lon);
  LAT = lat;
  LON = lon;
  {
    feedgps(); // If we don't feed the gps during this long routine, we may drop characters and get checksum errors
  }
}

void getGPS(){
  bool newdata = false;

    if (feedgps ()){
      newdata = true;
    }
  if (newdata)
  {
    gpsdump(tgps);
  }
}

void GridSquare(float latitude,float longtitude)
{
  // Maidenhead Grid Square Calculation
  float lat_0,lat_1, long_0, long_1, lat_2, long_2, lat_3, long_3,calc_long, calc_lat, calc_long_2, calc_lat_2, calc_long_3, calc_lat_3;
  lat_0 = latitude/1000000;
  long_0 = longtitude/1000000;
  grid_text = " ";
  int grid_long_1, grid_lat_1, grid_long_2, grid_lat_2, grid_long_3, grid_lat_3;
  // Begin Calcs
  calc_long = (long_0 + 180);
  calc_lat = (lat_0 + 90);
  long_1 = calc_long/20;
  lat_1 = (lat_0 + 90)/10;
  grid_lat_1 = int(lat_1);
  grid_long_1 = int(long_1);
  calc_long_2 = (long_0+180) - (grid_long_1 * 20);
  long_2 = calc_long_2 / 2;
  lat_2 = (lat_0 + 90) - (grid_lat_1 * 10);
  grid_long_2 = int(long_2);
  grid_lat_2 = int(lat_2);
  calc_long_3 = calc_long_2 - (grid_long_2 * 2);
  long_3 = calc_long_3 / .083333;
  grid_long_3 = int(long_3);
  lat_3 = (lat_2 - int(lat_2)) / .0416665;
  grid_lat_3 = int(lat_3);
  // Here's the first 2 characters of Grid Square - place into array
  grid[0] = A_Z[grid_long_1]; 
  grid[1] = A_Z[grid_lat_1];
  // The second set of the grid square
  grid[2] = (grid_long_2 + 48);
  grid[3] = (grid_lat_2 + 48);
  // The final 2 characters
  grid[4] = a_z[grid_long_3];
  grid[5] = a_z[grid_lat_3];
  grid_text = grid;
  return;
}
// --- End of GPS routines ---

// Nokia 5110 Pin Assignments
#define GLCD_SCK   30
#define GLCD_MOSI  29
#define GLCD_DC    28
#define GLCD_RST   26
#define GLCD_CS    27

// Nokia 5110 LCD Display

LCD5110 glcd(GLCD_SCK,GLCD_MOSI,GLCD_DC,GLCD_RST,GLCD_CS);

extern unsigned char SmallFont[];

const char txt3[8]          = "100 HZ ";
const char txt4[8]          = "1 KHZ  ";
const char txt5[8]          = "10 KHZ ";
const char txt52[5]         = " ";
const char txt57[6]         = "FREQ:" ;
const char txt60[6]         = "STEP:";
const char txt62[3]         = "RX";
const char txt64[4]         = "RIT";
const char txt65[5]         = "Band";
const char txt66[4]         = "20M";
const char txt67[4]         = "40M";
const char txt68[3]         = "TX";
const char txt69[2]         = "W";
const char txt70[2]         = "M";
const char txt71[2]         = "N";
const char txt72[4]         = "100";
const char txt73[4]         = " 1K";
const char txt74[4]         = "10K";

//-------------------------------------------------------------------- 
// 10-10-2013 W6CQZ
// Adding array to hold transmit FSK values and handler for cmdMessenger serial control library
unsigned long fsk65Vals[128];  // 126 JT65 symbols + 2 spares :) See notes in loader code for +2 logic.
boolean jt65TXOn = false; // If true immediately start sending FSK set in fsk65Vals[0..125]
boolean jt65Valid = false; // Do NOT attempt JT mode TX unless this is true - remains false until a valid TX set is uploaded.
unsigned int jt65Sym = 0; // Index to where we are in the symbol TX chain

unsigned long fsk9Vals[88]; // ## JT9 fsk symbols - same logic as JT65 - uploading FSK vals in chunks of 4 so buffer needs to be multiple 4 (3 spares)
boolean jt9TXOn = false; // If true immediately start sending FSK set in fsk65Vals[0..125]
boolean jt9Valid = false; // Do NOT attempt JT mode TX unless this is true - remains false until a valid TX set is uploaded.
unsigned int jt9Sym = 0; // Index to where we are in the symbol TX chain

int rxOffset = 718; // Value to offset RX for correction DO NOT blindly trust this will be correct for your Rebel.
int txOffset = -50; // Value to offset TX for correction DO NOT blindly trust this will be correct for your Rebel.
boolean flipflop = true; // Testing something
long symoffset = 0;                // Begin at this Index on start TX
boolean txcwid = false; // When true will fire off CWID in string cwid next pass through loop at frequency set in command.
boolean txstat = false; // Any time TX is invoked set true
unsigned long cwidqrg = 0;  // DDS tuning word for CWID QRG
//char cwid[14]; // Holds CW ID text - up to 14 characters.
String cwid = "";
CmdMessenger cmdMessenger = CmdMessenger(Serial);
// Commands for rig control
enum
{
  kError,
  kAck,
  gVersion,
  gDDSVer,
  gDDSRef,
  sLockPanel,
  sUnlockPanel,
  gloopSpeed,
  gRXOffset,
  gTXOffset,
  sRXOffset,
  sTXOffset,
  gBand,
  gRXFreq,
  sRXFreq,
  gTXStatus,
  sTXOn,
  sTX9On,
  sTXOff,
  sDTXOn,
  sD9TXOn,
  sDoCWID,
  gClearTX,
  sTXFreq,
  gLoadTXBlock,
  gLoad9TXBlock,
  gFSKVals,
  gFSK9Vals,
  gGPSGrid,
  gGPSTime,
};
// Define the command callback routines
void attachCommandCallbacks()
{
  cmdMessenger.attach(OnUnknownCommand);              // Catch all in case of garbage/bad command - does nothing but ignore junk.                                              Command ID
  cmdMessenger.attach(gVersion, onGVersion);           // Get firmware version                                                                                           2
  cmdMessenger.attach(gDDSVer, onGDDSVer);             // Get DDS type                                                                                                   3
  cmdMessenger.attach(gDDSRef, onGDDSRef);             // Get DDS reference QRG                                                                                          4
  cmdMessenger.attach(sLockPanel, onSLockPanel);       // Lock out controls (going away - default is locked and stay locked)                                             5
  cmdMessenger.attach(sUnlockPanel, onSUnlockPanel);   // Unlock panel controls (use with caution!)                                                                      6
  cmdMessenger.attach(gloopSpeed, onLoopSpeed);        // Get main loop execution speed as string                                                                        7
  cmdMessenger.attach(gRXOffset, onGRXOffset);         // Get RX offset value                                                                                            8
  cmdMessenger.attach(gTXOffset, onGTXOffset);         // Get TX offset value                                                                                            9
  cmdMessenger.attach(sRXOffset, onSRXOffset);         // Set RX offset for correcting CW RX offset built into 2nd LO/mixer                                             10
  cmdMessenger.attach(sTXOffset, onSTXOffset);         // Set TX offset (usually 0 but if you want to calibrate the Rebel this value will do it, not the RX offset!     11
  cmdMessenger.attach(gBand, onGBand);                 // Get Band                                                                                                      12
  cmdMessenger.attach(gRXFreq, onGRXFreq);             // Get RX QRG                                                                                                    13
  cmdMessenger.attach(sRXFreq, onSRXFreq);             // Set RX QRG with DDS tuning word                                                                               14
  cmdMessenger.attach(gTXStatus, onGTXStatus);         // Get TX status, on or off - JT65 or JT9                                                                        15
  cmdMessenger.attach(sTXOn, onSTXOn);                 // Start TX - JT65                                                                                               16
  cmdMessenger.attach(sTX9On, onS9TXOn);               // Start TX - JT9                                                                                                17
  cmdMessenger.attach(sTXOff, onSTXOff);               // Stop TX - JT65 or JT9                                                                                         18
  cmdMessenger.attach(sDTXOn, onSDTXOn);               // Begin delayed TX at offset given - JT65                                                                       19
  cmdMessenger.attach(sD9TXOn, onSD9TXOn);             // Begin delayed TX at offset given - JT9                                                                        20
  cmdMessenger.attach(sDoCWID, onDoCWID);              // Send CW ID with string provided after current JT65 or JT9 TX is completed                                     21
  cmdMessenger.attach(gClearTX, onGClearTX);           // Clear FSK tuning word array - Clears JT9 and JT65 FSK Array                                                   22
  cmdMessenger.attach(sTXFreq, onSTXFreq);             // Request to setup TX array - JT65                                                                              23
  cmdMessenger.attach(gLoadTXBlock, onGLoadTXBlock);   // FSK tuning word loader setup - JT65 format                                                                    24
  cmdMessenger.attach(gLoad9TXBlock, onG9LoadTXBlock); // FSK tuning word loader - JT9 format                                                                           25
  cmdMessenger.attach(gFSKVals, onGFSKVals);           // Return current loaded FSK array - JT65                                                                        26
  cmdMessenger.attach(gFSK9Vals, onG9FSKVals);         // Return current loaded FSK array - JT9                                                                         27
  cmdMessenger.attach(gGPSGrid, onGGPSGrid);           // Get Grid from GPS                                                                                             28
  cmdMessenger.attach(gGPSTime, onGGPSTime);           // Get Time from GPS                                                                                             29
}
// --- End of cmdMessenger definition/setup ---

void setup() 
{
  for(jt65Sym=0; jt65Sym<128; jt65Sym++) {fsk65Vals[jt65Sym]=0;}  // 126 JT65 symbols + 2 spares :) See notes in loader code for +2 logic.
  for(jt9Sym=0; jt9Sym<88; jt9Sym++) {fsk9Vals[jt9Sym]=0;} // 85 JT9 symbols + 3 spares.  Same logic on +3 as above.
  jt65TXOn = false; // If true immediately start sending FSK set in fskVals[0..125]
  jt65Valid = false; // Do NOT attempt JT mode TX unless this is true - remains false until a valid TX set is uploaded.
  jt9TXOn = false; // If true immediately start sending FSK set in fskVals[0..125]
  jt9Valid = false; // Do NOT attempt JT mode TX unless this is true - remains false until a valid TX set is uploaded.
  jt65Sym = 0; // Index to where we are in the symbol TX chain
  jt9Sym = 0; // Index to where we are in the symbol TX chain
  rxOffset = 0; // 700 seems the nominal so far to correct for built in CW beat note offset in 2nd LO
  txOffset = 0; // Value to offset TX for correction. Can be changed via command.  -50 seems pretty common so far.
  flipflop = true; // Testing something
  
  // Next 5 pins are for the AD9834 control
  pinMode(SCLK_BIT,               OUTPUT);    // clock
  pinMode(FSYNC_BIT,              OUTPUT);    // fsync
  pinMode(SDATA_BIT,              OUTPUT);    // data
  pinMode(RESET_BIT,              OUTPUT);    // reset
  pinMode(FREQ_REGISTER_BIT,      OUTPUT);    // freq register select
  pinMode (encoder0PinA,          INPUT);     // using optical for now
  pinMode (encoder0PinB,          INPUT);     // using optical for now 
  pinMode (TX_Dit,                INPUT);     // Dit Key line 
  pinMode (TX_Dah,                INPUT);     // Dah Key line
  pinMode (TX_OUT,                OUTPUT);
  pinMode (Band_End_Flash_led,    OUTPUT);
  pinMode (Multi_function_Green,  OUTPUT);    // Band width
  pinMode (Multi_function_Yellow, OUTPUT);    // Step size
  pinMode (Multi_function_Red,    OUTPUT);    // Other
  pinMode (Multi_Function_Button, INPUT);     // Choose from Band width, Step size, Other
  pinMode (Select_Green,          OUTPUT);    //  BW wide, 100 hz step, other1
  pinMode (Select_Yellow,         OUTPUT);    //  BW medium, 1 khz step, other2
  pinMode (Select_Red,            OUTPUT);    //  BW narrow, 10 khz step, other3
  pinMode (Select_Button,         INPUT);     //  Selection form the above
  pinMode (Medium_A8,             OUTPUT);    // Hardware control of I.F. filter Bandwidth
  pinMode (Narrow_A9,             OUTPUT);    // Hardware control of I.F. filter Bandwidth
  pinMode (Side_Tone,             OUTPUT);    // sidetone enable
  if(W6CQZ==1)
  {
    pinMode (42,                 OUTPUT);    // External PTT LOW = PTT OFF HIGH = PTT On
    digitalWrite(42,LOW);                    // External PTT OFF
  }

  Default_Settings();
  pinMode (Band_Select,           INPUT);     // select
  AD9834_init();
  AD9834_reset();                             // low to high
  digitalWrite(TX_OUT,            LOW);       // turn off TX
  
  // Following sets filter to wide
  digitalWrite( Medium_A8, LOW);   // Hardware control of I.F. filter shape
  digitalWrite( Narrow_A9, LOW);   // Hardware control of I.F. filter shape
  
  // Initialize the Nokia Display
  glcd.InitLCD();
  glcd.setContrast(65);    // Contrast setting of 65 looks good at 3.3v
  glcd.setFont(SmallFont);
    
  attachCoreTimerService(TimerOverFlow);//See function at the bottom of the file.
  
  // Following NEEDS to be changed to account for band vs blindly assuming 20M.
  program_freq0((14076000+rxOffset)-IF); // Go ahead and set to default 20M JT65 QRG
  program_freq1(14076000+txOffset);
  
  digitalWrite ( FREQ_REGISTER_BIT,   LOW);   // Double be sure FR0 is selected
  
  Serial.begin(9600);  // GPS requires this to be 9600 baud
  pinMode(gps_reset_pin,OUTPUT); // Set GPS Reset Pin Assignment
  digitalWrite(gps_reset_pin,LOW);  // Reset GPS
  glcd.clrScr();  // Clear the Nokia display
//  glcd.print("GPS",CENTER,0);
//  glcd.print("Acquiring Sats",CENTER,8);
//  glcd.print("Please Wait",CENTER,32);
//  digitalWrite(gps_reset_pin,HIGH);  // Release GPS Reset
  // retrieves +/- lat/long in 100000ths of a degree
//  tgps.get_position(&lat, &lon, &fix_age);
  gps_ok = false;
//  gps_tick = 0;
//  while (fix_age == TinyGPS::GPS_INVALID_AGE & gps_tick < gps_timeout)
//  {
//    tgps.get_position(&lat, &lon, &fix_age);
//    getGPS();
//    glcd.print("No Sat. Fix", CENTER,16);
//    glcd.print((" "+ String(120 - gps_tick) + " "),CENTER,40);
//    delay(1000);    
//    gps_tick++;
//  }
//  if (gps_tick < gps_timeout)
//  { 
//    gps_ok = true;
//  }
//  digitalWrite(gps_reset_pin,LOW);  // Hold GPS in Reset
  if (gps_ok)
  {
    getGPS();
    tgps.get_position(&lat, &lon, &fix_age);     
    tgps.get_datetime(&date, &time, &fix_age);
    s_date = date;
    s_time = time;
    if (s_time.length() == 7)
    {
      s_time = "0" + s_time;
    }
    s_year = "20" + s_date.substring(4,6);
    s_month = s_date.substring(2,4);
    s_day = s_date.substring(0,2);
    s_hour = s_time.substring(0,2);
    s_minute = s_time.substring(2,4);
    s_second = s_time.substring(4,6);
    s_hundredths = s_time.substring(6.8);

    glcd.clrScr();
    glcd.printNumF(abs(LAT/1000000),2,0,24);
    if (LAT > 0)
    {
      glcd.print("N",30,24);
    } else if (LAT < 0)
    {
        glcd.print("S",30,24);
    }
    glcd.printNumF(abs(LON/1000000),2,47,24);
    if (LON > 0)
    {
      glcd.print("E",78,24);
    } else if (LON < 0)
    {
      glcd.print("W",78,24);
    }
    GridSquare(LAT,LON);  // Calulate the Grid Square
    glcd.print(grid_text,0,40);
    gps_altitude = int(tgps.f_altitude());
    glcd.print(String(gps_altitude) + "m",50,40);
  } else {
    glcd.clrScr();
    glcd.print("NO GPS Data",CENTER,40);
  }

  Serial.end(); // Ends low rate GPS processing
  
  Serial.begin(115200);  // Fire up serial port (For HFWST this ***must*** be 9600 or 115200 baud)
  cmdMessenger.printLfCr(); // Making sure cmdMessenger terminates responses with CR/LF
  attachCommandCallbacks(); // Enables callbacks for cmdMessenger
  cmdMessenger.sendCmd(kAck,"W6CQZ_FW_1000");  // Sends a 1 time signon message at firmware strartup
}
//    end of setup

//===================================================================
void Default_Settings()
{
  digitalWrite(Multi_function_Green,  HIGH);  // Band_Width
  digitalWrite(Multi_function_Yellow, LOW);   //
  digitalWrite(Multi_function_Red,    LOW);   //
  digitalWrite(Select_Green,          HIGH);  //  
  digitalWrite(Select_Yellow,         LOW);   //
  digitalWrite(Select_Green,          LOW);   //
  digitalWrite (TX_OUT,               LOW);                                            
  digitalWrite (Band_End_Flash_led,   LOW);
  digitalWrite (Side_Tone,            LOW);    
  digitalWrite ( FREQ_REGISTER_BIT,   LOW);   // Added 9/4/13
}

//======================= Main Part =================================
void loop()     // 
{
  digitalWrite(FSYNC_BIT,             HIGH);  // 
  digitalWrite(SCLK_BIT,              HIGH);  //
  
  // I've setup cmdMessenger such that it should ignore anything that
  // makes no sense to it - but - if dealing with mixed data on serial
  // probably be best to process all that before calling feedinSerialData()
  // Wish we had two serial ports as we *should* :(  Will just have to
  // orchestrate points where serial belongs to GPS or command.
  
  // Process any serial data for commands
  cmdMessenger.feedinSerialData();
  
  // Lets start adding some code to twiddle the lights so I can
  // see what's happening here.  Using the left hand set of
  // LEDs where;
  // Green = RX
  // Yellow = Problem
  // Red = TX (not really sending any RF yet)
  //digitalWrite(Select_Green, LOW);   //
  //digitalWrite(Select_Yellow, LOW);  // 
  //digitalWrite(Select_Red, HIGH);    //
  
  if(jt65TXStatus())
  {
    if(jt65FrameStatus())
    {
      digitalWrite(Select_Yellow, LOW); // Error LED none
      digitalWrite(Select_Green, LOW);  // RX LED off
      digitalWrite(Select_Red, HIGH);   // TX LED on :D
      int i=0;
      int j=0;
      int k=0;
      unsigned long rx = getRX();
      // Mark TX status = on
      txstat = true;
      flipflop = false; // Sets software "flipflop" to false where it needs to be for first symbol TX
      // Get correct value in place for first symbol to TX
      // program_ab loads register 0 and 1 in one pass.  Pass a 0 value to either if you only want to set 0 or 1.
      // program_ab takes TUNING WORDS NOT frequency values.  It then splits out the 2 14 bit tuning nibbles and
      // sends to DDS.
      // Adding a symbol offset to allow late TX start - this is RESET TO ZERO after TX cycle
      program_ab(fsk65Vals[0+symoffset],fsk65Vals[1+symoffset]);
      i = 0+symoffset;
      j = j+symoffset;
      k = 0;
      for(i; i<126; i++)
      {
        if(k==0)
        {
          // Double++++++++ make sure FR zero is active and let free the blistering 5 watts upon the world
          digitalWrite ( FREQ_REGISTER_BIT,   LOW);   // FR0 is selected
          // Key external PTT before setting TX on
          if(W6CQZ==1)
          {
            digitalWrite(42,HIGH);                   // External PTT ON
          }
          digitalWrite(TX_OUT, HIGH); // Frightening little bit (for now cause this is the great unknown)
          k++;
        }
        // OK - time to get in the trenches and make this happen.  Here's the process flow.
        // At start of TX preserve current RX value - load in first symbol value (fskVals[0]) to register 1
        // start the actual TX and *immediately* load register 0 with next value.  After delay switch register
        // to 0 and *immediately* load register 1 with next value.  Rinse and repeat until all 126 out the door
        // or an abort command is received from host (or *eventually* panel button press). When TX is done,
        // one way or another, restore RX LO value to register 0.  Done.
        //
        // One more time to make sure I keep my logic in line
        // At entry I have first 2 tones in register 0 and register 1.  Need to be sure register 0 Z E R O is
        // active as it containst the first tone. The software flipflop toggles after each delay.  If it is
        // false we TX from 0 load to 1.  If it is true we TX from 1 load to 0.
        // WARNING WARNING WARNING DO NOT NOT NOT clobber flipflop or bad bad things will happen during a TX
        // cycle.
        if(flipflop)
        {
          // Flipflop is true so we TX from 1 load to 0.
          // Set TX register to 1
          digitalWrite(FREQ_REGISTER_BIT, HIGH);   // FR One is selected
          // Load in next value for register 0 leaving 1 alone
          program_ab(fsk65Vals[j],0);
          digitalWrite(Band_End_Flash_led, LOW); // when flipflop is true we stay dark
          j++;
        }
        else
        {
          // Flipflop is false so we TX from 0 load to 1.
          // Set TX register to 0
          digitalWrite(FREQ_REGISTER_BIT, LOW);   // FR Zero is selected
          // Load in next value for register 1 leaving 0 alone
          program_ab(0,fsk65Vals[j]);
          digitalWrite(Band_End_Flash_led, HIGH);  // when flipflop is false we light some bling
          j++;
        }
        // Maybe not best idea... frame time is actually 371.5193 mS.  372 is running us 63mS long by end of frame.
        // using this I do 63 at 372, 63 at 371 for a frame time of 46.809 seconds.  If I did the actual "real" JT65
        // symbol time length frame would be 46.811 versus 46.872 doing it all at 372 or 46.746 at 371.
        //
        // Error value at 372 = 46.872/46.811428571428571428571428571429 = 1.0012939453125 11010.8 Samples/Second equiv     
        // Error value at 371 = 46.746/46.811428571428571428571428571429 = 0.9986022949219 11040.4
        // Error value at mix = 46.809/46.811428571428571428571428571429 = 0.9999481201172 11025.6
        //
        // Compared to what's seen with typical sound cards doing this AFSK.... any of those would be beyond fine.  :)
        //
        //  If it breaks look here.  :)
        //delay(372);
        if(flipflop) { delay(372); } else { delay(371); }
        // CRTICIAL that this is kept right :)
        if(flipflop)
        {
          flipflop = false;
        }
        else
        {
          flipflop = true;
        }
        // Quick call to command parser so we could catch a TX abort.  This MUST MUST MUST be left
        // as is.  There's no way to stop TX without it short of yanking power.  Next build will
        // check for a panel button to abort TX as well.
        cmdMessenger.feedinSerialData();
        if(!jt65TXStatus())
        {
          // Got TX abort
          // DROP TX NOW
          symoffset=0;
          digitalWrite(TX_OUT, LOW);
          if(W6CQZ==1)
          {
            digitalWrite(42,LOW);                   // External PTT OFF
          }
          // Restore RX QRG
          program_ab(rx, 0);
          digitalWrite (FREQ_REGISTER_BIT, LOW);  // FR Zero is selected
          digitalWrite(Select_Red, LOW);          // TX LED Off
          digitalWrite(Band_End_Flash_led, LOW);  // Bling LED Off
          // Mark TX status = off
          txstat = false;
          txcwid = false; // In case it was set to go before
          break;
        }
      }
      // Clean up and restore RX
      // Drop TX NOW
      symoffset=0;
      digitalWrite(TX_OUT, LOW);
      if(W6CQZ==1)
      {
        digitalWrite(42,LOW);                // External PTT OFF
      }
        
      // Adding CW ID
      if(txcwid)
      {
        if(cwidqrg > 0)
        {
        // Minor delay to flush things a touch
          delay(250);
          // OK this should set the TX QRG to the sync +/- a little (I'm sending a tuning word with the command so that's done in HFWST)
          // The message to send is in (string)cwid and tuning word in cwidqrg
          cqSender.setup();
          cqSender.setMessage(cwid);
          // DDS register 1 (B) is by default used for TX - no need to preserve it right now
          program_ab(0, cwidqrg); // Remember - program_ab takes a tuning word and sets A and B registers if value > 0.  If = 0 it skips that register.
          delay(10);
          digitalWrite(FREQ_REGISTER_BIT, HIGH);   // FR One is selected
          // Mark TX on
          txstat = true;
          if(W6CQZ==1)
          {
            digitalWrite(42,HIGH);                   // External PTT ON
            delay(20);
          }
          digitalWrite(Band_End_Flash_led, HIGH);
          cqSender.sendBlocking();  // I set the default to 25 WPM - Part 97 only says I need to send an ID - not that I have to be able to copy it!  ;)
          digitalWrite(FREQ_REGISTER_BIT, LOW);   // FR One is selected
          digitalWrite(Band_End_Flash_led, LOW);
          if(W6CQZ==1)
          {
            digitalWrite(42,LOW);                   // External PTT OFF
          }
          // Mark TX off
          txstat = false;
        }
        txcwid = false; // clear it or we'll be sending it forever.
      }
        
      program_ab(rx, 0);
      digitalWrite(FREQ_REGISTER_BIT,LOW);    // FR Zero is selected
      digitalWrite(Select_Red, LOW);          // TX LED Off
      digitalWrite(Band_End_Flash_led, LOW);  // Bling LED Off
      // Mark TX status = off
      txstat = false;
    }
    else
    {
      // Frame did not validate
      digitalWrite(TX_OUT, LOW); // Just to be safe :)
      if(W6CQZ==1)
      {
        digitalWrite(42,LOW);                   // External PTT OFF
      }
      digitalWrite(FREQ_REGISTER_BIT, LOW);   // FR Zero is selected
      digitalWrite(Select_Yellow, HIGH);  // Indicates the Frame data is invalid! Bad hoodoo
      delay(500); // Give some time to see the error condition.
      stx65(false); // Set jtTXStatus false since the FSK values don't make sense.
      // Mark TX status = off
      txstat = false;
    }
    stx65(false);
  }
  else
  {
    digitalWrite(TX_OUT, LOW); // Just to be safe :)
    if(W6CQZ==1)
    {
      digitalWrite(42,LOW);                   // External PTT OFF
    }
    digitalWrite(FREQ_REGISTER_BIT, LOW);   // FR Zero is selected
    digitalWrite(Select_Green, HIGH);       // RX On
    digitalWrite(Select_Yellow, LOW);       // Error none
    digitalWrite(Select_Red, LOW);          // TX Off
    digitalWrite(Band_End_Flash_led, LOW);  // Bling Off
    // Mark TX status = off
    txstat = false;
  }

  if(jt9TXStatus())
  {
    if(jt9FrameStatus())
    {
      digitalWrite(Select_Yellow, LOW); // Error LED none
      digitalWrite(Select_Green, LOW);  // RX LED off
      digitalWrite(Select_Red, HIGH);   // TX LED on :D
      int i=0;
      int j=0;
      int k=0;
      unsigned long rx = getRX();
      // Mark TX status = on
      txstat = true;
      flipflop = false; // Sets software "flipflop" to false where it needs to be for first symbol TX
      // Get correct value in place for first symbol to TX
      // program_ab loads register 0 and 1 in one pass.  Pass a 0 value to either if you only want to set 0 or 1.
      // program_ab takes TUNING WORDS NOT frequency values.  It then splits out the 2 14 bit tuning nibbles and
      // sends to DDS.
      // Adding a symbol offset to allow late TX start - this is RESET TO ZERO after TX cycle
      program_ab(fsk9Vals[0+symoffset],fsk9Vals[1+symoffset]);
      i = 0+symoffset;
      j = j+symoffset;
      k = 0;
      for(i; i<86; i++)
      {
        if(k==0)
        {
          // Double++++++++ make sure FR zero is active and let free the blistering 5 watts upon the world
          digitalWrite ( FREQ_REGISTER_BIT,   LOW);   // FR0 is selected
          // Key external PTT before setting TX on
          if(W6CQZ==1)
          {
            digitalWrite(42,HIGH);                   // External PTT ON
          }
          digitalWrite(TX_OUT, HIGH); // Frightening little bit (for now cause this is the great unknown)
          k++;
        }
        // OK - time to get in the trenches and make this happen.  Here's the process flow.
        // At start of TX preserve current RX value - load in first symbol value (fskVals[0]) to register 1
        // start the actual TX and *immediately* load register 0 with next value.  After delay switch register
        // to 0 and *immediately* load register 1 with next value.  Rinse and repeat until all 126 out the door
        // or an abort command is received from host (or *eventually* panel button press). When TX is done,
        // one way or another, restore RX LO value to register 0.  Done.
        //
        // One more time to make sure I keep my logic in line
        // At entry I have first 2 tones in register 0 and register 1.  Need to be sure register 0 Z E R O is
        // active as it containst the first tone. The software flipflop toggles after each delay.  If it is
        // false we TX from 0 load to 1.  If it is true we TX from 1 load to 0.
        // WARNING WARNING WARNING DO NOT NOT NOT clobber flipflop or bad bad things will happen during a TX
        // cycle.
        if(flipflop)
        {
          // Flipflop is true so we TX from 1 load to 0.
          // Set TX register to 1
          digitalWrite(FREQ_REGISTER_BIT, HIGH);   // FR One is selected
          // Load in next value for register 0 leaving 1 alone
          program_ab(fsk9Vals[j],0);
          digitalWrite(Band_End_Flash_led, LOW); // when flipflop is true we stay dark
          j++;
        }
        else
        {
          // Flipflop is false so we TX from 0 load to 1.
          // Set TX register to 0
          digitalWrite(FREQ_REGISTER_BIT, LOW);   // FR Zero is selected
          // Load in next value for register 1 leaving 0 alone
          program_ab(0,fsk9Vals[j]);
          digitalWrite(Band_End_Flash_led, HIGH);  // when flipflop is false we light some bling
          j++;
        }
        delay(580); // JT9-1 says 580 mS per symbol - need to be sure JT didn't round that too much as he's want to do.
        // CRTICIAL that this is kept right :)
        if(flipflop)
        {
          flipflop = false;
        }
        else
        {
          flipflop = true;
        }
        // Quick call to command parser so we could catch a TX abort.  This MUST MUST MUST be left
        // as is.  There's no way to stop TX without it short of yanking power.  Next build will
        // check for a panel button to abort TX as well.
        cmdMessenger.feedinSerialData();
        if(!jt9TXStatus())
        {
          // Got TX abort
          // DROP TX NOW
          symoffset=0;
          digitalWrite(TX_OUT, LOW);
          if(W6CQZ==1)
          {
            digitalWrite(42,LOW);                   // External PTT OFF
          }
          // Restore RX QRG
          program_ab(rx, 0);
          digitalWrite (FREQ_REGISTER_BIT, LOW);  // FR Zero is selected
          digitalWrite(Select_Red, LOW);          // TX LED Off
          digitalWrite(Band_End_Flash_led, LOW);  // Bling LED Off
          // Mark TX status = off
          txstat = false;
          txcwid = false;
          break;
        }
      }
      // Clean up and restore RX
      // Drop TX NOW
      symoffset=0;
      digitalWrite(TX_OUT, LOW);
      if(W6CQZ==1)
      {
        digitalWrite(42,LOW);                // External PTT OFF
      }
      // Adding CW ID
      if(txcwid)
      {
        // Minor delay to flush things a touch
        // OK this should set the TX QRG to the sync +/- a little (I'm sending a tuning word with the command so that's done in HFWST)
        // The message to send is in (string)cwid and tuning word in cwidqrg
        if(cwidqrg > 0)
        {
          delay(250);
          cqSender.setMessage(cwid);
          // DDS register 1 (B) is by default used for TX - no need to preserve it right now
          program_ab(0, cwidqrg); // Remember - program_ab takes a tuning word and sets A and B registers if value > 0.  If = 0 it skips that register.
          digitalWrite(FREQ_REGISTER_BIT, HIGH);   // FR One is selected
          delay(10);
          // Mark TX on
          txstat = true;
          if(W6CQZ==1)
          {
            digitalWrite(42,HIGH);                   // External PTT ON
            delay(20);
          }
          digitalWrite(Band_End_Flash_led, HIGH);
          cqSender.sendBlocking();  // I set the default to 25 WPM - Part 97 only says I need to send an ID - not that I have to be able to copy it!  ;)
          digitalWrite(FREQ_REGISTER_BIT, LOW);   // FR One is selected
          digitalWrite(Band_End_Flash_led, LOW);
          if(W6CQZ==1)
          {
            digitalWrite(42,LOW);                   // External PTT OFF
          }
          // Mark TX off
          txstat = false;
        }
        txcwid = false; // clear it or we'll be sending it forever.
      }
      program_ab(rx, 0);
      digitalWrite(FREQ_REGISTER_BIT,LOW);    // FR Zero is selected
      digitalWrite(Select_Red, LOW);          // TX LED Off
      digitalWrite(Band_End_Flash_led, LOW);  // Bling LED Off
      // Mark TX status = off
      txstat = false;
    }
    else
    {
      // Frame did not validate
      digitalWrite(TX_OUT, LOW); // Just to be safe :)
      if(W6CQZ==1)
      {
        digitalWrite(42,LOW);                   // External PTT OFF
      }
      digitalWrite(FREQ_REGISTER_BIT, LOW);   // FR Zero is selected
      digitalWrite(Select_Yellow, HIGH);  // Indicates the Frame data is invalid! Bad hoodoo
      delay(500); // Give some time to see the error condition.
      stx9(false); // Set jtTXStatus false since the FSK values don't make sense.
      // Mark TX status = off
      txstat = false;
    }
    stx9(false);
  }
  else
  {
    digitalWrite(TX_OUT, LOW); // Just to be safe :)
    if(W6CQZ==1)
    {
      digitalWrite(42,LOW);                   // External PTT OFF
    }
    digitalWrite(FREQ_REGISTER_BIT, LOW);   // FR Zero is selected
    digitalWrite(Select_Green, HIGH);       // RX On
    digitalWrite(Select_Yellow, LOW);       // Error none
    digitalWrite(Select_Red, LOW);          // TX Off
    digitalWrite(Band_End_Flash_led, LOW);  // Bling Off
    // Mark TX status = off
    txstat = false;
  }

  // Keep track of loop speed
  loopCount++;
  loopElapsedTime    = millis() - loopStartTime;
  // has 1000 milliseconds elasped?
  if( 1000 <= loopElapsedTime )
  {
    serialDump();    // comment this out to remove the one second tick
  }

}    //  END LOOP

//===================================================================
//------------------ Debug data output ------------------------------
void    serialDump()
{
  loopStartTime   = millis();
  loopsPerSecond  = loopCount - lastLoopCount;
  loopSpeed       = (float)1e6 / loopsPerSecond;
  lastLoopCount   = loopCount;
}
// end serialDump()

//-----------------------------------------------------------------------------
uint32_t TimerOverFlow(uint32_t currentTime)
{
  return (currentTime + CORE_TICK_RATE*(1));//the Core Tick Rate is 1ms
}

//-----------------------------------------------------------------------------
// 10-10-2013 W6CQZ
// Writes tuning word in f0 to AD9834 frequency register 0 and/or
// f1 to register 1.  To set one register only pass 0 to f0 or f1
// This wants the 28 bit tuning word!
void program_ab(unsigned long f0, unsigned long f1)
{
  int flow,fhigh;
  if(f0>0)
  {
    flow = f0&0x3fff; // Remove upper bits leaving 14 low bits
    fhigh = (f0>>14)&0x3fff; // Shift right 14 bits and mask leaving lower 14 bits as previous upper 14 bits
    digitalWrite(FSYNC_BIT, LOW);
    clock_data_to_ad9834(flow|AD9834_FREQ0_REGISTER_SELECT_BIT);
    clock_data_to_ad9834(fhigh|AD9834_FREQ0_REGISTER_SELECT_BIT);
  }
  if(f1>0)
  {
    flow = f1&0x3fff;
    fhigh = (f1>>14)&0x3fff;
    digitalWrite(FSYNC_BIT, LOW);
    clock_data_to_ad9834(flow|AD9834_FREQ1_REGISTER_SELECT_BIT);
    clock_data_to_ad9834(fhigh|AD9834_FREQ1_REGISTER_SELECT_BIT);
    digitalWrite(FSYNC_BIT, HIGH);
  }
}

//-----------------------------------------------------------------------------
// ****************  Dont bother the code below  ******************************
// \/  \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/ \/
//-----------------------------------------------------------------------------
// W6CQZ did bother it.  I'm not *sure* why the AD9834 was being reset before
// and after ptogramming.  Everything tested seems to indicate that's not needed
// and probably a BAD idea to begin with.  Will read and re-read the data sheets
// to see if I can find a reason why it *should* be done.

void program_freq0(long frequency)
{
  int flow,fhigh;
  fcalc0 = frequency*(268.435456e6 / Reference );    // 2^28 =
  flow = fcalc0&0x3fff;              //  49.99975mhz  
  fhigh = (fcalc0>>14)&0x3fff;
  digitalWrite(FSYNC_BIT, LOW);  //
  clock_data_to_ad9834(flow|AD9834_FREQ0_REGISTER_SELECT_BIT);
  clock_data_to_ad9834(fhigh|AD9834_FREQ0_REGISTER_SELECT_BIT);
  digitalWrite(FSYNC_BIT, HIGH);
}    // end   program_freq0

//|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||  
void program_freq1(long frequency)
{
  int flow,fhigh;
  fcalc1 = frequency*(268.435456e6 / Reference );    // 2^28 =
  flow = fcalc1&0x3fff;              //  use for 49.99975mhz   
  fhigh = (fcalc1>>14)&0x3fff;
  digitalWrite(FSYNC_BIT, LOW);  
  clock_data_to_ad9834(flow|AD9834_FREQ1_REGISTER_SELECT_BIT);
  clock_data_to_ad9834(fhigh|AD9834_FREQ1_REGISTER_SELECT_BIT);
  digitalWrite(FSYNC_BIT, HIGH);  
}  

//------------------------------------------------------------------------------
void clock_data_to_ad9834(unsigned int data_word)
{
  char bcount;
  unsigned int iData;
  iData=data_word;
  digitalWrite(SCLK_BIT, HIGH);  //portb.SCLK_BIT = 1;  
  // make sure clock high - only chnage data when high
  for(bcount=0;bcount<16;bcount++)
  {
    if((iData & 0x8000)) digitalWrite(SDATA_BIT, HIGH);  //portb.SDATA_BIT = 1; 
    // test and set data bits
    else  digitalWrite(SDATA_BIT, LOW);  
    digitalWrite(SCLK_BIT, LOW);  
    digitalWrite(SCLK_BIT, HIGH);     
    // set clock high - only change data when high
    iData = iData<<1; // shift the word 1 bit to the left
  }  // end for
}  // end  clock_data_to_ad9834

//-----------------------------------------------------------------------------
void AD9834_init()      // set up registers
{
  AD9834_reset_high(); 
  digitalWrite(FSYNC_BIT, LOW);
  clock_data_to_ad9834(0x2300);  // Reset goes high to 0 the registers and enable the output to mid scale.
  clock_data_to_ad9834((FREQ0_INIT_VALUE&0x3fff)|AD9834_FREQ0_REGISTER_SELECT_BIT);
  clock_data_to_ad9834(((FREQ0_INIT_VALUE>>14)&0x3fff)|AD9834_FREQ0_REGISTER_SELECT_BIT);
  clock_data_to_ad9834(0x2200); // reset goes low to enable the output.
  AD9834_reset_low();
  digitalWrite(FSYNC_BIT, HIGH);  
}  //  end   init_AD9834()

//----------------------------------------------------------------------------   
void AD9834_reset()
{
  digitalWrite(RESET_BIT, HIGH);  // hardware connection
  for (int i=0; i <= 2048; i++);  // small delay
  digitalWrite(RESET_BIT, LOW);   // hardware connection
}

//-----------------------------------------------------------------------------
void AD9834_reset_low()
{
  digitalWrite(RESET_BIT, LOW);
}

//..............................................................................     
void AD9834_reset_high()
{  
  digitalWrite(RESET_BIT, HIGH);
}
//^^^^^^^^^^^^^^^^^^^^^^^^^  DON'T BOTHER CODE ABOVE  ^^^^^^^^^^^^^^^^^^^^^^^^^ 
//=============================================================================

unsigned long getRX()
{
  return fcalc0;  // Returns last set value for DDS register 0 (RX)
}

boolean jt65TXStatus()
{
  if(jt65TXOn) { return true; } else {return false;}
}

boolean jt9TXStatus()
{
  if(jt9TXOn) { return true; } else {return false;}
}

void setFlip()
{
  flipflop = false;
}

boolean flip()
{
  if(flipflop)
  {
    flipflop=false;
    return true;
  }
  else
  {
    flipflop=true;
    return false;
  }
}

boolean jt65FrameStatus()
{
  int i;
  boolean v = true;
  for(i=0; i<126; i++)
  {
    if((fsk65Vals[i] < 37581152) || (fsk65Vals[i] > 77041361))
    {
      v = false;
      break;
    }
  }
  return v;
}

boolean jt9FrameStatus()
{
  int i;
  boolean v = true;
  for(i=0; i<86; i++)
  {
    if((fsk65Vals[i] < 37581152) || (fsk65Vals[i] > 77041361))
    {
      v = false;
      break;
    }
  }
  return v;
}

void stx65(boolean v)
{
  if(v) { jt65TXOn = true; } else { jt65TXOn = false; }
}

void stx9(boolean v)
{
  if(v) { jt9TXOn = true; } else { jt9TXOn = false; }
}

/*
cmdMessenger command callback processors by W6CQZ
Defines the CAT command set and routines for Rebel
*/

void OnUnknownCommand()
{
  // Do nothing - one of my all time favorites! \0/
}
void onGVersion()
{
  // Command ID = 2;
  cmdMessenger.sendCmd(kAck,ROMVERSION);
}
void onGDDSVer()
{
  // Command ID = 3;
  cmdMessenger.sendCmd(kAck,"AD9834");
}
void onGDDSRef()
{
  // Command ID = 4;
  cmdMessenger.sendCmd(kAck,Reference);
}
void onSLockPanel()
{
  // Command ID 5
  cmdMessenger.sendCmd(kAck,5);
}
void onSUnlockPanel()
{
  // Command ID 6
  cmdMessenger.sendCmd(kAck,6);
}
void onLoopSpeed()
{
  // Command ID=7;
  cmdMessenger.sendCmd(kAck,loopSpeed);
}
void onGRXOffset()
{
  // Command ID=8;
  // Reads RX offset
  cmdMessenger.sendCmd(kAck,rxOffset);
}
void onGTXOffset()
{
  // Command ID=9;
  // Reads TX offset
  cmdMessenger.sendCmd(kAck,txOffset);
}
void onSRXOffset()
{
  // Command ID=10,rx_offset_hz;
  // Sets the INTEGER value to offset RX
  int i = cmdMessenger.readIntArg();
  rxOffset = i;
  cmdMessenger.sendCmd(kAck,i);
}
void onSTXOffset()
{
  // Command ID=11,tx_offset_hz;
  // Sets the INTEGER value to offset TX
  int i = cmdMessenger.readIntArg();
  txOffset = i;
  cmdMessenger.sendCmd(kAck,i);
}
void onGBand()
{
  // Command ID = 12;
  // bsm = 1 = 20M bsm = 0 = 40M
  int i = digitalRead(Band_Select);
  if(i==0)
  {
    cmdMessenger.sendCmd(kAck,40);
  } else if(i==1) {
    cmdMessenger.sendCmd(kAck,20);
  } else {
    cmdMessenger.sendCmd(kError,0);
  }
}
void onGRXFreq()
{
  // Command ID = 13;
  cmdMessenger.sendCmd(kAck,fcalc0);
}
  
void onSRXFreq()
{
  // Command ID = 14,value;
  unsigned long frx = cmdMessenger.readIntArg();
  // calling my routine to take a direct tuning word
  // this sets only register 0 (RX) to its LO value
  // it ***DOES NOT*** account for the needed offset
  // to RX due to 2nd LO being shifted to give a CW
  // beat note.
  program_ab(frx, 0);
  cmdMessenger.sendCmd(kAck,frx);
  fcalc0=frx;
}
void onGTXStatus()
{
  // Command ID 15
  if(txstat) { cmdMessenger.sendCmd(kAck,1); } else { cmdMessenger.sendCmd(kAck,0); }
}
void onSTXOn()
{
  // Command ID 16;
  // Clear any symoffset as this is an on time TX
  symoffset = 0;
  if(jt65Valid)
  {
    jt65TXOn = true;
    cmdMessenger.sendCmd(kAck,16);
  } else
  {
    jt65TXOn = false;
    cmdMessenger.sendCmd(kError,16);
  }    
}
void onS9TXOn()
{
  // Command ID 17;
  // Clear any symoffset as this is an on time TX
  symoffset = 0;
  if(jt9Valid)
  {
    jt9TXOn = true;
    cmdMessenger.sendCmd(kAck,17);
  } else
  {
    jt9TXOn = false;
    cmdMessenger.sendCmd(kError,17);
  }    
}
void onSTXOff()
{
  // Command ID 18;
  jt65TXOn = false;
  jt9TXOn = false;
  txcwid = false;
  cmdMessenger.sendCmd(kAck,18);
}
void onSDTXOn()
{
  // Command ID 19;
  long i = cmdMessenger.readIntArg();
  if(i>0 & i <45)
  {
    symoffset = i;
    if(jt65Valid)
    {
      jt65TXOn = true;
      cmdMessenger.sendCmdStart(kAck);
      cmdMessenger.sendCmdArg(19);
      cmdMessenger.sendCmdArg(i);
      cmdMessenger.sendCmdEnd();
    } else
    {
      jt65TXOn = false;
      cmdMessenger.sendCmdStart(kError);
      cmdMessenger.sendCmdArg(19);
      cmdMessenger.sendCmdArg(-1);
      cmdMessenger.sendCmdEnd();
    }
  } else
  {
    jt65TXOn = false;
    cmdMessenger.sendCmdStart(kError);
    cmdMessenger.sendCmdArg(19);
    cmdMessenger.sendCmdArg(i);
    cmdMessenger.sendCmdEnd();
  }
}
void onSD9TXOn()
{
  // Command ID 20;
  long i = cmdMessenger.readIntArg();
  if(i>0 & i <45)
  {
    symoffset = i;
    if(jt9Valid)
    {
      jt9TXOn = true;
      cmdMessenger.sendCmdStart(kAck);
      cmdMessenger.sendCmdArg(20);
      cmdMessenger.sendCmdArg(i);
      cmdMessenger.sendCmdEnd();
    } else
    {
      jt9TXOn = false;
      cmdMessenger.sendCmdStart(kError);
      cmdMessenger.sendCmdArg(20);
      cmdMessenger.sendCmdArg(-1);
      cmdMessenger.sendCmdEnd();
    }
  } else
  {
    jt9TXOn = false;
    cmdMessenger.sendCmdStart(kError);
    cmdMessenger.sendCmdArg(20);
    cmdMessenger.sendCmdArg(i);
    cmdMessenger.sendCmdEnd();
  }
}
void onDoCWID()
{
  // Command ID 21;
  // Expects CWID as string and TX QRG as integer tuning word
  String scwid = cmdMessenger.readStringArg();
  cwid = scwid;
  cwidqrg = cmdMessenger.readIntArg();
  txcwid = true;
  cmdMessenger.sendCmdStart(kAck);
  cmdMessenger.sendCmdArg(cwid);
  cmdMessenger.sendCmdArg(cwidqrg);
  cmdMessenger.sendCmdEnd();
}
void onGClearTX()
{
  // Command ID 22;
  // Clears fskVals[] and sets jtTXValid false
  jt65Valid = false;
  jt9Valid = false;
  int i;
  for(i=0; i<129; i++) { fsk65Vals[i]=0; }
  for(i=0; i<88; i++) { fsk9Vals[i]=0; }
  cmdMessenger.sendCmd(kAck,22);
}
void onSTXFreq()
{
  // Command ID 23;
  // Prepares FSK value receiver.  Once this is acked you can
  // begin uploading FSK values
  if(jt9TXOn || jt65TXOn)
  {
    cmdMessenger.sendCmd(kError,23);
  }
  else
  {
    cmdMessenger.sendCmd(kAck,23);
    jt65Valid = false;
    jt9Valid = false;
  }
  
}
void onGLoadTXBlock()
{
  // Command ID=24,Block {1..32},I1,I2,I3,I4;
  // Loading 4 Integer tuning words from Block # to Block #+3
  // into master TX array fskVals[0..127]
  // It is perfectly fine to send same block twice - this
  // allows correction should a block be corrupted in transit.
  // Modifying this to take the full 126 value frame so I don't
  // have to shuffle things here.  To keep it simple using 128
  // elements with extra 2 set to 0.  Just keeps the 4 value
  // chunk idea working in easy mode.  TX Routine will only
  // go 126 :)
  int i = 0;
  int block = 0;
  unsigned long i1 = 0;
  unsigned long i2 = 0;
  unsigned long i3 = 0;
  unsigned long i4 = 0;
  block = cmdMessenger.readIntArg();
  i1 = cmdMessenger.readIntArg();
  i2 = cmdMessenger.readIntArg();
  i3 = cmdMessenger.readIntArg();
  i4 = cmdMessenger.readIntArg();
  
  if(block<1)
  {
    jt65Valid = false;
    cmdMessenger.sendCmdStart(kError);  // NAK
    cmdMessenger.sendCmdArg(24);        // Command
    cmdMessenger.sendCmdArg(block);     // Parameter count where it went wrong
    cmdMessenger.sendCmdEnd();
  }
  else
  {
    // Have right value count - (eventually) validate (now) just stuff them into values array.
    //if(block>0) {i=block*4;} else {i=block;} // can skip this if mult by 0 is not an issue and just do i=block*4
    i=(block-1)*4; // This adjusts block to be 0...31 - I need to spec 1...32 above to be sure I'm reading a value
    // since cmdMessenger sets an Int value to 0 if it's not present.
    fsk65Vals[i]=i1;
    i++;
    fsk65Vals[i]=i2;
    i++;
    fsk65Vals[i]=i3;
    i++;
    fsk65Vals[i]=i4;
    // Echo the block back for confirmation on host side.
    cmdMessenger.sendCmdStart(24); // This was last block and simple range check = all good.
    cmdMessenger.sendCmdArg(block);
    cmdMessenger.sendCmdArg(i1);  // Echo the values back just to be sure.
    cmdMessenger.sendCmdArg(i2);  // After all... this is a TX routine so
    cmdMessenger.sendCmdArg(i3);  // it really is a good idea to double
    cmdMessenger.sendCmdArg(i4);  // check the values got in correct.
    cmdMessenger.sendCmdEnd();
    if(block==32) { jt65Valid = true; } else { jt65Valid = false; }
  }
}
void onG9LoadTXBlock()
{
  // Command ID=25,Block {1..22},I1,I2,I3,I4;
  // Loading 4 Integer tuning words from Block # to Block #+3
  // into master TX array fsk9Vals[0..87]
  // It is perfectly fine to send same block twice - this
  // allows correction should a block be corrupted in transit.
  // Modifying this to take the full 85 value frame so I don't
  // have to shuffle things here.  To keep it simple using 88
  // elements with extra 3 set to 0.  Just keeps the 4 value
  // chunk idea working in easy mode.  TX Routine will only
  // go 85 :)
  int i = 0;
  int block = 0;
  unsigned long i1 = 0;
  unsigned long i2 = 0;
  unsigned long i3 = 0;
  unsigned long i4 = 0;
  block = cmdMessenger.readIntArg();
  i1 = cmdMessenger.readIntArg();
  i2 = cmdMessenger.readIntArg();
  i3 = cmdMessenger.readIntArg();
  i4 = cmdMessenger.readIntArg();
  
  if(block<1)
  {
    jt9Valid = false;
    cmdMessenger.sendCmdStart(kError);  // NAK
    cmdMessenger.sendCmdArg(25);        // Command
    cmdMessenger.sendCmdArg(block);     // Parameter count where it went wrong
    cmdMessenger.sendCmdEnd();
  }
  else
  {
    // Have right value count - (eventually) validate (now) just stuff them into values array.
    //if(block>0) {i=block*4;} else {i=block;} // can skip this if mult by 0 is not an issue and just do i=block*4
    i=(block-1)*4; // This adjusts block to be 0...21 - I need to spec 1...22 above to be sure I'm reading a value
    // since cmdMessenger sets an Int value to 0 if it's not present.
    fsk9Vals[i]=i1;
    i++;
    fsk9Vals[i]=i2;
    i++;
    fsk9Vals[i]=i3;
    i++;
    fsk9Vals[i]=i4;
    // Echo the block back for confirmation on host side.
    cmdMessenger.sendCmdStart(25); // This was last block and simple range check = all good.
    cmdMessenger.sendCmdArg(block);
    cmdMessenger.sendCmdArg(i1);  // Echo the values back just to be sure.
    cmdMessenger.sendCmdArg(i2);  // After all... this is a TX routine so
    cmdMessenger.sendCmdArg(i3);  // it really is a good idea to double
    cmdMessenger.sendCmdArg(i4);  // check the values got in correct.
    cmdMessenger.sendCmdEnd();
    if(block==22) { jt9Valid = true; } else { jt9Valid = false; }
  }
}
void onGFSKVals()
{
  // Command ID=26;
  // Dumps 126 FSK values previously uploaded
  // for a JT65 frame.
  int i=0;
  cmdMessenger.sendCmdStart(kAck);
  cmdMessenger.sendCmdArg("FSK VALUES FOLLOW");
  for(i=0; i<126; i++)
  {
    cmdMessenger.sendCmdArg(fsk65Vals[i]);
  }
  cmdMessenger.sendCmdEnd();
}
void onG9FSKVals()
{
  // Command ID=27;
  // Dumps 88 FSK values previously uploaded
  // for a JT9 frame.
  int i=0;
  cmdMessenger.sendCmdStart(kAck);
  cmdMessenger.sendCmdArg("FSK VALUES FOLLOW");
  for(i=0; i<88; i++)
  {
    cmdMessenger.sendCmdArg(fsk9Vals[i]);
  }
  cmdMessenger.sendCmdEnd();
}
void onGGPSGrid()
{
  // Command ID=28;
  // Returns GPS derived grid
  cmdMessenger.sendCmd(kAck,28);
}
void onGGPSTime()
{
  // Command ID=29;
  // Returns GPS Time
  cmdMessenger.sendCmd(kAck,29);
}

