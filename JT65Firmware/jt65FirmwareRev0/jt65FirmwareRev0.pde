// Version JT65V005
// 13-October-2013
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
// things not currently used as I have uses for them
// coming up. :)
//

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

const int ROMVERSION        = 1; // Defines this firmware revision level - not bothering with major.minor 0 to max_int_value "should" be enough space. :)

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

// W6CQZ Debugging already
long gfl = 0;
long gfh = 0;

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
const long meter_40             = 16076000;     // IF + Band frequency, JT65
// HI side injection 40 meter 
// range 16 > 16.3 mhz

const long meter_20             = 5076000;      // Band frequency - IF, LOW JT65
// LOW side injection 20 meter 
// range 5 > 5.35 mhz

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

//-------------------------------------------------------------------- 
// 10-10-2013 W6CQZ
// Adding array to hold transmit FSK values and handler for cmdMessenger serial control library
unsigned long fskVals[128];  // 126 JT65 symbols + 2 spares :) See notes in loader code for +2 logic.
boolean jtTXOn = false; // If true immediately start sending FSK set in fskVals[0..125]
boolean jtValid = false; // Do NOT attempt JT mode TX unless this is true - remains false until a valid TX set is uploaded.
unsigned int jtSym = 0; // Index to where we are in the symbol TX chain
int rxOffset = 718; // Value to offset RX for correction DO NOT blindly trust this will be correct for your Rebel.
int txOffset = 0; // Value to offset TX for correction
boolean flipflop = true; // Testing something
#include <Streaming.h>  // Needed by CmdMessenger
#include <CmdMessenger.h>
CmdMessenger cmdMessenger = CmdMessenger(Serial);
// Commands for rig control
enum
{
  kError,
  kAck,
  gRXFreq,
  sRXFreq,
  gBand,
  sTXFreq,
  gVersion,
  gDDSRef,
  gDDSVer,
  sFRXFreq,
  sTXOn,
  sTXOff,
  gTXStatus,
  sLockPanel,
  gLockPanel,
  gloopSpeed,
  sRXOffset,
  sTXOffset,
  gRXOffset,
  gTXOffset,
  gLoadTXBlock,
  gClearTX,
  gFSKVals,
};
// Define the command callback routines
void attachCommandCallbacks()
{
  cmdMessenger.attach(OnUnknownCommand);              // Catch all in case of garbage/bad command - does nothing but ignore junk.
  cmdMessenger.attach(gRXFreq, onGRXFreq);            // Get RX QRG
  cmdMessenger.attach(sRXFreq, onSRXFreq);            // Set RX QRG
  cmdMessenger.attach(gBand, onGBand);                // Get Band
  cmdMessenger.attach(sTXFreq, onSTXFreq);            // Request to setup TX array
  cmdMessenger.attach(gVersion, onGVersion);          // Get firmware version
  cmdMessenger.attach(gDDSRef, onGDDSRef);            // Get DDS reference QRG
  cmdMessenger.attach(gDDSVer, onGDDSVer);            // Get DDS type
  cmdMessenger.attach(sFRXFreq, onSFRXFreq);          // Set RX QRG (alternate version takes a Hz vs tuning word value)
  cmdMessenger.attach(sTXOn, onSTXOn);                // Start TX
  cmdMessenger.attach(sTXOff, onSTXOff);              // Stop TX
  cmdMessenger.attach(sLockPanel, onSLockPanel);      // Lock out controls (going away - default is locked and stay locked)
  cmdMessenger.attach(gLockPanel, onGLockPanel);      // Get control lock status (going away due to ^^^)
  cmdMessenger.attach(gloopSpeed, onLoopSpeed);       // Get main loop execution speed as string
  cmdMessenger.attach(gTXStatus, onGTXStatus);        // Get TX status, on or off
  cmdMessenger.attach(sRXOffset, onSRXOffset);        // Set RX offset for correcting CW RX offset built into 2nd LO/mixer
  cmdMessenger.attach(sTXOffset, onSTXOffset);        // Set TX offset (usually 0 but if you want to calibrate the Rebel *** this value *** will do it not the RX offset!
  cmdMessenger.attach(gRXOffset, onGRXOffset);        // Get RX offset value
  cmdMessenger.attach(gTXOffset, onGTXOffset);        // Get TX offset value
  cmdMessenger.attach(gLoadTXBlock, onGLoadTXBlock);  // FSK tuning word loader
  cmdMessenger.attach(gClearTX, onGClearTX);          // Clear FSK tuning word array
  cmdMessenger.attach(gFSKVals, onGFSKVals);
}
// --- End of cmdMessenger definition/setup ---

void setup() 
{
  for(jtSym=0; jtSym<128; jtSym++) {fskVals[jtSym]=0;}  // 126 JT65 symbols + 2 spares :) See notes in loader code for +2 logic.
  jtTXOn = false; // If true immediately start sending FSK set in fskVals[0..125]
  jtValid = false; // Do NOT attempt JT mode TX unless this is true - remains false until a valid TX set is uploaded.
  jtSym = 0; // Index to where we are in the symbol TX chain
  rxOffset = 718; // Value to offset RX for correction DO NOT blindly trust this will be correct for your Rebel. Can be changed via command
  txOffset = 0; // Value to offset TX for correction. Can be changed via command.
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
  Default_Settings();
  pinMode (Band_Select,           INPUT);     // select
  AD9834_init();
  AD9834_reset();                             // low to high
  digitalWrite(TX_OUT,            LOW);       // turn off TX
  attachCoreTimerService(TimerOverFlow);//See function at the bottom of the file.
  Serial.begin(115200);  // Fire up serial port (For HFWST this ***must*** be 9600 or 115200 baud)
  cmdMessenger.printLfCr(); // Making sure cmdMessenger terminates responses with CR/LF
  attachCommandCallbacks(); // Enables callbacks for cmdMessenger
  
  // Following NEEDS to be changed to account for band vs blindly assuming 20M.
  program_freq0((14076000+rxOffset)-IF); // Go ahead and set to default 20M JT65 QRG
  program_freq1(14076000+txOffset);
  
  digitalWrite ( FREQ_REGISTER_BIT,   LOW);   // Double be sure FR0 is selected
  // DO *****NOT***** CHANGE NEXT LINE - HFWST uses this to detect Rebel - if changed HFWST will NOT be able to see Rebel.
  cmdMessenger.sendCmd(kAck,"Rebel Command Ready");  // Sends a 1 time signon message at firmware strartup
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

  if(jtTXStatus())
  {
    if(jtFrameStatus())
    {
      digitalWrite(Select_Yellow, LOW); // Error LED none
      digitalWrite(Select_Green, LOW);  // RX LED off
      digitalWrite(Select_Red, HIGH);   // TX LED on :D
      int i;
      int j=0;
      unsigned long rx = getRX();
      flipflop = false; // Sets software "flipflop" to false where it needs to be
      // Get correct value in place for first symbol to TX
      program_ab(fskVals[0],fskVals[1]);
      for(i=0; i<126; i++)
      {
        if(i==0)
        {
          // Double++++++++ make sure FR zero is active and let free the blistering 5 watts upon the world
          digitalWrite ( FREQ_REGISTER_BIT,   LOW);   // FR0 is selected
          digitalWrite(TX_OUT, HIGH); // Frightening little bit (for now cause this is the great unknown)
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
        // WARNING WARNING WARNING - flip() returns value of flipflop AND toggles it.  DO NOT NOT NOT call
        // it more than once per trip through here.
        if(flipflop)
        {
          // Flipflop is true so we TX from 1 load to 0.
          // Set TX register to 1
          digitalWrite(FREQ_REGISTER_BIT, HIGH);   // FR1 is selected
          // Load in next value for register 0 leaving 1 alone
          program_ab(fskVals[j],0);
          digitalWrite(Band_End_Flash_led, LOW); // when flipflop is true we stay dark
          j++;
        }
        else
        {
          // Flipflop is false so we TX from 0 load to 1.
          // Set TX register to 0
          digitalWrite(FREQ_REGISTER_BIT, LOW);   // FR0 is selected
          // Load in next value for register 1 leaving 0 alone
          program_ab(0,fskVals[j]);
          digitalWrite(Band_End_Flash_led, HIGH);  // when flipflop is false we light some bling
          j++;
        }
        //   
        delay(372);
        // CRTICIAL that this is kept right :)
        if(flipflop)
        {
          flipflop = false;
        }
        else
        {
          flipflop = true;
        }
        // Quick call to command parser so we could catch a TX abort.
        cmdMessenger.feedinSerialData();
        if(!jtTXStatus())
        {
          // Got TX abort
          // DROP TX NOW
          digitalWrite(TX_OUT, LOW);
          // Restore RX QRG
          program_ab(rx, 0);
          digitalWrite (FREQ_REGISTER_BIT, LOW);   // FR0 is selected
          digitalWrite(Select_Red, LOW);          // TX LED Off
          digitalWrite(Band_End_Flash_led, LOW);  // Bling LED Off
          break;
        }
      }
        // Clean up and restore RX
        // Drop TX NOW
        digitalWrite(TX_OUT, LOW);
        program_ab(rx, 0);
        digitalWrite(FREQ_REGISTER_BIT,LOW);   // FR0 is selected
        digitalWrite(Select_Red, LOW);          // TX LED Off
        digitalWrite(Band_End_Flash_led, LOW);  // Bling LED Off
    }
    else
    {
      digitalWrite(TX_OUT, LOW); // Just to be safe :)
      digitalWrite(FREQ_REGISTER_BIT, LOW);   // FR0 is selected
      digitalWrite(Select_Yellow, HIGH);  // Indicates the Frame data is invalid! Bad hoodoo
      delay(500); // Give some time to see the error condition.
      stx(false); // Set jtTXStatus false since the FSK values don't make sense.
    }
    stx(false);
  }
  else
  {
    digitalWrite(TX_OUT, LOW); // Just to be safe :)
    digitalWrite(FREQ_REGISTER_BIT, LOW);   // FR0 is selected
    digitalWrite(Select_Green, HIGH);       // RX On
    digitalWrite(Select_Yellow, LOW);       // Error none
    digitalWrite(Select_Red, LOW);          // TX Off
    digitalWrite(Band_End_Flash_led, LOW);  // Bling Off
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
  gfl = flow;
  fhigh = (fcalc1>>14)&0x3fff;
  gfh = fhigh;
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

boolean jtTXStatus()
{
  if(jtTXOn) { return true; } else {return false;}
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

boolean jtFrameStatus()
{
  int i;
  boolean v = true;
  for(i=0; i<126; i++)
  {
    if((fskVals[i] < 37581152) || (fskVals[i] > 77041361))
    {
      v = false;
      break;
    }
  }
  return v;
}

void stx(boolean v)
{
  if(v) { jtTXOn = true; } else { jtTXOn = false; }
}

//--- cmdMessenger command callback processors by W6CQZ ---
void OnUnknownCommand()
{
  // Do nothing - one of my all time favorites! \0/
}

void onGRXFreq()
{
  // Command ID = 2;
  cmdMessenger.sendCmd(kAck,fcalc0);
}
  
void onSRXFreq()
{
  // Command ID = 3,value;
  unsigned long frx = cmdMessenger.readIntArg();
  // calling my routine to take a direct tuning word
  // this sets only register 0 (RX) to its LO value
  // or (for 20M) (Fdesired - 9MHz) + 750 Hz
  // +750 is to removed RX offset for CW use
  // For 20M the LO range is 5.0 ... 5.35 MHz for a
  // DDS Word value of 26843680 ... 28722737
  // or for TX of 14.0 ... 14.35
  // DDS Word value of 75162303 ... 77041361
  // Will add 40M ranges later
  // For 14,076,000 I get 5,076750 for a tuning word of 27255760
  // 
  program_ab(frx, 0);
  cmdMessenger.sendCmd(kAck,frx);
  fcalc0=frx;
}
  
void onGBand()
{
  // Command ID = 4;
  // bsm=1 = 20M bsm = 0 = 40M
  int i = digitalRead(Band_Select);
  if(i==0)
  {
    cmdMessenger.sendCmd(kAck,40);
  } else if(i==1) {
    cmdMessenger.sendCmd(kAck,20);
  } else {
    cmdMessenger.sendCmd(kError,"??");
  }
}
  
void onSTXFreq()
{
  // Command ID 5;
  // This one is complex.  Reads in 64 integer values
  // stuffing them into fskVals1[0..126] plus two 0
  // values in 127..128 so I can keep using the 4
  // word blocks in easy mode.
  //
  // OK - to be sure I don't over-run the input buffer
  // between serial reads I'm going to break this down
  // into "packets" of values.
  // Each word is going to be an 8 character value -
  // docs say the serial RX FIFO is 64 bytes so....
  // lets send 32 rounds of 4 values at a time like
  // Command ID X,Y,Z1,Z2,Z3,Z4; where
  // X is command #20, Y is round [0..15] Z1..Z4 the 4
  // tuning words.
  // So call command 5 and if return is kAck start
  // sending values.  If TX is in progress or Rebel
  // can not otherwise handle this now response will
  // be kError.
  // It is CRITICAL that I not change the array if TX
  // is in progress.
  if(jtTXOn)
  {
    cmdMessenger.sendCmd(kError,5);
  }
  else
  {
    cmdMessenger.sendCmd(kAck,5);
    jtValid = false; // Do NOT set this true until the uploader has gotten the new frame
  }
  
}

void onGLoadTXBlock()
{
  // Command ID=20,Block {1..32},I1,I2,I3,I4;
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
    jtValid = false;
    cmdMessenger.sendCmdStart(kError);  // NAK
    cmdMessenger.sendCmdArg(20);        // Command
    cmdMessenger.sendCmdArg(block);     // Parameter count where it went wrong
    cmdMessenger.sendCmdEnd();
  }
  else
  {
    // Have right value count - (eventually) validate (now) just stuff them into values array.
    //if(block>0) {i=block*4;} else {i=block;} // can skip this if mult by 0 is not an issue and just do i=block*4
    i=(block-1)*4; // This adjusts block to be 0...31 - I need to spec 1...32 above to be sure I'm reading a value
    // since cmdMessenger sets an Int value to 0 if it's not present.
    fskVals[i]=i1;
    i++;
    fskVals[i]=i2;
    i++;
    fskVals[i]=i3;
    i++;
    fskVals[i]=i4;
    // Echo the block back for confirmation on host side.
    cmdMessenger.sendCmdStart(20); // This was last block and simple range check = all good.
    cmdMessenger.sendCmdArg(block);
    cmdMessenger.sendCmdArg(i1);  // Echo the values back just to be sure.
    cmdMessenger.sendCmdArg(i2);  // After all... this is a TX routine so
    cmdMessenger.sendCmdArg(i3);  // it really is a good idea to double
    cmdMessenger.sendCmdArg(i4);  // check the values got in correct.
    cmdMessenger.sendCmdEnd();
    if(block==32) { jtValid = true; } else { jtValid = false; }
  }
}

void onGClearTX()
{
  // Command ID 21;
  // Clears fskVals[] and sets jtTXValid false
  jtValid = false;
  int i;
  for(i=0; i<129; i++) { fskVals[i]=0; }
  cmdMessenger.sendCmd(kAck,21);
}

void onGVersion()
{
  // Command ID = 6;
  cmdMessenger.sendCmd(kAck,ROMVERSION);
}
  
void onGDDSRef()
{
  // Command ID = 7;
  cmdMessenger.sendCmd(kAck,Reference);
}
  
void onGDDSVer()
{
  // Command ID=8;
  cmdMessenger.sendCmd(kAck,"AD9834");
}

void onSFRXFreq()
{
  // Command ID=9,f;
  // Set 0 and 1 frequency registers
  // Expects an integer frequency value as in
  // 14076000
  // Adjusts RX to proper LO applying any correction needed
  long f = cmdMessenger.readIntArg();
  program_freq0((f+rxOffset)-IF);
  program_freq1(f+txOffset);
  cmdMessenger.sendCmdStart(kAck);
  cmdMessenger.sendCmdArg(f-IF);
  cmdMessenger.sendCmdArg(f);
  cmdMessenger.sendCmdEnd();
}

void onSTXOn()
{
  // Command ID 10;
  //if(jtTXValid)
  //{
    jtTXOn = true;
    cmdMessenger.sendCmd(kAck,10);
  //} else
  //{
    //jtTXOn = false;
    //cmdMessenger.sendCmd(kError,10);
  //}    
}

void onSTXOff()
{
  // Command ID 11;
  jtTXOn = false;
  cmdMessenger.sendCmd(kAck,11);
}

void onGTXStatus()
{
  // Command ID 12
  if(jtTXOn) { cmdMessenger.sendCmd(kAck,1); } else { cmdMessenger.sendCmd(kAck,0); }
}

void onSLockPanel()
{
  // Command ID 13,0|1; where 0 locks controls and 1 enables
  // Need to remove this but it means reordering the command set and too lazy
  // to do right now - will replace them with other functions anyhow.  Panel
  // is now ALWAYS locked though I do intend to monitor 1 button for a manual
  // TX stop method in case CAT barfs.
  cmdMessenger.sendCmd(kAck,1);
}

void onGLockPanel()
{
  // Command ID 14;
  // Can leave this but will eventually repurpose.
  cmdMessenger.sendCmd(kAck,1);
}

void onLoopSpeed()
{
  // Command ID=15;
  cmdMessenger.sendCmd(kAck,loopSpeed);
}

void onSRXOffset()
{
  // Command ID=16,rx_offset_hz;
  int i = cmdMessenger.readIntArg();
  rxOffset = i;
  cmdMessenger.sendCmd(kAck,i);
}

void onSTXOffset()
{
  // Command ID=17,tx_offset_hz;
  int i = cmdMessenger.readIntArg();
  txOffset = i;
  cmdMessenger.sendCmd(kAck,i);
}

void onGRXOffset()
{
  // Command ID=18;
  cmdMessenger.sendCmd(kAck,rxOffset);
}

void onGTXOffset()
{
  // Command ID=19;
  cmdMessenger.sendCmd(kAck,txOffset);
}

void onGFSKVals()
{
  // Command ID=22;
  int i=0;
  cmdMessenger.sendCmdStart(kAck);
  cmdMessenger.sendCmdArg("FSK VALUES FOLLOW");
  for(i=0; i<126; i++)
  {
    cmdMessenger.sendCmdArg(fskVals[i]);
  }
  cmdMessenger.sendCmdEnd();
}
//--- End cmdMessenger callbacks ---

