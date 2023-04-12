#! perl -w
###############################################################################
# o32BGCTool
###############################################################################

use strict;
#no warnings 'deprecated';
use Win32;
use Win32::GUI();
use Win32::GUI::Constants qw( /^WS_/ );
my ($PerlWindow) = Win32::GUI::GetPerlWindow();
Win32::GUI::Hide($PerlWindow);

use Win32::SerialPort 0.22;
use Switch;
use Win32API::File qw(QueryDosDevice); #produces error: (in cleanup) Can't call method "FETCH" on an undefined value at C:/Perl/site/lib/Win32/GUI.pm line 3480 during global destruction.
use Win32::Wlan;
use IO::Socket::INET;
use IO::Select;
use Config::IniFiles;
use File::Basename;
use Cwd 'abs_path';
use Win32::GUI::TabFrame;
use Win32::GUI::BitmapInline ();

use Win32::GUI::DIBitmap;

#---------------------------
# ALWAYS finish with a retrun value in Event Handlers!
# 1: Proceed, taking the default action defined for the event.
# 0: Proceed, but do not take the default action.
# -1: Terminate the message loop.
#---------------------------

############################################################################### #XX
# Versions

my $VersionStr = '21. Jan. 2023 v2.65e';

#CAREFULL: in Data Display version is not double checked!
my $SupportedBGCLayoutVersion = '262'; #layout version supported by o32BGCTool, used in ExecuteHeader()

my @FirmwareVersionList =  ( 'v2.65e','v2.59e','v2.53','v0.96' ); #versions available in the flash tab selector
my @FirmwareVReplaceList = ( 'v265e_nt','v259e_nt','v253_nt','v096_nt' ); #versions available in the flash tab selector

my @STorM32BoardList = (
{
  name => 'STorM32 v3.3',             hexfile => 'o323bgc_V_storm32bgc_v330_f103rc',
#},{
#  name => 'STorM32 v4.1',             hexfile => 'o323bgc_V_storm32bgc_v410_f103rc',
},{
  name => 'STorM32 v1.3',             hexfile => 'o323bgc_V_storm32bgc_v130_f103rc',
},{
  name => 'STorM32 v1.3x',            hexfile => 'o323bgc_V_storm32bgc_v130_f103rc',
},{
  name => 'NT Imu Module v3.x',  hexfile => 'o323bgc_ntimu_V_module_v3x_f103t8',
  versions =>  [ 'v0.52c', 'v0.49' ],
  vreplaces => [ 'v052c', 'v049' ],
  boards =>    [ 'v3.x F103T8' ],
},{
  name => 'NT Imu Module v2.x',  hexfile => 'o323bgc_ntimu_V_module_v2x_f103t8',
  versions =>  [ 'v0.52c', 'v0.49' ],
  vreplaces => [ 'v052c', 'v049' ],
  boards =>    [ 'v2.x F103T8','v2.2 F103T8','v2.1 F103T8', ],
},{
  name => 'NT Imu Module v1.x',  hexfile => 'o323bgc_ntimu_V_module_v1x_f103t8',
  versions =>  [ 'v0.52c', 'v0.49' ],
  vreplaces => [ 'v052c', 'v049' ],
  boards =>    [ 'v1.0 F103T8','v1.1 F103T8' ],
},{
  name => 'NT Motor Module v2.x',     hexfile => 'o323bgc_ntmotor_V_module_v2x_f103t8',
  versions =>  [ 'v0.52c', 'v0.40f' ],
  vreplaces => [ 'v052c', 'v040f' ],
  boards =>    [ 'v2.xE F103T8','v2.3E F103T8','v2.4E F103T8','v2.5E F103T8'],
},{
  name => 'NT Motor Triple Module v1.x',     hexfile => 'o323bgc_ntmotor_triple_V_module_v1x_f103t8',
  versions =>  [ 'v0.52c', 'v0.46' ],
  vreplaces => [ 'v052c', 'v046' ],
  boards =>    [ 'v1.x F103T8'],

},{
  name => 'NT Logger Module v1.x',    hexfile => 'o323bgc_ntlogger_V_module_v1x_f103t8',
  versions =>  [ 'v0.52c', 'v0.49' ],
  vreplaces => [ 'v052c', 'v049' ],
  boards =>    [ 'v1.0 F103T8','v1.1 F103T8' ],

},{
  name => 'NT Imu Module CC3D Atom',  hexfile => 'o323bgc_ntimu_V_module_cc3d',
  versions =>  [ 'v0.46' ],
  vreplaces => [ 'v046' ],
  boards =>    [ 'CC3D F103CB' ],

  #the boardversion is checked before flashing, so allow the possibility
  # to have different boards fitting a firmware file
}
);

my $UpdateInstructionsStr =
#The firmware will reset all parameters, scripts and calibration settings when flashed. Please memorize your old settings before flashing, and restore them afterwards manually.
#NT modules: The NT imu module firmware has been modified, please upgrade. The NT Motor and NT Logger firmwares have not been modified, nothing to do here.
#"When you're updating from v2.42j or later then you just need to flash the new firmware. ".
#"All settings, including the scripts and calibration data, are copied over.
#
#For version v2.42i and older, the firmware will reset all parameters, scripts and calibration settings when flashed. Please memorize your old settings before flashing, and restore them afterwards manually.
#"The firmware may reset all parameters, scripts and calibration settings when flashed. Please memorize your old settings before flashing, and restore them afterwards manually.

"Updating from v2.53 and later:
You just need to flash the new firmware. All settings, including the scripts and calibration data, should be copied over correctly.
However, it is highly recommended to store the settings before updating, and to carefully check them afterwards.

All other versions:
The firmware may reset all parameters, scripts and calibration settings when flashed. Please memorize your old settings before flashing, and restore them afterwards manually.

NT modules: The firmware for the NT module has been modified, please consider upgrading.

Please note: For reasons of size, NTLoggerTool and BetaPilot are NOT included in the standard package. ".
"If you require them then please download the latest version from the project web page or the wiki.";


my $BGCStr = "o323BGC";
#my $BGCStr = "STorM32 GUI";


###############################################################################
# Options

#ImuOrientation no. = index in List
#ImuOrientation value =  if( no.>11 ) value= no. + 4 else value= no.;
my @ImuOrientationList = (
{ name => 'z0°',     axes => '+x +y +z',  value => 0, },
{ name => 'z90°',    axes => '-y +x +z',  value => 1, },
{ name => 'z180°',   axes => '-x -y +z',  value => 2, },
{ name => 'z270°',   axes => '+y -x +z',  value => 3, },

{ name => 'x0°',     axes => '+y +z +x',  value => 4, },
{ name => 'x90°',    axes => '-z +y +x',  value => 5, },
{ name => 'x180°',   axes => '-y -z +x',  value => 6, },
{ name => 'x270°',   axes => '+z -y +x',  value => 7, },

{ name => 'y0°',     axes => '+z +x +y',  value => 8, },
{ name => 'y90°',    axes => '-x +z +y',  value => 9, },
{ name => 'y180°',   axes => '-z -x +y',  value => 10, },
{ name => 'y270°',   axes => '+x -z +y',  value => 11, },

{ name => '-z0°',    axes => '+y +x -z',  value => 16, },
{ name => '-z90°',   axes => '-x +y -z',  value => 17, },
{ name => '-z180°',  axes => '-y -x -z',  value => 18, },
{ name => '-z270°',  axes => '+x -y -z',  value => 19, },

{ name => '-x0°',    axes => '+z +y -x',  value => 20, },
{ name => '-x90°',   axes => '-y +z -x',  value => 21, },
{ name => '-x180°',  axes => '-z -y -x',  value => 22, },
{ name => '-x270°',  axes => '+y -z -x',  value => 23, },

{ name => '-y0°',    axes => '+x +z -y',  value => 24, },
{ name => '-y90°',   axes => '-z +x -y',  value => 25, },
{ name => '-y180°',  axes => '-x -z -y',  value => 26, },
{ name => '-y270°',  axes => '+z -x -y',  value => 27, },
);

my @ImuChoicesList = ();
{
  my $no = 0;
  foreach my $orientation (@ImuOrientationList){
    push( @ImuChoicesList, 'no.'.$no.':  '.$orientation->{name}.'  '.AxesRemovePlus($orientation->{axes}) );
    $no++;
  }
}

sub AxesRemovePlus{ my $axes= shift; $axes=~ s/\+/ /g; return $axes; }

my @FunctionInputChoicesList = (
  'off', 'Rc-0', 'Rc-1', 'Rc-2', 'Rc2-0', 'Rc2-1', 'Rc2-2', 'Rc2-3', 'Pot-0', 'Pot-1', 'Pot-2',
  'Virtual-1', 'Virtual-2', 'Virtual-3', 'Virtual-4', 'Virtual-5', 'Virtual-6', 'Virtual-7', 'Virtual-8',
  'Virtual-9', 'Virtual-10', 'Virtual-11', 'Virtual-12', 'Virtual-13', 'Virtual-14', 'Virtual-15', 'Virtual-16',
  'But switch', 'But latch', 'But step',
  'Aux-0 switch', 'Aux-1 switch', 'Aux-2 switch', 'Aux-01 switch', 'Aux-012 switch',
  'Aux-0 latch', 'Aux-1 latch', 'Aux-2 latch', 'Aux-01 latch', 'Aux-012 latch',
  'Aux-0 step', 'Aux-1 step', 'Aux-2 step', 'Prearm check'
);
my $FunctionInputMax = 44 -1;

my @SetupTabList = ( 'dashboard', 'pid', 'pan', 'rcinputs', 'functions', 'scripts', 'setup',
                     'gimbalconfig', 'expert', 'interfaces', 'servo', 'gimbalmodel', 'filter' );
my $MaxSetupTabs = scalar(@SetupTabList); #this is the number of setup tabs

my $SCRIPTSIZE = 128;
my $CMD_s_PARAMETER_ZAHL = 7; #number of values transmitted with a 's' get data command, V1: 5, V2: 7
my $CMD_d_PARAMETER_ZAHL = 32; #number of values transmitted with a 'd' get data command, V1: 32, V2: 32
my $CMD_g_PARAMETER_ZAHL = 189; #number of values transmitted with a 'g' get data command
my $CMD_g_PARAMETER_LEN = 263; #length of bytes transmitted with a 'g' get data command

# one longer than SETUP_PARAMETER_ZAHL, allows to determine size from consequative value
my @PosInBuf = (
0,2,4,6,7,9,11,13,14,16,18,20,21,22,23,24,26,27,28,30,31,32,34,35,37,39,41,43,45,46,
48,50,52,54,56,58,60,62,64,66,68,70,71,72,74,75,77,78,80,81,82,84,85,86,87,88,89,90,91,93,
95,97,99,101,103,105,106,107,108,109,110,111,112,113,114,115,116,118,119,120,121,122,123,124,125,126,128,129,130,132,
133,134,136,137,139,140,142,143,144,145,147,149,151,152,153,154,156,158,160,162,163,164,165,167,169,171,173,174,175,176,
178,180,182,184,185,186,187,188,189,190,192,193,195,197,199,201,202,203,204,205,206,207,209,210,211,212,213,214,215,216,
217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,245,247,249,
251,253,255,256,257,258,259,260,261,263,
);

my @OptionList_L256 = (
{
  name => 'Firmware Version',
  type => 'STR+READONLY',
  size => 16,
  page=> 'dashboard',
  column=> 1,
},{
  name => 'Board',
  type => 'STR+READONLY',
  size => 16,
},{
  name => 'Name',
  type => 'STR+READONLY',
  size => 16,

##--- PID tab --------------------
},{#DEFAULT parameters
  name => 'Gyro LPF', foc => 1, # hide for foc, show for default
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 6, default => 1, steps => 1,
  adr => 12,
  choices => [ 'off', '1.5 ms', '3.0 ms', '4.5 ms', '6.0 ms', '7.5 ms', '9 ms' ],
  page => 'pid',
  pos => [1,1],
},{#FOC parameters
  name => 'Foc Gyro LPF', foc => 2, # show for foc, hide for default
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 6, default => 1, steps => 1,
  adr => 41,
  choices => [ 'off', '1.5 ms', '3.0 ms', '4.5 ms', '6.0 ms', '7.5 ms', '9 ms' ],
  pos => [1,1],
},{
  name => 'Imu2 FeedForward LPF', foc => 3, # show but disable for foc, show and enable else
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 6, default => 1, steps => 1,
  adr => 72,
  choices => [ 'off', '1.5 ms', '4 ms', '10 ms', '22 ms', '46 ms', '94 ms' ],

},{
  name => 'Roll Yaw PD Mixing',
  type => 'UINT8', len => 5, ppos => 0, min => 0, max => 100, default => 0, steps => 1,
  adr => 73,
  unit => '%',
  pos => [1,4],
},{
  name => 'Voltage Correction', foc => 3, # show but disable for foc, show and enable else
  type => 'UINT8', len => 7, ppos => 0, min => 0, max => 200, default => 0, steps => 1,
  adr => 75,
  unit => '%',

},{#DEFAULT parameters
  name => 'Pitch P', foc => 1, # hide for foc, show for default
  type => 'UINT', len => 5, ppos => 2, min => 0, max => 3000, default => 400, steps => 10,
  adr => 0,
  pos => [2,1],
},{
  name => 'Pitch I', foc => 1, # hide for foc, show for default
  type => 'UINT', len => 7, ppos => 1, min => 0, max => 32000, default => 1000, steps => 50,
  adr => 1,
},{
  name => 'Pitch D', foc => 1, # hide for foc, show for default
  type => 'UINT', len => 3, ppos => 4, min => 0, max => 8000, default => 500, steps => 50,
  adr => 2,
},{
  name => 'Pitch Motor Vmax', foc => 1, # hide for foc, show for default
  type => 'UINT8', len => 5, ppos => 0, min => 0, max => 255, default => 150, steps => 1,
  adr => 3,

},{
  name => 'Roll P', foc => 1, # hide for foc, show for default
  type => 'UINT', len => 5, ppos => 2, min => 0, max => 3000, default => 400, steps => 10,
  adr => 4,
  pos => [3,1],
},{
  name => 'Roll I', foc => 1, # hide for foc, show for default
  type => 'UINT', len => 7, ppos => 1, min => 0, max => 32000, default => 1000, steps => 50,
  adr => 5,
},{
  name => 'Roll D', foc => 1, # hide for foc, show for default
  type => 'UINT', len => 3, ppos => 4, min => 0, max => 8000, default => 500, steps => 50,
  adr => 6,
},{
  name => 'Roll Motor Vmax', foc => 1, # hide for foc, show for default
  type => 'UINT8', len => 5, ppos => 0, min => 0, max => 255, default => 150, steps => 1,
  adr => 7,

},{
  name => 'Yaw P', foc => 1, # hide for foc, show for default
  type => 'UINT', len => 5, ppos => 2, min => 0, max => 3000, default => 400, steps => 10,
  adr => 8,
  pos => [4,1],
},{
  name => 'Yaw I', foc => 1, # hide for foc, show for default
  type => 'UINT', len => 7, ppos => 1, min => 0, max => 32000, default => 1000, steps => 50,
  adr => 9,
},{
  name => 'Yaw D', foc => 1, # hide for foc, show for default
  type => 'UINT', len => 3, ppos => 4, min => 0, max => 8000, default => 500, steps => 50,
  adr => 10,
},{
  name => 'Yaw Motor Vmax', foc => 1, # hide for foc, show for default
  type => 'UINT8', len => 5, ppos => 0, min => 0, max => 255, default => 150, steps => 1,
  adr => 11,

},{#FOC parameters
  name => 'Foc Pitch P', foc => 2, # show for foc, hide for default
  type => 'UINT', len => 5, ppos => 2, min => 0, max => 3000, default => 400, steps => 10,
  adr => 23,
  pos => [2,1],
},{
  name => 'Foc Pitch I', foc => 2, # show for foc, hide for default
  type => 'UINT', len => 7, ppos => 1, min => 0, max => 32000, default => 100, steps => 50,
  adr => 24,
},{
  name => 'Foc Pitch D', foc => 2, # show for foc, hide for default
  type => 'UINT', len => 3, ppos => 4, min => 0, max => 8000, default => 2000, steps => 50,
  adr => 25,
},{
  name => 'Foc Pitch K', foc => 2, # show for foc, hide for default
  type => 'UINT', len => 5, ppos => 1, min => 1, max => 100, default => 10, steps => 1,
  adr => 26,

},{
  name => 'Foc Roll P', foc => 2, # show for foc, hide for default
  type => 'UINT', len => 5, ppos => 2, min => 0, max => 3000, default => 400, steps => 10,
  adr => 29,
  pos => [3,1],
},{
  name => 'Foc Roll I', foc => 2, # show for foc, hide for default
  type => 'UINT', len => 7, ppos => 1, min => 0, max => 32000, default => 100, steps => 50,
  adr => 30,
},{
  name => 'Foc Roll D', foc => 2, # show for foc, hide for default
  type => 'UINT', len => 3, ppos => 4, min => 0, max => 8000, default => 2000, steps => 50,
  adr => 31,
},{
  name => 'Foc Roll K', foc => 2, # show for foc, hide for default
  type => 'UINT', len => 5, ppos => 1, min => 1, max => 100, default => 10, steps => 1,
  adr => 32,

},{
  name => 'Foc Yaw P', foc => 2, # show for foc, hide for default
  type => 'UINT', len => 5, ppos => 2, min => 0, max => 3000, default => 400, steps => 10,
  adr => 35,
  pos => [4,1],
},{
  name => 'Foc Yaw I', foc => 2, # show for foc, hide for default
  type => 'UINT', len => 7, ppos => 1, min => 0, max => 32000, default => 100, steps => 50,
  adr => 36,
},{
  name => 'Foc Yaw D', foc => 2, # show for foc, hide for default
  type => 'UINT', len => 3, ppos => 4, min => 0, max => 8000, default => 2000, steps => 50,
  adr => 37,
},{
  name => 'Foc Yaw K', foc => 2, # show for foc, hide for default
  type => 'UINT', len => 5, ppos => 1, min => 1, max => 100, default => 10, steps => 1,
  adr => 38,
},{
  name => 'Foc Controller', foc => 2, # show for foc, hide for default
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 3, default => 0, steps => 1,
  adr => 175,
  choices => [ 'default', 'roll mixing', 'mdl based wo roll mix', 'model based' ],
  pos => [2,6],
},{
  name => 'Controller', foc => 1, # hide for foc, show for default
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 1, default => 0, steps => 1,
  adr => 183,
  choices => [ 'default', 'roll mixing' ],
  pos => [2,6],
},{
  name => 'D Source',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 1, default => 1, steps => 1,
  adr => 182,
  choices => [ 'default', 'gyro' ],
  pos => [4,6],

##--- PAN tab --------------------
},{
  name => 'Pan Mode Control',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => $FunctionInputMax, default => 0, steps => 1,
  adr => 79,
  choices => \@FunctionInputChoicesList,
  page=> 'pan',
  column=> 1,
},{
  name => 'Pan Mode Default Setting',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 5, default => 0, steps => 1,
  adr => 80,
  choices => [ 'hold hold pan', 'hold hold hold', 'pan pan pan', 'pan hold hold', 'pan hold pan', 'hold pan pan', 'off' ],
},{
  name => 'Pan Mode Setting #1',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 6, default => 1, steps => 1,
  adr => 81,
  choices => [ 'hold hold pan', 'hold hold hold', 'pan pan pan', 'pan hold hold', 'pan hold pan', 'hold pan pan', 'off' ],
},{
  name => 'Pan Mode Setting #2',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 6, default => 4, steps => 1,
  adr => 82,
  choices => [ 'hold hold pan', 'hold hold hold', 'pan pan pan', 'pan hold hold', 'pan hold pan', 'hold pan pan', 'off' ],
},{
  name => 'Pan Mode Setting #3',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 6, default => 2, steps => 1,
  adr => 83,
  choices => [ 'hold hold pan', 'hold hold hold', 'pan pan pan', 'pan hold hold', 'pan hold pan', 'hold pan pan', 'off' ],

},{
  name => 'Pitch Pan', comment => '(0 = hold)',
  type => 'UINT8', len => 5, ppos => 1, min => 0, max => 50, default => 20, steps => 1,
  adr => 84,
  column => 2,
},{
  name => 'Pitch Pan Deadband',
  type => 'UINT', len => 5, ppos => 1, min => 0, max => 600, default => 0, steps => 5,
  adr => 85,
  unit => '°',
  pos => [2,3],
},{
  name => 'Pitch Pan Expo',
  type => 'UINT8', len => 5, ppos => 0, min => 0, max => 100, default => 0, steps => 1,
  adr => 86,
  unit=> '%',
},{
  name => 'Pitch Pan Method',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 1, default => 0, steps => 1,
  adr => 147,
  choices => [ 'normal', 'plane', 'accumulate' ],

},{
  name => 'Roll Pan', comment => '(0 = hold)',
  type => 'UINT8', len => 5, ppos => 1, min => 0, max => 50, default => 20, steps => 1,
  adr => 87,
  column => 3,
},{
  name => 'Roll Pan Deadband',
  type => 'UINT', len => 5, ppos => 1, min => 0, max => 600, default => 0, steps => 5,
  adr => 88,
  unit => '°',
  pos => [3,3],
},{
  name => 'Roll Pan Expo',
  type => 'UINT8', len => 5, ppos => 0, min => 0, max => 100, default => 0, steps => 1,
  adr => 89,
  unit => '%',
},{
  name => 'Roll Pan Method',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 1, default =>1, steps => 1,
  adr => 128,
  choices => [ 'normal', 'plane' ],

},{
  name => 'Yaw Pan', comment => '(0 = hold)',
  type => 'UINT8', len => 5, ppos => 1, min => 0, max => 50, default => 20, steps => 1,
  adr => 90,
  column => 4,
},{
  name => 'Yaw Pan Deadband',
  type => 'UINT', len => 5, ppos => 1, min => 0, max => 100, default => 50, steps => 5,
  adr => 91,
  unit => '°',
  pos => [4,3],
},{
  name => 'Yaw Pan Expo',
  type => 'UINT8', len => 5, ppos => 0, min => 0, max => 100, default => 0, steps => 1,
  adr => 92,
  unit => '%',
},{
  name => 'Yaw Pan Deadband LPF',
  type => 'UINT', len => 5, ppos => 2, min => 0, max => 400, default => 150, steps => 5,
  adr => 93,
  unit => 's',
##},{
  #name => 'Yaw Pan Deadband Hysteresis',
  #type => 'UINT', len => 5, ppos => 1, min => 0, max => 50, default => 0, steps => 1,
  #adr => 94,
  #unit => '°',
  #pos => [4,6],
#},{
  #name => 'Yaw Soft MinMax (0 = off)',
  #type => 'UINT8', len => 0, ppos => 0, min => 0, max => 175, default => 0, steps => 1,
  #adr => 148,
  #unit => '°',
  #pos => [4,7],

##--- RC INPUTS tab --------------------
},{
  name => 'Rc Dead Band',
  type => 'UINT8', len => 0, ppos => 0, min => 0, max => 50, default => 10, steps => 1,
  adr => 96,
  unit => 'us',
  page => 'rcinputs',
},{
  name => 'Rc Hysteresis',
  type => 'UINT8', len => 0, ppos => 0, min => 0, max => 50, default => 5, steps => 1,
  adr => 97,
  unit => 'us',

},{
  name => 'Rc Pitch Trim',
  type => 'INT8', len => 0, ppos => 0, min => -100, max => 100, default => 0, steps => 1,
  adr => 104,
  unit => 'us',
  pos => [1,4],
},{
  name => 'Rc Roll Trim',
  type => 'INT8', len => 0, ppos => 0, min => -100, max => 100, default => 0, steps => 1,
  adr => 111,
  unit => 'us',
},{
  name => 'Rc Yaw Trim',
  type => 'INT8', len => 0, ppos => 0, min => -100, max => 100, default => 0, steps => 1,
  adr => 118,
  unit => 'us',

},{
  name => 'Rc Pitch',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => $FunctionInputMax, default => 0, steps => 1,
  adr => 102,
  choices => \@FunctionInputChoicesList,
  column => 2,
},{
  name => 'Rc Pitch Mode',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 2, default => 2, steps => 1,
  adr => 103,
  choices => [ 'absolute', 'relative', 'absolute centered' ],
},{
  name => 'Rc Pitch Min',
  type => 'INT', len => 0, ppos => 1, min => -1200, max => 1200, default => -250, steps => 5,
  adr => 105,
  unit => '°',
},{
  name => 'Rc Pitch Max',
  type => 'INT', len => 0, ppos => 1, min => -1200, max => 1200, default => 250, steps => 5,
  adr => 106,
  unit => '°',
},{
  name => 'Rc Pitch Speed Limit', comment => '(0 = off)',
  type => 'UINT', len => 0, ppos => 1, min => 0, max => 1000, default => 400, steps => 5,
  adr => 107,
  unit => '°/s',
},{
  name => 'Rc Pitch Accel Limit', comment => '(0 = off)',
  type => 'UINT', len => 0, ppos => 3, min => 0, max => 1000, default => 300, steps => 10,
  adr => 108,

},{
  name => 'Rc Roll',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => $FunctionInputMax, default => 0, steps => 1,
  adr => 109,
  choices => \@FunctionInputChoicesList,
  column => 3,
},{
  name => 'Rc Roll Mode',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 2, default => 2, steps => 1,
  adr => 110,
  choices => [ 'absolute', 'relative', 'absolute centered' ],
},{
  name => 'Rc Roll Min',
  type => 'INT', len => 0, ppos => 1, min => -450, max => 450, default => -250, steps => 5,
  adr => 112,
  unit => '°',
},{
  name => 'Rc Roll Max',
  type => 'INT', len => 0, ppos => 1, min => -450, max => 450, default => 250, steps => 5,
  adr => 113,
  unit => '°',
},{
  name => 'Rc Roll Speed Limit', comment => '(0 = off)',
  type => 'UINT', len => 0, ppos => 1, min => 0, max => 1000, default => 400, steps => 5,
  adr => 114,
  unit => '°/s',
},{
  name => 'Rc Roll Accel Limit', comment => '(0 = off)',
  type => 'UINT', len => 0, ppos => 3, min => 0, max => 1000, default => 300, steps => 10,
  adr => 115,

},{
  name => 'Rc Yaw',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => $FunctionInputMax, default => 0, steps => 1,
  adr => 116,
  choices => \@FunctionInputChoicesList,
  column => 4,
},{
  name => 'Rc Yaw Mode',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 3, default => 2, steps => 1,
  adr => 117,
  choices => [ 'absolute', 'relative', 'absolute centered', 'relative turn around' ], #'relative slip ring' ],
},{
  name => 'Rc Yaw Min',
  type => 'INT', len => 0, ppos => 1, min => -2700, max => 2700, default => -250, steps => 10,
  adr => 119,
  unit => '°',
},{
  name => 'Rc Yaw Max',
  type => 'INT', len => 0, ppos => 1, min => -2700, max => 2700, default => 250, steps => 10,
  adr => 120,
  unit => '°',
},{
  name => 'Rc Yaw Speed Limit', comment => '(0 = off)',
  type => 'UINT', len => 0, ppos => 1, min => 0, max => 1000, default => 400, steps => 5,
  adr => 121,
  unit => '°/s',
},{
  name => 'Rc Yaw Accel Limit', comment => '(0 = off)',
  type => 'UINT', len => 0, ppos => 3, min => 0, max => 1000, default => 300, steps => 10,
  adr => 122,

##--- FUNCTIONS tab --------------------
},{
  name => 'Standby',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => $FunctionInputMax, default => 0, steps => 1,
  adr => 123,
  choices => \@FunctionInputChoicesList,
  page => 'functions',
  column => 1,

},{
  name => 'Re-center Camera',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => $FunctionInputMax, default => 0, steps => 1,
  adr => 124,
  choices => \@FunctionInputChoicesList,
  pos => [1,3],
},{
  name => 'Re-center Camera Axes',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 6, default => 0, steps => 1,
  adr => 135,
  choices => [ 'all', 'pitch', 'roll', 'yaw', 'pitch roll', 'pitch yaw', 'roll yaw' ],

},{
  name => 'Camera Control',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => $FunctionInputMax, default => 0, steps => 1,
  adr => 125,
  choices => \@FunctionInputChoicesList,
  column => 2,
},{
  name => 'Camera Control2',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => $FunctionInputMax, default => 0, steps => 1,
  adr => 138,
  choices => \@FunctionInputChoicesList,
},{
  name => 'Camera Model',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 12, default => 0, steps => 1,
  adr => 126,
  choices => [ 'Generic Rc', 'Git2 Rc', 'Mapir Survey Rc', 'Firefly Split 4K Rc', 'CAMremote Rc', 'Pwm',
               'CAMremote Uart', 'Runcam Generic',
               'GoPro Generic', 'GoPro Hero5', 'GoPro Hero7',
               'Visca', 'Serial Api' ],
},{
  name => 'Camera Control Mode',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 5, default => 0, steps => 1,
  adr => 127,
  choices => [ 'video - off - shutter', 'shutter - off - video',
               'off - shutter', 'off - video', 'shutter - off', 'video - off', ],
},{
  name => 'Camera Time Interval', comment => '(0 = off)',
  type => 'UINT', len => 0, ppos => 1, min => 0, max => 150, default => 0, steps => 1,
  adr => 129,
  unit => 's',
},{
  name => 'Camera ComPort', reboot => 1,
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 4, default => 0, steps => 1,
  adr => 174,
  choices => [ 'default', 'uart', 'uart2', 'uartX', 'mavlink' ],

},{
  name => 'Pwm Out Control',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => $FunctionInputMax, default => 0, steps => 1,
  adr => 130,
  choices => \@FunctionInputChoicesList,
  column => 3,
},{
  name => 'Pwm Out Mid',
  type => 'UINT', len => 0, ppos => 0, min => 900, max => 2100, default => 1500, steps => 1,
  adr => 131,
  unit => 'us',
},{
  name => 'Pwm Out Min',
  type => 'UINT', len => 0, ppos => 0, min => 900, max => 2100, default => 1100, steps => 10,
  adr => 132,
  unit => 'us',
},{
  name => 'Pwm Out Max',
  type => 'UINT', len => 0, ppos => 0, min => 900, max => 2100, default => 1900, steps => 10,
  adr => 133,
  unit => 'us',
},{
  name => 'Pwm Out Speed Limit', comment => '(0 = off)',
  type => 'UINT', len => 0, ppos => 0, min => 0, max => 1000, default => 0, steps => 5,
  adr => 134,
  unit => 'us/s',

##--- SCRIPTS tab --------------------
},{
  name => 'Script1 Control',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => $FunctionInputMax, default => 0, steps => 1,
  adr => $CMD_g_PARAMETER_ZAHL-5,
  choices => \@FunctionInputChoicesList,
  page => 'scripts',
  column => 1,
},{
  name => 'Script2 Control',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => $FunctionInputMax, default => 0, steps => 1,
  adr => $CMD_g_PARAMETER_ZAHL-4,
  choices => \@FunctionInputChoicesList,
  column => 2,
},{
  name => 'Script3 Control',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => $FunctionInputMax, default => 0, steps => 1,
  adr => $CMD_g_PARAMETER_ZAHL-3,
  choices => \@FunctionInputChoicesList,
  column => 3,
},{
  name => 'Script4 Control',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => $FunctionInputMax, default => 0, steps => 1,
  adr => $CMD_g_PARAMETER_ZAHL-2,
  choices => \@FunctionInputChoicesList,
  column => 4,

},{
  name => 'Scripts',
  type => 'SCRIPT', len => 0, ppos => 0, min => 0, max => 0, default => '', steps => 0,
  size => 2, #this is NOT $SCRIPTSIZE, since it's a dummy field, must be of UINT16 length
  adr => $CMD_g_PARAMETER_ZAHL-1,
  hidden => 1,

##--- GIMBAL SETUP tab --------------------
},{
  name => 'Imu2 Configuration', foc => 3, # show but disable for foc, show and enable else
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 1, default => 0, steps => 1,
  adr => 53,
  choices => [ 'off', 'full' ],
  page => 'setup',

},{
  name => 'Startup Mode', foc => 3, # show but disable for foc, show and enable else
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 1, default => 0, steps => 1,
  adr => 140,
  choices => [ 'normal', 'fast' ],
  pos => [1,4],
},{
  name => 'Startup Delay',
  type => 'UINT', len => 0, ppos => 1, min => 0, max => 250, default => 0, steps => 5,
  adr => 141,
  unit => 's',
},{
  name => 'Prearm Checks', reboot => 1,
  type => 'BITMASK16', len => 0, ppos => 0, min => 0, max => 0, default => 0, steps => 0,
  adr => 33,
  bits => ['state is NORMAL', 'IMUs working', 'Motors working', 'Encoders working', 'Voltage OK',
           'Virtual Channel receiving', 'MAVLink receiving',
           'STorM32-Link Qfix', 'STorM32-Link working',
           'Camera connected', 'AUX-0 low', 'AUX-1 low'
#           'NTLogger working'],
            ],
  presets => [ 'Clear' => 0, 'Standard' => 1+2+4+8+16, 'STorM32-Link' => 1+2+4+8+16+64+128+256, ],

},{
  name => 'Virtual Channel Configuration',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 9, default => 0, steps => 1,
  adr => 77,
  choices => [ 'off', 'sum ppm auto', 'sbus', 'sbus inverted',
               'crsf', 'spektrum 10 bit', 'spektrum 11 bit', 'srxl', 'ibus',
               'serial' ],
  column => 2,
},{
  name => 'Pwm Out Configuration',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 3, default => 0, steps => 1,
  adr => 78,
  choices => [ 'off', '1520 us 55 Hz', '1520 us 250 Hz', 'onoff' ],

},{
  name => 'Rc Pitch Offset',
  type => 'INT', len => 0, ppos => 1, min => -1200, max => 1200, default => 0, steps => 5,
  adr => 99,
  unit => '°',
  pos => [2,4],
},{
  name => 'Rc Roll Offset',
  type => 'INT', len => 0, ppos => 1, min => -1200, max => 1200, default => 0, steps => 5,
  adr => 100,
  unit => '°',
},{
  name => 'Rc Yaw Offset',
  type => 'INT', len => 0, ppos => 1, min => -1200, max => 1200, default => 0, steps => 5,
  adr => 101,
  unit => '°',

},{
  name => 'UartX Configuration',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 1, default => 0, steps => 1,
  adr => 48,
  choices => [ 'off', 'uartX @ 115200' ],
  pos => [3,1],

},{
  name => 'Low Voltage Limit',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 11, default => 7, steps => 1,
  adr => 74,
  choices => [ 'off', '2.5 V/cell', '2.6 V/cell', '2.7 V/cell', '2.8 V/cell', '2.9 V/cell', '3.0 V/cell', '3.1 V/cell', '3.2 V/cell', '3.3 V/cell', '3.4 V/cell', '3.5 V/cell' ],
  pos => [3,4],

},{
  name => 'Beep with Motors',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 2, default => 1, steps => 1,
  adr => 143,
  choices => [ 'off', 'basic', 'all' ],
},{
  name => 'NT Logging',
  type => 'BITMASK8', len => 0, ppos => 0, min => 0, max => 0, default => 1, steps => 0,
  adr => 142,
  bits => [ 'Basic', 'Acc + Gyro Raw', 'PID In', 'PID Out', 'Acc + Gyro', 'Inputs', 'PID I D', 'STorM32 Link' ], #not used bits are marked by ''
  presets => [ 'Clear' => 0, 'Standard' => 1+2+4+8+128, 'Tunning' => 1+4+8+64, 'Vibration' => 1+2+4+16, 'All' => 1+2+4+8+16+32+64+128, ],

},{
  name => 'Pitch Motor Usage',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 3, default => 3, steps => 1,
  adr => 55,
  choices => [ 'normal', 'servo', 'startup pos', 'disabled' ],
  column => 4,
},{
  name => 'Roll Motor Usage',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 3, default => 3, steps => 1,
  adr => 56,
  choices => [ 'normal', 'servo', 'startup pos', 'disabled' ],
},{
  name => 'Yaw Motor Usage',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 3, default => 3, steps => 1,
  adr => 57,
  choices => [ 'normal', 'servo', 'startup pos', 'disabled' ],

##--- CONFIGURE GIMBAL tab  --------------------
},{
  name => 'Imu Orientation',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 23, default => 0, steps => 1,
  adr => 51,
  choices => \@ImuChoicesList,
  page => 'gimbalconfig',
  pos => [1,1],
},{
  name => 'Imu2 Orientation',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 23, default => 0, steps => 1,
  adr => 54,
  choices => \@ImuChoicesList,

},{#DEFAULT parameters
  name => 'Pitch Motor Poles', foc => 1, # hide for foc, show for default
  type => 'UINT8', len => 0, ppos => 0, min => 8, max => 42, default => 14, steps => 2,
  adr => 13,
  pos => [2,1],
},{
  name => 'Pitch Motor Direction', foc => 1, # hide for foc, show for default
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 2, default => 2, steps => 1,
  adr => 14,
  choices => [ 'normal',  'reversed', 'auto' ],
},{
  name => 'Pitch Startup Motor Pos', foc => 1, # hide for foc, show for default
  type => 'UINT', len => 5, ppos => 0, min => 0, max => 1008, default => 504, steps => 1,
  adr => 15,
},{#FOC parameters
  name => 'Foc Pitch Motor Direction', foc => 2, # show for foc, hide for default
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 1, default => 0, steps => 1,
  adr => 42,
  choices => [ 'normal',  'reversed', 'auto' ],
  pos => [2,1],
},{
  name => 'Foc Pitch Zero Pos', foc => 2, # show for foc, hide for default
  type => 'INT', len => 5, ppos => 0, min => -16384, max => 16383, default => 0, steps => 8,
  adr => 43,
},{#for all
  name => 'Pitch Offset',
  type => 'INT', len => 5, ppos => 2, min => -300, max => 300, default => 0, steps => 5,
  adr => 58,
  unit => '°',
  pos => [2,4],

},{#DEFAULT parameters
  name => 'Roll Motor Poles', foc => 1, # hide for foc, show for default
  type => 'UINT8', len => 0, ppos => 0, min => 8, max => 42, default => 14, steps => 2,
  adr => 16,
  pos => [3,1],
},{
  name => 'Roll Motor Direction', foc => 1, # hide for foc, show for default
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 2, default => 2, steps => 1,
  adr => 17,
  choices => [ 'normal',  'reversed', 'auto' ],
},{
  name => 'Roll Startup Motor Pos', foc => 1, # hide for foc, show for default
  type => 'UINT', len => 5, ppos => 0, min => 0, max => 1008, default => 504, steps => 1,
  adr => 18,
},{#FOC parameters
  name => 'Foc Roll Motor Direction', foc => 2, # show for foc, hide for default
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 1, default => 0, steps => 1,
  adr => 44,
  choices => [ 'normal',  'reversed', 'auto' ],
  pos => [3,1],
},{
  name => 'Foc Roll Zero Pos', foc => 2, # show for foc, hide for default
  type => 'INT', len => 5, ppos => 0, min => -16384, max => 16383, default => 0, steps => 8,
  adr => 45,
},{#for all
  name => 'Roll Offset',
  type => 'INT', len => 5, ppos => 2, min => -300, max => 300, default => 0, steps => 5,
  adr => 59,
  unit => '°',
  pos => [3,4],

},{#DEFAULT parameters
  name => 'Yaw Motor Poles', foc => 1, # hide for foc, show for default
  type => 'UINT8', len => 0, ppos => 0, min => 8, max => 42, default => 14, steps => 2,
  adr => 19,
  pos => [4,1],
},{
  name => 'Yaw Motor Direction', foc => 1, # hide for foc, show for default
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 2, default => 2, steps => 1,
  adr => 20,
  choices => [ 'normal',  'reversed', 'auto' ],
},{
  name => 'Yaw Startup Motor Pos', foc => 1, # hide for foc, show for default
  type => 'UINT', len => 5, ppos => 0, min => 0, max => 1008, default => 504, steps => 1,
  adr => 21,
},{#FOC parameters
  name => 'Foc Yaw Motor Direction', foc => 2, # show for foc, hide for default
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 1, default => 0, steps => 1,
  adr => 46,
  choices => [ 'normal',  'reversed', 'auto' ],
  pos => [4,1],
},{
  name => 'Foc Yaw Zero Pos', foc => 2, # show for foc, hide for default
  type => 'INT', len => 5, ppos => 0, min => -16384, max => 16383, default => 0, steps => 8,
  adr => 47,
},{#for all
  name => 'Yaw Offset',
  type => 'INT', len => 5, ppos => 2, min => -300, max => 300, default => 0, steps => 5,
  adr => 60,
  unit => '°',
  pos => [4,4],

##--- EXPERT tab  --------------------
},{
  name => 'Motor Mapping', foc => 3, # show but disable for foc, show and enable else
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 5, default => 0, steps => 1,
  adr => 22,
  choices => [ 'M0=pitch , M1=roll',  'M0=roll , M1=pitch', 'roll yaw pitch', 'yaw roll pitch', 'pitch yaw roll', 'yaw pitch roll', ],
  page => 'expert',
  column => 3,
},{
  name => 'Imu Mapping',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 1, default => 0, steps => 1,
  adr => 52,
  choices => [ '1 = id1 , 2 = id2',  '1 = id2 , 2 = id1', ],
},{
  name => 'Lipo Cells',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 6, default => 0, steps => 1,
  adr => 49,
  choices => [ 'auto', '1 S', '2 S', '3 S', '4 S', '5 S', '6 S' ],
  pos => [3,4]
},{
  name => 'Lipo Voltage per Cell',
  type => 'UINT', len => 0, ppos => 2, min => 300, max => 500, default => 420, steps => 5,
  adr => 50,
  unit => 'V'
},{
  name => 'ADC Calibration',
  type => 'UINT', len => 0, ppos => 0, min => 1000, max => 2000, default => 1550, steps => 10,
  adr => 76,

},{
  name => 'Imu AHRS',
  type => 'UINT', len => 5, ppos => 2, min => 0, max => 2500, default => 1000, steps => 100,
  adr => 61,
  unit => 's',
  pos => [4,1]
},{
  name => 'Imu2 Rotation', foc => 3, # show but disable for foc, show and enable else
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 1, default => 0, steps => 1,
  adr => 67,
  choices => [ 'normal', 'xy' ],
},{
  name => 'Startup Gyro Calibration',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 1, default => 0, steps => 1,
  adr => 28,
  choices => [ 'normal', 'skip' ],

},{
  name => 'Acc LPF',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 6, default => 2, steps => 1,
  adr => 71,
  choices => [ 'off', '1.5 ms', '4.5 ms', '12 ms', '25 ms', '50 ms', '100 ms' ],
  column => 1,
},{
  name => 'Rc Adc LPF',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 6, default => 0, steps => 1,
  adr => 98,
  choices => [ 'off', '1.5 ms', '4.5 ms', '12 ms', '25 ms', '50 ms', '100 ms' ],
},{
  name => 'Acc Compensation Method',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 1, default => 1, steps => 1,
  adr => 65,
  choices => [ 'standard', 'advanced' ],
  pos => [1,6],
},{
  name => 'Foc Emergency', foc => 2, # show for foc, hide for default
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 3, default => 0, steps => 1,
  adr => 136,
  choices => [ 'default', 'stage1', 'stage2', 'off' ],
  pos => [2,6],

},{
  name => 'Pan Hold Transition Time',
  type => 'UINT', len => 5, ppos => 3, min => 200, max => 3000, default => 1000, steps => 50,
  adr => 95,
  unit => 's',
  pos => [2,1],
},{
  name => 'Pan Speed Limit', comment => '(0 = off)',
  type => 'UINT8', len => 0, ppos => 0, min => 0, max => 200, default => 50, steps => 5,
  adr => 149,
  unit => '°/s',
},{
  name => 'Pan Accel Limit', comment => '(0 = off)',
  type => 'UINT8', len => 0, ppos => 0, min => 0, max => 250, default => 100, steps => 5,
  adr => 148,
  unit => '°/s/s',

##--- INTERFACES tab --------------------
},{
  name => 'Mavlink Gimbal',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 6, default => 0, steps => 1,
  adr => 144,
  choices => [ 'off', 'Gimbal1', 'Gimbal2', 'Gimbal3', 'Gimbal4', 'Gimbal5', 'Gimbal6', 'AutoPilot1' ],
  page => 'interfaces',
  pos => [1,1],
},{
  name => 'Mavlink Gimbal Stream',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 3, default => 0, steps => 1,
  adr => 146,
  choices => [ 'off', 'mountstatus', 'device status', 'manager status' ],
},{
  name => 'Mavlink ComPort', reboot => 1,
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 2, default => 0, steps => 1,
  adr => 66,
  choices => [ 'uart', 'usb', 'uart2' ],
},{
  name => 'Mavlink System ID', comment => '(0 = a.d.)',
  type => 'UINT8', len => 0, ppos => 0, min => 0, max => 255, default => 0, steps => 1,
  adr => 145,
},{
  name => 'Mavlink Camera',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 6, default => 0, steps => 1,
  adr => 139,
  choices => [ 'off', 'Camera1', 'Camera2', 'Camera3', 'Camera4', 'Camera5', 'Camera6' ],

},{
  name => 'STorM32Link Configuration',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 2, default => 0, steps => 1,
  adr => 137,
  choices => [ 'off', 'yaw drift comp.', 'v1' ],
  pos => [2,1],
#},{
#  name => 'STorM32Link Pitch Offset',
#  type => 'INT', len => 5, ppos => 2, min => -500, max => 500, default => 0, steps => 1,
#  adr => 39,
#  unit => '°',
#},{
#  name => 'STorM32Link Roll Offset',
#  type => 'INT', len => 5, ppos => 2, min => -500, max => 500, default => 0, steps => 1,
#  adr => 40,
#  unit => '°',
#},{
#  name => 'STorM32Link AHRS Factor',
#  type => 'UINT', len => 5, ppos => 2, min => 0, max => 200, default => 100, steps => 1,
#  adr => 34,
#  #unit => '%',

},{
  name => 'Uart Baudrate', reboot => 1,
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 7, default => 0, steps => 1,
  adr => 68,
  choices => [ 'default', '9600', '19200', '38400', '57600', '115200', '230400', '460800' ],
  pos => [3,1],
},{
  name => 'Uart2 Baudrate', reboot => 1,
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 7, default => 0, steps => 1,
  adr => 69,
  choices => [ 'default', '9600', '19200', '38400', '57600', '115200', '230400', '460800' ],
},{
  name => 'Usb Baudrate', reboot => 1,
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 7, default => 0, steps => 1,
  adr => 70,
  choices => [ 'default', '9600', '19200', '38400', '57600', '115200', '230400', '460800' ],

##--- FILTER tab --------------------
},{
  name => 'Filter1 Source',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 12, default => 0, steps => 1,
  adr => 150,
  choices => [ 'off', 'gyro1 all', 'gyro1 x', 'gyro1 y', 'gyro1 z', 'imu1 all', 'imu1 x', 'imu1 y', 'imu1 z', 'mot all', 'mot pitch', 'mot roll', 'mot yaw'  ],
  page => 'filter',
  column => 1,
},{
  name => 'Filter1 Center Frequency',
  type => 'UINT8', len => 0, ppos => 0, min => 20, max => 200, default => 100, steps => 1,
  adr => 151,
  unit => 'Hz',
},{
  name => 'Filter1 Bandwidth',
  type => 'UINT8', len => 0, ppos => 0, min => 5, max => 50, default => 10, steps => 1,
  adr => 152,
  unit => 'Hz',
},{
  name => 'Filter1 Attenuation',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 8, default => 3, steps => 1,
  adr => 153,
  choices => [ '0 dB', '-6 dB', '-12 dB', '-20 dB', '-25 dB', '-30 dB', '-35 dB', '-40 dB', 'inf' ],

},{
  name => 'Filter2 Source',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 12, default => 0, steps => 1,
  adr => 154,
  choices => [ 'off', 'gyro1 all', 'gyro1 x', 'gyro1 y', 'gyro1 z', 'imu1 all', 'imu1 x', 'imu1 y', 'imu1 z', 'mot all', 'mot pitch', 'mot roll', 'mot yaw'  ],
  page => 'filter',
  column => 2,
},{
  name => 'Filter2 Center Frequency',
  type => 'UINT8', len => 0, ppos => 0, min => 20, max => 200, default => 100, steps => 1,
  adr => 155,
  unit => 'Hz',
},{
  name => 'Filter2 Bandwidth',
  type => 'UINT8', len => 0, ppos => 0, min => 5, max => 50, default => 10, steps => 1,
  adr => 156,
  unit => 'Hz',
},{
  name => 'Filter2 Attenuation',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 8, default => 3, steps => 1,
  adr => 157,
  choices => [ '0 dB', '-6 dB', '-12 dB', '-20 dB', '-25 dB', '-30 dB', '-35 dB', '-40 dB', 'inf' ],

},{
  name => 'Filter3 Source',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 12, default => 0, steps => 1,
  adr => 158,
  choices => [ 'off', 'gyro1 all', 'gyro1 x', 'gyro1 y', 'gyro1 z', 'imu1 all', 'imu1 x', 'imu1 y', 'imu1 z', 'mot all', 'mot pitch', 'mot roll', 'mot yaw'  ],
  page => 'filter',
  column => 3,
},{
  name => 'Filter3 Center Frequency',
  type => 'UINT8', len => 0, ppos => 0, min => 20, max => 200, default => 100, steps => 1,
  adr => 159,
  unit => 'Hz',
},{
  name => 'Filter3 Bandwidth',
  type => 'UINT8', len => 0, ppos => 0, min => 5, max => 50, default => 10, steps => 1,
  adr => 160,
  unit => 'Hz',
},{
  name => 'Filter3 Attenuation',
  type => 'LIST', len => 0, ppos => 0, min => 0, max => 8, default => 3, steps => 1,
  adr => 161,
  choices => [ '0 dB', '-6 dB', '-12 dB', '-20 dB', '-25 dB', '-30 dB', '-35 dB', '-40 dB', 'inf' ],

##--- SERVO tab --------------------
},{
  name => 'Servo Pitch P', foc => 4, # show and enable for foc, show but disable else
  type => 'UINT8', len => 3, ppos => 0, min => 0, max => 255, default => 0, steps => 1,
  adr => 162,
  page => 'servo',
  pos => [1,1],
},{
  name => 'Servo Pitch I', foc => 4, # show and enable for foc, show but disable else
  type => 'UINT8', len => 3, ppos => 0, min => 0, max => 255, default => 0, steps => 1,
  adr => 163,
},{
  name => 'Servo Pitch D', foc => 4, # show and enable for foc, show but disable else
  type => 'UINT8', len => 3, ppos => 0, min => 0, max => 255, default => 0, steps => 1,
  adr => 164,
},{
  name => 'Servo Pitch DLPF', foc => 4, # show and enable for foc, show but disable else
  type => 'UINT8', len => 3, ppos => 0, min => 0, max => 255, default => 0, steps => 1,
  adr => 165,

},{
  name => 'Servo Roll P', foc => 4, # show and enable for foc, show but disable else
  type => 'UINT8', len => 3, ppos => 0, min => 0, max => 255, default => 0, steps => 1,
  adr => 166,
  pos => [2,1],
},{
  name => 'Servo Roll I', foc => 4, # show and enable for foc, show but disable else
  type => 'UINT8', len => 3, ppos => 0, min => 0, max => 255, default => 0, steps => 1,
  adr => 167,
},{
  name => 'Servo Roll D', foc => 4, # show and enable for foc, show but disable else
  type => 'UINT8', len => 3, ppos => 0, min => 0, max => 255, default => 0, steps => 1,
  adr => 168,
},{
  name => 'Servo Roll DLPF', foc => 4, # show and enable for foc, show but disable else
  type => 'UINT8', len => 3, ppos => 0, min => 0, max => 255, default => 0, steps => 1,
  adr => 169,

},{
  name => 'Servo Yaw P', foc => 4, # show and enable for foc, show but disable else
  type => 'UINT8', len => 3, ppos => 0, min => 0, max => 255, default => 0, steps => 1,
  adr => 170,
  pos => [3,1],
},{
  name => 'Servo Yaw I', foc => 4, # show and enable for foc, show but disable else
  type => 'UINT8', len => 3, ppos => 0, min => 0, max => 255, default => 0, steps => 1,
  adr => 171,
},{
  name => 'Servo Yaw D', foc => 4, # show and enable for foc, show but disable else
  type => 'UINT8', len => 3, ppos => 0, min => 0, max => 255, default => 0, steps => 1,
  adr => 172,
},{
  name => 'Servo Yaw DLPF', foc => 4, # show and enable for foc, show but disable else
  type => 'UINT8', len => 3, ppos => 0, min => 0, max => 255, default => 0, steps => 1,
  adr => 173,

##--- GimbalModel tab --------------------
},{
  name => 'T1 Pitch', foc => 4, # show and enable for foc, show but disable else
  type => 'UINT', len => 5, ppos => 2, min => 1, max => 500, default => 100, steps => 1,
  adr => 176,
  page => 'gimbalmodel',
  pos => [1,2],

},{
  name => 'T1 Roll', foc => 4, # show and enable for foc, show but disable else
  type => 'UINT', len => 5, ppos => 2, min => 1, max => 500, default => 100, steps => 1,
  adr => 177,
  pos => [2,2],
},{
  name => 'T2 Roll', foc => 4, # show and enable for foc, show but disable else
  type => 'UINT', len => 5, ppos => 2, min => 0, max => 500, default => 0, steps => 1,
  adr => 179,

},{
  name => 'T1 Yaw', foc => 4, # show and enable for foc, show but disable else
  type => 'UINT', len => 5, ppos => 2, min => 1, max => 500, default => 100, steps => 1,
  adr => 178,
  pos => [3,2],
},{
  name => 'T2 Yaw', foc => 4, # show and enable for foc, show but disable else
  type => 'UINT', len => 5, ppos => 2, min => 0, max => 500, default => 0, steps => 1,
  adr => 180,
#},{
#  name => 'T3 Yaw', foc => 4, # show and enable for foc, show but disable else
#  type => 'UINT', len => 5, ppos => 2, min => 0, max => 500, default => 0, steps => 1,
#  adr => 181,

}
);

my %NameToOptionHash = (); #will be populated by PopulateOptions()


###############################################################################
# Allgemeine Resourcen

use lib 'o323BgcPackages';
use myIcon;
use myCom;
use myUtils;

my $Icon = Win32::GUI::BitmapInline->newIcon( getMyIcon() );

my $ExePath = dirname(abs_path($0));
$ExePath =~ tr/\//\\/;
SetBasePath($ExePath);


#---------------------------
# Inifile
#---------------------------
my $IniFileName = $BGCStr."Tool.ini";
my $IniFile;
if( open(F,"<$IniFileName") ){
  close( F );
  $IniFile = new Config::IniFiles( -file => $IniFileName );
}
if( not defined $IniFile ){
  #$ErrorStr.= "Error in ".$IniFileName." or ini file not found\n";
}else{
  $IniFile->ReadConfig();
}

#---------------------------
# Init: Options
#---------------------------
my $BOARDCONFIGURATION_IS_DEFAULT = 0; # = $cfDefault
my $BOARDCONFIGURATION_IS_FOC     = 1; # = $cfFoc

my $ActiveBoardConfiguration = $BOARDCONFIGURATION_IS_DEFAULT;
##my $ActiveBoardConfiguration = $BOARDCONFIGURATION_IS_FOC;

if( defined $IniFile ){
  if( defined $IniFile->val('BOARDCONFIGURATION','LastActiveConfiguration') ){
    $ActiveBoardConfiguration = $IniFile->val('BOARDCONFIGURATION','LastActiveConfiguration');
  }
}

my @OptionList = ();
my $ColNumber = 4;
my $RowNumber = 7;

sub ClearOptionList{
  @OptionList = ();
  undef @OptionList;
}

sub OptionToSkip{
  my $Option = shift;
  if( uc($Option->{name}) eq uc('Firmware Version') ){ return 1; }
  if( uc($Option->{name}) eq uc('Name') ){ return 2; }
  if( uc($Option->{name}) eq uc('Board') ){ return 3; }
  return 0;
}

#determines size
sub SizeOfOptionFromPosInBuf{
  my $adr = shift;
  if( $adr >= $CMD_g_PARAMETER_ZAHL ){ return -1; }
  return $PosInBuf[$adr+1] - $PosInBuf[$adr] ;
}

#is called in Read with parameters, in ClearOptions as SetOptionList()
# ensures proper entries in options
# requires:   type, name, and len, ppos, min, max if not str
# adds:       size, default, steps, unit, expert, hidden
# untouched:  choices, pos, column
sub SetOptionList{
  my $ErrorStr = '';
  #clear optionlist
  ClearOptionList();
  #DO HERE THE AVAILABLE OPTIONS!
  @OptionList = @OptionList_L256;
  #check options for consistency and validity
  my $page = 'dashboard';
  foreach my $Option (@OptionList){

    # check len, ppos, min, max
    switch( $Option->{type} ){
      case ['UINT','INT','UINT8','INT8']{
        if( not defined $Option->{len} ){ $ErrorStr .= "Error in option ".$Option->{name}.", len is missing\n"; next; }
        if( not defined $Option->{ppos} ){ $ErrorStr .= "Error in option ".$Option->{name}.", ppos is missing\n"; next; }
        if( not defined $Option->{min} ){ $ErrorStr .= "Error in option ".$Option->{name}.", min is missing\n"; next; }
        if( not defined $Option->{max} ){ $ErrorStr .= "Error in option ".$Option->{name}.", max is missing\n"; next; }
      }
    }
    switch( $Option->{type} ){
      case ['LIST']{
        if( not defined $Option->{min} ){ $ErrorStr .= "Error in option ".$Option->{name}.", min is missing\n"; next; }
        if( not defined $Option->{max} ){ $ErrorStr .= "Error in option ".$Option->{name}.", max is missing\n"; next; }
      }
    }

    # set and check size, check for unknown type
    switch( $Option->{type} ){
      case ['BITMASK8','LIST','UINT8','INT8','UINT8+READONLY','INT8+READONLY']{
        $Option->{size} = 1; #XXX 1; ## the size is actually 2 since always a uint16_t is used !!!!
      }
      case ['BITMASK16','UINT','INT','UINT+READONLY','INT+READONLY']{
        $Option->{size} = 2;
      }
      case ['STR+READONLY']{
        if( not defined $Option->{size} ){ $ErrorStr .= "Error in option ".$Option->{name}.", size is missing\n"; next; }
      }
      case ['SCRIPT']{
        if( not defined $Option->{adr} ){ $ErrorStr .= "SCRIPT option has no adr\n"; next; }
      }
      else {
        $ErrorStr .= "Error in option ".$Option->{name}.", option has unknown type (7)\n"; next;
      }
    }
    if( not defined $Option->{size} ){ $ErrorStr .= "Error in option ".$Option->{name}.", size is missing (2)\n"; next; }

    # check of presence of adr
    if( $Option->{type} ne 'STR+READONLY' ){
      if( not defined $Option->{adr} ){ $ErrorStr .= "Option ".$Option->{name}." has not adr\n"; next; }
      if( $Option->{size} != SizeOfOptionFromPosInBuf($Option->{adr}) ){
        $ErrorStr .= "Error in option ".$Option->{name}.", size inconsistency\n"; next;
      }
    }

    # check lists
    if( $Option->{type} eq 'LIST' ){
      if( not defined $Option->{choices} ){ $ErrorStr .= "Error in option ".$Option->{name}.", no choices in list\n"; }
    }

    #MISSING: check that $Option->{modes}->{lc($s)} is existing and correct (no problem in write)
    # complete options
    if( not defined $Option->{comment} ) { $Option->{comment} = ''; }
    if( not defined $Option->{default} ){
      if( index($Option->{type},'STR') >= 0 ){
         $Option->{default} = '';
      }else{
        if( $Option->{min} > 0 )   {  $Option->{default} = $Option->{min}; }
        elsif( $Option->{max} < 0 ){  $Option->{default} = $Option->{max}; }
        else{ $Option->{default} = 0; }
      }
    }
    if( not defined $Option->{len} ){ $Option->{len} = 0; }
    if( not defined $Option->{ppos} ){ $Option->{ppos} = 0; }
    if( not defined $Option->{steps} ) { $Option->{steps} = 1; }
    if( not defined $Option->{unit} )  { $Option->{unit} = ''; }
    if( not defined $Option->{page} ){
      $Option->{page} = $page;
    }else{
      $page = $Option->{page};
    }
    if( GetTabIndex($page) < 0 ){ $ErrorStr .= "Error in option ".$Option->{name}.", page (".$page.") is incorrect (3)\n"; next }
    if( not defined $Option->{hidden} ){ $Option->{hidden} = 0; }

    if( not defined $Option->{foc} ){ $Option->{foc} = 0; }
    if( not defined $Option->{reboot} ){ $Option->{reboot} = 0; }
  }
  if( $ErrorStr ne '' ){ print($ErrorStr); die;}
}

#---------------------------
# Init: Font
#---------------------------
my $StdWinFontName = 'Tahoma';
my $StdWinFontSize = 8;
my $StdTextFontSize = 10;

if( defined $IniFile ){
  if( defined $IniFile->val('SYSTEM','FontName') ){ $StdWinFontName= $IniFile->val( 'SYSTEM','FontName'); }
  if( defined $IniFile->val('SYSTEM','FontSize') ){ $StdWinFontSize= $IniFile->val( 'SYSTEM','FontSize'); }
  if( defined $IniFile->val('SYSTEM','TextFontSize') ){ $StdTextFontSize= $IniFile->val( 'SYSTEM','TextFontSize'); }
}
my $StdWinFont= Win32::GUI::Font->new(-name=>$StdWinFontName, -size=>$StdWinFontSize, -bold => 0, );
my $StdWinFontBold= Win32::GUI::Font->new(-name=>$StdWinFontName, -size=>$StdWinFontSize, -bold => 0, );
my $StdWinFontSmall= Win32::GUI::Font->new(-name=>$StdWinFontName, -size=>$StdWinFontSize-2, -bold => 0, );
my $StdTextFont= Win32::GUI::Font->new(-name=>'Lucida Console', -size=>$StdTextFontSize );
my $StdScriptFont= Win32::GUI::Font->new(-name=>$StdWinFontName, -size=>$StdWinFontSize, -bold => 0, );
#my $StdScriptFont= Win32::GUI::Font->new(-name=>'Lucida Console', -size=>$StdWinFontSize, -bold => 0, );

my $MicroFont= Win32::GUI::Font->new(-name=>'Lucida Console',-size=>1,);
my $StatusFont= Win32::GUI::Font->new(-name=>'Tahoma',-size=>8,);

#---------------------------
# Init: Dialog location
#---------------------------
my $DialogXPos= 100;
my $DialogYPos= 100;
if( defined $IniFile ){
  if( defined $IniFile->val('SYSTEM','XPos') ){ $DialogXPos= $IniFile->val( 'SYSTEM','XPos'); }
  if( defined $IniFile->val('SYSTEM','YPos') ){ $DialogYPos= $IniFile->val( 'SYSTEM','YPos'); }
}
if( $DialogXPos<0 ){ $DialogXPos = 100; }
if( $DialogYPos<0 ){ $DialogYPos = 100; }

my $DataDisplayXPos= 100;
my $DataDisplayYPos= 100;
if( defined $IniFile ){
  if( defined $IniFile->val('SYSTEM','DataDisplayXPos') ){ $DataDisplayXPos= $IniFile->val( 'SYSTEM','DataDisplayXPos'); }
  if( defined $IniFile->val('SYSTEM','DataDisplayYPos') ){ $DataDisplayYPos= $IniFile->val( 'SYSTEM','DataDisplayYPos'); }
}
if( $DataDisplayXPos<0 ){ $DataDisplayXPos = 100; }
if( $DataDisplayYPos<0 ){ $DataDisplayYPos = 100; }

#---------------------------
# Init: Port & enumerate ports
#---------------------------
my $PORTTYPE_UNDEFINED = 0; #constant
my $PORTTYPE_COM = 1;       #constant
my $PORTTYPE_ESP = 2;       #constant

my $Port = '';
my $PortType = $PORTTYPE_UNDEFINED; #this is set whenever $Port is opened

my $EspWifiSSID = '192.168.4.1';
my $EspWifiPort = '80'; #'23'; #'7167'; #23';
my $EspWifiName = 'STorM32 ESP';

sub ESPIsAvailable{
  my $ret = 0;
  eval 'my $wlan = Win32::Wlan->new;
        if( $wlan->available ){
          if( $wlan->connection->{profile_name} eq $EspWifiName ){ $ret = 1; }
        }';
  if( not $@ ){ return $ret; }
  print($@);
  return 0;
}

#all methods:
# https://stackoverflow.com/questions/1388871/how-do-i-get-a-list-of-available-serial-ports-in-win32
# https://www.perlmonks.org/?node_id=921590
#this link has all WMI dic entries, but I found that only {Caption},{Description},{Name} yields info
# https://www.activexperts.com/admin/scripts/wmi/perl/0383/
use Win32::OLE('in');
sub GetComPortNiceNames{
  my @ComNameList = ();
  my $objWMIService = Win32::OLE->GetObject( "winmgmts:\\\\.\\root\\CIMV2" );
  if( $objWMIService ){
    my $items = $objWMIService->ExecQuery(
          "SELECT * FROM Win32_PnPEntity WHERE Name LIKE '%(COM%'", "WQL", 0x10);
    foreach my $item (in $items){
      #print "Name: $item->{Name}\n";
      my $com = $item->{Name}; # 'PX4 FMU (COM18)'
      $com =~ s/.*(COM\d{1,3}).*/$1/;
      my $name = $item->{Name};
      $name =~ s/(.*?)[ ]*\(COM\d{1,3}\)/$1/;
      my $nicename = TrimStrToLength($com,10+4-length($com)).' ('.$name.')';
      #print "$nicename\n";
      push( @ComNameList, $nicename );
    }
  }
  return @ComNameList;
}

sub GetComPorts{
  my @ComNiceNameList = GetComPortNiceNames();
  my @ComList = ();
  #http://cpansearch.perl.org/src/CHORNY/Win32API-File-0.1200/ex/ListDevs.plx
  my $size = 4096; my $all;
  while( !QueryDosDevice([],$all,$size) ){ $size *= 2; }
  for( split(/\0/,$all) ){
    if( (QueryDosDevice($_,$all,0)) && ($_ =~ /^COM/) ){
      my $com = $_;  my $nicename = '';
      foreach my $n (@ComNiceNameList){ if( $com eq ExtractCom($n) ){ $nicename = $n; last; } }
      if( $nicename ne '' ){
        if( $all =~ m/usb/i ){ $nicename =~ s/\(/\(USB /; } #to keep
        push(@ComList, $nicename);
      }else{
        push(@ComList, TrimStrToLength($com,10+4-length($com))."( ".ExtractComName($all)." )" );
      }
    }
  }
  @ComList = sort{substr($a,3,3)<=>substr($b,3,3)} @ComList;
  if( ESPIsAvailable() ){ push( @ComList, "ESP          ($EspWifiName)" ); }
  if( scalar @ComList == 0 ){ push( @ComList, 'COM1' ); }
  return (scalar @ComList, @ComList);
}

my ($GetComPortOK, @PortList) = GetComPorts();
if( defined $IniFile ){
  if( defined $IniFile->val('PORT','Port') ){ $Port= $IniFile->val('PORT','Port'); } #$Port has only COMXX part
  #this adds the port specified in Ini file even if it is not present on system
  if( not grep{ExtractCom($_) eq ExtractCom($Port)} @PortList ){ push( @PortList, $Port ); }
}
if( $Port eq '' ){
  if( $GetComPortOK > 0 ){ $Port = $PortList[0]; }
}else{
  if( $GetComPortOK > 0 ){
    if( not grep{ExtractCom($_) eq $Port} @PortList ){
      if( scalar @PortList > 1 ){ $Port = $PortList[1]; }else{ $Port = $PortList[0]; }
    }
  }else{
    $Port = '';
  }
}
#$Port has now COM part + friendly name, or ESP + friendly name

#---------------------------
# Init: Baudrate
#---------------------------
my $Baudrate = 115200; #57600; #9600; #115200;

if( defined $IniFile ){
  if( defined $IniFile->val('PORT','BaudRate') ){
    $Baudrate= StrToDez( $IniFile->val( 'PORT','BaudRate') );
  }
}

#$Baudrate = 115200;
#$Baudrate = 57600;

#---------------------------
# Init: Timing
#---------------------------
my $ExecuteCmdTimeOutFirst= 8 + 25; #3; #increase by 25 = 500 to handle slow SiK telemetry links!!
my $ExecuteCmdTimeOut= 50; #100 ms
my $MaxConnectionLost = 2; # this allows two failures

if( defined $IniFile ){
  if( defined $IniFile->val('TIMING','ExecuteCmdTimeOutFirst') ){
    $ExecuteCmdTimeOutFirst= $IniFile->val('TIMING','ExecuteCmdTimeOutFirst');
  }
  if( defined $IniFile->val('TIMING','ExecuteCmdTimeOut') ){
    $ExecuteCmdTimeOut= $IniFile->val('TIMING','ExecuteCmdTimeOut');
  }
  if( defined $IniFile->val('TIMING','MaxConnectionLost') ){
    $MaxConnectionLost= $IniFile->val('TIMING','MaxConnectionLost');
  }
}

#---------------------------
# Init: Protocol
#---------------------------
my $MAV_COMP_ID_GIMBAL_forward = 154; #forward declaration
my $MAV_COMP_ID_TUNNEL_NODE_forward = 242; #forward declaration

my $MavlinkGuiComponentId = $MAV_COMP_ID_TUNNEL_NODE_forward;
my $MavlinkDefaultSystemId = 1;
my $MavlinkGimbalDefaultComponentId = $MAV_COMP_ID_GIMBAL_forward;
my @MavlinkComPorts = ('PX4 FMU');

if( defined $IniFile ){
  if( defined $IniFile->val('PROTOCOL','MavlinkGuiComponentId') ){
    $MavlinkGuiComponentId= $IniFile->val('PROTOCOL','MavlinkGuiComponentId');
  }
  if( defined $IniFile->val('PROTOCOL','MavlinkDefaultSystemId') ){
    $MavlinkDefaultSystemId= $IniFile->val('PROTOCOL','MavlinkDefaultSystemId');
  }
  if( defined $IniFile->val('PROTOCOL','MavlinkGimbalDefaultComponentId') ){
    $MavlinkGimbalDefaultComponentId= $IniFile->val('PROTOCOL','MavlinkGimbalDefaultComponentId');
  }
  if( defined $IniFile->val('PROTOCOL','MavlinkComPorts') ){
    @MavlinkComPorts= split(/,/,$IniFile->val('PROTOCOL','MavlinkComPorts'));
  }
}
if( $MavlinkGuiComponentId < 1 ){ $MavlinkGuiComponentId = $MAV_COMP_ID_TUNNEL_NODE_forward; }
if( $MavlinkGuiComponentId > 255 ){ $MavlinkGuiComponentId = $MAV_COMP_ID_TUNNEL_NODE_forward; }
if( $MavlinkDefaultSystemId < 1 ){ $MavlinkDefaultSystemId = 1; }
if( $MavlinkDefaultSystemId > 255 ){ $MavlinkDefaultSystemId = 1; }
if( $MavlinkGimbalDefaultComponentId < 1 ){ $MavlinkGimbalDefaultComponentId = $MAV_COMP_ID_GIMBAL_forward; }
if( $MavlinkGimbalDefaultComponentId > 255 ){ $MavlinkGimbalDefaultComponentId = $MAV_COMP_ID_GIMBAL_forward; }

#---------------------------
# Init: Flash tab
#---------------------------
my $FirmwareHexFileDir = 'o323BgcFirmwareFiles';
my $NtFirmwareHexFileDir = 'o323BgcNtFirmwareFiles';
#my $STLinkPath = 'bin\ST\STLink';
#my $STMFlashLoaderPath = 'bin\ST\STMFlashLoader';
#my $STMFlashLoaderExe = 'STMFlashLoaderOlliW.exe';
my $STM32CubeProgrammerPath = 'bin\ST\STM32CubeProgrammer\bin';

my $BGCToolRunFile = $BGCStr."Tool_Run";
my $StLink = 'ST-Link/V2 SWD';
my $SystemBootloader = 'System Bootloader @ UART1';
my $Storm32UpgradeViaUSB = 'Upgrade via STorM32 USB port';
my $NtUpgradeViaUSB = 'Upgrade via STorM32 USB port';
my $NtUpgradeViaSystemBootloader = 'Upgrade via System Bootloader @ UART1';
my $NtFlashViaUSB = 'System Bootloader via STorM32 USB port';

my @Storm32ProgrammerList = ( $StLink, $SystemBootloader );
my @Storm32ProgrammerListV3X = ( $Storm32UpgradeViaUSB, $StLink, $SystemBootloader );
my @NtProgrammerList = ( $NtUpgradeViaUSB, $NtFlashViaUSB, $StLink, $SystemBootloader );
##my @NtProgrammerList = ( $NtUpgradeViaUSB, $NtUpgradeViaSystemBootloader, $NtFlashViaUSB, $StLink, $SystemBootloader );
##my @NtProgrammerList = ( $NtUpgradeViaUSB, $NtUpgradeViaSystemBootloader, $StLink, $SystemBootloader );

my $STorM32Board = '';
my $FirmwareVersion = '';
my $Storm32Programmer = $Storm32ProgrammerList[0];
my $Storm32ProgrammerV3X = $Storm32ProgrammerListV3X[0];
my $NtProgrammer = $NtProgrammerList[0];
my $CheckNtModuleVersions = 1;

if( defined $IniFile ){
  if( defined $IniFile->val('FLASH','HexFileDir') ){ $FirmwareHexFileDir= RemoveBasePath($IniFile->val('FLASH','HexFileDir')); }
  if( defined $IniFile->val('FLASH','NtHexFileDir') ){ $NtFirmwareHexFileDir= RemoveBasePath($IniFile->val('FLASH','NtHexFileDir')); }
  if( defined $IniFile->val('FLASH','Board') ){ $STorM32Board= $IniFile->val('FLASH','Board'); }
  if( defined $IniFile->val('FLASH','Version') ){ $FirmwareVersion= $IniFile->val('FLASH','Version'); }
  if( defined $IniFile->val('FLASH','Stm32Programmer') ){ $Storm32Programmer= $IniFile->val('FLASH','Stm32Programmer'); }
  if( defined $IniFile->val('FLASH','Stm32ProgrammerV3X') ){ $Storm32ProgrammerV3X= $IniFile->val('FLASH','Stm32ProgrammerV3X'); }
  if( defined $IniFile->val('FLASH','NtProgrammer') ){ $NtProgrammer= $IniFile->val('FLASH','NtProgrammer'); }
  if( defined $IniFile->val('FLASH','CheckNtModuleVersions') ){ $CheckNtModuleVersions= $IniFile->val('FLASH','CheckNtModuleVersions'); }
  if( defined $IniFile->val('FLASH','STM32CubeProgrammerPath') ){ $STM32CubeProgrammerPath= $IniFile->val('FLASH','STM32CubeProgrammerPath'); }
}

if( not grep{$_->{name} eq $STorM32Board} @STorM32BoardList ){ $STorM32Board= $STorM32BoardList[0]->{name}; }
if( not grep{$_ eq $FirmwareVersion} @FirmwareVersionList ){ $FirmwareVersion= $FirmwareVersionList[0]; }
if( not grep{$_ eq $Storm32Programmer} @Storm32ProgrammerList ){ $Storm32Programmer= $Storm32ProgrammerList[0]; }
if( not grep{$_ eq $Storm32ProgrammerV3X} @Storm32ProgrammerListV3X ){ $Storm32ProgrammerV3X= $Storm32ProgrammerListV3X[0]; }
if( not grep{$_ eq $NtProgrammer} @NtProgrammerList ){ $NtProgrammer= $NtProgrammerList[0]; }


#---------------------------
# Init: Packages
#---------------------------
my $PackagesDir = 'o323BgcPackages';

if( defined $IniFile ){
  if( defined $IniFile->val('PACKAGES','PackagesDir') ){ $PackagesDir= RemoveBasePath($IniFile->val('PACKAGES','PackagesDir')); }
}

#---------------------------
# Init: Toolsfile
#---------------------------
my $w_Main;
sub ExecuteTool{ return $w_Main->ShellExecute('open',shift,shift,'',1); }

#---------------------------
# Init: Option Colors
#---------------------------
my $OptionInvalidColor = 0xaaaaFF; #red
my $OptionValidColor = 0xbbFFbb; #green
my $OptionModifiedColor = 0xFFbbbb; #blue
if( defined $IniFile ){
  if( defined $IniFile->val('DIALOG','OptionInvalidColor') ){ $OptionInvalidColor= oct($IniFile->val('DIALOG','OptionInvalidColor')); }
  if( defined $IniFile->val('DIALOG','OptionValidColor') ){ $OptionValidColor= oct($IniFile->val('DIALOG','OptionValidColor')); }
  if( defined $IniFile->val('DIALOG','OptionModifiedColor') ){ $OptionModifiedColor= oct($IniFile->val('DIALOG','OptionModifiedColor')); }
}

#---------------------------
# Init: Links
#---------------------------
my $HelpLink = 'http://www.olliw.eu/storm32bgc-wiki/Manuals_and_Tutorials';
my $ConfigureGimbalStepIIHelpLink = 'http://www.olliw.eu/storm32bgc-wiki/Getting_Started#Basic_Controller_Configuration_Quick_Trouble_Shooting';
if( defined $IniFile ){
  if( defined $IniFile->val('LINKS','HelpLink') ){ $HelpLink= $IniFile->val('LINKS','HelpLink'); }
  if( defined $IniFile->val('LINKS','ConfigureGimbalStepIIHelpLink') ){
    $ConfigureGimbalStepIIHelpLink= $IniFile->val('LINKS', 'ConfigureGimbalStepIIHelpLink');
  }
}

#---------------------------
# Init: Startup Notes, Simplified PIDs, Auto write PID Changes
#---------------------------
my $ShowUpdateNotesAtStartup = 1;
my $UseAutoWritePIDChanges = 1; #activated by default

if( defined $IniFile ){
  if( defined $IniFile->val('SYSTEM','ShowNotesAtStartup') ){ $ShowUpdateNotesAtStartup= $IniFile->val('SYSTEM', 'ShowNotesAtStartup'); }
  if( defined $IniFile->val('SYSTEM','UseAutoWritePIDChanges') ){ $UseAutoWritePIDChanges= $IniFile->val('SYSTEM','UseAutoWritePIDChanges'); }
}
if( $ShowUpdateNotesAtStartup>0 ){ $ShowUpdateNotesAtStartup = 1; }else{ $ShowUpdateNotesAtStartup = 0; }
if( $UseAutoWritePIDChanges>0 ){ $UseAutoWritePIDChanges = 1; }else{ $UseAutoWritePIDChanges = 0; }

#---------------------------
# Further Global Variables
#---------------------------
my $p_Serial = ();
my $p_Socket = ();

my $AllFieldsAreReadyToUse = 0; #this is to avoid calling undefined fields
my $OptionsLoaded = 0; #somewhat unfortunate name, controls behavior before first read or load

my $PortIsOpen = 0; #indicates if the port is opened
my $Connected = 0; #indicates if the connection to the BGC is established

my $Execute_IsRunning = 0; #to prevent double clicks ###currently not used ????
my $DataDisplay_IsRunning = 0;
my $ConfigureGimbalTool_IsRunning = 0;
my $Acc16PCalibration_IsRunning = 0;
my $InputsTool_IsRunning = 0;
my $MavlinkInspectorTool_IsRunning = 0;

my $ACC_GRAVITY = 8192; #const 16384; #8192; #16384;

my $ReadWriteWithFullOutput_Global = 0;


#-----------------------------------------------------------------------------#
###############################################################################
###############################################################################
#
# Main Window
#
###############################################################################
###############################################################################
#-----------------------------------------------------------------------------#

sub GetTabIndex{
  my $tab = uc(shift);
  for(my $i=0; $i<scalar(@SetupTabList); $i++){
    if( $tab eq uc($SetupTabList[$i]) ){ return $i; }
  }
  return -1; #not found, should never happen
}

my $OPTIONSWIDTH_X = 180; #const
my $OPTIONSWIDTH_Y = 45; #const

my $xsize = $ColNumber*$OPTIONSWIDTH_X +40 -15 +20;
my $tabsize = $RowNumber*$OPTIONSWIDTH_Y + 40;
my $statussize = 12 +1;
my $ysize = 225 + $tabsize + $statussize;

my $m_Menubar= Win32::GUI::Menu-> new(
  'Setting' => '',
#    '>Load Parameters from File...', 'm_LoadSettings', #saves settings and scripts into config file
#    '>Save Parameters to File...', 'm_SaveSettings', #saves all settings into another .ini file
#    '>-', 0,
    '>Import from File...', 'm_ImportSettings',
    '>Export to File...', 'm_ExportSettings',
#    '>Save Settings to File...', 'm_SaveSettings', #finally removed, if I need it recompile
    '>-', 0,
    '>Retrieve from EEPROM', 'm_RetrieveSettings',
#    '>-', 0,
#    '>Store to EEPROM', 'm_StoreSettings',
    '>-', 0,
    '>Default', 'm_DefaultSettings',
    '>Clear GUI', 'm_Clear',
    '>-', 0,
    '>Share Settings...', 'm_ShareSettings',
    '>-', 0,
    '>Exit', 'm_Exit',
  'Tools' => '',
    ">Restart Controller", "t_RestartController",
    ">-", 0,
    ">Get Current Encoder Positions", 't_GetCurrentEncoderPositions',
    ">Change Encoder Support Tool...", 't_ChangeBoardConfiguration',
    ">-", 0,
    ">NT Module CLI Tool...", 't_NtCliTool',
    ">NTLogger RTC Tool...", 't_RTCConfigTool',
    ">-", 0,
    ">Erase EEPROM to 0xFF", 't_EraseEeprom',
  'Experts Only' => '',
    ">Interfaces Tab...", 't_InterfacesTool',
    ">Expert Tab...", 't_ExpertTool',
    ">Filter Tab...", 't_FilterTool',
    ">Gimbal Model Tab...", 't_GimbalModelTool',
    ">Servo Tab...", 't_ServoTool',
    ">-", 0,
    ">RC Command Tool...", 't_RcCmdTool',
    ">Inputs Tool...", 't_InputsTool',
    ">Mavlink Inspector Tool...", 't_MavlinkInspectorTool',
    ">-", 0,
    ">Gui Baudrate...", 't_GuiBaudrate',
##    @ExpertTool,
##    @InterfacesTool,
##    ">-", 0,
##    ">Change Uart Baudrate Tool...", 't_ChangeBaudrate',
##    ">Change Board Configuration Tool...", 't_ChangeBoardConfiguration',
##    ">Change Encoder Support Tool...", 't_ChangeBoardConfiguration',
  '?' => '',
    '>Help...' => 'm_Help',
    '>Check for Updates...' => 'm_Update',
    '>Update Instructions...' => 'm_UpdateNotes',
    '>About...' => 'm_About',
);

$w_Main= Win32::GUI::Window->new( -name=> 'm_Window', -font=> $StdWinFont,
  -text=> '', -size=> [$xsize,$ysize], -pos=> [$DialogXPos,$DialogYPos],
  -menu=> $m_Menubar,
  -resizable=>0, -maximizebox=>0, -hasmaximize=>0,
);
$w_Main->SetIcon($Icon);

my $xpos= 10;
my $ypos= 10;

my %f_Tab = ();
$w_Main->AddTabFrame(-name=> 'w_Tab', -font=> $StdWinFontBold,
  -pos=> [$xpos,$ypos], -size=>[$xsize-22-4, $tabsize ],
  #-background=> [96,96,96],
  -onChange => sub{
    my $cur = $w_Main->w_Tab->SelectedItem();
    if( $cur < $MaxSetupTabs ){
      $w_Main->m_Read->Enable(); if($OptionsLoaded){ $w_Main->m_Write->Enable(); }
      SynchroniseConfigTabs($cur);
    }else{
      $w_Main->m_Read->Disable(); $w_Main->m_Write->Disable();
    }
    w_Tab_Click(); 1; },
);
$w_Main->w_Tab->MinTabWidth(65);
$f_Tab{dashboard} = $w_Main->w_Tab->InsertItem(-text=> 'Dashboard');
$f_Tab{pid} = $w_Main->w_Tab->InsertItem(-text=> '      PID');
$f_Tab{pan} = $w_Main->w_Tab->InsertItem(-text=> '      Pan');
$f_Tab{rcinputs} = $w_Main->w_Tab->InsertItem(-text=> ' Rc Inputs');
$f_Tab{functions} = $w_Main->w_Tab->InsertItem(-text=> ' Functions');
$f_Tab{scripts} = $w_Main->w_Tab->InsertItem(-text=> '    Scripts');
$f_Tab{setup} = $w_Main->w_Tab->InsertItem(-text=> '    Setup' );
$f_Tab{gimbalconfig} = $w_Main->w_Tab->InsertItem(-text=> '    Gimbal');
$f_Tab{calibrateacc} = $w_Main->w_Tab->InsertItem(-text=> 'Calibration');
$f_Tab{flash} = $w_Main->w_Tab->InsertItem(-text=> '  Firmware');
#these are windows, not tabs #we keep them for py parser to find them and extract the names
#$f_Tab{expert} = $w_Main->w_Tab->InsertItem(-text=> '    Expert');
#$f_Tab{interfaces} = $w_Main->w_Tab->InsertItem(-text=> '    Interfaces');
#$f_Tab{servo} = $w_Main->w_Tab->InsertItem(-text=> '    Servo');
#$f_Tab{gimbalmodel} = $w_Main->w_Tab->InsertItem(-text=> 'Gimbal Model');
#$f_Tab{filter} = $w_Main->w_Tab->InsertItem(-text=> '     Filter');
$f_Tab{expert} = Win32::GUI::DialogBox->new( -name=> 'm_ExpertWindow', -parent => $w_Main,
  -text=>'o323BGC Expert Tab',
  -size=> [10+4*$OPTIONSWIDTH_X,360-2], -pos=> [$DialogXPos+$xsize-380-180,$DialogYPos+50], -helpbox => 0,
);
$f_Tab{expert}->Hide();

sub t_ExpertTool_Click{
  my ($x,$y)=($w_Main->GetWindowRect())[0..1];
  $f_Tab{expert}->Move($x+$ColNumber*$OPTIONSWIDTH_X+40-15+20-385-180+1-180,$y+50-12);
  $f_Tab{expert}->Show(); 0;
}
sub m_ExpertWindow_Terminate{ $f_Tab{expert}->Hide(); 0; }

$f_Tab{interfaces} = Win32::GUI::DialogBox->new( -name=> 'm_InterfacesWindow', -parent => $w_Main,
  -text=>'o323BGC Interfaces Tab',
  -size=> [10+4*$OPTIONSWIDTH_X,360-2], -pos=> [$DialogXPos+$xsize-380-180,$DialogYPos+50], -helpbox => 0,
);
$f_Tab{interfaces}->Hide();

sub t_InterfacesTool_Click{
  my ($x,$y)=($w_Main->GetWindowRect())[0..1];
  $f_Tab{interfaces}->Move($x+$ColNumber*$OPTIONSWIDTH_X+40-15+20-385-180+1-180,$y+50-12);
  $f_Tab{interfaces}->Show(); 0;
}
sub m_InterfacesWindow_Terminate{ $f_Tab{interfaces}->Hide(); 0; }

$f_Tab{servo} = Win32::GUI::DialogBox->new( -name=> 'm_ServoWindow', -parent => $w_Main,
  -text=>'o323BGC Servo Tab',
  -size=> [10+4*$OPTIONSWIDTH_X,360-2], -pos=> [$DialogXPos+$xsize-380-180,$DialogYPos+50], -helpbox => 0,
);
$f_Tab{servo}->Hide();

sub t_ServoTool_Click{
  my ($x,$y)=($w_Main->GetWindowRect())[0..1];
  $f_Tab{servo}->Move($x+$ColNumber*$OPTIONSWIDTH_X+40-15+20-385-180+1-180,$y+50-12);
  $f_Tab{servo}->Show(); 0;
}
sub m_ServoWindow_Terminate{ $f_Tab{servo}->Hide(); 0; }

$f_Tab{gimbalmodel} = Win32::GUI::DialogBox->new( -name=> 'm_GimbalModelWindow', -parent => $w_Main,
  -text=>'o323BGC Gimbal Model Tab',
  -size=> [10+4*$OPTIONSWIDTH_X,360-2], -pos=> [$DialogXPos+$xsize-380-180,$DialogYPos+50], -helpbox => 0,
);
$f_Tab{gimbalmodel}->Hide();

sub t_GimbalModelTool_Click{
  my ($x,$y)=($w_Main->GetWindowRect())[0..1];
  $f_Tab{gimbalmodel}->Move($x+$ColNumber*$OPTIONSWIDTH_X+40-15+20-385-180+1-180,$y+50-12);
  $f_Tab{gimbalmodel}->Show(); 0;
}
sub m_GimbalModelWindow_Terminate{ $f_Tab{gimbalmodel}->Hide(); 0; }

$f_Tab{filter} = Win32::GUI::DialogBox->new( -name=> 'm_FilterWindow', -parent => $w_Main,
  -text=>'o323BGC Filter Tab',
  -size=> [10+4*$OPTIONSWIDTH_X,360-2], -pos=> [$DialogXPos+$xsize-380-180,$DialogYPos+50], -helpbox => 0,
);
$f_Tab{filter}->Hide();

sub t_FilterTool_Click{
  my ($x,$y)=($w_Main->GetWindowRect())[0..1];
  $f_Tab{filter}->Move($x+$ColNumber*$OPTIONSWIDTH_X+40-15+20-385-180+1-180,$y+50-12);
  $f_Tab{filter}->Show(); 0;
}
sub m_FilterWindow_Terminate{ $f_Tab{filter}->Hide(); 0; }

my @f_TabWindows = ();
push(@f_TabWindows, {'tab'=>$f_Tab{expert}, 'index'=>GetTabIndex('expert')} );
push(@f_TabWindows, {'tab'=>$f_Tab{interfaces}, 'index'=>GetTabIndex('interfaces')} );
push(@f_TabWindows, {'tab'=>$f_Tab{servo}, 'index'=>GetTabIndex('servo')} );
push(@f_TabWindows, {'tab'=>$f_Tab{gimbalmodel}, 'index'=>GetTabIndex('gimbalmodel')} );
push(@f_TabWindows, {'tab'=>$f_Tab{filter}, 'index'=>GetTabIndex('filter')} );

sub getWriteButtonText{
  my $writeandstore = shift;
  my $writecurtabonly = shift;
  if( $writecurtabonly ){
    if( $writeandstore ){ return 'Write Tab+Store'; }else{ return 'Write Tab'; }
  }
  if( $writeandstore ){ return 'Write+Store'; }
  return 'Write';
}

$ypos= $ysize-204 - $statussize;

$w_Main->AddLabel( -name=> 'm_Port_label', -font=> $StdWinFont,
  -text=> 'Port', -pos=> [$xpos,$ypos],
);
$w_Main->AddCombobox( -name=> 'm_Port', -font=> $StdWinFont,
  -pos=> [$xpos+$w_Main->m_Port_label->Width()+3,$ypos-3], -size=> [70,180],
  -dropdown=> 1, -vscroll=>1,
  -onDropDown=> sub{
    ($GetComPortOK,@PortList)= GetComPorts();
    if( $GetComPortOK > 0 ){
      my $s = $_[0]->Text();
      $_[0]->Clear(); $_[0]->Add(@PortList); $_[0]->SelectString($s); #$Port has COM + friendly name
      if( $_[0]->SelectedItem() < 0 ){ $_[0]->Select(0); }
    }
    1;
  },
  -onChange=> sub{
    my $res = 0;
    if( $GetComPortOK > 0 ){
      my $comportname = $PortList[$_[0]->SelectedItem()];
      for (@MavlinkComPorts){ if( index(uc($comportname),uc($_)) >= 0 ){ $res = 1; last; } }
    }
    $w_Main->m_Mavlink_check->Checked($res); #set/reset MAVLink
    MavlinkTunnelUpdate($res);
    1;
  }
);
$w_Main->m_Port->SetDroppedWidth(300); #was 160
$w_Main->m_Port->Add( @PortList );
if( scalar @PortList){ $w_Main->m_Port->SelectString( $Port ); } #$Port has COM + friendly name
$w_Main->AddCheckbox( -name => 'm_Mavlink_check', -font=> $StdWinFont,
#  -text=>'MAVLink',
  -pos=> [$xpos+100,$ypos+1], -size=> [12,12],
  -onClick=> sub{ if( $_[0]->GetCheck() ){ MavlinkTunnelUpdate(1); }else{ MavlinkTunnelUpdate(0); } },
);
$w_Main->AddLabel( -name=> 'm_Mavlink_label1', -font=> $StdWinFontSmall,
  -text=>'MAV', -pos=> [$xpos+118-1,$ypos-3], #-size=> [40,10],
);
$w_Main->AddLabel( -name=> 'm_Mavlink_label2', -font=> $StdWinFontSmall,
  -text=>'Link', -pos=> [$xpos+118-1,$ypos+6], #-size=> [40,10],
);
$w_Main->m_Mavlink_check->Checked(0);
$xpos += 25;
$w_Main->AddButton( -name=> 'm_Connect', -font=> $StdWinFont,
  -text=> 'Connect', -pos=> [$xpos+130,$ypos-3], -width=> 80,
);
$w_Main->AddButton( -name=> 'm_DataDisplay', -font=> $StdWinFont,
  -text=> 'Data Display', -pos=> [$xpos+130+80+15,$ypos-3], -width=> 80,
);
$w_Main->AddButton( -name=> 'm_Read', -font=> $StdWinFont,
  -text=> 'Read', -pos=> [$xpos+130+(80+15)+80+50,$ypos-3], -width=> 80,
#  -text=> 'Read', -pos=> [$xpos+130+(80+15)+80+50 -5,$ypos-3], -width=> 80,
);
$w_Main->AddButton( -name=> 'm_Write', -font=> $StdWinFont,
  -text=> 'Write', -pos=> [$xpos+130+(80+15)+(80+50)+80+40,$ypos-3], -width=> 80,
#  -text=> 'Write', -pos=> [$xpos+130+(80+15)+(80+50)+80+40 -5,$ypos-3], -width=> 80 +15,
);
$w_Main->m_Write->Disable();
$w_Main->AddCheckbox( -name  => 'm_WriteAndStore_check', -font=> $StdWinFont,
  -text => '(check for Write+Store)',
  -pos=> [$xpos+130+(80+15)+(80+50)+(80+40)+80+20,$ypos+1], -size=> [150,12],
#  -text => 'check for Write+Store',
#  -pos=> [$xpos+130+(80+15)+(80+50)+(80+40)+80+20 +10,$ypos+1 -9], -size=> [150,12],
  -onClick=> sub{
      $w_Main->m_Write->Text(getWriteButtonText( $_[0]->GetCheck(), 0));
#      $w_Main->m_Write->Text(getWriteButtonText( $_[0]->GetCheck(), $w_Main->m_WriteCurrentTabOnly_check->GetCheck() ));
    },
);
#$w_Main->AddCheckbox( -name  => 'm_WriteCurrentTabOnly_check', -font=> $StdWinFont,
#  -text => 'current Tab only',
#  -pos=> [$xpos+130+(80+15)+(80+50)+(80+40)+80+20 +10,$ypos+1 +8], -size=> [150,12],
#  -onClick=> sub{
#      $w_Main->m_Write->Text(getWriteButtonText( $w_Main->m_WriteAndStore_check->GetCheck(), $_[0]->GetCheck() ));
#    },
#);
#$w_Main->m_WriteCurrentTabOnly_check->Checked(0);
$w_Main->m_WriteAndStore_check->Checked(0);

$ypos= $ysize-150-40+13 - $statussize -1;
$w_Main->AddTextfield( -name=> 'm_RecieveText', -font=> $StdTextFont,
  -pos=> [5,$ypos], -size=> [$xsize-16,93+40-5],
  -vscroll=> 1, -multiline=> 1, -readonly => 1,
  -foreground =>[ 0, 0, 0],
  -background=> [192,192,192],#[96,96,96],
);
$w_Main->m_RecieveText->SetLimitText( 60000 );

$ypos= $ysize-60+1 -2   -1;
$w_Main->AddTextfield( -name=> 'm_StatusBlinker', -font=> $MicroFont,
  -pos=> [4,$ypos+2], -size=> [11,11], -readonly => 1,
  -background=> [255,0,0],#[96,96,96],
);
$w_Main->AddLabel( -name=> 'm_StatusField', -font=> $StatusFont,
  -text=>'not connected',
  -pos=> [5 +12,$ypos], -size=> [$xsize-16 -12,13],
);

sub MavlinkTunnelUpdate{
  my $flag = shift;
  if( $flag ){
    MavlinkStatusShow();
    $f_Tab{flash}->flash_Flash->Disable();
  }else{
    MavlinkStatusHide();
    $f_Tab{flash}->flash_Flash->Enable();
  }
}




#-----------------------------------------------------------------------------#
###############################################################################
### do DASHBOARD tab ###
###############################################################################
#-----------------------------------------------------------------------------#

my $DashboardStatusBackgroundColor = [224,224,224]; #[96,96,96];

$xpos= 20 + 1*$OPTIONSWIDTH_X;
$ypos= 10 + 0*$OPTIONSWIDTH_Y -1;
$f_Tab{dashboard}->AddLabel( -name=> 'dashboard_Status_frame', -font=> $StdWinFont,
  -pos=> [$xpos -5,$ypos -5],
  -size=>[505+10,127+45+10 +27 +25 +23],
  -background => $DashboardStatusBackgroundColor,
);
$f_Tab{dashboard}->AddLabel( -name=> 'dashboard_Status_label', -font=> $StdWinFont,
  -text=> 'Info Center:', -pos=> [$xpos,$ypos], -background => $DashboardStatusBackgroundColor,
);
$f_Tab{dashboard}->AddLabel( -name=> 'dashboard_Status_a', -font=> $StdWinFont,
  -text=> '', -pos=> [$xpos+10,$ypos+26], -size=>[250,202],#-pos=> [$xpos,$ypos],
  -background => $DashboardStatusBackgroundColor,
);
$f_Tab{dashboard}->AddLabel( -name=> 'dashboard_Status_b', -font=> $StdWinFont,
  -text=> '', -pos=> [$xpos+10+260,$ypos+26], -size=>[175,202+23],#-pos=> [$xpos,$ypos],
  -background => $DashboardStatusBackgroundColor,
);

$ypos= 10 + 5.5*$OPTIONSWIDTH_Y + 10;
$f_Tab{dashboard}->AddLabel( -name=> 'dashboard_MavlinkStatus_label', -font=> $StdWinFont,
  -text=> 'Mavlink Info Center:', -pos=> [$xpos,$ypos], #-background => $DashboardStatusBackgroundColor,
);
$f_Tab{dashboard}->AddLabel( -name=> 'dashboard_MavlinkStatus_n', -font=> $StdWinFont,
  -text=> "", #"GUI\r\nautopilot\r\ngimbal",
  -pos=> [$xpos+10,$ypos + 13 ], -size=>[250,50],#-pos=> [$xpos,$ypos],
  #-background => $DashboardStatusBackgroundColor,
);
$f_Tab{dashboard}->AddLabel( -name=> 'dashboard_MavlinkStatus_s', -font=> $StdWinFont,
  -text=> "", #system ID: -\r\nsystem ID: -\r\nsystem ID: -",
  -pos=> [$xpos+10 + 60,$ypos + 13], -size=>[250,50],#-pos=> [$xpos,$ypos],
  #-background => $DashboardStatusBackgroundColor,
);
$f_Tab{dashboard}->AddLabel( -name=> 'dashboard_MavlinkStatus_c', -font=> $StdWinFont,
  -text=> "", #component ID: -\r\ncomponent ID: -\r\ncomponent ID: -",
  -pos=> [$xpos+10 + 150,$ypos + 13], -size=>[250,50],#-pos=> [$xpos,$ypos],
  #-background => $DashboardStatusBackgroundColor,
);
sub MavlinkStatusShow{
  $f_Tab{dashboard}->dashboard_MavlinkStatus_label->Show();
  $f_Tab{dashboard}->dashboard_MavlinkStatus_n->Show();
  $f_Tab{dashboard}->dashboard_MavlinkStatus_s->Show();
  $f_Tab{dashboard}->dashboard_MavlinkStatus_c->Show();
}
sub MavlinkStatusHide{
  $f_Tab{dashboard}->dashboard_MavlinkStatus_label->Hide();
  $f_Tab{dashboard}->dashboard_MavlinkStatus_n->Hide();
  $f_Tab{dashboard}->dashboard_MavlinkStatus_s->Hide();
  $f_Tab{dashboard}->dashboard_MavlinkStatus_c->Hide();
}
sub MavlinkStatusDefault{
  $f_Tab{dashboard}->dashboard_MavlinkStatus_n->Text("GUI\r\nautopilot\r\ngimbal");
  $f_Tab{dashboard}->dashboard_MavlinkStatus_s->Text("system ID: -\r\nsystem ID: -\r\nsystem ID: -");
  $f_Tab{dashboard}->dashboard_MavlinkStatus_c->Text("component ID: -\r\ncomponent ID: -\r\ncomponent ID: -");
};
MavlinkStatusHide();
MavlinkStatusDefault();

$xpos= 20 +0*$OPTIONSWIDTH_X;
$ypos= 10 +3*$OPTIONSWIDTH_Y;
$f_Tab{dashboard}->AddButton( -name=> 'dashboard_ChangeBoardName', -font=> $StdWinFont,
  -text=> 'Change Name', -pos=> [$xpos,$ypos+4], -width=> 120,
  -onClick=> sub{ DoChangeBoardName(); 1; },
);

$ypos= 10 +5*$OPTIONSWIDTH_Y;
$f_Tab{dashboard}->AddButton( -name=> 'dashboard_ShareSettings', -font=> $StdWinFont,
  -text=> 'Share Settings', -pos=> [$xpos,$ypos+4], -width=> 120,
  -onClick=> sub{ m_ShareSettings_Click(); 1; },
);
$ypos= 10 +5.75*$OPTIONSWIDTH_Y;
$f_Tab{dashboard}->AddButton( -name=> 'dashboard_CheckForUpdates', -font=> $StdWinFont,
  -text=> 'Check for Updates', -pos=> [$xpos,$ypos+4], -width=> 120,
  -onClick=> sub{ m_Update_Click(); 1; },
);


sub DoChangeBoardName{
  if( $OptionsLoaded<1 ){
#    TextOut("\r\nCalibrate rc trims... ABORTED!");
  TextOut( "\r\nEdit Board Name Tool... ABORTED!" );
    TextOut("\r\nPlease do first a read to get controller settings!\r\n");
    return 0;
  }
  t_EditBoardName_Click();
  return 1;
}




#-----------------------------------------------------------------------------#
###############################################################################
### do PID tab ###
###############################################################################
#-----------------------------------------------------------------------------#

my $IMCCalculatorBackgroundColor = [224,224,224]; #[96,96,96];

$xpos= 20+(0)*$OPTIONSWIDTH_X; #3
$ypos= 10 + (6)*$OPTIONSWIDTH_Y; # + 18 -10; #4

$xpos= 20+(0)*$OPTIONSWIDTH_X;
$ypos += 25;
$f_Tab{pid}->AddLabel( -name=> 'AutoWritePIDChanges_label', -font=> $StdWinFont,
  -text=> 'Auto write PID changes', -pos=> [$xpos+15,$ypos], #-pos=> [$xpos,$ypos],
);
$f_Tab{pid}->AddCheckbox( -name  => 'AutoWritePIDChanges', -font=> $StdWinFont,
  -pos=> [$xpos,$ypos+1], #-pos=> [$xpos+130-10,$ypos+1],
  -size=> [12,12],
);
$f_Tab{pid}->AutoWritePIDChanges->Checked($UseAutoWritePIDChanges);

$xpos= 20 +2*$OPTIONSWIDTH_X;
$ypos= 10 +5*$OPTIONSWIDTH_Y;
$f_Tab{pid}->AddButton( -name=> 'pid_ShowGimbalModelTool', -font=> $StdWinFont,
  -text=> 'Gimbal Model', -pos=> [$xpos,$ypos+4], -width=> 120,
  -onClick=> sub{ t_GimbalModelTool_Click(); 1; },
);
$f_Tab{pid}->pid_ShowGimbalModelTool->Hide();


my $AutoWritePID_ChangesOccured = 0;
my $AutoWritePID_TimeoutCounter = 0;
my %AutoWritePID_HashOptions = ();
my %AutoWritePID_HashChanged = ();
my $AutoWritePID_HashIsInitialized = 0;

sub AutoWritePID_Clear{
  $AutoWritePID_ChangesOccured = 0;
  if( not $AutoWritePID_HashIsInitialized ){ AutoWritePID_InitHash(); }
  foreach my $optionname (keys %AutoWritePID_HashChanged){
    $AutoWritePID_HashChanged{$optionname} = 0;
  }
}

sub AutoWritePID_InitHash{
  my $Option;
  $Option = $NameToOptionHash{'Pitch P'}; $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Pitch I'}; $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Pitch D'}; $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Roll P'};  $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Roll I'};  $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Roll D'};  $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Yaw P'};   $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Yaw I'};   $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Yaw D'};   $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Pitch Motor Vmax'};      $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Roll Motor Vmax'};       $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Yaw Motor Vmax'};        $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Gyro LPF'};              $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Imu2 FeedForward LPF'};  $AutoWritePID_HashOptions{ $Option->{name} } = $Option;

  $Option = $NameToOptionHash{'Foc Pitch P'}; $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Foc Pitch I'}; $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Foc Pitch D'}; $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Foc Roll P'};  $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Foc Roll I'};  $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Foc Roll D'};  $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Foc Yaw P'};   $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Foc Yaw I'};   $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Foc Yaw D'};   $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Foc Pitch K'}; $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Foc Roll K'};  $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Foc Yaw K'};   $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Foc Gyro LPF'};$AutoWritePID_HashOptions{ $Option->{name} } = $Option;

  $Option = $NameToOptionHash{'Servo Pitch P'}; $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Servo Pitch I'}; $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Servo Pitch D'}; $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Servo Roll P'};  $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Servo Roll I'};  $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Servo Roll D'};  $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Servo Yaw P'};   $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Servo Yaw I'};   $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Servo Yaw D'};   $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Servo Pitch DLPF'}; $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Servo Roll DLPF'};  $AutoWritePID_HashOptions{ $Option->{name} } = $Option;
  $Option = $NameToOptionHash{'Servo Yaw DLPF'};   $AutoWritePID_HashOptions{ $Option->{name} } = $Option;

  foreach my $optionname (keys %AutoWritePID_HashChanged){
    $AutoWritePID_HashChanged{$optionname} = 0;
  }
  $AutoWritePID_HashIsInitialized = 1;
}

#is called in timer routine a regular time intervals
# isn't called when not connected, that's ensured by the timer routine
sub AutoWritePID_CheckIfItShouldBeDone{
  if( not $AutoWritePID_ChangesOccured ){ return 0; } #get out fast
  if( $AutoWritePID_TimeoutCounter ){ $AutoWritePID_TimeoutCounter--; return 0; } #get out if time is not yet ripe
  if( ($w_Main->w_Tab->SelectedItem() != 1) and (not $f_Tab{servo}->IsVisible()) ){ goto EXIT; }
  if( not $f_Tab{pid}->AutoWritePIDChanges->Checked() ){ goto EXIT; }
  foreach my $optionname (keys %AutoWritePID_HashOptions){
    if( $AutoWritePID_HashChanged{$optionname} ){
#TextOut("c".$optionname);
      my $Option= $AutoWritePID_HashOptions{$optionname};
      my $v = GetOptionField( $Option );
      #TextOut( $v );
      #if( $v<0 ){ $v = $v+65536; }
      $v = UIntToHexstrSwapped($v);
      my $res1= SendRcCmdwoOut( '04'. UCharToHexstr($Option->{adr}).'00'. $v );
      #if( $res1 =~ /[tc]/ ){ goto WERROR; }
    }
  }
#TextOut("X");
  $AutoWritePID_ChangesOccured = 0;
  foreach my $optionname (keys %AutoWritePID_HashOptions){
    if( $AutoWritePID_HashChanged{$optionname} ){
      $AutoWritePID_HashChanged{$optionname} = 0;
      Option_SetBackground( $AutoWritePID_HashOptions{$optionname}, $OptionValidColor );
    }
  }
  #foreach my $Option (@OptionList){ Option_SetBackground($Option,$OptionValidColor); }
  return 1;
EXIT:
  #$AutoWritePID_ChangesOccured = 0; #no, don't do that
  return 0;
}

sub SetAutoWritePID{
  my $optionname = shift; #= $Option->{name};
  $AutoWritePID_ChangesOccured = 1;
  $AutoWritePID_TimeoutCounter = 5;
  if( not $AutoWritePID_HashIsInitialized ){ return; }
  $AutoWritePID_HashChanged{$optionname} = 1;
}


##IMC calculator
my $IMCCalculatorIsDisplayed= 1;

sub AddIMCCalculatorToPIDTab{
  my $xpos= 30+(1)*$OPTIONSWIDTH_X - 5;
  my $ypos= 10 + (6)*$OPTIONSWIDTH_Y;

  $f_Tab{pid}->AddLabel( -name=> 'IMCCalculator_frame', -font=> $StdWinFont,
    -pos=> [$xpos-5,$ypos-5], -size=> [505+10+5,127+10], -background => $IMCCalculatorBackgroundColor,
  );

  $f_Tab{pid}->AddLabel( -name=> 'PitchIMCf0_label', -font=> $StdWinFont,
    -text=> '  f0 =', -pos=> [$xpos,$ypos], -size=> [140,13+2],
  );
  $f_Tab{pid}->AddLabel( -name=> 'PitchIMCd_label', -font=> $StdWinFont,
    -text=> '   d =', -pos=> [$xpos,$ypos+16], -size=> [140,13+2],
  );
  $f_Tab{pid}->AddLabel( -name=> 'PitchIMCtau_label', -font=> $StdWinFont,
    -text=> 'tau =', -pos=> [$xpos,$ypos+32], -size=> [140,13+2],
  );

  $xpos= 30+(2)*$OPTIONSWIDTH_X;
  $ypos= 10 + (6)*$OPTIONSWIDTH_Y;
  $f_Tab{pid}->AddLabel( -name=> 'RollIMCf0_label', -font=> $StdWinFont,
    -text=> '  f0 =', -pos=> [$xpos,$ypos], -size=> [140,13+2],
  );
  $f_Tab{pid}->AddLabel( -name=> 'RollIMCd_label', -font=> $StdWinFont,
    -text=> '   d =', -pos=> [$xpos,$ypos+16], -size=> [140,13+2],
  );
  $f_Tab{pid}->AddLabel( -name=> 'RollIMCtau_label', -font=> $StdWinFont,
    -text=> 'tau =', -pos=> [$xpos,$ypos+32], -size=> [140,13+2],
  );

  $xpos= 30+(3)*$OPTIONSWIDTH_X;
  $ypos= 10 + (6)*$OPTIONSWIDTH_Y;
  $f_Tab{pid}->AddLabel( -name=> 'YawIMCf0_label', -font=> $StdWinFont,
    -text=> '  f0 =', -pos=> [$xpos,$ypos], -size=> [140,13+2],
  );
  $f_Tab{pid}->AddLabel( -name=> 'YawIMCd_label', -font=> $StdWinFont,
    -text=> '   d =', -pos=> [$xpos,$ypos+16], -size=> [140,13+2],
  );
  $f_Tab{pid}->AddLabel( -name=> 'YawIMCtau_label', -font=> $StdWinFont,
    -text=> 'tau =', -pos=> [$xpos,$ypos+32], -size=> [140,13+2],
  );

  $IMCCalculatorIsDisplayed= 1;
  $f_Tab{pid}->AddButton( -name=> 'ShowIMCCalculator',
  -text=> '-', -pos=> [$xsize-41, $tabsize-35], -width=> 12, -height=> 12,
  -flat  => 1,
  );
}
#AddIMCCalculatorToPIDTab();


sub ShowIMCCalculator_Click{
  if( $AllFieldsAreReadyToUse!=1 ){ return; }
  if( $IMCCalculatorIsDisplayed==0 ){ #unfold
    $IMCCalculatorIsDisplayed= 1;
    $f_Tab{pid}->ShowIMCCalculator->Text( "-");
    $f_Tab{pid}->IMCCalculator_frame->Show();
    $f_Tab{pid}->PitchIMCf0_label->Show();
    $f_Tab{pid}->PitchIMCd_label->Show();
    $f_Tab{pid}->PitchIMCtau_label->Show();
    $f_Tab{pid}->RollIMCf0_label->Show();
    $f_Tab{pid}->RollIMCd_label->Show();
    $f_Tab{pid}->RollIMCtau_label->Show();
    $f_Tab{pid}->YawIMCf0_label->Show();
    $f_Tab{pid}->YawIMCd_label->Show();
    $f_Tab{pid}->YawIMCtau_label->Show();
  }else{ #fold
    $IMCCalculatorIsDisplayed= 0;
    $f_Tab{pid}->ShowIMCCalculator->Text( "+");
    $f_Tab{pid}->IMCCalculator_frame->Hide();
    $f_Tab{pid}->PitchIMCf0_label->Hide();
    $f_Tab{pid}->PitchIMCd_label->Hide();
    $f_Tab{pid}->PitchIMCtau_label->Hide();
    $f_Tab{pid}->RollIMCf0_label->Hide();
    $f_Tab{pid}->RollIMCd_label->Hide();
    $f_Tab{pid}->RollIMCtau_label->Hide();
    $f_Tab{pid}->YawIMCf0_label->Hide();
    $f_Tab{pid}->YawIMCd_label->Hide();
    $f_Tab{pid}->YawIMCtau_label->Hide();
  }
}

sub SetIMCCalculator{
  my $s= shift;
  if( $AllFieldsAreReadyToUse!=1 ){ return; }
  my $Kp = $NameToOptionHash{$s.' P'}->{textfield}->Text();
  my $Ki = $NameToOptionHash{$s.' I'}->{textfield}->Text();
  my $Kd = $NameToOptionHash{$s.' D'}->{textfield}->Text();
  #my $invKi = divide( 1.0, $Ki );
  my $f0 = sqrt( divide( $Ki, 39.4784176*$Kd ) );
  my $d = $Kp * sqrt( divide( 1.0, 4.0*$Kd*$Ki ) );
  if( $s eq 'Pitch' ){
    $f_Tab{pid}->PitchIMCf0_label->Text( '  f0 = '. sprintf("%.4g",$f0).' Hz' );
    $f_Tab{pid}->PitchIMCd_label->Text( '   d = '.sprintf("%.4f",$d) );
    $f_Tab{pid}->PitchIMCtau_label->Text( 'tau = '.sprintf("%.2f",1570.80/(1.0+$Ki)).' ms' );
  }
  if( $s eq 'Roll' ){
    $f_Tab{pid}->RollIMCf0_label->Text( '  f0 = '. sprintf("%.4g",$f0).' Hz' );
    $f_Tab{pid}->RollIMCd_label->Text( '   d = '.sprintf("%.4f",$d) );
    $f_Tab{pid}->RollIMCtau_label->Text( 'tau = '.sprintf("%.2f",1570.80/(1.0+$Ki)).' ms' );
  }
  if( $s eq 'Yaw' ){
    $f_Tab{pid}->YawIMCf0_label->Text( '  f0 = '. sprintf("%.4g",$f0).' Hz' );
    $f_Tab{pid}->YawIMCd_label->Text( '   d = '.sprintf("%.4f",$d) );
    $f_Tab{pid}->YawIMCtau_label->Text( 'tau = '.sprintf("%.2f",1570.80/(1.0+$Ki)).' ms' );
  }
}


#-----------------------------------------------------------------------------#
###############################################################################
### do Pan tab ###
###############################################################################
#-----------------------------------------------------------------------------#

# nothing to do


#-----------------------------------------------------------------------------#
###############################################################################
### do RC Inputs tab ###
###############################################################################
#-----------------------------------------------------------------------------#
$xpos= 20;
$ypos= 20;

$f_Tab{rcinputs}->AddButton( -name=> 'rcinputs_AutoTrim', -font=> $StdWinFont,
  -text=> 'Auto Trim', -pos=> [$xpos+0*$OPTIONSWIDTH_X,$ypos+4+6*$OPTIONSWIDTH_Y], -width=> 120,
  -onClick=> sub{ DoAutoTrim(); 1; },
);

sub DoAutoTrim{
  if( $OptionsLoaded<1 ){
    TextOut("\r\nCalibrate rc trims... ABORTED!");
    TextOut("\r\nPlease do first a read to get controller settings!\r\n");
    return 0;
  }
  ExecuteCalibrateRcTrim();
  return 1;
}


#-----------------------------------------------------------------------------#
###############################################################################
### do Functions tab ###
###############################################################################
#-----------------------------------------------------------------------------#

# nothing to do


#-----------------------------------------------------------------------------#
###############################################################################
### do Scripts tab ###
###############################################################################
#-----------------------------------------------------------------------------#

# nothing to do here


#-----------------------------------------------------------------------------#
###############################################################################
### do Setup tab ###
###############################################################################
#-----------------------------------------------------------------------------#
$xpos= 20;
$ypos= 20;

$f_Tab{setup}->AddButton( -name=> 'gimbalconfig_EnableAllMotors', -font=> $StdWinFont,
  -text=> 'Enable all Motors', -pos=> [$xpos+3*$OPTIONSWIDTH_X,$ypos+4+4*$OPTIONSWIDTH_Y], -width=> 120,
  -onClick=> sub{
    if( $Execute_IsRunning ){ return 1; }
    $Execute_IsRunning = 1;
    SetUsageOfAllMotors(0);
    $Execute_IsRunning = 0;
    1; },
);

$f_Tab{setup}->AddButton( -name=> 'gimbalconfig_DisableAllMotors', -font=> $StdWinFont,
  -text=> 'Disable all Motors', -pos=> [$xpos+3*$OPTIONSWIDTH_X,$ypos+4+5*$OPTIONSWIDTH_Y], -width=> 120,
  -onClick=> sub{
    if( $Execute_IsRunning ){ return 1; }
    $Execute_IsRunning = 1;
    SetUsageOfAllMotors(3);
    $Execute_IsRunning = 0;
    1; },
);

sub SetUsageOfAllMotors{
  my $usage= shift;
  if( $OptionsLoaded<1 ){
    if( $usage==3 ){ TextOut("\r\nDisable all motors... ABORTED!"); }
    elsif( $usage==2 ){ TextOut("\r\nSet all motors to startup pos... ABORTED!"); }
    elsif( $usage==1 ){ TextOut("\r\nSet all motors to level.. ABORTED!"); }
    else{ TextOut("\r\nEnable all motors... ABORTED"); }
    TextOut("\r\nPlease do first a read to get controller settings!\r\n");
    return 1;
  }
  my $Option= $NameToOptionHash{'Pitch Motor Usage'};
  if( defined $Option ){
    SetOptionField( $Option, $usage );
    $Option->{textfield}->Change( -background => $OptionInvalidColor );
  }
  $Option= $NameToOptionHash{'Roll Motor Usage'};
  if( defined $Option ){
    SetOptionField( $Option, $usage );
    $Option->{textfield}->Change( -background => $OptionInvalidColor );
  }
  $Option= $NameToOptionHash{'Yaw Motor Usage'};
  if( defined $Option ){
    SetOptionField( $Option, $usage );
    $Option->{textfield}->Change( -background => $OptionInvalidColor );
  }
  if( $usage==3 ){ TextOut("\r\nDisable all motors... OK"); }
  elsif( $usage==2 ){ TextOut("\r\nSet all motors to startup pos... OK"); }
  elsif( $usage==1 ){ TextOut("\r\nSet all motors to level.. OK"); }
  else{ TextOut("\r\nEnable all motors... OK"); }
  ExecuteWrite(0);
  1;
}


#-----------------------------------------------------------------------------#
###############################################################################
### do Configure Gimbal tab ###
###############################################################################
#-----------------------------------------------------------------------------#

my @ImuZList=( 'up', 'down', 'forward', 'backward', 'right', 'left' );
my @ImuXList=( 'forward', 'backward', 'right', 'left'  );

$xpos= 20;
$ypos= 20;

$f_Tab{gimbalconfig}->AddButton( -name=> 'gimbalconfig_ConfigureGimbal', -font=> $StdWinFont,
  -text=> 'Configure Gimbal Tool', -pos=> [$xpos+0*$OPTIONSWIDTH_X,$ypos+4+3*$OPTIONSWIDTH_Y-8], -width=> 120, -height=> 30,
);

$ypos= 200;

$ypos+= 30 + 1*13;
$xpos= 50 +30;
$f_Tab{gimbalconfig}->AddLabel( -name=> 'gimbalconfig_ImuNummer_label', -font=> $StdWinFont,
  -text=> ' Imu', -pos=> [$xpos-1,$ypos],
);
$f_Tab{gimbalconfig}->AddCombobox( -name=> 'gimbalconfig_ImuNumber', -font=> $StdWinFont,
  -pos=> [$xpos,$ypos+20-3], -size=> [120,160],
  -dropdown=> 1, -vscroll=>1,
  -onChange=> sub{
    my $Option; my $imu;
    if( $f_Tab{gimbalconfig}->gimbalconfig_ImuNumber->GetCurSel() == 1 ){
      $Option= $NameToOptionHash{'Imu2 Orientation'}; $imu= '2';
      $f_Tab{gimbalconfig}->gimbalconfig_ImuOrientationText2_label_IMU1->Hide();
      $f_Tab{gimbalconfig}->gimbalconfig_ImuOrientationText2_label_IMU2->Show();
##    }elsif( $f_Tab{gimbalconfig}->gimbalconfig_ImuNumber->GetCurSel() == 2 ){
##      $Option= $NameToOptionHash{'Imu3 Orientation'}; $imu= '3';
##      $f_Tab{gimbalconfig}->gimbalconfig_ImuOrientationText2_label_IMU1->Hide();
##      $f_Tab{gimbalconfig}->gimbalconfig_ImuOrientationText2_label_IMU2->Hide();
    }else{
      $Option= $NameToOptionHash{'Imu Orientation'}; $imu= '';
      $f_Tab{gimbalconfig}->gimbalconfig_ImuOrientationText2_label_IMU2->Hide();
      $f_Tab{gimbalconfig}->gimbalconfig_ImuOrientationText2_label_IMU1->Show();
    }
    if( defined $Option ){
      my $no= GetOptionField( $Option );
      UpdateZXAxisFields( $no, $imu );
    }
    1;
  },
);
$f_Tab{gimbalconfig}->gimbalconfig_ImuNumber->SetDroppedWidth(100);
$f_Tab{gimbalconfig}->gimbalconfig_ImuNumber->Add( 'Imu  (camera IMU)' );
$f_Tab{gimbalconfig}->gimbalconfig_ImuNumber->Add( 'Imu2 (2nd IMU)' );
##$f_Tab{gimbalconfig}->gimbalconfig_ImuNumber->Add( 'Imu3 (vibrations)' );
$f_Tab{gimbalconfig}->gimbalconfig_ImuNumber->Select( 0 );

$xpos= 120 + 50 + 50 +20;
$f_Tab{gimbalconfig}->AddLabel( -name=> 'gimbalconfig_AxisZ_label', -font=> $StdWinFont,
  -text=> ' z axis points', -pos=> [$xpos-1,$ypos],
);
$f_Tab{gimbalconfig}->AddCombobox( -name=> 'gimbalconfig_AxisZ', -font=> $StdWinFont,
  -pos=> [$xpos,$ypos+20-3], -size=> [80,160],
  -dropdown=> 1, -vscroll=>1,
  -onChange=> sub{
    my $Option; my $imu= '';
    if( $f_Tab{gimbalconfig}->gimbalconfig_ImuNumber->GetCurSel() == 1 ){
      $Option= $NameToOptionHash{'Imu2 Orientation'}; $imu= '2';
##    }elsif( $f_Tab{gimbalconfig}->gimbalconfig_ImuNumber->GetCurSel() == 2 ){
##      $Option= $NameToOptionHash{'Imu3 Orientation'}; $imu= '3';
    }else{
      $Option= $NameToOptionHash{'Imu Orientation'}; $imu= '';
    }
    my $z= $_[0]->GetString($_[0]->GetCurSel());
    my $x= $f_Tab{gimbalconfig}->gimbalconfig_AxisX->Text();
    UpdateXAxisField( $z, $x );
    $x= $f_Tab{gimbalconfig}->gimbalconfig_AxisX->GetString( $f_Tab{gimbalconfig}->gimbalconfig_AxisX->GetCurSel() );
    my ($no)= PaintImuOrientation( $imu, $z, $x );
    if( defined $Option ){
      SetOptionField( $Option, $no );
      $Option->{textfield}->Change( -background => $OptionInvalidColor );
    }
    1;
  }
);
$f_Tab{gimbalconfig}->gimbalconfig_AxisZ->SetDroppedWidth(60);
$f_Tab{gimbalconfig}->gimbalconfig_AxisZ->Add( @ImuZList );
$f_Tab{gimbalconfig}->gimbalconfig_AxisZ->Select( 0 );
#$ypos+= 50;
$xpos+=120;
$f_Tab{gimbalconfig}->AddLabel( -name=> 'gimbalconfig_AxisX_label', -font=> $StdWinFont,
  -text=> ' x axis points', -pos=> [$xpos-1,$ypos],
);
$f_Tab{gimbalconfig}->AddCombobox( -name=> 'gimbalconfig_AxisX', -font=> $StdWinFont,
  -pos=> [$xpos,$ypos+20-3], -size=> [80,160],
  -dropdown=> 1, -vscroll=>1,
  -onChange=> sub{
    my $Option; my $imu= '';
    if( $f_Tab{gimbalconfig}->gimbalconfig_ImuNumber->GetCurSel() == 1 ){
      $Option= $NameToOptionHash{'Imu2 Orientation'}; $imu= '2';
##    }elsif( $f_Tab{gimbalconfig}->gimbalconfig_ImuNumber->GetCurSel() == 2 ){
##      $Option= $NameToOptionHash{'Imu3 Orientation'}; $imu= '3';
    }else{
      $Option= $NameToOptionHash{'Imu Orientation'}; $imu= '';
    }
    my $z= $f_Tab{gimbalconfig}->gimbalconfig_AxisZ->Text();
    my $x= $_[0]->GetString( $_[0]->GetCurSel() );
    my ($no)= PaintImuOrientation( $imu, $z, $x );
    if( defined $Option ){
      SetOptionField( $Option, $no );
      $Option->{textfield}->Change( -background => $OptionInvalidColor ); #$OptionModifiedColor );
    }
    1;
  }
);
$f_Tab{gimbalconfig}->gimbalconfig_AxisX->SetDroppedWidth(60);
$f_Tab{gimbalconfig}->gimbalconfig_AxisX->Add( @ImuXList );
$f_Tab{gimbalconfig}->gimbalconfig_AxisX->Select( 0 );
$xpos= 80;
$ypos+= 55;
$f_Tab{gimbalconfig}->AddLabel( -name=> 'gimbalconfig_ImuOrientationText2_label_IMU1', -font=> $StdWinFont,
  -text=> 'Check in Data Display: Tilting CAMERA downwards must lead '.
'to positive Pitch angles, and rolling it like in a right turn to positive Roll angles.',
  -pos=> [$xpos,$ypos], -multiline => 1, -height=>26+13+10, -width=>420,
);
$f_Tab{gimbalconfig}->AddLabel( -name=> 'gimbalconfig_ImuOrientationText2_label_IMU2', -font=> $StdWinFont,
  -text=> 'Check in Data Display: Tilting GIMBAL downwards must lead '.
'to positive Pitch2 angles, and rolling it like in a right turn to positive Roll2 angles.',
  -pos=> [$xpos,$ypos], -multiline => 1, -height=>26+13, -width=>420,
);
$xpos= 480 - 8 +50 -10;
$ypos+= -30-3;
$f_Tab{gimbalconfig}->AddLabel( -name=> 'gimbalconfig_ImuX_label', -font=> $StdWinFont,
  -text=> ' ', -pos=> [$xpos+110,$ypos-40+10], -width=> 70,
);
$f_Tab{gimbalconfig}->AddLabel( -name=> 'gimbalconfig_No_label', -font=> $StdWinFont,
  -text=> ' ', -pos=> [$xpos+110,$ypos-40+25], -width=> 70,
);
$f_Tab{gimbalconfig}->AddLabel( -name=> 'gimbalconfig_Name_label', -font=> $StdWinFont,
  -text=> ' ', -pos=> [$xpos+110,$ypos-40+40], -width=> 70,
);
$f_Tab{gimbalconfig}->AddLabel( -name=> 'gimbalconfig_Axes_label', -font=> $StdWinFont,
  -text=> ' ', -pos=> [$xpos+110,$ypos-40+55], -width=> 70,
);
$f_Tab{gimbalconfig}->AddLabel( -name=> 'gimbalconfig_Value_label', -font=> $StdWinFont,
  -text=> ' ', -pos=> [$xpos+110,$ypos-40+70], -width=> 70,
);
$ypos+= -30;
#moved to here to handle overlap of plot with textfield
my $w_ImuPlot= $f_Tab{gimbalconfig}->AddGraphic( -parent=> $f_Tab{gimbalconfig}, -name=> 'gimbalconfig_Plot',
    -pos=> [$xpos,$ypos], -size=> [100,90], -interactive=> 1,
);

sub UpdateZXAxisFields{
  my $no = shift;
  my $imux = shift;
  my $s= $ImuOrientationList[$no]->{axes};
  my $z= ConvertImuOrientation( $s, 'z' );
  my $x= ConvertImuOrientation( $s, 'x' );
  $f_Tab{gimbalconfig}->gimbalconfig_AxisZ->SelectString( $z );
  UpdateXAxisField( $z, $x );
  $f_Tab{gimbalconfig}->gimbalconfig_AxisX->SelectString( $x );
  PaintImuOrientation( $imux, $z, $x );
}

sub UpdateXAxisField{
  my $z= shift;
  my $x= shift;
  if(( $z eq 'up' )or( $z eq 'down' )){ @ImuXList= ( 'forward', 'backward', 'right', 'left' ); }
  if(( $z eq 'forward' )or( $z eq 'backward' )){ @ImuXList= ( 'up', 'down', 'right', 'left' ); }
  if(( $z eq 'right' )or( $z eq 'left' )){ @ImuXList= ( 'up', 'down', 'forward', 'backward' ); }
  $f_Tab{gimbalconfig}->gimbalconfig_AxisX->Clear();
  $f_Tab{gimbalconfig}->gimbalconfig_AxisX->Add( @ImuXList );
  $f_Tab{gimbalconfig}->gimbalconfig_AxisX->SelectString( $x );
  if( $f_Tab{gimbalconfig}->gimbalconfig_AxisX->GetCurSel() < 0 ){ $f_Tab{gimbalconfig}->gimbalconfig_AxisX->SetCurSel(0); }
}

sub ConvertImuOrientation{
  my $s= shift; my $f= shift;
  my $i= index( $s, '+'.$f );
  if( $i==0 ){ return 'forward'; }elsif( $i==3 ){ return 'left'; }elsif( $i==6 ){ return 'up'; }
  $i= index( $s, '-'.$f );
  if( $i==0 ){ return 'backward'; }elsif( $i==3 ){ return 'right'; }elsif( $i==6 ){ return 'down'; }
}

sub FindImuOrientation{
  my $z= shift; my $x= shift;
  my $y= ''; my @s= ('??','??','??');  my $s1= ''; my $s2= '';
  #put z at right position
  if( $z eq 'forward' ){ $s[0]= '+z'; }
  elsif( $z eq 'backward' ) { $s[0]= '-z'; }
  elsif( $z eq 'left' ){ $s[1]= '+z'; }
  elsif( $z eq 'right' ) { $s[1]= '-z'; }
  elsif( $z eq 'up' )   { $s[2]= '+z'; }
  elsif( $z eq 'down' ) { $s[2]= '-z'; }
  #put x at right position
  if( $x eq 'forward' ){ $s[0]= '+x'; }
  elsif( $x eq 'backward' ) { $s[0]= '-x'; }
  elsif( $x eq 'left' ){ $s[1]= '+x'; }
  elsif( $x eq 'right' ) { $s[1]= '-x'; }
  elsif( $x eq 'up' )   { $s[2]= '+x'; }
  elsif( $x eq 'down' ) { $s[2]= '-x'; }
  # y is missing
  if( $s[0] eq '??' ){ $s1.= '+y'; $s2.= '-y'; }else{ $s1.= $s[0]; $s2.= $s[0]; }
  if( $s[1] eq '??' ){ $s1.= ' +y'; $s2.= ' -y'; }else{ $s1.= ' '.$s[1]; $s2.= ' '.$s[1]; }
  if( $s[2] eq '??' ){ $s1.= ' +y'; $s2.= ' -y'; }else{ $s1.= ' '.$s[2]; $s2.= ' '.$s[2]; }
  #find matching orientation
  my $no= 0; my $option;
  foreach my $o (@ImuOrientationList){
    if(( $o->{axes} eq $s1 )or( $o->{axes} eq $s2 )){ $y= $o->{axes}; $option= $o; last; }
    $no++;
  }
  $y= ConvertImuOrientation( $y, 'y' );
  return ($y,$no,$option->{value},$option->{name},$option->{axes});
}

my $penImu = new Win32::GUI::Pen( -color => [127,127,127], -width => 1); #black
my $brushImu = new Win32::GUI::Brush( [191,191,191] ); #lightgray
my $brushImuFrame = new Win32::GUI::Brush( [0,0,0] );  #white
my $penImuGrid= new Win32::GUI::Pen( -color=> [127,127,127], -width=> 1);
my $fontImu= Win32::GUI::Font->new(-name=>'Lucida Console',-size=>8);

my @ImuColors= ( [255,0,0], [0,255,0], [0,0,255], [128,128,128], [0,255,255], [255,0,255], [255,255,0], [0,0,0]);

my $AxisLen= 32;
my $AxisXLen= int( $AxisLen/1.41 );
my $ArrowGap= 6;
my $ArrowXGap= 5;
my $AxisXOffset= -8;
my $AxisYOffset= +4;

sub AxisCoordinate{
  my $a= shift;
  if( $a eq 'up' )       { return (0                      , $AxisLen-$ArrowGap     , 5,$AxisLen+2); }
  if( $a eq 'down' )     { return (0                      ,-($AxisLen-$ArrowGap)   , 5,-$AxisLen+7); }
  if( $a eq 'forward' )  { return ($AxisXLen-$ArrowXGap   ,$AxisXLen-$ArrowXGap    , $AxisXLen+2,$AxisXLen  ); }
  if( $a eq 'backward' ) { return (-($AxisXLen-$ArrowXGap),-($AxisXLen-$ArrowXGap) , -$AxisXLen-6,-$AxisXLen+12  ); }
  if( $a eq 'right' )    { return ($AxisLen-$ArrowGap     , 0                      , $AxisLen-4,+12); }
  if( $a eq 'left' )     { return (-($AxisLen-$ArrowGap)  , 0                      , -$AxisLen,+12); }
}

sub PaintImuOrientationFrame{
  my $Plot= shift;
  my $z= shift;
  my $x= shift;
  my $y= shift;
  # setting of Ranges and Regions
  my $DC= $Plot->GetDC();
  my ( $W, $H )= ($Plot->GetClientRect())[2..3];
  my $plot_region= CreateRectRgn Win32::GUI::Region(0,0,$W,$H);
  # get the DC's
  my $DC2= $DC->CreateCompatibleDC();
  my $bit= $DC->CreateCompatibleBitmap( $W, $H );
  $DC2->SelectObject( $bit );
  # draw the Plot region things: background, labels, xy, plotframe
  $DC2->SelectClipRgn( $plot_region );
  $DC2->SelectObject( $brushImu );
  $DC2->PaintRgn( $plot_region );
  $DC2->SelectObject( $fontImu );
  $DC2->TextColor( [127,127,127] );
  $DC2->BackColor( [191,191,191] );
  # draw the Imu things: grid, labels
  $DC2->SelectObject( $penImu );
  $DC2->Line( $W/2+$AxisXOffset, $H/2+$AxisYOffset-$AxisLen, $W/2+$AxisXOffset, $H/2+$AxisYOffset+$AxisLen ); #z
  $DC2->Line( $W/2+$AxisXOffset+$AxisXLen, $H/2+$AxisYOffset-$AxisXLen, $W/2+$AxisXOffset-$AxisXLen, $H/2+$AxisYOffset+$AxisXLen ); #x
  $DC2->Line( $W/2+$AxisXOffset-$AxisLen, $H/2+$AxisYOffset, $W/2+$AxisXOffset+$AxisLen, $H/2+$AxisYOffset ); #y
  $DC2->TextOut( $W/2-15, -1, 'up' );
  $DC2->TextOut( $W-36, $H/2+11, 'right' );
  $DC2->TextOut( $W-31, 6, 'for' );$DC2->TextOut( $W-31, 15, 'ward' );
  # draw seleced axes
  my $pen = new Win32::GUI::Pen( -color => $ImuColors[0], -width => 3 );
  $DC2->SelectObject( $pen );
  my @c= AxisCoordinate( $z );
  $DC2->Line( $W/2+$AxisXOffset, $H/2+$AxisYOffset, $W/2+$AxisXOffset+$c[0], $H/2+$AxisYOffset-$c[1] );
  $DC2->TextColor( $ImuColors[0] );
  $DC2->TextOut( $W/2+$AxisXOffset+$c[2], $H/2+$AxisYOffset-$c[3], 'z' );
  $pen = new Win32::GUI::Pen( -color => $ImuColors[1], -width => 3 );
  $DC2->SelectObject( $pen );
  @c= AxisCoordinate( $x );
  $DC2->Line( $W/2+$AxisXOffset, $H/2+$AxisYOffset, $W/2+$AxisXOffset+$c[0], $H/2+$AxisYOffset-$c[1] );
  $DC2->TextColor( $ImuColors[1] );
  $DC2->TextOut( $W/2+$AxisXOffset+$c[2], $H/2+$AxisYOffset-$c[3], 'x' );
  $pen = new Win32::GUI::Pen( -color => $ImuColors[2], -width => 3 );
  $DC2->SelectObject( $pen );
  @c= AxisCoordinate( $y );
  $DC2->Line( $W/2+$AxisXOffset, $H/2+$AxisYOffset, $W/2+$AxisXOffset+$c[0], $H/2+$AxisYOffset-$c[1] );
  $DC2->TextColor( $ImuColors[2] );
  $DC2->TextOut( $W/2+$AxisXOffset+$c[2], $H/2+$AxisYOffset-$c[3], 'y' );
  # update the screen in one action, and clean up
  $DC->BitBlt(0,0,$W,$H,$DC2,0,0);
  $DC2->DeleteDC();
  $DC->Validate();
}

sub PaintImuOrientation{
  my $imu= shift;
  my $z= shift;
  my $x= shift;
  my ($y,$no,$value,$name,$axes)= FindImuOrientation( $z, $x );
  # do first orientation info
  $f_Tab{gimbalconfig}->gimbalconfig_ImuX_label->Text( 'Imu'.$imu.'  ' );
  $f_Tab{gimbalconfig}->gimbalconfig_No_label->Text( 'no. '.$no );
  $f_Tab{gimbalconfig}->gimbalconfig_Name_label->Text( $name );
  $f_Tab{gimbalconfig}->gimbalconfig_Axes_label->Text( AxesRemovePlus($axes) );
  $f_Tab{gimbalconfig}->gimbalconfig_Value_label->Text( '('.$value.')' );
  # setting of Ranges and Regions
  PaintImuOrientationFrame( $w_ImuPlot, $z, $x, $y );
  return ($no,$value,$name,$axes);
}

sub gimbalconfig_Plot_Paint{
  my $imux= '';
  if( $f_Tab{gimbalconfig}->gimbalconfig_ImuNumber->GetCurSel() == 1 ){ $imux= '2'; }else{ $imux= ''; }
  PaintImuOrientation(
      $imux,
      $f_Tab{gimbalconfig}->gimbalconfig_AxisZ->Text(),
      $f_Tab{gimbalconfig}->gimbalconfig_AxisX->Text()
    );
  1;
}


#-----------------------------------------------------------------------------#
###############################################################################
### do Calibrate Acc tab ###
###############################################################################
#-----------------------------------------------------------------------------#

# this hash stores the actually worked on calibration data record
my %CalibrationDataRecord= (
  axzero=> '',
  ayzero=> '',
  azzero=> '',
  axscale=> '',
  ayscale=> '',
  azscale=> '',
  calibrationmethod=> '',
  raw=> '',
  gxzero=> '',
  gyzero=> '',
  gzzero=> '',
);

sub ClearCalibrationDataRecord{
  $CalibrationDataRecord{axzero}= '';
  $CalibrationDataRecord{ayzero}= '';
  $CalibrationDataRecord{azzero}= '';
  $CalibrationDataRecord{axscale}= '';
  $CalibrationDataRecord{ayscale}= '';
  $CalibrationDataRecord{azscale}= '';
  $CalibrationDataRecord{calibrationtype}= '';
  $CalibrationDataRecord{raw}= '';
  $CalibrationDataRecord{gxzero}= '';
  $CalibrationDataRecord{gyzero}= '';
  $CalibrationDataRecord{gzzero}= '';
}

$xpos= 30;
$ypos= 20;

$f_Tab{calibrateacc}->AddLabel( -name=> 'cacc_IntroText_label', -font=> $StdWinFont,
  -text=> "1. Deactivate Motors
For saftey, power up board with USB only (no battery connected). Motors are then deactivated.",
  -pos=> [$xpos,$ypos], -multiline=>1, -height=>3*13+20,
);

$ypos+= 35 + 1*13;
$f_Tab{calibrateacc}->AddLabel( -name=> 'cacc_IntroTextdrgdg_label', -font=> $StdWinFont,
  -text=> "2. Accelerometer and Gyro Calibration Data
Chose imu. Choose sensors. Then run calibration, or load calibration data from file.",
  -pos=> [$xpos,$ypos], -multiline=>1, -height=>2*13+10,
);

$ypos+= 3*13;
$f_Tab{calibrateacc}->AddButton( -name=> 'caac_Run1PointCalibration', -font=> $StdWinFont,
  -text=> 'Run 1-Point Acc Calibration', -pos=> [$xpos+20,$ypos-3+2*13], -width=> 120+20,
);
$f_Tab{calibrateacc}->AddButton( -name=> 'caac_Run6PointCalibration', -font=> $StdWinFont,
  -text=> 'Run 6-Point Acc Calibration', -pos=> [$xpos+20,$ypos-3+4*13], -width=> 120+20,
);
$f_Tab{calibrateacc}->AddButton( -name=> 'caac_RunGyroCalibration', -font=> $StdWinFont,
  -text=> 'Run Gyro Calibration', -pos=> [$xpos+20,$ypos-3+8*13], -width=> 120+20,
);

$xpos= 280;
$ypos+=  10;
$f_Tab{calibrateacc}->AddLabel( -name=> 'cacc_ImuNummer_label', -font=> $StdWinFont,
  -text=> ' Imu', -pos=> [$xpos-1-30,$ypos],
);
$f_Tab{calibrateacc}->AddCombobox( -name=> 'cacc_ImuNumber', -font=> $StdWinFont,
  -pos=> [$xpos,$ypos-3], -size=> [120,160],
  -dropdown=> 1, -vscroll=>1,
  -onChange=> sub{ CalibrateTabClearCalibration(); 1; },
);
$f_Tab{calibrateacc}->cacc_ImuNumber->SetDroppedWidth(100);
$f_Tab{calibrateacc}->cacc_ImuNumber->Add( 'Imu  (camera IMU)' );
$f_Tab{calibrateacc}->cacc_ImuNumber->Add( 'Imu2 (2nd IMU)' );
$f_Tab{calibrateacc}->cacc_ImuNumber->Select( 0 );

my $AccCalibDataColor = [255,255,255];
my $GyroCalibDataColor = [255,255,255];
$xpos= 280;
$ypos+= 3*13;
$f_Tab{calibrateacc}->AddLabel( -name=> 'caac_Zero_label', -font=> $StdWinFont,
  -text=> 'Acc Zero', -pos=> [$xpos-1-30 -20,$ypos+1*13],
);
$f_Tab{calibrateacc}->AddLabel( -name=> 'caac_Scale_label', -font=> $StdWinFont,
  -text=> 'Acc Scale', -pos=> [$xpos-1-30 -20,$ypos+3*13],
);
$f_Tab{calibrateacc}->AddLabel( -name=> 'caac_GyroZero_label', -font=> $StdWinFont,
  -text=> 'Gyro Zero', -pos=> [$xpos-1-30 -20,$ypos+5*13],
);
$f_Tab{calibrateacc}->AddLabel( -name=> 'caac_AccX_label', -font=> $StdWinFont,
  -text=> ' x', -pos=> [$xpos-1,$ypos-7],
);
$f_Tab{calibrateacc}->AddTextfield( -name=> 'caac_AccXZero', -font=> $StdWinFont,
  -pos=> [$xpos,$ypos+1*13-4], -size=> [60,23],
  -align=> "right",
);
$f_Tab{calibrateacc}->AddTextfield( -name=> 'caac_AccXScale', -font=> $StdWinFont,
  -pos=> [$xpos,$ypos+3*13-4], -size=> [60,23],
  -align=> "right",
);
$f_Tab{calibrateacc}->AddTextfield( -name=> 'caac_GyroXZero', -font=> $StdWinFont,
  -pos=> [$xpos,$ypos+5*13-4], -size=> [60,23],
  -align=> "right",
);
$xpos+= 70;
$f_Tab{calibrateacc}->AddLabel( -name=> 'caac_AccY_label', -font=> $StdWinFont,
  -text=> ' y', -pos=> [$xpos-1,$ypos-7],
);
$f_Tab{calibrateacc}->AddTextfield( -name=> 'caac_AccYZero', -font=> $StdWinFont,
  -pos=> [$xpos,$ypos+1*13-4], -size=> [60,23],
  -align=> "right",
);
$f_Tab{calibrateacc}->AddTextfield( -name=> 'caac_AccYScale', -font=> $StdWinFont,
  -pos=> [$xpos,$ypos+3*13-4], -size=> [60,23],
  -align=> "right",
);
$f_Tab{calibrateacc}->AddTextfield( -name=> 'caac_GyroYZero', -font=> $StdWinFont,
  -pos=> [$xpos,$ypos+5*13-4], -size=> [60,23],
  -align=> "right",
);
$xpos+= 70;
$f_Tab{calibrateacc}->AddLabel( -name=> 'caac_AccZ_label', -font=> $StdWinFont,
  -text=> ' z', -pos=> [$xpos-1,$ypos-7],
);
$f_Tab{calibrateacc}->AddTextfield( -name=> 'caac_AccZZero', -font=> $StdWinFont,
  -pos=> [$xpos,$ypos+1*13-4], -size=> [60,23],
  -align=> "right",
);
$f_Tab{calibrateacc}->AddTextfield( -name=> 'caac_AccZScale', -font=> $StdWinFont,
  -pos=> [$xpos,$ypos+3*13-4], -size=> [60,23],
  -align=> "right",
);
$f_Tab{calibrateacc}->AddTextfield( -name=> 'caac_GyroZZero', -font=> $StdWinFont,
  -pos=> [$xpos,$ypos+5*13-4], -size=> [60,23],
  -align=> "right",
);

$xpos= 530;
$ypos-= 4*13; #2*13 + 10;
$f_Tab{calibrateacc}->AddButton( -name=> 'caac_LoadFromFile', -font=> $StdWinFont,
  -text=> 'Load from File', -pos=> [$xpos,$ypos-3+1*13], -width=> 100,
  -onClick => sub{ ExecuteLoadCalibrationData(GetCalibrationSensors()); 1;}
);
$f_Tab{calibrateacc}->AddButton( -name=> 'caac_SaveToFile', -font=> $StdWinFont,
  -text=> 'Save to File', -pos=> [$xpos,$ypos-3+3*13], -width=> 100,
  -onClick => sub{ ExecuteSaveCalibrationData(GetCalibrationSensors()); 1;}
);
$f_Tab{calibrateacc}->AddButton( -name=> 'caac_Reset', -font=> $StdWinFont,
  -text=> 'Reset to Default', -pos=> [$xpos,$ypos-3+5*13], -width=> 100,
  -onClick => sub{
        AccCalibrateTabSetCalibration(0,0,0,$ACC_GRAVITY,$ACC_GRAVITY,$ACC_GRAVITY);
        GyroCalibrateTabSetCalibration(0,0,0);
        1;}
);
$f_Tab{calibrateacc}->AddButton( -name=> 'caac_ReadFromBoard', -font=> $StdWinFont,
  -text=> 'Read from Board', -pos=> [$xpos,$ypos-3+7*13], -width=> 100,
  -onClick => sub{
    if( $Execute_IsRunning ){ return 1; }
    $Execute_IsRunning = 1;
    my $ret = ExecuteReadCalibrationData(GetCalibrationSensors());
    if( $ret == 1 ){ CalibrateTabEnable(1); }
    $Execute_IsRunning = 0;
    1; }
);

$xpos= 655;
$f_Tab{calibrateacc}->AddRadioButton( -name=> 'caac_SensorAcc', -font=> $StdWinFont,
  -text=> 'Acc', -pos=> [$xpos,$ypos-3+1*13], -width=> 100,
  -checked=>1,
  -onClick => sub{
      #CalibrateTabClearCalibration();
      $f_Tab{calibrateacc}->caac_Run1PointCalibration->Enable(1);
      $f_Tab{calibrateacc}->caac_Run6PointCalibration->Enable(1);
      $f_Tab{calibrateacc}->caac_Zero_label->Enable(1);
      $f_Tab{calibrateacc}->caac_AccXZero->Enable(1);
      $f_Tab{calibrateacc}->caac_AccYZero->Enable(1);
      $f_Tab{calibrateacc}->caac_AccZZero->Enable(1);
      $f_Tab{calibrateacc}->caac_Scale_label->Enable(1);
      $f_Tab{calibrateacc}->caac_AccXScale->Enable(1);
      $f_Tab{calibrateacc}->caac_AccYScale->Enable(1);
      $f_Tab{calibrateacc}->caac_AccZScale->Enable(1);

      $f_Tab{calibrateacc}->caac_RunGyroCalibration->Hide();
      $f_Tab{calibrateacc}->caac_GyroZero_label->Hide();
      $f_Tab{calibrateacc}->caac_GyroXZero->Hide();
      $f_Tab{calibrateacc}->caac_GyroYZero->Hide();
      $f_Tab{calibrateacc}->caac_GyroZZero->Hide();
      1;}
);
$f_Tab{calibrateacc}->AddRadioButton( -name=> 'caac_SensorGyro', -font=> $StdWinFont,
  -text=> 'Gyro', -pos=> [$xpos,$ypos-3+2.5*13], -width=> 100,
  -onClick => sub{
      #CalibrateTabClearCalibration();
      $f_Tab{calibrateacc}->caac_Run1PointCalibration->Enable(0);
      $f_Tab{calibrateacc}->caac_Run6PointCalibration->Enable(0);
      $f_Tab{calibrateacc}->caac_Zero_label->Enable(0);
      $f_Tab{calibrateacc}->caac_AccXZero->Enable(0);
      $f_Tab{calibrateacc}->caac_AccYZero->Enable(0);
      $f_Tab{calibrateacc}->caac_AccZZero->Enable(0);
      $f_Tab{calibrateacc}->caac_Scale_label->Enable(0);
      $f_Tab{calibrateacc}->caac_AccXScale->Enable(0);
      $f_Tab{calibrateacc}->caac_AccYScale->Enable(0);
      $f_Tab{calibrateacc}->caac_AccZScale->Enable(0);

      $f_Tab{calibrateacc}->caac_RunGyroCalibration->Show();
      $f_Tab{calibrateacc}->caac_GyroZero_label->Show();
      $f_Tab{calibrateacc}->caac_GyroXZero->Show();
      $f_Tab{calibrateacc}->caac_GyroYZero->Show();
      $f_Tab{calibrateacc}->caac_GyroZZero->Show();
      1;}
);
$f_Tab{calibrateacc}->AddRadioButton( -name=> 'caac_SensorAccGyro', -font=> $StdWinFont,
  -text=> 'Acc+Gyro', -pos=> [$xpos,$ypos-3+4*13], -width=> 100,
  -onClick => sub{
      #CalibrateTabClearCalibration();
      $f_Tab{calibrateacc}->caac_Run1PointCalibration->Enable(1);
      $f_Tab{calibrateacc}->caac_Run6PointCalibration->Enable(1);
      $f_Tab{calibrateacc}->caac_Zero_label->Enable(1);
      $f_Tab{calibrateacc}->caac_AccXZero->Enable(1);
      $f_Tab{calibrateacc}->caac_AccYZero->Enable(1);
      $f_Tab{calibrateacc}->caac_AccZZero->Enable(1);
      $f_Tab{calibrateacc}->caac_Scale_label->Enable(1);
      $f_Tab{calibrateacc}->caac_AccXScale->Enable(1);
      $f_Tab{calibrateacc}->caac_AccYScale->Enable(1);
      $f_Tab{calibrateacc}->caac_AccZScale->Enable(1);

      $f_Tab{calibrateacc}->caac_RunGyroCalibration->Show();
      $f_Tab{calibrateacc}->caac_GyroZero_label->Show();
      $f_Tab{calibrateacc}->caac_GyroXZero->Show();
      $f_Tab{calibrateacc}->caac_GyroYZero->Show();
      $f_Tab{calibrateacc}->caac_GyroZZero->Show();
      1;}
);
#$f_Tab{calibrateacc}->caac_SensorAcc->Click();
$f_Tab{calibrateacc}->caac_RunGyroCalibration->Hide();
$f_Tab{calibrateacc}->caac_GyroZero_label->Hide();
$f_Tab{calibrateacc}->caac_GyroXZero->Hide();
$f_Tab{calibrateacc}->caac_GyroYZero->Hide();
$f_Tab{calibrateacc}->caac_GyroZZero->Hide();

$xpos= 30;
$ypos= 20 + 17*13 + 4 +1*13;
$f_Tab{calibrateacc}->AddLabel( -name=> 'caac_StoreInEEprom_label', -font=> $StdWinFont,
  -text=> "3. Store Calibration Data
Store the selecter calibration data to the EEPROM, otherwise it won't be active nor permanent.

ATTENTION: Be carefull to not store nonsense data!",
  -pos=> [$xpos,$ypos], -multiline=>1, -size=>[460,70],
);
$f_Tab{calibrateacc}->AddButton( -name=> 'caac_StoreInEEprom', -font=> $StdWinFont,
  -text=> 'Store Calibration', -pos=> [$xpos+490-10,$ypos-3+13-5], -width=> 120+20, -height=> 30,
  -onClick => sub{
    if( $Execute_IsRunning ){ return 1; }
    $Execute_IsRunning = 1;
    ExecuteStoreCalibrationData(GetCalibrationSensors());
    $Execute_IsRunning = 0;
    1; }
);
$f_Tab{calibrateacc}->caac_StoreInEEprom->Disable();


sub CalibrateTabEnable{
  if(shift){
    $f_Tab{calibrateacc}->caac_StoreInEEprom->Enable();
  }else{
    $f_Tab{calibrateacc}->caac_StoreInEEprom->Disable();
  }
}

sub CalibrateTabClearCalibration{
  #CalibrateTabEnable(0); this needs a bit more work to get it all right
  ClearCalibrationDataRecord();
  AccCalibrateTabCopyRecordToTab();
  GyroCalibrateTabCopyRecordToTab();
}

sub GetCalibrationSensors{
  if( $f_Tab{calibrateacc}->caac_SensorAccGyro->Checked() ){ return 3; }
  if( $f_Tab{calibrateacc}->caac_SensorGyro->Checked() ){ return 2; }
  return 1;
}


sub AccCalibrateTabCopyRecordToTab{
  $f_Tab{calibrateacc}->caac_AccXZero->Text( $CalibrationDataRecord{axzero} );
  $f_Tab{calibrateacc}->caac_AccYZero->Text( $CalibrationDataRecord{ayzero} );
  $f_Tab{calibrateacc}->caac_AccZZero->Text( $CalibrationDataRecord{azzero} );
  $f_Tab{calibrateacc}->caac_AccXScale->Text( $CalibrationDataRecord{axscale} );
  $f_Tab{calibrateacc}->caac_AccYScale->Text( $CalibrationDataRecord{ayscale} );
  $f_Tab{calibrateacc}->caac_AccZScale->Text( $CalibrationDataRecord{azscale} );
}

sub AccCalibrateTabCopyTabToRecord{
  $CalibrationDataRecord{axzero}= $f_Tab{calibrateacc}->caac_AccXZero->Text();
  $CalibrationDataRecord{ayzero}= $f_Tab{calibrateacc}->caac_AccYZero->Text();
  $CalibrationDataRecord{azzero}= $f_Tab{calibrateacc}->caac_AccZZero->Text();
  $CalibrationDataRecord{axscale}= $f_Tab{calibrateacc}->caac_AccXScale->Text();
  $CalibrationDataRecord{ayscale}= $f_Tab{calibrateacc}->caac_AccYScale->Text();
  $CalibrationDataRecord{azscale}= $f_Tab{calibrateacc}->caac_AccZScale->Text();
}

sub AccCalibrateTabSetCalibration{
  $CalibrationDataRecord{axzero}= shift;
  $CalibrationDataRecord{ayzero}= shift;
  $CalibrationDataRecord{azzero}= shift;
  $CalibrationDataRecord{axscale}= shift;
  $CalibrationDataRecord{ayscale}= shift;
  $CalibrationDataRecord{azscale}= shift;
  AccCalibrateTabCopyRecordToTab();
}

sub AccCalibrateTabGetCalibration{
  AccCalibrateTabCopyTabToRecord();
  return (
    $CalibrationDataRecord{axzero},
    $CalibrationDataRecord{ayzero},
    $CalibrationDataRecord{azzero},
    $CalibrationDataRecord{axscale},
    $CalibrationDataRecord{ayscale},
    $CalibrationDataRecord{azscale},
  );
}

sub GyroCalibrateTabCopyRecordToTab{
  $f_Tab{calibrateacc}->caac_GyroXZero->Text( $CalibrationDataRecord{gxzero} );
  $f_Tab{calibrateacc}->caac_GyroYZero->Text( $CalibrationDataRecord{gyzero} );
  $f_Tab{calibrateacc}->caac_GyroZZero->Text( $CalibrationDataRecord{gzzero} );
}

sub GyroCalibrateTabCopyTabToRecord{
  $CalibrationDataRecord{gxzero}= $f_Tab{calibrateacc}->caac_GyroXZero->Text();
  $CalibrationDataRecord{gyzero}= $f_Tab{calibrateacc}->caac_GyroYZero->Text();
  $CalibrationDataRecord{gzzero}= $f_Tab{calibrateacc}->caac_GyroZZero->Text();
}

sub GyroCalibrateTabSetCalibration{
  $CalibrationDataRecord{gxzero}= shift;
  $CalibrationDataRecord{gyzero}= shift;
  $CalibrationDataRecord{gzzero}= shift;
  GyroCalibrateTabCopyRecordToTab();
}

sub GyroCalibrateTabGetCalibration{
  GyroCalibrateTabCopyTabToRecord();
  return (
    $CalibrationDataRecord{gxzero},
    $CalibrationDataRecord{gyzero},
    $CalibrationDataRecord{gzzero},
  );
}


sub ExecuteReadCalibrationData{
  my $sensors = shift; #1=acc, 2=gyro, 3=acc+gyro
  #read all calibration data from board
  if( not ConnectionIsValid() ){ ConnectToBoardwoRead(); }
  my ($ret,$s) = ExecuteCommandFullwoGet( 'Cr', 'Read calibration data', '', 1, 18*2 );
  if( $ret == 0 ){ return 0; }
  my @CrData = unpack( "v18", $s );
  for(my $n=0;$n<18;$n++){ if( $CrData[$n] > 32768-1 ){ $CrData[$n] -= 65536; } }
  #copy to record and into tab
  ClearCalibrationDataRecord(); #clear record
  if( $f_Tab{calibrateacc}->cacc_ImuNumber->GetCurSel() != 1 ){ #IMU1 selected
      AccCalibrateTabSetCalibration( #copies into record and tab
        $CrData[0], $CrData[1], $CrData[2],  $CrData[3], $CrData[4], $CrData[5]
      );
      GyroCalibrateTabSetCalibration( $CrData[6], $CrData[7], $CrData[8] );
  }else{ #IMU2
      AccCalibrateTabSetCalibration( #copies into record and tab
        $CrData[9], $CrData[10], $CrData[11],  $CrData[12], $CrData[13], $CrData[14]
      );
      GyroCalibrateTabSetCalibration( $CrData[15], $CrData[16], $CrData[17] );
  }
  return 1;
}


sub CheckIntegrityOfCalibrationDataInTab{
  my $sensors = shift; #1=acc, 2=gyro, 3=acc+gyro
  my $error_flag= 0;
  if( $sensors == 3 or $sensors == 1 ){
    my ( $axzero, $ayzero, $azzero, $axscale, $ayscale, $azscale ) =  AccCalibrateTabGetCalibration();
    if( $axzero eq '' ){ $error_flag= 1; }
    if( $ayzero eq '' ){ $error_flag= 1; }
    if( $azzero eq '' ){ $error_flag= 1; }
    if( $axscale eq '' ){ $error_flag= 1; }
    if( $ayscale eq '' ){ $error_flag= 1; }
    if( $azscale eq '' ){ $error_flag= 1; }
    if( not $axzero =~ m/^[+-]?\d*$/ ){ $error_flag= 2; }
    if( not $ayzero =~ m/^[+-]?\d*$/ ){ $error_flag= 2; }
    if( not $azzero =~ m/^[+-]?\d*$/ ){ $error_flag= 2; }
    if( not $axscale =~ m/^[+]?\d*$/ ){ $error_flag= 3; }
    if( not $ayscale =~ m/^[+]?\d*$/ ){ $error_flag= 3; }
    if( not $azscale =~ m/^[+]?\d*$/ ){ $error_flag= 3; }
    my $ZeroLimit = 7000; my $ScaleLimitLow = 15000; my $ScaleLimitHigh = 17500;
    if( abs($ACC_GRAVITY - 8192) < 1000 ){
      $ZeroLimit = 3500; $ScaleLimitLow = 7500; $ScaleLimitHigh = 8900;
    }
    if( abs($axzero)>$ZeroLimit ){ $error_flag= 4; }
    if( abs($ayzero)>$ZeroLimit ){ $error_flag= 4; }
    if( abs($azzero)>$ZeroLimit ){ $error_flag= 4; }
    if(( $axscale<$ScaleLimitLow )or( $axscale>$ScaleLimitHigh )){ $error_flag= 5; }
    if(( $ayscale<$ScaleLimitLow )or( $ayscale>$ScaleLimitHigh )){ $error_flag= 5; }
    if(( $azscale<$ScaleLimitLow )or( $azscale>$ScaleLimitHigh )){ $error_flag= 5; }

    if( $error_flag ){
      my $res = $w_Main->MessageBox( "You have entered invalid acc calibration data!

The values have to be (signed) integers, the Zero values should
be in the range of -$ZeroLimit to +$ZeroLimit, and the Scale values in the
range of +$ScaleLimitLow to +$ScaleLimitHigh.

If you want to continue anyway, press Yes, else No.", 'WARNING', 0x0010 + 4 );# MB_ICONHAND
      if( $res==6 ){ $error_flag= 0; }else{ return 10; }
    }
  }
  if( $sensors == 3 or $sensors == 2 ){
    my ( $gxzero, $gyzero, $gzzero ) =  GyroCalibrateTabGetCalibration();
    if( $gxzero eq '' ){ $error_flag= 6; }
    if( $gyzero eq '' ){ $error_flag= 6; }
    if( $gzzero eq '' ){ $error_flag= 6; }
    if( not $gxzero =~ m/^[+-]?\d*$/ ){ $error_flag= 7; }
    if( not $gyzero =~ m/^[+-]?\d*$/ ){ $error_flag= 7; }
    if( not $gzzero =~ m/^[+-]?\d*$/ ){ $error_flag= 7; }
    my $ZeroLimit = 12000;
    if( abs($gxzero)>$ZeroLimit ){ $error_flag= 8; }
    if( abs($gyzero)>$ZeroLimit ){ $error_flag= 8; }
    if( abs($gzzero)>$ZeroLimit ){ $error_flag= 8; }

    if( $error_flag ){
      my $res = $w_Main->MessageBox( "You have entered invalid gyro calibration data!

The values have to be (signed) integers and the Zero values should
be in the range of -$ZeroLimit to +$ZeroLimit.

If you want to continue anyway, press Yes, else No.", 'WARNING', 0x0010 + 4 );# MB_ICONHAND
      if( $res==6 ){ $error_flag= 0; }else{ return 20; }
    }
  }
  return $error_flag;
}


sub ExecuteStoreCalibrationData{
  my $sensors = shift; #1=acc, 2=gyro, 3=acc+gyro
  #the first entry tells:
  # 1:acc1, 2:gyro1, 3:acc2, 4:gyro2, 5:acc1&gyro1, 6:acc2&gyro2, 7: all, else: error
  #make first a sanity check of the parameters
  if( CheckIntegrityOfCalibrationDataInTab($sensors) > 0 ){ return; }
  #warn that calibration will be overwritten
  if(
    $w_Main->MessageBox( "You are going to rewrite calibration data permanently!

Are you sure you want to continue?", 'WARNING', 0x0034 ) #MB_ICONEXCLAMATION|MB_YESNO
    != 6 #IDYES
  ){ return; }
  my @CalibrationDataArray = (); #this holds all data as array
  for(my $n=0; $n<18; $n++){ $CalibrationDataArray[$n] = 0; } #this is to create array with 18 fields
  my $CwData = ''; # this holds the data as packed string
  if( $f_Tab{calibrateacc}->cacc_ImuNumber->GetCurSel() != 1 ){ #IMU1 selected
    ( $CalibrationDataArray[0], $CalibrationDataArray[1], $CalibrationDataArray[2],
      $CalibrationDataArray[3], $CalibrationDataArray[4], $CalibrationDataArray[5] ) =  AccCalibrateTabGetCalibration();
    ( $CalibrationDataArray[6], $CalibrationDataArray[7], $CalibrationDataArray[8] ) =  GyroCalibrateTabGetCalibration();
    if( $sensors == 1 ){
      $CwData = pack( "v", '1' ); #1: store only IMU1 acc values
    }elsif( $sensors == 2 ){
      $CwData = pack( "v", '2' );
    }elsif( $sensors == 3 ){
      $CwData = pack( "v", '5' );
    }
  }else{ #IMU2
    ( $CalibrationDataArray[9], $CalibrationDataArray[10], $CalibrationDataArray[11],
      $CalibrationDataArray[12], $CalibrationDataArray[13], $CalibrationDataArray[14] ) =  AccCalibrateTabGetCalibration();
    ( $CalibrationDataArray[15], $CalibrationDataArray[16], $CalibrationDataArray[17] ) =  GyroCalibrateTabGetCalibration();
    if( $sensors == 1 ){
      $CwData = pack( "v", '3' ); #3: store only IMU2 acc values
    }elsif( $sensors == 2 ){
      $CwData = pack( "v", '4' );
    }elsif( $sensors == 3 ){
      $CwData = pack( "v", '6' );
    }
  }
  for(my $n=0;$n<18;$n++){ $CwData .= pack( "v", $CalibrationDataArray[$n] ); }
  SetExtendedTimoutFirst(1000); #storing to Eerpom can take a while! so extend timeout
  ExecuteCommandWritewoGet( 'Cw', 'Write calibration data', '', $CwData, 1 );
}


my $SettingsFile_lastdir= $ExePath; #also used below for save and load settings

sub ExecuteSaveCalibrationData{
  my $sensors = shift; #1=acc, 2=gyro, 3=acc+gyro
  #make first a sanity check of the parameters
  if( CheckIntegrityOfCalibrationDataInTab($sensors)>0 ){ return; }
  my $file= Win32::GUI::GetSaveFileName( -owner=> $w_Main,
    -title=> 'Save Calibration Data to File',
    -nochangedir=> 1,
    -directory=> $SettingsFile_lastdir, #".\\",
    -defaultextension=> '.cal',
    -filter=> ['*.cal'=>'*.cal','All files' => '*.*'],
    -pathmustexist=> 1,
    -overwriteprompt=> 1,
    -noreadonlyreturn => 1,
    -explorer=>0,
  );
  if( $file ){
    if( !open(F,">$file") ){ $w_Main->MessageBox("Some error occured, sorry",'ERROR'); return; }
    print F 'RECORD#1'."\n";
    if( $sensors == 3 or $sensors == 1 ){
      print F 'AXZERO: '.$CalibrationDataRecord{axzero}."\n";
      print F 'AYZERO: '.$CalibrationDataRecord{ayzero}."\n";
      print F 'AZZERO: '.$CalibrationDataRecord{azzero}."\n";
      print F 'AXSCALE: '.$CalibrationDataRecord{axscale}."\n";
      print F 'AYSCALE: '.$CalibrationDataRecord{ayscale}."\n";
      print F 'AZSCALE: '.$CalibrationDataRecord{azscale}."\n";
      print F 'CALIBRATIONMETHOD: '.$CalibrationDataRecord{calibrationmethod}."\n";
    }
    if( $sensors == 3 or $sensors == 2 ){
      print F 'GXZERO: '.$CalibrationDataRecord{gxzero}."\n";
      print F 'GYZERO: '.$CalibrationDataRecord{gyzero}."\n";
      print F 'GZZERO: '.$CalibrationDataRecord{gzzero}."\n";
    }
    print F 'TEMPERATURE: '.$CalibrationDataRecord{temperature}."\n";
    print F 'RAW: '."\n";
    print F $CalibrationDataRecord{raw}."\n";
    close(F);
  }elsif( Win32::GUI::CommDlgExtendedError() ){$w_Main->MessageBox("Some error occured, sorry",'ERROR');}
  1;
}


sub ExecuteLoadCalibrationData{
  my $sensors = shift; #1=acc, 2=gyro, 3=acc+gyro
  my $file= Win32::GUI::GetOpenFileName( -owner=> $w_Main,
    -title=> 'Load Calibration Data from File',
    -nochangedir=> 1,
    -directory=> $SettingsFile_lastdir, #".\\",
    -defaultextension=> '.cal',
    -filter=> ['*.cal'=>'*.cal','*.cfgx'=>'*.cfgx','All files' => '*.*'],
    -pathmustexist=> 1,
    -filemustexist=> 1,
  );
  if( $file ){
    if( !open(F,"<$file") ){ $w_Main->MessageBox( "Some error occured, sorry",'ERROR'); return; }
    my $s=''; my $s2=''; while(<F>){ $s.= $_.'\n'; $s2.= $_;} close(F);
    #check if it is a cfgx file
    my $axzero = 0; my $ayzero = 0; my $azzero = 0; my $axscale; my $ayscale; my $azscale;
    my $gxzero = 0; my $gyzero = 0; my $gzzero = 0;
    if( ($s =~ /\%SettingsHash/) or ($s =~ /\%SettingsHashV2/) or ($s =~ /\$Script/) ){
      my %SettingsHash = (); my %SettingsHashV2 = ();
      my $Script1 = 'e'; my $Script2 = 'e'; my $Script3 = 'e'; my $Script4 = 'e';
      my %CalibrationConstants = ();
      my %Imu1 = (); my %Imu2 = (); ##my %Imu3 = ();
      my %MotorPitch = (); my %MotorRoll = (); my %MotorYaw = (); my %Logger = ();
      eval "$s2";
      if($@){ %CalibrationConstants = (); }
      if( %CalibrationConstants ){
        my $imu = '1';
        if( $f_Tab{calibrateacc}->cacc_ImuNumber->GetCurSel() == 1 ){ $imu = '2'; }
        $axzero = $CalibrationConstants{'Acc'.$imu.' Zero'}[0];
        $ayzero = $CalibrationConstants{'Acc'.$imu.' Zero'}[1];
        $azzero = $CalibrationConstants{'Acc'.$imu.' Zero'}[2];
        $axscale = $CalibrationConstants{'Acc'.$imu.' Scale'}[0];
        $ayscale = $CalibrationConstants{'Acc'.$imu.' Scale'}[1];
        $azscale = $CalibrationConstants{'Acc'.$imu.' Scale'}[2];
        $gxzero = $CalibrationConstants{'Gyro'.$imu.' Zero'}[0];
        $gyzero = $CalibrationConstants{'Gyro'.$imu.' Zero'}[1];
        $gzzero = $CalibrationConstants{'Gyro'.$imu.' Zero'}[2];
      }
    }else{
      $s =~ /AXZERO\s*:\s*([+-]?\d+)\s*\\n/; $axzero = $1;
      $s =~ /AYZERO\s*:\s*([+-]?\d+)\s*\\n/; $ayzero = $1;
      $s =~ /AZZERO\s*:\s*([+-]?\d+)\s*\\n/; $azzero = $1;
      $s =~ /AXSCALE\s*:\s*([+-]?\d+)\s*\\n/; $axscale = $1;
      $s =~ /AYSCALE\s*:\s*([+-]?\d+)\s*\\n/; $ayscale = $1;
      $s =~ /AZSCALE\s*:\s*([+-]?\d+)\s*\\n/; $azscale = $1;
      $s =~ /GXZERO\s*:\s*([+-]?\d+)\s*\\n/; $gxzero = $1;
      $s =~ /GYZERO\s*:\s*([+-]?\d+)\s*\\n/; $gyzero = $1;
      $s =~ /GZZERO\s*:\s*([+-]?\d+)\s*\\n/; $gzzero = $1;
    }
    if( $sensors == 3 or $sensors == 1 ){
      AccCalibrateTabSetCalibration( $axzero, $ayzero, $azzero, $axscale, $ayscale, $azscale );
    }
    if( $sensors == 3 or $sensors == 2 ){
      GyroCalibrateTabSetCalibration( $gxzero, $gyzero, $gzzero );
    }
  }elsif( Win32::GUI::CommDlgExtendedError() ){ $w_Main->MessageBox("Some error occured, sorry",'ERROR'); }
  1;
}



#-----------------------------------------------------------------------------#
###############################################################################
### do Flash tab ###
###############################################################################
#-----------------------------------------------------------------------------#

$xpos= 30;
$ypos= 20;

$f_Tab{flash}->AddLabel( -name=> 'flash_text1a', -font=> $StdWinFont,
  -text=> '1. Select the correct firmware file via the following filters:', -pos=> [$xpos,$ypos],
);

$xpos= 30+20;
$ypos+= 25;
$f_Tab{flash}->AddLabel( -name=> 'flash_Board_label', -font=> $StdWinFont,
  -text=> 'Board', -pos=> [$xpos,$ypos],
);
$f_Tab{flash}->AddCombobox( -name=> 'flash_Board', -font=> $StdWinFont,
  -pos=> [$xpos+120,$ypos-3], -size=> [260,200],
  -dropdown=> 1, -vscroll=>1,
  -onChange=> sub{ SetBoard(); SetFirmwareHexFile(); 1; }
);
foreach my $board (@STorM32BoardList){ $f_Tab{flash}->flash_Board->Add( $board->{name} ); }
$f_Tab{flash}->flash_Board->SelectString( $STorM32Board );

$f_Tab{flash}->AddButton( -name=> 'flash_ScanNtBus_button', -font=> $StdWinFont,
  -text=> 'Scan NT Bus', -pos=> [$xsize-100+20-82,$ypos-4], -width=> 100,
);
#$f_Tab{flash}->AddButton( -name=> 'flash_CheckNtVersions_button', -font=> $StdWinFont,
#  -text=> 'Check NT module firmware versions', -pos=> [$xsize-180+20-82,$ypos-4 +30], -width=> 180,
#);
$f_Tab{flash}->AddLabel( -name=> 'flash_CheckNtVersions_label', -font=> $StdWinFont,
  -text=> 'Check versions', -pos=> [$xsize-100+20-82 +15,$ypos-4 + 30],
);
$f_Tab{flash}->AddCheckbox( -name  => 'flash_CheckNtVersions_check', -font=> $StdWinFont,
  -pos=> [$xsize-100+20-82,$ypos-4 + 30 + 1], -size=> [12,12],
);
$f_Tab{flash}->flash_CheckNtVersions_check->Checked($CheckNtModuleVersions);

$ypos+= 30;
$f_Tab{flash}->AddLabel( -name=> 'flash_Version_label', -font=> $StdWinFont,
  -text=> 'Firmware Version', -pos=> [$xpos,$ypos],
);
$f_Tab{flash}->AddCombobox( -name=> 'flash_Version', -font=> $StdWinFont,
  -pos=> [$xpos+120,$ypos-3], -size=> [260,200],
  -dropdown=> 1, -vscroll=>1,
  -onChange=> sub{ SetFirmwareHexFile(); 1; }
);

$xpos= 30;
$ypos+= 50;
$f_Tab{flash}->AddLabel( -name=> 'flash_HexFile_label', -font=> $StdWinFont,
  -text=> 'Selected Firmware Hex File', -pos=> [$xpos,$ypos], -size=> [$xsize-100+20,20],
);
$f_Tab{flash}->AddTextfield( -name=> 'flash_HexFile', -font=> $StdWinFont,
  -pos=> [$xpos+140-1,$ypos+13-16], -size=> [$xsize-$xpos-80-140,23],
);
$f_Tab{flash}->AddButton( -name=> 'flash_HexFile_button', -font=> $StdWinFont,
  -text=> '...', -pos=> [$xsize-100+20,$ypos+13-13-3], -width=> 18,
);
$ypos+= 30+20;
$f_Tab{flash}->AddLabel( -name=> 'flash_text21a', -font=> $StdWinFont,
  -text=> '2. Select the programmer type, and related options:', -pos=> [$xpos,$ypos],
);

$ypos+= 30-5;
$f_Tab{flash}->AddLabel( -name=> 'flash_Programmer_label', -font=> $StdWinFont,
  -text=> 'STM32 Programmer', -pos=> [$xpos+20,$ypos],
);
$f_Tab{flash}->AddCombobox( -name=> 'flash_Programmer', -font=> $StdWinFont,
  -pos=> [$xpos+140,$ypos-3], -size=> [260,200],
  -dropdown=> 1, -vscroll=>1,
  -onChange=> sub{ SetProgrammer(); 1;}
);

$f_Tab{flash}->AddLabel( -name=> 'flash_ProgrammerComPort_label', -font=> $StdWinFont,
  -text=> 'Com Port', -pos=> [$xpos+420,$ypos],
);
$f_Tab{flash}->AddCombobox( -name=> 'flash_ProgrammerComPort', -font=> $StdWinFont,
  -pos=> [$xpos+420+$f_Tab{flash}->flash_ProgrammerComPort_label->Width()+2,$ypos-3], -size=> [70,200],
  -dropdown=> 1, -vscroll=>1,
  -onDropDown=> sub{
    my ($STMComPortOK,@STMPortList)= GetComPorts();
    if($STMComPortOK>0){
      my $s= $_[0]->Text();
      $_[0]->Clear(); $_[0]->Add( @STMPortList ); $_[0]->SelectString( $s ); #$Port has COM + friendly name
      if($_[0]->SelectedItem()<0){ $_[0]->Select(0); }
    }
    1;
  }
);
$f_Tab{flash}->flash_ProgrammerComPort->SetDroppedWidth(160);

$f_Tab{flash}->AddLabel( -name=> 'flash_ProgrammerModuleId_label', -font=> $StdWinFont,
  -text=> 'Module Id', -pos=> [$xpos+420-3,$ypos],
);
$f_Tab{flash}->AddCombobox( -name=> 'flash_ProgrammerModuleId', -font=> $StdWinFont,
  -pos=> [$xpos+420+$f_Tab{flash}->flash_ProgrammerComPort_label->Width()+2,$ypos-3], -size=> [90,200],
  -dropdown=> 1, -vscroll=>1,
);
$f_Tab{flash}->flash_ProgrammerModuleId->SetDroppedWidth(90);

#STorM32 SystemBootLoaderAtUart1 for V1x
$f_Tab{flash}->AddLabel( -name=> 'flash_ProgrammerUsage_Storm32v1x_SysBootLoad_label', -font=> $StdWinFont,
  -pos=> [$xpos+430+35,$ypos+30], -multiline => 1, -height=>6*13+50, -width=>300,
  -text=> 'Usage:
1. Connect usb adapter to UART1 at RC port
2. Select com port of the usb adapter
3. Press RESET and BOOT0 buttons on the board
4. Release RESET while holding down BOOT0
5. Release BOOT0
6. Hit >Flash Firmware<',
);

#STorM32 SystemBootLoaderAtUart1 for V2x
$f_Tab{flash}->AddLabel( -name=> 'flash_ProgrammerUsage_Storm32v2x_SysBootLoad_label', -font=> $StdWinFont,
  -pos=> [$xpos+430+35,$ypos+30], -multiline => 1, -height=>6*13+50, -width=>300,
  -text=> 'Usage:
1. Connect usb adapter to UART1
2. Select com port of the usb adapter
3. Close BOOT0 solder bridge and
     repower or reset STorM32 board
4. Hit >Flash Firmware<',
);

#STorM32 SystemBootLoaderAtUart1 for V3x
$f_Tab{flash}->AddLabel( -name=> 'flash_ProgrammerUsage_Storm32v3x_SysBootLoad_label', -font=> $StdWinFont,
  -pos=> [$xpos+430+35,$ypos+30], -multiline => 1, -height=>6*13+50, -width=>300,
  -text=> 'Usage:
1. Connect STorM32 board via usb
2. Select port
3. Close BOOT0 solder bridge and
     repower or reset STorM32 board
4. Hit >Flash Firmware<',
);
#STorM32 UpgradeViaUSB for V3x
$f_Tab{flash}->AddLabel( -name=> 'flash_ProgrammerUsage_Storm32v3x_UpgradeViaUsb_label', -font=> $StdWinFont,
  -pos=> [$xpos+430+35,$ypos+30], -multiline => 1, -height=>6*13+50, -width=>300,
  -text=> 'Usage:
1. Connect STorM32 board via usb
2. Select port
3. Hit >Flash Firmware<',
);

#NT Module UpgradeViaStorm32UsbPort
$f_Tab{flash}->AddLabel( -name=> 'flash_ProgrammerUsage_NtUpgradeViaStorm32Usb_label', -font=> $StdWinFont,
  -pos=> [$xpos+430+35,$ypos+30], -multiline => 1, -height=>6*13+50, -width=>300,
  -text=> 'Usage:
1. Connect STorM32 board via usb
2. Select port
3. Select id of NT module
4. Hit >Flash Firmware<',
);
#NT Module UpgradeViaSystemBootLoaderAtUart1
$f_Tab{flash}->AddLabel( -name=> 'flash_ProgrammerUsage_NtUpgradeViaSysBootLoad_label', -font=> $StdWinFont,
  -pos=> [$xpos+430+35,$ypos+30], -multiline => 1, -height=>6*13+50, -width=>300,
  -text=> 'Usage:
1. Connect usb adapter to NT module
2. Select com port of the usb adapter
3. Power up NT module
4. Hit >Flash Firmware<',
);
#NT Module FlashViaStorm32UsbPort
$f_Tab{flash}->AddLabel( -name=> 'flash_ProgrammerUsage_NtFlashViaStorm32Usb_label', -font=> $StdWinFont,
  -pos=> [$xpos+430+35,$ypos+30], -multiline => 1, -height=>6*13+50, -width=>300,
  -text=> 'Usage:
1. Connect STorM32 board via usb
2. Close BOOT0 solder bridge on NT module
    (do not yet connect the NT module)
4. Select port
5. Hit >Flash Firmware<
6. Connect NT module to STorM32 board',
);
#NT Module SystemBootLoaderAtUart1
$f_Tab{flash}->AddLabel( -name=> 'flash_ProgrammerUsage_NtSysBootLoad_label', -font=> $StdWinFont,
  -pos=> [$xpos+430+35,$ypos+30], -multiline => 1, -height=>6*13+50, -width=>300,
  -text=> 'Usage:
1. Connect usb adapter to NT module
2. Select com port of the usb adapter
3. Close BOOT0 solder bridge and
     repower NT module
4. Hit >Flash Firmware<',
);

$ypos+= 30;
$f_Tab{flash}->AddLabel( -name=> 'flash_FullErase_label', -font=> $StdWinFont,
  -text=> 'Perform full chip erase', -pos=> [$xpos+20,$ypos],
);
$f_Tab{flash}->AddCheckbox( -name  => 'flash_FullErase_check', -font=> $StdWinFont,
  -pos=> [$xpos+140,$ypos+1], -size=> [12,12],
  -onClick=>sub{ SetRemoveProtections(); 1; }
);

$f_Tab{flash}->AddLabel( -name=> 'flash_RemoveProtections_label', -font=> $StdWinFont,
  -text=> 'remove protections (keep BOOT0 pressed!)', -pos=> [$xpos+140+20+20+5,$ypos],
);
$f_Tab{flash}->AddCheckbox( -name  => 'flash_RemoveProtections_check', -font=> $StdWinFont,
  -pos=> [$xpos+170,$ypos+1], -size=> [12,12],
);

$ypos+= 30;
$f_Tab{flash}->AddLabel( -name=> 'flash_Verify_label', -font=> $StdWinFont,
  -text=> 'Verify flashed firmware', -pos=> [$xpos+20,$ypos],
);
$f_Tab{flash}->AddCheckbox( -name  => 'flash_Verify_check', -font=> $StdWinFont,
  -pos=> [$xpos+140,$ypos+1], -size=> [12,12],
);

$xpos= $xsize-80;
$ypos+= 30 + 10 -15;
$f_Tab{flash}->AddButton( -name=> 'flash_Flash', -font=> $StdWinFont,
  -text=> 'Flash Firmware', -pos=> [$xpos/2-60,$ypos-3], -width=> 120, -height=> 30,
);

my $BOARDTYPE_IS_UNKNOWN = -1;
my $BOARDTYPE_IS_STORM32 = 0;
my $BOARDTYPE_IS_STORM32_V3X = 3; #this allows Upgrade via USB
my $BOARDTYPE_IS_NTMODULE = 1;

sub GetBoardTypeAndName{
  my $bi = $f_Tab{flash}->flash_Board->GetCurSel();
  #print($bi);
  my $boardname = '';
  my @boardslist = ();
  if( $bi >= 0 ){
    $boardname = $STorM32BoardList[$bi]->{name};
    if( $boardname =~ /^NT/ ){
      @boardslist= @{$STorM32BoardList[$bi]->{boards}};
    }else{
      @boardslist=[];
    }
  }
  my $boardtype = $BOARDTYPE_IS_STORM32;
  if( $boardname =~ /^STorM32 v3./ ){ $boardtype = $BOARDTYPE_IS_STORM32_V3X; }
  if( $boardname =~ /^STorM32 v4./ ){ $boardtype = $BOARDTYPE_IS_STORM32_V3X; }
  if( $boardname =~ /^NT/ ){ $boardtype = $BOARDTYPE_IS_NTMODULE; }
##TextOut( $boardtype.' '.$boardname."\r\n" ); ##XX
  return ($boardtype,$boardname,@boardslist);
}

#this is called by a board and/or firmware change
# handles changes required in firmware hex fiele field
sub SetFirmwareHexFile{
  my ($boardtype) = GetBoardTypeAndName();
  my $bi= $f_Tab{flash}->flash_Board->GetCurSel();
  my $s = '';
  my $hexfile =' ';
  if( $bi >= 0 ){ $hexfile = $STorM32BoardList[$bi]->{hexfile}; }
  my $Vreplace = '';
  my $fi = $f_Tab{flash}->flash_Version->GetCurSel();
  if( $boardtype == $BOARDTYPE_IS_NTMODULE ){ #this is a NT module
    $s = $NtFirmwareHexFileDir;
    if( $fi >= 0 ){ $Vreplace = '_'.${$STorM32BoardList[$bi]->{vreplaces}}[$fi].'_'; }
  }else{
    #good for both v1.x and v3.x boards
    $s = $FirmwareHexFileDir;
    if( $fi >= 0 ){ $Vreplace = '_'.$FirmwareVReplaceList[$fi].'_'; }
  }
  if( $s ne '' ){ $s.= '\\'; }
  $hexfile =~ s/_V_/$Vreplace/;
  $f_Tab{flash}->flash_HexFile->Text( $s.$hexfile.'.hex' );
}

#this is called by a board change
# handles all changes required in the programmer section
my $lastboardtype = $BOARDTYPE_IS_UNKNOWN; #this ensures that the list is set up at startup

sub SetBoard{
  my ($boardtype,$boardname) = GetBoardTypeAndName();
  #set STM32 Programmer list
  if( $boardtype != $lastboardtype ){ #type has been changed
    $f_Tab{flash}->flash_Programmer->Clear();
    if( $boardtype == $BOARDTYPE_IS_NTMODULE ){ #this is a NT module
      $f_Tab{flash}->flash_Programmer->Add( @NtProgrammerList );
      $f_Tab{flash}->flash_Programmer->SelectString( $NtProgrammer );
    }elsif( $boardtype == $BOARDTYPE_IS_STORM32_V3X ){ #this is a v3.x or v4.x board
      $f_Tab{flash}->flash_Programmer->Add( @Storm32ProgrammerListV3X );
      $f_Tab{flash}->flash_Programmer->SelectString( $Storm32ProgrammerV3X );
    }else{
      #good for both v1.x and v2.x boards
      $f_Tab{flash}->flash_Programmer->Add( @Storm32ProgrammerList );
      $f_Tab{flash}->flash_Programmer->SelectString( $Storm32Programmer );
      # WE NEED TO CHECK IF ENTRY WAS VALID
    }
    if( $f_Tab{flash}->flash_Programmer->GetCurSel() < 0 ){ #no valid entry found
      $Storm32Programmer = $SystemBootloader; #$f_Tab{flash}->flash_Programmer->GetString(0);
      $f_Tab{flash}->flash_Programmer->SelectString( $Storm32Programmer );
    }
  }
  #set Firmware Version list
  if( $boardtype == $BOARDTYPE_IS_NTMODULE ){ #this is a NT module
    $f_Tab{flash}->flash_Version->Clear();
    my $bi= $f_Tab{flash}->flash_Board->GetCurSel();
    if( $bi>=0 ){ $f_Tab{flash}->flash_Version->Add( @{$STorM32BoardList[$bi]->{versions}} ); }
    $f_Tab{flash}->flash_Version->Select(0);
  }else{
    if( $boardtype != $lastboardtype ){ #type has been changed
      #good for v1.x, v2.x and v3.x boards
      $f_Tab{flash}->flash_Version->Clear();
      $f_Tab{flash}->flash_Version->Add( @FirmwareVersionList );
      $f_Tab{flash}->flash_Version->SelectString( $FirmwareVersion );
    }
  }
  $lastboardtype = $boardtype;
  #set Module Id list in case of a NT module
  if( $boardtype == $BOARDTYPE_IS_NTMODULE ){ #this is a NT module
    $f_Tab{flash}->flash_ProgrammerModuleId->Clear();
    if( $boardname =~ /Imu/ ){
      $f_Tab{flash}->flash_ProgrammerModuleId->Add( 'Imu1' );
      $f_Tab{flash}->flash_ProgrammerModuleId->Add( 'Imu2' );
##      $f_Tab{flash}->flash_ProgrammerModuleId->Add( 'Imu3' );
    }elsif( $boardname =~ /Motor Triple/ ){
      $f_Tab{flash}->flash_ProgrammerModuleId->Add( 'Motor Triple' );
    }elsif( $boardname =~ /Motor/ ){
      $f_Tab{flash}->flash_ProgrammerModuleId->Add( 'Motor Pitch' );
      $f_Tab{flash}->flash_ProgrammerModuleId->Add( 'Motor Roll' );
      $f_Tab{flash}->flash_ProgrammerModuleId->Add( 'Motor Yaw' );
    }elsif( $boardname =~ /Logger/ ){
      $f_Tab{flash}->flash_ProgrammerModuleId->Add( 'Logger' );
    }
    $f_Tab{flash}->flash_ProgrammerModuleId->Select(0);
  }
  $f_Tab{flash}->flash_FullErase_check->Checked(0);
  $f_Tab{flash}->flash_Verify_check->Checked(1);
  SetProgrammer();
  return 1;
}


#this is called by a board change
# handles all changes required in the programmer section

sub SetProgrammer{
  my $pstr = $f_Tab{flash}->flash_Programmer->GetString( $f_Tab{flash}->flash_Programmer->GetCurSel() );
  my ($boardtype) = GetBoardTypeAndName();
  if( $boardtype == $BOARDTYPE_IS_NTMODULE ){ #this is a NT module
    $NtProgrammer = $pstr;
  }elsif( $boardtype == $BOARDTYPE_IS_STORM32_V3X ){ #this is a v3.x or v4.x board
    $Storm32ProgrammerV3X = $pstr;
  }else{
    #good for v1.x, v2.x boards
    $Storm32Programmer = $pstr;
  }
  $f_Tab{flash}->flash_ProgrammerComPort_label->Hide();
  $f_Tab{flash}->flash_ProgrammerComPort->Hide();
  $f_Tab{flash}->flash_ProgrammerModuleId_label->Hide();
  $f_Tab{flash}->flash_ProgrammerModuleId->Hide();
  $f_Tab{flash}->flash_ProgrammerUsage_Storm32v3x_UpgradeViaUsb_label->Hide();
  $f_Tab{flash}->flash_ProgrammerUsage_Storm32v1x_SysBootLoad_label->Hide();
  $f_Tab{flash}->flash_ProgrammerUsage_Storm32v2x_SysBootLoad_label->Hide();
  $f_Tab{flash}->flash_ProgrammerUsage_Storm32v3x_SysBootLoad_label->Hide();
  $f_Tab{flash}->flash_ProgrammerUsage_NtUpgradeViaStorm32Usb_label->Hide();
  $f_Tab{flash}->flash_ProgrammerUsage_NtUpgradeViaSysBootLoad_label->Hide();
  $f_Tab{flash}->flash_ProgrammerUsage_NtFlashViaStorm32Usb_label->Hide();
  $f_Tab{flash}->flash_ProgrammerUsage_NtSysBootLoad_label->Hide();
  if( $pstr eq $SystemBootloader ){
    if( $boardtype == $BOARDTYPE_IS_NTMODULE ){ #this is a NT module
      $f_Tab{flash}->flash_ProgrammerComPort_label->Show(); #COM is needed for all boards and NT modules, NOT v3.x
      $f_Tab{flash}->flash_ProgrammerComPort->Show();
      $f_Tab{flash}->flash_ProgrammerUsage_NtSysBootLoad_label->Show(); #THIS IS IT

    }elsif( $boardtype == $BOARDTYPE_IS_STORM32_V3X ){ #this is a v3.x or v4.x board
      $f_Tab{flash}->flash_ProgrammerUsage_Storm32v3x_SysBootLoad_label->Show(); #THIS IS IT

    }else{
      $f_Tab{flash}->flash_ProgrammerComPort_label->Show(); #COM is needed for all boards and NT modules, NOT v3.x
      $f_Tab{flash}->flash_ProgrammerComPort->Show();
      $f_Tab{flash}->flash_ProgrammerUsage_Storm32v1x_SysBootLoad_label->Show(); #THIS IS IT
    }

  }elsif( ($boardtype == $BOARDTYPE_IS_STORM32_V3X) and ($pstr eq $Storm32UpgradeViaUSB) ){
    $f_Tab{flash}->flash_ProgrammerUsage_Storm32v3x_UpgradeViaUsb_label->Show(); #THIS IS IT

  }elsif( ($boardtype == $BOARDTYPE_IS_NTMODULE) and ($pstr eq $NtUpgradeViaSystemBootloader) ){
    $f_Tab{flash}->flash_ProgrammerComPort_label->Show();
    $f_Tab{flash}->flash_ProgrammerComPort->Show();
    $f_Tab{flash}->flash_ProgrammerUsage_NtUpgradeViaSysBootLoad_label->Show(); #THIS IS IT

  }elsif( ($boardtype == $BOARDTYPE_IS_NTMODULE) and ($pstr eq $NtUpgradeViaUSB) ){
    $f_Tab{flash}->flash_ProgrammerModuleId_label->Show();
    $f_Tab{flash}->flash_ProgrammerModuleId->Show();
    $f_Tab{flash}->flash_ProgrammerUsage_NtUpgradeViaStorm32Usb_label->Show(); #THIS IS IT

  }elsif( ($boardtype == $BOARDTYPE_IS_NTMODULE) and ($pstr eq $NtFlashViaUSB) ){
    $f_Tab{flash}->flash_ProgrammerUsage_NtFlashViaStorm32Usb_label->Show(); #THIS IS IT

  }else{ #this is SWD
  }
  SetRemoveProtections();
  return 1;
}

#this is called by a full erase change
# handles changes required in the remove protections section
sub RemoveProtectionsUnCheck{
  $f_Tab{flash}->flash_RemoveProtections_check->Checked(0);
  $f_Tab{flash}->flash_RemoveProtections_label->Hide();
  $f_Tab{flash}->flash_RemoveProtections_check->Hide();
}

sub SetRemoveProtections{
  my $pstr= $f_Tab{flash}->flash_Programmer->GetString( $f_Tab{flash}->flash_Programmer->GetCurSel() );
  if(( $f_Tab{flash}->flash_FullErase_check->GetCheck() )and
     ( ($pstr eq $SystemBootloader) or ($pstr eq $NtUpgradeViaSystemBootloader) )){
    $f_Tab{flash}->flash_RemoveProtections_check->Checked(0);
    $f_Tab{flash}->flash_RemoveProtections_label->Show();
    $f_Tab{flash}->flash_RemoveProtections_check->Show();
  }else{
    RemoveProtectionsUnCheck();
  }
}

SetBoard();
SetFirmwareHexFile();
SetProgrammer();
SetRemoveProtections();


#-----------------------------------------------------------------------------#
###############################################################################
### do Expert tab ###
###############################################################################
#-----------------------------------------------------------------------------#
$xpos= 20;
$ypos= 20;

sub AddFramesToExpertTab{
  $f_Tab{expert}->AddGroupbox( -name=> 'expert_Frame',
    -pos=> [10,-3], -size=> [520-175,333 -4],
  );
  $f_Tab{expert}->AddLabel( -name=> 'expert_FrameText', -font=> $StdWinFont,
    -text=> 'Please ensure that you know what you\'re doing when tweaking these parameters :)',
    -pos=> [20,260+36], -size=> [320,28+4 -4], -wrap=>1,
  );
}


#-----------------------------------------------------------------------------#
###############################################################################
### do Interfaces tab ###
###############################################################################
#-----------------------------------------------------------------------------#

# nothing to do


#-----------------------------------------------------------------------------#
###############################################################################
### do Servo tab ###
###############################################################################
#-----------------------------------------------------------------------------#

# nothing to do


#-----------------------------------------------------------------------------#
###############################################################################
### do GimbalModel tab ###
###############################################################################
#-----------------------------------------------------------------------------#
$xpos= 20;
$ypos= 20;

$f_Tab{gimbalmodel}->AddLabel( -name=> 'gimbalmodel_Text1', -font=> $StdWinFont,
#  -text=> 'Please ensure that you know what you\'re doing when tweaking these parameters :)',
#  -pos=> [20,260+36], -size=> [320,28+4], -wrap=>1,
  -text=> 'The Foc Pitch K, Foc Roll K, Foc Yaw K parameters in the PID tab are also part of the gimbal model.',
  -pos=> [20,20], -size=> [600,28+4], -wrap=>1,
);
$f_Tab{gimbalmodel}->AddLabel( -name=> 'gimbalmodel_Text2', -font=> $StdWinFont,
  -text=> 'Please ensure that you know what you\'re doing when tweaking these parameters :)',
  -pos=> [20,260+36], -size=> [600,28+4], -wrap=>1,
);


#-----------------------------------------------------------------------------#
###############################################################################
### do the Options ###
###############################################################################
#-----------------------------------------------------------------------------#

sub PopulateOptions{
  my @i; my @j; my $ex;
  for( $ex=0; $ex<$MaxSetupTabs; $ex++ ){ $i[$ex] = 0; $j[$ex] = 0; }
  %NameToOptionHash = ();
  foreach my $Option (@OptionList){
    $NameToOptionHash{$Option->{name}} = $Option; #store option with key name for easier reference
    my $label; my $textfield; my $setfield; my $min= $Option->{min}; my $max= $Option->{max};
    $ex = GetTabIndex($Option->{page});
    if( $ex >= $MaxSetupTabs ){ $ex = $MaxSetupTabs-1; }
    #set xpos, ypos
    if( defined $Option->{column} ){ $i[$ex] = $Option->{column}-1; $j[$ex] = 0; }
    if( defined $Option->{pos} ){ $i[$ex] = $Option->{pos}[0]-1; $j[$ex] = $Option->{pos}[1]-1; }
    my $xpos = 20 + $i[$ex]*$OPTIONSWIDTH_X;
    my $ypos = 10 + $j[$ex]*$OPTIONSWIDTH_Y;
    my $nr = $j[$ex] + $i[$ex]*$RowNumber;
    $j[$ex]++;
    my $tab_ptr = $SetupTabList[$ex];
    # create label
    my $labelname = $Option->{name}.' '.$Option->{comment};
    $label = $f_Tab{$tab_ptr}->AddLabel(-name=> 'OptionField'.$nr.'_label', -font=> $StdWinFont,
      -text=> $labelname, -pos=> [$xpos,$ypos-1], -size=> [160,15],
      #-background =>[10,10,10],
    );
    if( $Option->{hidden} ){ $label->Hide(); } #required for scripts
    #set textfield and setfield
    switch( $Option->{type} ){
      #set readonly textfield
      case ['STR+READONLY','UINT+READONLY','INT+READONLY','UINT8+READONLY','INT8+READONLY'] {
        $textfield = $f_Tab{$tab_ptr}->AddTextfield(-name=> 'OptionField'.$nr.'_readonly', -font=> $StdWinFont,
          -pos=> [$xpos,$ypos+13], -size=> [120,23],
          -readonly => 1, -align => 'center',  -background => $OptionInvalidColor,
        );
        $setfield= undef;
      }
      #set textfield
      case ['STR'] {
        $textfield = $f_Tab{$tab_ptr}->AddTextfield( -name=> 'OptionField'.$nr.'_str', -font=> $StdWinFont,
          -pos=> [$xpos,$ypos+13], -size=> [120,23],
          -background => $OptionInvalidColor,
        );
        $setfield= undef;
      }
      #set textfield with up/down
      case 'LIST' {
        $textfield = $f_Tab{$tab_ptr}->AddTextfield( -name=> 'OptionField'.$nr.'_updown', -font=> $StdWinFont,
          -pos=> [$xpos,$ypos+13], -size=> [120,23],
          -readonly => 1, -align => 'center', -background => $OptionInvalidColor,
        );
        $setfield = $f_Tab{$tab_ptr}->AddUpDown( -name=> 'OptionField'.$nr.'_updownfield', -font=> $StdWinFont,
          -pos=> [$xpos+120,$ypos+13], -size=> [100,23],
          -autobuddy => 0, -arrowkeys => 1,
          -onScroll => sub{
            onScrollSetTextfield( $Option );
            if($OptionsLoaded){ $Option->{textfield}->Change( -background => $OptionModifiedColor ); }
            1;
          },
        );
        $setfield->SetRange( $min, $max );
      }
      #set bitmaskfield
      case ['BITMASK8','BITMASK16'] {
        $textfield = $f_Tab{$tab_ptr}->AddTextfield( -name=> 'OptionField'.$nr.'_button', -font=> $StdWinFont,
          -pos=> [$xpos,$ypos+13], -size=> [120,23],
          -readonly => 1, -align => 'center', -background => $OptionInvalidColor,
        );
        $setfield = $f_Tab{$tab_ptr}->AddButton( -name=> 'OptionField'.$nr.'_buttonfield', -font=> $StdWinFont,
          -text=> '...', -pos=> [$xpos+120,$ypos+13+1], -width=> 18, #-size=> [17,22],
          -onClick => sub{
            onClickSetBitmaskfield( $Option );
            if($OptionsLoaded){ $Option->{textfield}->Change( -background => $OptionModifiedColor ); }
            1;
          },
        );
      }
      #set textfield with slider
      case ['UINT','INT','UINT8','INT8'] {
        $textfield = $f_Tab{$tab_ptr}->AddTextfield( -name=> 'OptionField'.$nr.'_slider', -font=> $StdWinFont,
          -pos=> [$xpos,$ypos+13], -size=> [60,23],
          -readonly => 1, -align => 'center', -background => $OptionInvalidColor,
        );
        $setfield = $f_Tab{$tab_ptr}->AddTrackbar( -name=> 'OptionField'.$nr.'_sliderfield', -font=> $StdWinFont,
          -pos=> [$xpos+60,$ypos+13], -size=> [90,23], #[100,23],
          -aligntop => 1, -autoticks => 0,
          -onScroll => sub{
            onScrollSetTextfield( $Option );
            if($OptionsLoaded){ $Option->{textfield}->Change( -background => $OptionModifiedColor ); }
            1;
          },
        );
        $setfield->SetLineSize( 1 );
        $setfield->SetPageSize( 1 );
        $setfield->SetRange( $min, $max );
        $min = $min/$Option->{steps};
        $max = $max/$Option->{steps};
        $setfield->SetRange( $min, $max );
        for(my $i= 1; $i<4; $i++){ $setfield->SetTic( 0.25*( ($max-$min)*$i )+ $min ); }
      }
###SCRIPT
      case ['SCRIPT'] { #the SCRIPT textfield holds the complete script code in hexstr format
        $textfield = undef;
        $setfield = undef;
        for(my $script_nr=1;$script_nr<=4;$script_nr++){
          $Option->{'textfield_script'.$script_nr} = Script_CreateTextFields($script_nr);
          $Option->{'textfield_script'.$script_nr}->Show();
        }
      }
    }
    $Option->{label}= $label;
    $Option->{textfield}= $textfield;
    $Option->{setfield}= $setfield;
    SetOptionField( $Option, $Option->{default} );
  }

  AddFramesToExpertTab();
}


sub ConvertOptionToStr{
  my $Option = shift; my $value = shift;
  my $ppos = $Option->{ppos};
  if( $ppos < 0 ){
    for(my $i=0; $i<-$ppos; $i++){ $value = $value*10.0; }
    $ppos = 0;
  }else{
    for(my $i=0; $i<$ppos; $i++){ $value = $value*0.1; }
  }
  return sprintf( "%.".$ppos."f", $value );
}

sub ConvertOptionToStrWUnit{
  my $Option = shift; my $value = shift;
  return ConvertOptionToStr($Option, $value)." ".$Option->{unit};
}

sub onScrollSetTextfield{
  my $Option = shift;
  switch( $Option->{type} ){
    case 'LIST' {
      $Option->{textfield}->Text( $Option->{choices}[$Option->{setfield}->GetPos()-65536] );
    }
    case ['UINT','INT','UINT8','INT8', ] {
      $Option->{textfield}->Text( ConvertOptionToStrWUnit($Option,$Option->{setfield}->GetPos()*$Option->{steps}) );
    }
  }
  if( $Option->{name} =~ /^Pitch [PID]$/ ){ SetIMCCalculator('Pitch'); SetAutoWritePID($Option->{name}); }
  elsif( $Option->{name} =~ /^Roll [PID]$/ ){ SetIMCCalculator('Roll'); SetAutoWritePID($Option->{name}); }
  elsif( $Option->{name} =~ /^Yaw [PID]$/ ){ SetIMCCalculator('Yaw'); SetAutoWritePID($Option->{name}); }
  elsif( $Option->{name} =~ /Motor Vmax$/ ){ SetAutoWritePID($Option->{name}); }
  elsif( $Option->{name} =~ 'Gyro LPF' ){ SetAutoWritePID($Option->{name}); }
  elsif( $Option->{name} =~ 'Imu2 FeedForward LPF' ){ SetAutoWritePID($Option->{name}); }
  elsif( $Option->{name} =~ /^Foc Pitch [PID]$/ ){ SetAutoWritePID($Option->{name}); }
  elsif( $Option->{name} =~ /^Foc Roll [PID]$/ ){ SetAutoWritePID($Option->{name}); }
  elsif( $Option->{name} =~ /^Foc Yaw [PID]$/ ){ SetAutoWritePID($Option->{name}); }
  elsif( $Option->{name} =~ /^Foc \w+ K$/ ){ SetAutoWritePID($Option->{name}); }
  elsif( $Option->{name} =~ 'Foc Gyro LPF' ){ SetAutoWritePID($Option->{name}); }
  elsif( $Option->{name} =~ /^Servo Pitch [PID]$/ ){ SetAutoWritePID($Option->{name}); }
  elsif( $Option->{name} =~ /^Servo Roll [PID]$/ ){ SetAutoWritePID($Option->{name}); }
  elsif( $Option->{name} =~ /^Servo Yaw [PID]$/ ){ SetAutoWritePID($Option->{name}); }
  elsif( $Option->{name} =~ /^Servo \w+ DLPF$/ ){ SetAutoWritePID($Option->{name}); }
  elsif( $Option->{name} eq 'Pan Mode Control' ){ SetPanModeSetting($Option->{textfield}->Text()); }
##  elsif( $Option->{name} eq 'IR Camera Control' ){ SetIRCameraSetting($Option->{textfield}->Text()); }
  elsif( $Option->{name} eq 'Pwm Out Control' ){ SetPwmOutSetting($Option->{textfield}->Text()); }
  elsif( $Option->{name} eq 'Script1 Control' ){ SetScriptTextField(1,$Option->{textfield}->Text()); }
  elsif( $Option->{name} eq 'Script2 Control' ){ SetScriptTextField(2,$Option->{textfield}->Text()); }
  elsif( $Option->{name} eq 'Script3 Control' ){ SetScriptTextField(3,$Option->{textfield}->Text()); }
  elsif( $Option->{name} eq 'Script4 Control' ){ SetScriptTextField(4,$Option->{textfield}->Text()); }
  elsif( $Option->{name} =~ 'Imu Orientation' ){ SetImuOrientationIndicator('Imu');  }
  elsif( $Option->{name} =~ 'Imu2 Orientation' ){ SetImuOrientationIndicator('Imu2');  }
  elsif( $Option->{name} eq 'Camera Control' ){ SetCameraSetting(); }
  elsif( $Option->{name} eq 'Camera Control2' ){ SetCameraSetting(); }
  elsif( $Option->{name} eq 'Mavlink Camera' ){ SetCameraSetting(); }
}

sub ConvertOptionBitmaskFromValue{
  my $Option = shift; my $value = shift;
  my $maxvalue = 0;
  my $bitpos = 0;
  my $bitsset = 0;
  my $bitname = '';
  foreach my $bit (@{$Option->{bits}}){
    if( $bit ne '' ){ $maxvalue += (1 << $bitpos); }
    if( $value & (1 << $bitpos) ){ $bitsset++; $bitname = $bit; }
    $bitpos++;
  }
  if( $value == 0 ){
    $Option->{textfield}->Text( 'off' ); return;
  }elsif( $value >= $maxvalue ){
    $Option->{textfield}->Text( 'all' ); return;
  }elsif( $bitsset == 1 ){
    $Option->{textfield}->Text( lc($bitname) ); return;
  }
  if( defined $Option->{presets} ){
    my %presets = @{$Option->{presets}};
    foreach my $key (keys %presets){
      if( $value == $presets{$key} ){
        $Option->{textfield}->Text( lc($key) ); return;
      }
    }
  }
  my $text;
  if( $Option->{size} == 1 ){
    $text = '0x'.uc(UCharToHexstr($value));
  }else{
    $text = '0x'.uc(UIntToHexstr($value));
  }
  $Option->{textfield}->Text( $text );
}

sub ConvertOptionBitmaskToValue{
  my $Option = shift;
  my $text = $Option->{textfield}->Text();
  if( $text eq 'off' ){
    return 0;
  }
  if( $text eq 'all' ){
    my $maxvalue = 0;
    my $bitpos = 0;
    foreach my $bit (@{$Option->{bits}}){
      if( $bit ne '' ){ $maxvalue += (1 << $bitpos); }
      $bitpos++;
    }
    return $maxvalue;
  }
  if( defined $Option->{presets} ){
    my %presets = @{$Option->{presets}};
    foreach my $key (keys %presets){
      if( lc($text) eq lc($key) ){ return $presets{$key}; }
    }
  }
  my $bitpos = 0;
  foreach my $bit (@{$Option->{bits}}){
    if( lc($text) eq lc($bit) ){ return (1 << $bitpos); }
    $bitpos++;
  }
  my $hexstr = substr($text, 2);
  return HexstrToDez($hexstr);
}

sub onClickSetBitmaskfield{
  my $Option = shift;
  my $value = GetOptionField($Option);
  OptionBitmaskShow($Option, $value);
}

sub OptionBitmaskHandleCloseWithOk{
  my $Option = shift;
  my $value = shift;
  SetOptionField($Option, $value);
}


# if option = editable -> onScrollSetTextField
# if option = readonly -> ConvertOptionToStr
#this function takes a numerical value as an unsigned value, converting afterwards it if needed
sub SetOptionField{
  my $Option = shift; my $value = shift;
  switch( $Option->{type} ){
    case ['STR'] {
      $Option->{textfield}->Text( CleanLeftRightStr($value) );
    }
    case ['STR+READONLY'] {
      $Option->{textfield}->Text( $value );
    }
    case ['UINT+READONLY','UINT8+READONLY'] {
      $Option->{textfield}->Text( ConvertOptionToStrWUnit($Option,$value) );
    }
    case 'INT8+READONLY' {
      if( $value > 128-1 ){ $value = $value-256; }
      $Option->{textfield}->Text( ConvertOptionToStrWUnit($Option,$value) );
    }
    case 'INT+READONLY' {
      if( $value > 32768-1 ){ $value = $value-65536; }
      $Option->{textfield}->Text( ConvertOptionToStrWUnit($Option,$value) );
    }
    case ['BITMASK8', 'BITMASK16'] {
      ConvertOptionBitmaskFromValue($Option,$value);
    }
    case ['LIST'] {
      $Option->{setfield}->SetPos( $value );
      onScrollSetTextfield( $Option );
    }
    case ['UINT','UINT8'] {
      $Option->{setfield}->SetPos( $value/$Option->{steps} );
      onScrollSetTextfield( $Option );
    }
    case 'INT8' {
      if( $value > 128-1 ){ $value = $value-256; }
      $Option->{setfield}->SetPos( $value/$Option->{steps} );
      onScrollSetTextfield( $Option );
    }
    case 'INT' {
      if( $value > 32768-1 ){ $value = $value-65536; }
      $Option->{setfield}->SetPos( $value/$Option->{steps} );
      onScrollSetTextfield( $Option );
    }
###SCRIPT
    case 'SCRIPT' {
      #$Option->{textfield}->Text( $value );
      Script_SetScriptHexCode( $value );
      for(my $script_nr=1;$script_nr<=4;$script_nr++){
        $Option->{'textfield_script'.$script_nr}->Text( Script_ConvertToTextForSingleScript($script_nr) );
      }
    }
  }
}


#this function returns a numerical value as an unsigned value, converting it beforehand if needed
sub GetOptionField{
  my $Option = shift; my $signcorrect = shift; my $value;
  if( not defined  $signcorrect ){ $signcorrect = 1; }
  switch( $Option->{type} ){
    case ['STR']{
      $value = $Option->{textfield}->Text();
      $value = CleanLeftRightStr($value);
    }
    case ['STR+READONLY','UINT+READONLY','UINT8+READONLY']{
      $value = $Option->{textfield}->Text();
    }
    case 'INT8+READONLY' {
      $value = $Option->{textfield}->Text();
      if( $signcorrect ){ if( $value < 0 ){ $value = $value+256; }}
    }
    case 'INT+READONLY' {
      $value = $Option->{textfield}->Text();
      if( $signcorrect ){ if( $value < 0 ){ $value = $value+65536; } }
    }
    case 'LIST' {
      $value = $Option->{setfield}->GetPos()-65536;
    }
    case ['BITMASK8','BITMASK16']{
      $value = ConvertOptionBitmaskToValue($Option);
    }
    case ['UINT','UINT8']{
      $value = $Option->{setfield}->GetPos()*$Option->{steps};
    }
    case 'INT8' {
      $value = $Option->{setfield}->GetPos()*$Option->{steps};
      if( $signcorrect ){ if( $value < 0 ){ $value = $value+256; }}
    }
    case 'INT' {
      $value = $Option->{setfield}->GetPos()*$Option->{steps};
      if( $signcorrect ){ if( $value < 0 ){ $value = $value+65536; }}
    }
###SCRIPT
    case 'SCRIPT' {
      #$value = $Option->{textfield}->Text();
      $value = Script_GetScriptHexCode();
    }
  }
  return $value;
}


#$OptionValidColor
sub Option_SetBackground{
  my $Option = shift;
  my $BackgroundColor = shift;
  if( $Option->{type} ne 'SCRIPT' ){
    $Option->{textfield}->Change( -background => $BackgroundColor );
    $Option->{textfield}->InvalidateRect( 1 );
  }else{
    for(my $script_nr=1;$script_nr<=4;$script_nr++){
      $Option->{'textfield_script'.$script_nr}->Change( -background => $BackgroundColor );
      $Option->{'textfield_script'.$script_nr}->InvalidateRect( 1 );
    }
  }
}



#-----------------------------------------------------------------------------#
###############################################################################
### Support Routines to handle dashboard window stuff
###############################################################################
#-----------------------------------------------------------------------------#

#is called then dashboard tab is changed
#is also called in DefaultSettings, RetrieveSettings, Clear, Read operations
## is currently not needed!
sub SynchroniseConfigTabs{
}

#handles the enable/disable of the Pan Mode fields
sub SetPanModeSetting{
  my $text = shift;
  if( $AllFieldsAreReadyToUse != 1 ){ return; }
  if( $text =~ /off/ ){ #modes enabled: default disabled: #1,#2,#3
    $NameToOptionHash{ 'Pan Mode Setting #1' }->{textfield}->Disable();
    $NameToOptionHash{ 'Pan Mode Setting #2' }->{textfield}->Disable();
    $NameToOptionHash{ 'Pan Mode Setting #3' }->{textfield}->Disable();
  }elsif( (($text =~ /But/)or($text =~ /Aux-[012] /))and not($text =~ /step/) ){ #modes enabled: #1 disabled: #2
    $NameToOptionHash{ 'Pan Mode Setting #1' }->{textfield}->Enable();
    $NameToOptionHash{ 'Pan Mode Setting #2' }->{textfield}->Disable();
    $NameToOptionHash{ 'Pan Mode Setting #3' }->{textfield}->Disable();
  }else{ #modes enabled: default,#1,#2,#3
    $NameToOptionHash{ 'Pan Mode Setting #1' }->{textfield}->Enable();
    $NameToOptionHash{ 'Pan Mode Setting #2' }->{textfield}->Enable();
    $NameToOptionHash{ 'Pan Mode Setting #3' }->{textfield}->Enable();
  }
}

#handles the enable/disable of the Ir Camera fields
# let 'Camera Model' be enabled all time, as it can be relevant for IR and Mavlink
sub SetCameraSetting{
  if( $AllFieldsAreReadyToUse != 1 ){ return; }
  if( ($NameToOptionHash{'Camera Control'}->{textfield}->Text() eq 'off') and
      ($NameToOptionHash{'Camera Control2'}->{textfield}->Text() eq 'off') ){

    if( ($NameToOptionHash{'Mavlink Camera'}->{textfield}->Text() eq 'off') ){
      #$NameToOptionHash{ 'Camera Model' }->{textfield}->Disable();
      $NameToOptionHash{ 'Camera ComPort' }->{textfield}->Disable();
    }else{
      #$NameToOptionHash{ 'Camera Model' }->{textfield}->Enable();
      $NameToOptionHash{ 'Camera ComPort' }->{textfield}->Enable();
    }
    $NameToOptionHash{ 'Camera Control Mode' }->{textfield}->Disable();
    $NameToOptionHash{ 'Camera Time Interval' }->{textfield}->Disable();
  }else{
    #$NameToOptionHash{ 'Camera Model' }->{textfield}->Enable();
    $NameToOptionHash{ 'Camera Control Mode' }->{textfield}->Enable();
    $NameToOptionHash{ 'Camera Time Interval' }->{textfield}->Enable();
    $NameToOptionHash{ 'Camera ComPort' }->{textfield}->Enable();
  }
}

#handles the enable/disable of the Pwm Out fields
sub SetPwmOutSetting{
  my $text = shift;
  if( $AllFieldsAreReadyToUse != 1 ){ return; }
  if( $text =~ /off/ ){ #modes enabled: none  disabled: #1,#2
    $NameToOptionHash{ 'Pwm Out Mid' }->{textfield}->Disable();
    $NameToOptionHash{ 'Pwm Out Min' }->{textfield}->Disable();
    $NameToOptionHash{ 'Pwm Out Max' }->{textfield}->Disable();
    $NameToOptionHash{ 'Pwm Out Speed Limit' }->{textfield}->Disable();
##    $NameToOptionHash{ 'Pwm Out Acc Limit' }->{textfield}->Disable();
  }else{ #modes enabled: #1,#2
    $NameToOptionHash{ 'Pwm Out Mid' }->{textfield}->Enable();
    $NameToOptionHash{ 'Pwm Out Min' }->{textfield}->Enable();
    $NameToOptionHash{ 'Pwm Out Max' }->{textfield}->Enable();
    $NameToOptionHash{ 'Pwm Out Speed Limit' }->{textfield}->Enable();
##    $NameToOptionHash{ 'Pwm Out Acc Limit' }->{textfield}->Enable();
  }
}

#handles the enable/disable of the Script Text fields
sub SetScriptTextField{
  my $nr = shift;
  my $text = shift;
  if( not defined $NameToOptionHash{ 'Scripts' } ){ return; }
  if( $text =~ /off/ ){ #modes enabled: none  disabled: #1,#2
    $NameToOptionHash{ 'Scripts' }->{'textfield_script'.$nr}->Disable();
  }else{ #modes enabled:
    $NameToOptionHash{ 'Scripts' }->{'textfield_script'.$nr}->Enable();
  }
}

#handles the enable/disable of the Pan Mode fields
sub SetImuOrientationIndicator{
  my $s = shift;
  if( not defined $NameToOptionHash{$s.' Orientation'} ){ return; }
  my $Option; my $imux;
  $Option= $NameToOptionHash{$s.' Orientation'};
  if( $f_Tab{gimbalconfig}->gimbalconfig_ImuNumber->GetCurSel() == 1 ){ #Imu2 selected
    if( $s ne 'Imu2' ){ return 0; }
    $Option= $NameToOptionHash{'Imu2 Orientation'}; $imux= '2';
  }else{
    if( $s ne 'Imu' ){ return 0; }
    $Option= $NameToOptionHash{'Imu Orientation'}; $imux= '';
  }
  my $no = GetOptionField( $Option );
  UpdateZXAxisFields( $no, $imux );
}


sub PrepareTextForAppend{
  my $s = shift;
  $s =~ s/\r//g; # remove all \r
  $s =~ s/\n/\r\n/g; # replace all \n by \r\n
  return $s;
}


sub TextOut{
  if( $w_Main->m_RecieveText->GetLineCount() > 1000 ){
    my $t = $w_Main->m_RecieveText->Text();
    my $l = length($t);
    my $pos = $l/2;
    while( substr($t,$pos,1) ne "\n" ){ $pos++; }
    $t = substr( $t, $pos, $l );
    $w_Main->m_RecieveText->Clear();
    $w_Main->m_RecieveText->Text( $t );
  }
  $w_Main->m_RecieveText->Append( PrepareTextForAppend(shift) );
}


sub TextOut_{
  TextOut( shift );
}

sub WaitForJobDone{
#  my $s= $w_Main->m_RecieveText->GetLine(0); #this helps to avoid the next cmd to be executed too early
}

#sub SyncWindowsEvents{
#  Win32::GUI::DoEvents() >= 0 or die "BLHeliTool closed during processing";
#}

my $DoFirstReadOut = 1;
sub SetDoFirstReadOut{ $DoFirstReadOut = shift; }


sub SetOptionsLoaded{
  if( shift==0 ){
    $OptionsLoaded = 0;
    #$w_Main->m_DataDisplay->Disable();
    $w_Main->m_Write->Disable();
    if( $DoFirstReadOut ){ TextOut( "\r\n".'Please do first a read to get controller settings!'."\r\n" ); }
    foreach my $Option (@OptionList){ Option_SetBackground($Option,$OptionInvalidColor); }
    CalibrateTabEnable(0);
  }else{
    $OptionsLoaded = 1;
    #$w_Main->m_DataDisplay->Enable();
    $w_Main->m_Write->Enable();
    foreach my $Option (@OptionList){ Option_SetBackground($Option,$OptionValidColor); }
    CalibrateTabEnable(1);
  }
  $DoFirstReadOut = 1;
  AutoWritePID_Clear();
}


#is used in Clear and Flash events, do not confuse with ClearOptionsList();
sub ClearOptions{
  my $flag= shift;
  if( $flag==1 ){ $w_Main->m_RecieveText->Text(''); }
  foreach my $Option (@OptionList){ SetOptionField( $Option, $Option->{default} ); }
  SetOptionsLoaded(0);
}


sub MainBoardConfiguration_ParamsFoc{
  foreach my $Option (@OptionList){
    $NameToOptionHash{$Option->{name}} = $Option; #store option with key name for easier reference
    if( $Option->{foc} == 1 ){ #foc hide
      if( defined $Option->{label} )    { $Option->{label}->Disable(); $Option->{label}->Hide(); }
      if( defined $Option->{textfield} ){ $Option->{textfield}->Disable(); $Option->{textfield}->Hide(); }
      if( defined $Option->{setfield} ) { $Option->{setfield}->Disable(); $Option->{setfield}->Hide(); }
    }
    if( $Option->{foc} == 2 ){ #foc show
      if( defined $Option->{label} )    { $Option->{label}->Enable(); $Option->{label}->Show(); }
      if( defined $Option->{textfield} ){ $Option->{textfield}->Enable(); $Option->{textfield}->Show(); }
      if( defined $Option->{setfield} ) { $Option->{setfield}->Enable(); $Option->{setfield}->Show(); }
    }
    if( $Option->{foc} == 3 ){ #foc disable
      if( defined $Option->{label} )    { $Option->{label}->Disable(); }
      if( defined $Option->{textfield} ){ $Option->{textfield}->Disable(); }
      if( defined $Option->{setfield} ) { $Option->{setfield}->Disable(); }
    }
    if( $Option->{foc} == 4 ){ #foc enable
      if( defined $Option->{label} )    { $Option->{label}->Enable(); }
      if( defined $Option->{textfield} ){ $Option->{textfield}->Enable(); }
      if( defined $Option->{setfield} ) { $Option->{setfield}->Enable(); }
    }
  }
}


sub MainBoardConfiguration_ParamsDefault{
  foreach my $Option (@OptionList){
    $NameToOptionHash{$Option->{name}} = $Option; #store option with key name for easier reference
    if( $Option->{foc} == 1 ){ #foc hide, default show
      if( defined $Option->{label} )    { $Option->{label}->Enable(); $Option->{label}->Show(); }
      if( defined $Option->{textfield} ){ $Option->{textfield}->Enable(); $Option->{textfield}->Show(); }
      if( defined $Option->{setfield} ) { $Option->{setfield}->Enable(); $Option->{setfield}->Show(); }
    }
    if( $Option->{foc} == 2 ){ #foc show, default hide
      if( defined $Option->{label} )    { $Option->{label}->Disable(); $Option->{label}->Hide(); }
      if( defined $Option->{textfield} ){ $Option->{textfield}->Disable(); $Option->{textfield}->Hide(); }
      if( defined $Option->{setfield} ) { $Option->{setfield}->Disable(); $Option->{setfield}->Hide(); }
    }
    if( $Option->{foc} == 3 ){ #foc disable, default enable
      if( defined $Option->{label} )    { $Option->{label}->Enable(); }
      if( defined $Option->{textfield} ){ $Option->{textfield}->Enable(); }
      if( defined $Option->{setfield} ) { $Option->{setfield}->Enable(); }
    }
    if( $Option->{foc} == 4 ){ #foc enable, default disable
      if( defined $Option->{label} )    { $Option->{label}->Disable(); }
      if( defined $Option->{textfield} ){ $Option->{textfield}->Disable(); }
      if( defined $Option->{setfield} ) { $Option->{setfield}->Disable(); }
    }
  }
}


sub Main_AdaptToBoardConfigurationFoc{
  my @Qfhgjsgfgs = split(/ /,$VersionStr);
  my $TitleVersionStr = $Qfhgjsgfgs[-1];
  $w_Main->Text( 'OlliW\'s '.$BGCStr.'Tool '.$TitleVersionStr.' for T-STorM32 (for encoders)' );
  $m_Menubar->{t_GetCurrentEncoderPositions}->Enabled(1);
  $m_Menubar->{t_ServoTool}->Enabled(1);
  $m_Menubar->{t_GimbalModelTool}->Enabled(1);

  $IMCCalculatorIsDisplayed = 1; #to make it fold
  ShowIMCCalculator_Click();
  $f_Tab{pid}->ShowIMCCalculator->Hide();

  $f_Tab{pid}->pid_ShowGimbalModelTool->Show();

  MainBoardConfiguration_ParamsFoc();
}


sub Main_AdaptToBoardConfigurationDefault{
  my @Qfhgjsgfgs = split(/ /,$VersionStr);
  my $TitleVersionStr = $Qfhgjsgfgs[-1];
  $w_Main->Text( 'OlliW\'s '.$BGCStr.'Tool '.$TitleVersionStr.' for STorM32-NT' );
  $m_Menubar->{t_GetCurrentEncoderPositions}->Enabled(0);
  $m_Menubar->{t_ServoTool}->Enabled(0);
  $m_Menubar->{t_GimbalModelTool}->Enabled(0);

  $f_Tab{pid}->ShowIMCCalculator->Show();

  $f_Tab{pid}->pid_ShowGimbalModelTool->Hide();

  MainBoardConfiguration_ParamsDefault();
}


sub BoardConfiguration_Set{
  if( $ActiveBoardConfiguration == $BOARDCONFIGURATION_IS_FOC ){
    Main_AdaptToBoardConfigurationFoc();
    DataDisplay_AdaptToBoardConfigurationFoc();
    ConfigureGimbal_AdaptToBoardConfigurationFoc();
  }else{
    Main_AdaptToBoardConfigurationDefault();
    DataDisplay_AdaptToBoardConfigurationDefault();
    ConfigureGimbal_AdaptToBoardConfigurationDefault();
  }
}


sub BoardConfiguration_HandleChange{
  my $NewBoardConfiguration = shift;
  if( $ActiveBoardConfiguration == $NewBoardConfiguration ){ return; } #no need to change
  $ActiveBoardConfiguration = $NewBoardConfiguration;
  BoardConfiguration_Set();
}


#==============================================================================
# do now what needs to be done for startup

$AllFieldsAreReadyToUse = 0; #this is to avoid calling undefined fields
SetOptionList(); #options were cleared if error
PopulateOptions(); #create the GUI parameter fields
AddIMCCalculatorToPIDTab();
$AllFieldsAreReadyToUse = 1;

$IMCCalculatorIsDisplayed = 1;
ShowIMCCalculator_Click(); #hide as default
BoardConfiguration_Set();

ClearOptions(1);


#==============================================================================
# Event Handler für Main Menu and Tools

sub m_About_Click{
#  $w_Main->MessageBox( "OlliW's Brushless Gimbal Controller Tool ".$BGCStr."Tool\n\n".
  $w_Main->MessageBox( "OlliW's Brushless Gimbal Controller\n\n".
  "(c) OlliW @ www.olliw.eu\n\n$VersionStr\n\n".
  'Project web page: http://www.olliw.eu/'."\n\n".
  'Wiki: http://www.olliw.eu/storm32bgc-wiki/'."\n\n".
  "TERMS of USAGE\n------------------------------------------------------------------------\n".
  "The ".$BGCStr."Tool Windows GUI is open source, and the ".$BGCStr." firmware is free. ".
  "You are explicitely granted the ".
  "permission to use the GUI and the firmwares for commercial purposes under the condition that (1) you don't ".
  "modify the softwares/firmwares, e.g. remove or change copyright ".
  "statements, (2) provide it for free, i.e. don't charge any explicit or ".
  "implicit fees, to your customers, and (3) correctly and clearly ".
  "cite the origin of the softwares/firmwares and the above ".
  "project web page in any product documentation or web page.\n\n"
#  ."ACKNOWLEDGEMENTS:\n".
#  "Special thanks go to hexakopter/Dario and wdaehn, for their endless hours of testing and many contributions.\n\n"
  ,
  'o323BGC About' );
  1;
}


sub m_UpdateNotes_Click{
#  $w_Main->MessageBox( "OlliW's Brushless Gimbal Controller Tool ".$BGCStr."Tool\n\n".
  $w_Main->MessageBox( "OlliW's Brushless Gimbal Controller\n\n".
  "(c) OlliW @ www.olliw.eu\n$VersionStr\n".
  'Project web page: http://www.olliw.eu/'."\n\n".
  'Wiki: http://www.olliw.eu/storm32bgc-wiki/'."\n\n".
  "UPDATE INSTRUCTIONS\n------------------------------------------------------------------------\n".
  $UpdateInstructionsStr."\n\n".
  "RELEASE NOTES\n------------------------------------------------------------------------\n".
  "For the release notes please go to the main STorM32 thread at rcgroups\n\n\n".
  "Comment: This message will not be displayed again at startup. You may call it anytime via the 'Update Instructions' menu."
  ,
  'o323BGC Update Notes' );
  1;
}

sub m_Help_Click{ ExecuteTool($HelpLink,''); 1; }

sub m_Window_Terminate{ -1; }

sub m_Window_Minimize{ DataDisplayMinimize(); 1; }

sub m_Window_Activate{ DataDisplayActivate(); 1; }
#sub m_Window_Activate{ DataDisplayMakeVisible(); $w_Main->SetForegroundWindow(); 1; }

# the "old" loader
sub m_LoadSettings_Click{
  my $file= Win32::GUI::GetOpenFileName( -owner=> $w_Main,
    -title=> 'Load Parameters from File',
    -nochangedir=> 1,
    -directory=> $SettingsFile_lastdir, #".\\",
    -defaultextension=> '.cfg',
    -filter=> ['*.cfg'=>'*.cfg','All files' => '*.*'],
    -pathmustexist=> 1,
    -filemustexist=> 1,
  );
  if( $file ){
    ImportSettings($file,0)
  }elsif( Win32::GUI::CommDlgExtendedError() ){ $w_Main->MessageBox("Some error occured, sorry",'ERROR'); }
  1;
}

# the "old" saver
sub m_SaveSettings_Click{
  my $file= Win32::GUI::GetSaveFileName( -owner=> $w_Main,
    -title=> 'Save Parameters to File',
    -nochangedir=> 1,
    -directory=> $SettingsFile_lastdir, #".\\",
    -defaultextension=> '.cfg',
    -filter=> ['*.cfg'=>'*.cfg','All files' => '*.*'],
    -pathmustexist=> 1,
    -overwriteprompt=> 1,
    -noreadonlyreturn => 1,
    -explorer=>0,
  );
  if( $file ){
    if( !open(F,">$file") ){ $w_Main->MessageBox("Some error occured, sorry",'ERROR'); return 1; }
    print F '%SettingsHashV2 = ('."\n";
    print F "  'LAYOUT' => ".$SupportedBGCLayoutVersion.",\n";
    foreach my $Option (@OptionList){
      if( OptionToSkip($Option) ){ next; }
      if( $Option->{type} eq 'SCRIPT' ){
        my $hex = GetOptionField($Option); $hex =~ s/FF+$/FF/;
        print F "  '".$Option->{name}."' => '".$hex."',\n";
      }else{
        print F "  '".$Option->{name}."' => [ ".GetOptionField($Option)." , '".
                                                $Option->{textfield}->Text()."' , ".$Option->{adr}." ],\n";
      }
    }
    print F ');'."\n";
    close(F);
  }elsif( Win32::GUI::CommDlgExtendedError() ){$w_Main->MessageBox("Some error occured, sorry",'ERROR');}
  1;
}

#the "new" importer
sub m_ImportSettings_Click{
  my $flag = 1;
  if( not ConnectionIsValid() ){
    if( $w_Main->MessageBox(
        "WARNING: No connection to board. Only parameters and scripts can be imported. ".
        "\n\nDo you want to continue?",
        'Import Settings from File' , 0x0034) == 6 )
    {
      $flag = 0;
    }else{ return 1; }
  }
  my $file= Win32::GUI::GetOpenFileName( -owner=> $w_Main,
    -title=> 'Import Settings from File',
    -nochangedir=> 1,
    -directory=> $SettingsFile_lastdir, #".\\",
    -defaultextension=> '.cfgx',
    -filter=> ['*.cfgx;*.cfg'=>'*.cfgx;*.cfg','*.cfgx'=>'*.cfgx','*.cfg'=>'*.cfg','All files' => '*.*'],
    -pathmustexist=> 1,
    -filemustexist=> 1,
  );
  if( $file ){
    ImportSettings($file, $flag)
  }elsif( Win32::GUI::CommDlgExtendedError() ){ $w_Main->MessageBox("Some error occured, sorry",'ERROR'); }
  1;
}

sub ImportSettings{
  my $file = shift;
  my $flag = shift;

  if( !open(F,"<$file") ){ $w_Main->MessageBox( "Some error occured, sorry",'ERROR'); return 1; }
  TextOut( "\r\n".'Load from File...'."\r\n" );
  my $s = ''; while(<F>){ $s.= $_; } close(F);
  my %SettingsHash = ();
  my %SettingsHashV2 = ();
  my $Script1 = 'e'; my $Script2 = 'e'; my $Script3 = 'e'; my $Script4 = 'e';
  my %CalibrationConstants = ();
  my %Imu1 = (); my %Imu2 = (); my %Imu3 = ();
  my %MotorPitch = (); my %MotorRoll = (); my %MotorYaw = ();
  my %Logger = ();
  eval "$s";
  if($@){
    %SettingsHash = ();
    %SettingsHashV2 = ();
    $Script1 = 'e'; $Script2 = 'e'; $Script3 = 'e'; $Script4 = 'e';
    %CalibrationConstants = ();
    %Imu1 = (); %Imu2 = (); %Imu3 = (); %MotorPitch = (); %MotorRoll = (); %MotorYaw = ();
    %Logger = ();
    TextOut( 'Load from File... FAILED! Parse error.'."\r\n" );
    return 1;
  }

  if( %SettingsHash ){
    if( $w_Main->MessageBox(
        "Import from File: ".$file."\n\n".
        "WARNING: The importer cannot check if the firmware version used to store the settings in the file ".
        "is compatible with your current firmware. You may go on with importing the parameter settings, and ".
        "the importer will try its best and often will succeed, but you should double-check the ".
        "parameter values.".
        "\n\nDo you want to import the parameter settings?",
        'Load from File: Parameter Settings' , 0x0034) == 6 )
    {
      TextOut( 'v1 settings hash'."\r\n" );
      TextOut( 'parameters... ' );
      my $count_all = 0;
      my $count_changed = 0;
      foreach my $Option (@OptionList){
        if( OptionToSkip($Option) ){ next; }
        if( $Option->{type} eq 'SCRIPT' ){ next; }
        $count_all++;
        if( defined $SettingsHash{$Option->{name}} ){
          SetOptionField( $Option, $SettingsHash{$Option->{name}}[0] );
          Option_SetBackground( $Option, $OptionModifiedColor );
          $count_changed++;
        }else{
          #SetOptionField( $Option, $Option->{default} );
        }
        #Option_SetBackground( $Option, $OptionModifiedColor );
      }
      TextOut( $count_changed.' of '.$count_all.' parameters were set'."\r\n" );
    }
    if( $w_Main->MessageBox(
        "Import from File: ".$file."\n\n".
        "WARNING: The importer cannot check if the firmware version used to store the scripts in the file ".
        "is compatible with your current firmware. If it was not compatible, then the ".
        "imported scripts may be corrupted. You should double-check them very carefully.".
        "\n\nDo you want to import the scripts?",
        'Load from File: Scripts' , 0x0034) == 6 )
    {
      TextOut( 'scripts... '."\r\n" );
      foreach my $Option (@OptionList){
        if( OptionToSkip($Option) ){ next; }
        if( $Option->{type} ne 'SCRIPT' ){ next; }
        if( defined $SettingsHash{$Option->{name}} ){
          SetOptionField( $Option, $SettingsHash{$Option->{name}}[0] );
          Option_SetBackground( $Option, $OptionModifiedColor );
        }
      }
    }
    TextOut( 'Load from File... DONE'."\r\n" );
    return 1;
  }

  my $report_query_eqadr = '';
  my $report_query_eqname = '';
  my $report_notset = '';
  my $ScriptHexCode = '';

  # we can compare name and adr!
  # => these cases
  # name == name && adr == adr    => OK
  # name == name && adr != adr    => incompatible !!
  # name != name && adr == adr    => do we want to carry over ???
  # name != name && adr != adr    => ignore
  if( %SettingsHashV2 ){
    #get layout
    my $layout = 0;
    if( defined $SettingsHashV2{'LAYOUT'} ){ $layout =  $SettingsHashV2{'LAYOUT'}; }
    my $ok = 6;
    if( uc($layout) ne uc($SupportedBGCLayoutVersion) ){
      $ok = $w_Main->MessageBox(
        "Import from File: ".$file."\n\n".
        "WARNING: The firmware version used to store the settings in the file is not compatible ".
        "with your current firmware. You may go on with importing the parameter settings, and the importer ".
        "will try its best and often will succeed, but you nevertheless should double-check the ".
        "parameter values.".
        "\n\nDo you want to continue?",
        'Load from File: Parameter Settings' , 0x0034); #MB_ICONEXCLAMATION + MB_YESNO
    }
    if( $ok == 6 ){
      $ok = $w_Main->MessageBox(
        "Import from File: ".$file."\n\nDo you want to import the parameter settings?",
        'Load from File: Parameter Settings' , 0x0024); #MB_ICONQUESTION + MB_YESNO
    }
    if( $ok == 6 ){
      TextOut( 'v2 settings hash'."\r\n" );
      TextOut( 'parameters... ' );
      my $count_all = 0;
      my $count_changed = 0;
      foreach my $Option (@OptionList){
        if( OptionToSkip($Option) ){ next; }
        if( $Option->{type} eq 'SCRIPT' ){ $ScriptHexCode = $SettingsHashV2{$Option->{name}}; next; }
        $count_all++;
        if( defined $SettingsHashV2{$Option->{name}} ){
          # option name is in file
          if( $SettingsHashV2{$Option->{name}}[2] == $Option->{adr} ){
            # name == name && adr == adr    => OK
            # TODO: now check also that selected option is ok
            SetOptionField( $Option, $SettingsHashV2{$Option->{name}}[0] );
            Option_SetBackground( $Option, $OptionModifiedColor );
            $count_changed++;
          }else{
            # name == name && adr != adr
            # same option name but new adr => we might carry it over
            $report_query_eqname .= $Option->{name}.';';
          }
        }else{
          # option name is not in file
          my $set_name = '';
          for my $key (keys %SettingsHashV2){
            if( $key eq 'LAYOUT' ){ next; }
            if( $key eq 'Scripts' ){ next; }
            print($key, $SettingsHashV2{$key}, '\n');
            if( $SettingsHashV2{$key}[2] == $Option->{adr} ){ $set_name = $key; last; }
          }
          if( $set_name eq $Option->{name} ){
            # name == name && adr == adr => this should never happen since covered before
            TextOut( "SOMETHING WENT DEEPLY WRONG. Sorry.\r\n" );
          }elsif( $set_name ne '' ){
            # name not in file && name != name && adr == adr
            # looks like option has been just renamed => we might carry it over
            $report_query_eqadr .= $set_name.",".$Option->{name}.';';
          }else{
            $report_notset .= $Option->{name}.';';
          }
        }
      }
      TextOut( $count_changed.' of '.$count_all.' parameters were set'."\r\n" );
      if( $report_query_eqname ne '' or $report_query_eqadr ne '' or $report_notset ne '' ){
        #TextOut( "  eq name:".$report_query_eqname."\r\n" );
        #TextOut( "  eq adr:".$report_query_eqadr."\r\n" );
        #TextOut( "  not:".$report_notset."\r\n" ); TextOut( "\r\n" );
        my $s = '';
        foreach my $ss (split(';', $report_query_eqname)){ $s .= '  - '.$ss."\r\n"; }
        foreach my $ss (split(';', $report_query_eqadr)){ my @xx = split(',',$ss); $s .= '  - '.$xx[1]."\r\n"; }
        foreach my $ss (split(';', $report_notset)){ $s .= '  - '.$ss."\r\n"; }
        $w_Main->MessageBox(
          "Import from File: ".$file."\n\n".
          "WARNING: Some parameters could not be set:\n".$s
        ,
        'Load from File: Parameter Settings' , 0x0040); #MB_ICONASTERISK + MB_OK
      }
    }
  }else{
    TextOut( 'parameters... skipped. None in file.'."\r\n" );
  }

  if( ($Script1 ne 'e') or ($Script2 ne 'e') or ($Script3 ne 'e') or ($Script4 ne 'e') ){
    if( $w_Main->MessageBox(
        "Import from File: ".$file."\n\nDo you want to import the scripts?",
        'Load from File: Scripts' , 0x0024) == 6 )
    {
      TextOut( "\r\n" );
      if( $Script1 ne 'e' ){ TextOut( 'script 1... ' ); ScriptAccept(1, $Script1); }
      if( $Script2 ne 'e' ){ TextOut( 'script 2... ' ); ScriptAccept(2, $Script2); }
      if( $Script3 ne 'e' ){ TextOut( 'script 3... ' ); ScriptAccept(3, $Script3); }
      if( $Script4 ne 'e' ){ TextOut( 'script 4... ' ); ScriptAccept(4, $Script4); }
    }
  }elsif( $w_Main->MessageBox(
        "Import from File: ".$file."\n\n".
        "WARNING: The firmware version used to store the scripts in the file is not compatible ".
        "with your current firmware. It is possible that the imported scripts are corrupted. ".
        "You should double-check them very carefully.".
        "\n\nDo you want to import the scripts?",
        'Load from File: Scripts' , 0x0024) == 6 )
  {
    TextOut( 'scripts... '."\r\n" );
    foreach my $Option (@OptionList){
      if( OptionToSkip($Option) ){ next; }
      if( $Option->{type} ne 'SCRIPT' ){ next; }
      if( defined $SettingsHash{$Option->{name}} ){
        SetOptionField( $Option, $SettingsHash{$Option->{name}}[0] );
        Option_SetBackground( $Option, $OptionModifiedColor );
      }
    }
  }else{
    TextOut( 'scripts... skipped. None in file.'."\r\n" );
  }

  if( $flag != 0 ){
    if( %CalibrationConstants ){
      if( $w_Main->MessageBox(
        "Import from File: ".$file."\n\nDo you want to import and store the calibration constants?".
        "\n\nNote: The calibration data is going to be rewriten permanently!",
        'Load from File: Calibration Constants' , 0x0024) == 6 )
      {
        TextOut( "\r\n" );
        TextOut( 'calibration constants... ' );
        #copy calibration constants
        CalibrateTabClearCalibration();
        my @CalibrationData = ();
        for(my $n=0; $n<18; $n++){ $CalibrationData[$n] = 0; } #this is to create an array with 18 fields
        for(my $n=0; $n<3; $n++){ $CalibrationData[$n+0] = $CalibrationConstants{'Acc1 Zero'}[$n]; }
        for(my $n=0; $n<3; $n++){ $CalibrationData[$n+3] = $CalibrationConstants{'Acc1 Scale'}[$n]; }
        if( exists $CalibrationConstants{'Gyro1 Zero'} ){
          for(my $n=0; $n<3; $n++){ $CalibrationData[$n+6] = $CalibrationConstants{'Gyro1 Zero'}[$n]; }
        }else{
          for(my $n=0; $n<3; $n++){ $CalibrationData[$n+6] = 0; };
        }
        for(my $n=0; $n<3; $n++){ $CalibrationData[$n+9] = $CalibrationConstants{'Acc2 Zero'}[$n]; }
        for(my $n=0; $n<3; $n++){ $CalibrationData[$n+12] = $CalibrationConstants{'Acc2 Scale'}[$n]; }
        if( exists $CalibrationConstants{'Gyro2 Zero'} ){
          for(my $n=0; $n<3; $n++){ $CalibrationData[$n+15] = $CalibrationConstants{'Gyro2 Zero'}[$n]; }
        }else{
          for(my $n=0; $n<3; $n++){ $CalibrationData[$n+15] = 0; }
        }
        my $CwData = pack( "v", '9' ); #7: store acc1 & acc2 * gyro1 & gyro2
        for(my $n=0;$n<18;$n++){ $CwData .= pack("v", $CalibrationData[$n]); }
        SetExtendedTimoutFirst(1000); #storing to Eerpom can take a while! so extend timeout
        ExecuteCommandWritewoGet( 'Cw', 'Write calibration data', '', $CwData, 1 );
      }
    }else{
      TextOut( 'calibration constants... skipped. None in file.'."\r\n" );
    }
  }

  TextOut( 'Load from File... DONE'."\r\n" );
}

# the "new" exporter
sub m_ExportSettings_Click{
  #check connection to board, is needed for the following
#  if( not ConnectionIsValid() ){ ConnectToBoard(); }
#  if( not ConnectionIsValid() ){ $w_Main->MessageBox("Connection to board failed!",'ERROR'); return 1; }
  if( not ConnectionIsValid() ){ $w_Main->MessageBox("No connection to board. Please connect first.",'ERROR'); return 1; }
  #get file name
  my $file= Win32::GUI::GetSaveFileName( -owner=> $w_Main,
    -title=> 'Export Settings to File',
    -nochangedir=> 1,
    -directory=> $SettingsFile_lastdir, #".\\",
    -defaultextension=> '.cfgx',
    -filter=> ['*.cfgx;*.cfg'=>'*.cfgx;*.cfg','*.cfgx'=>'*.cfgx','*.cfg'=>'*.cfg','All files' => '*.*'],
    -pathmustexist=> 1,
    -overwriteprompt=> 1,
    -noreadonlyreturn => 1,
    -explorer=>0,
  );
  if( $file ){
    if( !open(F,">$file") ){ $w_Main->MessageBox("Some error occured, sorry",'ERROR'); return 1; }
    TextOut( "\r\n".'Export to File...'."\r\n" );
    #parameters
    TextOut( 'settings and scripts... '."\r\n" );
    print F '#### Parameter Settings ####'."\n\n";
    print F '%SettingsHashV2 = ('."\n";
    print F "  'LAYOUT' => ".$SupportedBGCLayoutVersion.",\n";
    foreach my $Option (@OptionList){
      if( OptionToSkip($Option) ){ next; }
      if( $Option->{type} eq 'SCRIPT' ){
        my $hex = GetOptionField($Option); $hex =~ s/FF+$/FF/;
        print F "  '".$Option->{name}."' => '".$hex."',\n";
      }else{
        print F "  '".$Option->{name}."' => [ ".GetOptionField($Option)." , '".
                                                $Option->{textfield}->Text()."' , ".$Option->{adr}." ],\n";
      }
    }
    print F ');'."\n";
    #scripts
    print F "\n\n";
    print F '#### Scripts ####'."\n\n";
    for(my $script_nr = 1; $script_nr <= 4; $script_nr++){
      print F '$Script'.$script_nr.' ='."\n";
      my $code = Script_ConvertToTextForSingleScript($script_nr,'nopc');
      $code =~ s/\r//g; #remove \r
      print F "'".$code."';"."\n\n";
    }
    print F "\n";
    #calibration constants, on-board
    TextOut( 'calibration constants... '."\r\n" );
    print F '#### Calibration Constants ####'."\n\n";
    my $s = ExecuteCmd( 'Cr', 18*2 );
    if( substr($s,length($s)-1,1) ne 'o' ){
      TextOut( 'Export to File... ERROR'."\r\n" ); close(F);
      $w_Main->MessageBox("Some error occured, sorry",'ERROR'); return 0;
    }
    my @CrData = unpack( "v18", $s );
    for(my $n=0;$n<18;$n++){ if( $CrData[$n] > 32768-1 ){ $CrData[$n] -= 65536; } }
    print F '%CalibrationConstants = ('."\n";
    print F "  'Acc1 Zero' => [ ".$CrData[0]." , ".$CrData[1]." , ".$CrData[2]." ],\n";
    print F "  'Acc1 Scale' => [ ".$CrData[3]." , ".$CrData[4]." , ".$CrData[5]." ],\n";
    print F "  'Acc2 Zero' => [ ".$CrData[9]." , ".$CrData[10]." , ".$CrData[11]." ],\n";
    print F "  'Acc2 Scale' => [ ".$CrData[12]." , ".$CrData[13]." , ".$CrData[14]." ],\n";
    print F ');'."\n";
    print F "\n\n";
    #NT module settings
    TextOut( 'NT modules... '."\r\n" );
    print F '#### NT Modules ####'."\n\n";
    my %NtScanList = GetNtScanList();
    for my $id (sort keys %NtScanList){
      _delay_ms(20);
      my $s = ExecuteCmdwCrc( 'Ns', HexstrToStr($id), 35 );
      if( substr($s,length($s)-1,1) ne 'o' ){
        TextOut( 'Export to File... ERROR'."\r\n" ); close(F);
        $w_Main->MessageBox("Some error occured, sorry",'ERROR'); return 0;
      }
      my ($str,%res) = NtScanNsResultToStr($id, $s);
      if( $str eq '-' ){ next; }
      my $name = $NtScanList{$id}; $name =~ s/ //g;
      print F '%'.$name.' = ('."\n";
      for my $key (sort keys %res){
        print F "  '".$key."' => '".CleanLeftRightStr($res{$key})."',\n";
      }
      _delay_ms(20);
      $s = ExecuteCmdwCrc( 'Nc', HexstrToStr($id), 34 );
#TextOut('!'.$name.'!'.StrToHexstr($s)."!\r\n");
      if( substr($s,length($s)-1,1) ne 'o' ){
        TextOut( 'Export to File... ERROR'."\r\n" ); close(F);
        $w_Main->MessageBox("Some error occured, sorry",'ERROR'); return 0;
      }
      if( substr($s,1,1) eq 'o' ){
        if( $name =~ /Imu/ ){
          #extract calibration data for imu structure
          my @NsImuData = unpack( "s9", substr($s,2,18) );
          for(my $n=0;$n<9;$n++){ if( $NsImuData[$n] > 32768-1 ){ $NsImuData[$n] -= 65536; } }
          print F "  'acc zero' => '[ ".$NsImuData[3]," , ".$NsImuData[4]." , ".$NsImuData[5]." ]',\n";
          print F "  'acc scale' => '[ ".$NsImuData[0]," , ".$NsImuData[1]." , ".$NsImuData[2]." ]',\n";
          print F "  'gyro zero' => '[ ".$NsImuData[6]," , ".$NsImuData[7]." , ".$NsImuData[8]." ]',\n";
        }
        if( $name =~ /Motor/ ){
          #extract calibration data for motor structure
          my @NsMotorData = unpack( "sl", substr($s,2,6) );
          if( $NsMotorData[0] > 32768-1 ){ $NsMotorData[0] -= 65536; }
          if( $NsMotorData[1] > 2147483648-1 ){ $NsMotorData[1] -= 4294967296; }
          print F "  'pole pairs' => ".$NsMotorData[0].",\n";
          print F "  'ofs' => ".$NsMotorData[1].",\n";
        }
        if( $name =~ /Logger/ ){
          #extract datetime data for logger structure
          my @NcLoggerData = unpack( "SCCCCC", substr($s,2,7) );
          print F "  'rtc date' => '[ ".$NcLoggerData[0]." , ".$NcLoggerData[1]." , ".$NcLoggerData[2]." ]',\n";
          print F "  'rtc time' => '[ ".$NcLoggerData[3]." , ".$NcLoggerData[4]." , ".$NcLoggerData[5]." ]',\n";
        }
      }
      print F ');'."\n\n";
    }
    close(F);
    TextOut( 'Export to File... DONE'."\r\n" );
  }elsif( Win32::GUI::CommDlgExtendedError() ){$w_Main->MessageBox("Some error occured, sorry",'ERROR');}
  1;
}

#sub m_Clear_Click{ ClearOptions(1); SynchroniseConfigTabs(); 1; }
sub m_Clear_Click{ DisconnectFromBoard(1); SynchroniseConfigTabs(); 1; }

sub m_Exit_Click{ -1; }

sub m_Connect_Click{
  if( $Execute_IsRunning ){ return 1; } #prevents double clicks
  $Execute_IsRunning = 1;
  if( $Connected ){
    DisconnectFromBoardByButton();
  }else{
    ConnectToBoardByButton();
    if( $Connected ){ ExecuteGetStatus(); }
  }
  $Execute_IsRunning = 0;
  1;
}

sub m_DataDisplay_Click{
  if( $Execute_IsRunning ){ return 1; } #prevents double clicks
  $Execute_IsRunning = 1;
  if( $Connected != 1 ){ ConnectToBoard(); SynchroniseConfigTabs(); }
  ShowDataDisplay();
  $Execute_IsRunning = 0;
  1;
}

sub m_Read_Click{
$w_Main->m_Read->Disable();
  if( $Execute_IsRunning ){ return 1; } #prevents double clicks
  $Execute_IsRunning = 1;
  if( $Connected == 1 ){ ExecuteRead(); }else{ ConnectToBoard(); } #the ConnectToBoard() does a read
  SynchroniseConfigTabs();
  $Execute_IsRunning = 0;
$w_Main->m_Read->Enable();
  1;
}

sub m_Write_Click{
$w_Main->m_Write->Disable();
  if( $Execute_IsRunning ){ return 1; } #prevents double clicks
  $Execute_IsRunning = 1;
  my $tabonly_flag = 0;
#  if( $w_Main->m_WriteCurrentTabOnly_check->GetCheck() ){ $tabonly_flag = 1; }
  if( $w_Main->m_WriteAndStore_check->GetCheck() ){
    ExecuteWrite(1, $tabonly_flag);
    $w_Main->m_WriteAndStore_check->Click();
  }else{
    ExecuteWrite(0, $tabonly_flag);
  }
  $Execute_IsRunning = 0;
  $w_Main->m_Write->Enable();
  1;
}

sub m_DefaultSettings_Click{
  if( $Execute_IsRunning ){ return 1; } #prevents double clicks
  $Execute_IsRunning = 1;
  ExecuteDefault(); #don't issue a restart, since it would overwrite things
  $Execute_IsRunning = 0;
  1;
}

#not used
sub m_StoreSettings_Click{
  if( $Execute_IsRunning ){ return 1; } #prevents double clicks
  $Execute_IsRunning = 1;
  ExecuteStoreToEeprom();
  $Execute_IsRunning = 0;
  1;
}

sub m_RetrieveSettings_Click{
  if( $Execute_IsRunning ){ return 1; } #prevents double clicks
  $Execute_IsRunning = 1;
  ExecuteRetrieveFromEeprom(); #don't issue a restart
  $Execute_IsRunning = 0;
  1;
}

sub t_EraseEeprom_Click{
  if( $Execute_IsRunning ){ return 1; }
  #double check and ask
  my $res = $w_Main->MessageBox(
      'Do you really want to do a full erase of the EEPROM?' ,
      'Erase EEPROM' , 0x0030 + 1 ); #0x0010 + 1 ); # MB_ICONHAND +  MB_OKCANCEL
  if( $res != 1 ){ TextOut( "\nErasing EEPROM... CANCELED!\n" ); return 1; }
  $Execute_IsRunning = 1;
  if( ExecuteEraseEeprom() ){ #issue a restart, to get current settings
    ExecuteRestartController();
  }
  $Execute_IsRunning = 0;
  1;
}

sub t_LevelGimbal_Click{
  if( $Execute_IsRunning ){ return 1; }
  $Execute_IsRunning = 1;
  ExecuteLevelGimbal();
  $Execute_IsRunning = 0;
  1;
}

sub t_GetCurrentEncoderPositions_Click{
  if( $Execute_IsRunning ){ return 1; }
  $Execute_IsRunning = 1;
  ExecuteGetCurrentEncoderPositions();
  $Execute_IsRunning = 0;
  1;
}

sub t_RestartController_Click{
  if( $Execute_IsRunning ){ return 1; }
  $Execute_IsRunning = 1;
  ExecuteRestartController();
  $Execute_IsRunning = 0;
  1;
}





#==============================================================================
# Event Handler für Flash tab

my $FirmwareHexFileDir_lastdir = $ExePath;
my $FirmwareHexFile_lastdir = $ExePath;

sub flash_HexFileDir_button_Click{
  my $file= Win32::GUI::BrowseForFolder( -owner=> $w_Main,
    -title=> 'Select Firmware File Directory',
    -directory=> $FirmwareHexFileDir_lastdir,
    -folderonly=> 1,
  );
  if( $file ){
    $FirmwareHexFileDir_lastdir= $file;
    $f_Tab{flash}->flash_HexFileDir->Text( RemoveBasePath($file) );
  }elsif( Win32::GUI::CommDlgExtendedError() ){ $w_Main->MessageBox("Some error occured, sorry",'ERROR'); }
  1;
}

sub flash_HexFile_button_Click{
  my $file= Win32::GUI::GetOpenFileName( -owner=> $w_Main,
    -title=> 'Load Firmware File',
    -nochangedir=> 1,
    -directory=> $FirmwareHexFile_lastdir,
    -defaultextension=> '.hex',
    -filter=> ['firmware files'=>'*.hex','*.bin','All files' => '*.*'],
    -pathmustexist=> 1,
    -filemustexist=> 1,
  );
  if( $file ){
    if( !open(F,"<$file") ){ $w_Main->MessageBox( "Some error occured, sorry",'ERROR'); return; }
    close( F );
    $FirmwareHexFile_lastdir= $file;
    $f_Tab{flash}->flash_HexFile->Text( RemoveBasePath($file) );
  }elsif( Win32::GUI::CommDlgExtendedError() ){ $w_Main->MessageBox("Some error occured, sorry",'ERROR'); }
  1;
}


my $NTBUS_IMU_CONFIG_MPU6050        = 15; #0x0001
my $NTBUS_IMU_CONFIG_MPU6000        = 14; #0x0002
my $NTBUS_IMU_CONFIG_MPU6500        = 15+14; #0x0003
my $NTBUS_IMU_CONFIG_MPU9250        = 13; #0x0004
my $NTBUS_IMU_CONFIG_ICM42605       = 15+13; #0x0005
my $NTBUS_IMU_CONFIG_ICM42688       = 14+13; #0x0006
#my $NTBUS_IMU_CONFIG_MODELUNKNOWN   = 16; #0x0000
#my $NTBUS_IMU_CONFIG_MODELMASK      = 16; #0x0007

my $NTBUS_IMU_CONFIG_OVERSAMPLED    = 11; #0x0010
my $NTBUS_IMU_CONFIG_FASTGYRO       = 10; #0x0020
my $NTBUS_IMU_CONFIG_FASTACC        =  9; #0x0040
my $NTBUS_IMU_CONFIG_GYROFILTER     =  8; #0x0080
my $NTBUS_IMU_CONFIG_ACCFILTER      =  7; #0x0100

my $NTBUS_MOTOR_CONFIG_TLE5012B     = 15; #0x0001
my $NTBUS_MOTOR_CONFIG_AS5048A      = 14; #0x0002
my $NTBUS_MOTOR_CONFIG_POTADC5      = 15+14; #0x0003
#my $NTBUS_MOTOR_CONFIG_ENCODERUNKNOWN = 16; #0x0000
#my $NTBUS_MOTOR_CONFIG_ENCODERMASK    = 16; #0x0007
my $NTBUS_MOTOR_CONFIG_FOC          =  3; #0x1000

sub NtModuleNameToId
{
  my $module = shift;
  my $id = ''; my $id_int = '';
  if(    uc($module) eq uc('Imu1') ){        $id = '01'; $id_int = '01'; }
  elsif( uc($module) eq uc('Imu2') ){        $id = '02'; $id_int = '02'; }
  elsif( uc($module) eq uc('Motor Pitch') ){ $id = '04'; $id_int = '04'; }
  elsif( uc($module) eq uc('Motor Roll') ){  $id = '05'; $id_int = '05'; }
  elsif( uc($module) eq uc('Motor Yaw') ){   $id = '06'; $id_int = '06'; }
  elsif( uc($module) eq uc('Logger') ){      $id = '0B'; $id_int = '11'; }
  elsif( uc($module) eq uc('Imu3') ){        $id = '0C'; $id_int = '12'; }
  elsif( uc($module) eq uc('Pitch') ){       $id = '04'; $id_int = '04'; }
  elsif( uc($module) eq uc('Roll') ){        $id = '05'; $id_int = '05'; }
  elsif( uc($module) eq uc('Yaw') ){         $id = '05'; $id_int = '05'; }

  elsif( uc($module) eq uc('Motor Triple') ){ $id = 'T'; $id_int = '04'; } #we use an alias for this one

  return ($id, $id_int);
}

sub NtModuleIdToType
{
  my $id = shift;
  if( ($id eq '01') or ($id eq '02') or ($id eq '0C') ){ return 'Imu'; }
  if( ($id eq '04') or ($id eq '05') or ($id eq '06') ){ return 'Motor'; }
  if( ($id eq '0B') ){ return 'Logger'; }

  if( ($id eq 'T') ){ return 'Motor Triple'; }

  return '';
}

sub NtModuleFindLatestFirmware
{
  my ($id,$id_int) = NtModuleNameToId(shift); #e.g. 'Imu1'
  return NtModuleFindLatestFirmwareFromId($id,shift);
}

sub NtModuleFindLatestFirmwareFromId
{
  my $id = shift; #e.g. '01'
  my $boardversion = shift; #e.g. 'v2.x F103T8             '
  $boardversion =~ s/ //g;
#XX  my $moduletype = 'NT '.substr(NtModuleIdToType($id),0,3);
  my $moduletype = 'NT '.NtModuleIdToType($id);
  foreach my $board (@STorM32BoardList){
#XX    if( uc(substr($board->{name},0,6)) eq uc($moduletype) ){
    if( uc(substr($board->{name},0,length($moduletype))) eq uc($moduletype) ){
      foreach my $v (@{$board->{boards}}){
        my $vv = $v; #use a copy, otherwise the entry in the @STorM32BoardList would be modified!?!?
        $vv =~ s/ //g;
        if( uc($vv) eq uc($boardversion) ){
          return $board->{versions}[0];
        }
      }
    }
  }
  return '';
}

my %NtScanList = ( '01' => 'Imu1', '02' => 'Imu2',
                   '04' => 'Motor Pitch', '05' => 'Motor Roll', '06' => 'Motor Yaw',
                   '0B' => 'Logger',
                   '0C' => 'Imu3',
                  );

sub GetNtScanList{ return %NtScanList; }

sub NtScanNsResultToStr{
  my $id = shift;
  my $s = shift;
  my $str = '';
  my %res = ();

  my $test = substr($s,1,34); $test =~ s/\0//g;
  if( length($test) == 0 ){
    $str = '-';
  }else{
    my $firmware = substr($s,1,16); $firmware =~ s/\0//g;
    my $board = substr($s,17,16);   $board =~ s/\0/ /g;
    my @data = unpack( "v", substr($s,33,2) );
    my $config = UIntToBitstr($data[0]);
    $res{'firmware'} = $firmware;
    $res{'board'} = $board;
    $res{'config'} = '0x'.UIntToHexstr($data[0]);
    $str = 'firmware: '.$firmware.'  board: '.$board.' ';
    if( ($id eq '01') or ($id eq '02') or ($id eq '0C') ){
      my $mputype = CheckStatus($config,15) + 2*CheckStatus($config,14) + 4*CheckStatus($config,13);
      if( $mputype == 1 )   { $str .= 'MPU6050 ';  $res{'mpu'} = 'MPU6050';  }
      elsif( $mputype == 2 ){ $str .= 'MPU6000 ';  $res{'mpu'} = 'MPU6000';  }
      elsif( $mputype == 4 ){ $str .= 'MPU9250 ';  $res{'mpu'} = 'MPU9250';  }
      elsif( $mputype == 5 ){ $str .= 'ICM42605 ';  $res{'mpu'} = 'ICM42605';  }
      elsif( $mputype == 6 ){ $str .= 'ICM42688 ';  $res{'mpu'} = 'ICM42688';  }
      else{ $str .= 'unknown ';  $res{'mpu'} = 'unknown';  }
      $res{'filter'} = '';
      if( CheckStatus($config,$NTBUS_IMU_CONFIG_OVERSAMPLED) ){ $str .= 'OVS '; $res{'filter'} .= 'OVERSAMPLED '; }
      if( CheckStatus($config,$NTBUS_IMU_CONFIG_FASTGYRO) ){ $str .= 'FG '; $res{'filter'} .= 'FASTGYRO '; }
      if( CheckStatus($config,$NTBUS_IMU_CONFIG_FASTACC) ){ $str .= 'FA '; $res{'filter'} .= 'FASTACC ';  }
      if( CheckStatus($config,$NTBUS_IMU_CONFIG_GYROFILTER) ){ $str .= 'GF '; $res{'filter'} .= 'GYROFILTER ';  }
      if( CheckStatus($config,$NTBUS_IMU_CONFIG_ACCFILTER) ){ $str .= 'AF '; $res{'filter'} .= 'ACCFILTER ';  }
    }
    if( ($id eq '04') or ($id eq '05') or ($id eq '06') ){
#      if( CheckStatus($config,$NTBUS_MOTOR_CONFIG_TLE5012B) and CheckStatus($config,$NTBUS_MOTOR_CONFIG_AS5048A) ){
#        $str .= 'POTADC5 '; $res{'encoder'} = 'POTADC5';
#      }elsif( CheckStatus($config,$NTBUS_MOTOR_CONFIG_TLE5012B) ){
#        $str .= 'TLE5012B '; $res{'encoder'} = 'TLE5012B';
#      }elsif( CheckStatus($config,$NTBUS_MOTOR_CONFIG_AS5048A) ){
#        $str .= 'AS5048A '; $res{'encoder'} = 'AS5048A';
#      }
      my $enctype = CheckStatus($config,15) + 2*CheckStatus($config,14) + 4*CheckStatus($config,13);
      if( $enctype == 1 )   { $str .= 'TLE5012B '; $res{'encoder'} = 'TLE5012B'; }
      elsif( $enctype == 2 ){ $str .= 'AS5048A ';  $res{'encoder'} = 'AS5048A';  }
      elsif( $enctype == 3 ){ $str .= 'POTADC5 ';  $res{'encoder'} = 'POTADC5';  }
    }
  }
  return ($str,%res);
}


sub flash_ScanNtBus_button_Click{
  TextOut( "\nScan NT bus... " );
  if( not ConnectionIsValid() ){
    if( not OpenPort() ){ ClosePort(); TextOut( "\n".'Scan NT bus... ABORTED!'."\n" ); goto EXIT; }
    ClosePort(); #close it again
    ConnectToBoardwoRead();
  }
  my $modulestoupgradecnt = 0;
  my $modulestoupgradestr = ''; #list of moulde names, e.g., Imu1, Imu2 ...
  my @modulestoupgrade = (); #detailed list of all infoo for each module
  for my $id (sort keys %NtScanList){
    _delay_ms(20);
    TextOut_( "\n".'  '.TrimStrToLength($NtScanList{$id},13) );
    my $s = ExecuteCmdwCrc( 'Ns', HexstrToStr($id), 35 );
    if( substr($s,length($s)-1,1) ne 'o' ){
      TextOut( "\n".'Scan NT bus... FAILED!'."\n" ); goto EXIT;
    }
#    my $test = substr($s,1,34); $test =~ s/\0//g;
#    if( length($test) == 0 ){
#      TextOut_( '-' );
#    }else{
#      my $firmware = substr($s,1,16); $firmware =~ s/\0//g; #$firmware =~ s/\0/ /g; #are in format vX.XX
#      my $board = substr($s,17,16);   $board =~ s/\0/ /g;
#      my @data = unpack( "v", substr($s,33,2) );
#      my $config = UIntToBitstr($data[0]);
#      #my $latestfirmware = NtModuleFindLatestFirmwareFromId($id,$board);
#      TextOut_( 'firmware: '.$firmware.'  board: '.$board.' ' ); #.'  (latest firmw.: '.$latestfirmware.')' );
#      if( ($id eq '01') or ($id eq '02') or ($id eq '0C') ){
#        #this is dirty, detects a icm20602
#        if( CheckStatus($config,$NTBUS_IMU_CONFIG_MPU6050) and CheckStatus($config,$NTBUS_IMU_CONFIG_MPU6000) ){
#          TextOut_('ICM20602 ');
#        }elsif( CheckStatus($config,$NTBUS_IMU_CONFIG_MPU6050) ){
#          TextOut_('MPU6050 ');
#        }elsif( CheckStatus($config,$NTBUS_IMU_CONFIG_MPU6000) ){
#          TextOut_('MPU6000 ');
#        }elsif( CheckStatus($config,$NTBUS_IMU_CONFIG_MPU9250) ){
#          TextOut_('MPU9250 ');
#        }
#        if( CheckStatus($config,$NTBUS_IMU_CONFIG_OVERSAMPLED) ){ TextOut_('OVS '); }
#        if( CheckStatus($config,$NTBUS_IMU_CONFIG_FASTGYRO) ){ TextOut_('FG '); }
#        if( CheckStatus($config,$NTBUS_IMU_CONFIG_FASTACC) ){ TextOut_('FA '); }
#        if( CheckStatus($config,$NTBUS_IMU_CONFIG_GYROFILTER) ){ TextOut_('GF '); }
#        if( CheckStatus($config,$NTBUS_IMU_CONFIG_ACCFILTER) ){ TextOut_('AF '); }
#      }
#      if( ($id eq '04') or ($id eq '05') or ($id eq '06') ){
#        if( CheckStatus($config,$NTBUS_MOTOR_CONFIG_TLE5012B) and CheckStatus($config,$NTBUS_MOTOR_CONFIG_AS5048A) ){
#          TextOut_('POTADC5 ');
#        }elsif( CheckStatus($config,$NTBUS_MOTOR_CONFIG_TLE5012B) ){
#          TextOut_('TLE5012B ');
#        }elsif( CheckStatus($config,$NTBUS_MOTOR_CONFIG_AS5048A) ){
#          TextOut_('AS5048A ');
#        }
#      }
#      $firmware =~ s/ //g;
#      my $latestfirmware = NtModuleFindLatestFirmwareFromId($id,$board);
#      my %modulehash = ();
#      $modulehash{'name'} = $NtScanList{$id};
#      $modulehash{'curversion'} = $firmware;
#      $modulehash{'latestversion'} = $latestfirmware;
#      $modulehash{'uptodate'} = 0; if( uc($firmware) ge uc($latestfirmware) ){ $modulehash{'uptodate'} = 1; }
#      push(@modulestoupgrade, \%modulehash); #push reference to hash
#      if( uc($firmware) ge uc($latestfirmware) ){
#      }else{
#        $modulestoupgradestr .= $NtScanList{$id}.', ';
#        $modulestoupgradecnt += 1;
#      }
#    }
    my ($str,%res) = NtScanNsResultToStr($id, $s);
    TextOut_($str);
    if( $str ne '-' ){
      my $firmware = $res{'firmware'};
      my $board = $res{'board'};
      $firmware =~ s/ //g;
      my $latestfirmware = NtModuleFindLatestFirmwareFromId($id,$board);
      my %modulehash = ();
      $modulehash{'name'} = $NtScanList{$id};
      $modulehash{'curversion'} = $firmware;
      $modulehash{'latestversion'} = $latestfirmware;
      $modulehash{'uptodate'} = 0; if( uc($firmware) ge uc($latestfirmware) ){ $modulehash{'uptodate'} = 1; }
      push(@modulestoupgrade, \%modulehash); #push reference to hash
      if( uc($firmware) ge uc($latestfirmware) ){
      }else{
        $modulestoupgradestr .= $NtScanList{$id}.', ';
        $modulestoupgradecnt += 1;
      }
    }
  }
  if( $modulestoupgradecnt == 0 ){
    TextOut( "\n".'All NT modules are up to date.' );
  }else{
    #TextOut( "\n".'NT modules which need upgrade: '.$modulestoupgradecnt );
    TextOut( "\n".'NT modules not up to date: '.$modulestoupgradecnt );
    if( $modulestoupgradecnt <= 3 ){ TextOut( ' ('.substr($modulestoupgradestr,0,-2).')' ); }
  }
  if( $f_Tab{flash}->flash_CheckNtVersions_check->Checked() ){
    m_CheckNtVersions(\@modulestoupgrade); #array needs to be passed in as reference
  }
  TextOut( "\nScan NT bus... DONE\n" );
EXIT:
  1;
}


sub flash_Flash_Click{
  TextOut( "\nFlash firmware... Please wait!" );
  my $file= $f_Tab{flash}->flash_HexFile->Text();
  if( $file eq '' ){
    TextOut( "\nFlash firmware... ABORTED!\nFirmware file is not set.\n" ); return 1;
  }
  if( !open(F,"<$file") ){
    TextOut( "\nFlash firmware... ABORTED!\nFirmware file is not existing!\n" ); return 1;
  }
  close( F );
  my $pstr = $f_Tab{flash}->flash_Programmer->GetString( $f_Tab{flash}->flash_Programmer->GetCurSel() );
  my ($boardtype, $boardname, @boardslist) = GetBoardTypeAndName();
##pre-checks
  # pre-checks for flash NT module using NtUpgradeViaUSB or NtFlashViaUSB
  # check for Port is usb
  # for NtUpgradeViaUSB also let the user confirm the NT module settings
  if( ($boardtype == $BOARDTYPE_IS_NTMODULE) and ($pstr eq $NtUpgradeViaUSB) ){
    $Port = $w_Main->m_Port->Text();
    if( not ComIsUSB($Port) ){ ##if it's a v3x board, this is a bug, right???
      TextOut( "\nFlash firmware... ABORTED!\nPort is not a USB connection.\n" ); return 1;
    }
    my $module = '';
    my $moduleindex = $f_Tab{flash}->flash_ProgrammerModuleId->GetCurSel();
    if( $moduleindex >= 0 ){ $module = $f_Tab{flash}->flash_ProgrammerModuleId->GetString($moduleindex); }
    my $res = $w_Main->MessageBox(
        "You are about to upgrade the NT module:\n\n        ".
        "NT ".$module."\n\n".
        "with a firmware for a module:\n\n        ".
        $boardname."\n\n".
        "Please check carefully the correctness of the settings before you proceed!"
        ,
        'Upgrade Firmware' , 0x0030 + 1 ); #0x0010 + 1 ); # MB_ICONHAND +  MB_OKCANCEL
    if( $res != 1 ){ TextOut( "\nFlash firmware... CANCELED!\n" ); return 1; }
  }
  if( ($boardtype == $BOARDTYPE_IS_NTMODULE) and ($pstr eq $NtFlashViaUSB) ){
    $Port = $w_Main->m_Port->Text();
    if( not ComIsUSB($Port) ){ ##if it's a v3x board, this is a bug, right???
      TextOut( "\nFlash firmware... ABORTED!\nPort is not a USB connection.\n" ); return 1;
    }
  }
  # pre-check, these need the connection to the STorM32 board via the normal Port
  if( (($boardtype == $BOARDTYPE_IS_NTMODULE) and (($pstr eq $NtUpgradeViaUSB) or ($pstr eq $NtFlashViaUSB))) ){
    if( not ConnectionIsValid() ){
      if( not OpenPort() ){
        ClosePort(); TextOut( "\nFlash firmware... ABORTED!\nConnection to STorM32 board failed!\n" ); return 1;
      }
      ClosePort(); #close it again
      ConnectToBoardwoRead();
    }
  }
  if( ($boardtype == $BOARDTYPE_IS_STORM32_V3X) and ($pstr eq $Storm32UpgradeViaUSB) ){
    #upgrading V3x or v4.x per usb needs its special handling, since it should work independent on version/layout!
    if( not ConnectionIsValid() ){
      if( not OpenPort() ){
        ClosePort(); TextOut( "\nFlash firmware... ABORTED!\nConnection to STorM32 board failed!\n" ); return 1;
      }
      #check connection
      my ($Version,$Name,$Board,$Layout,$Capabilities) = GetControllerVersion();
      if( $Version eq '' ){ DisconnectFromBoard(0); }
    }
  }
##flash STorM32 board or NT module using STLink
  if( $pstr eq $StLink ){
    SetDoFirstReadOut(0);
    DisconnectFromBoard(0); #this would happen anyway during a flash
    TextOut( "\nuse ST-Link/V2 SWD" );
#    my $d = '"'.$STLinkPath.'\st-link_cli.exe"';
#    my $s = '';
#    if( $f_Tab{flash}->flash_FullErase_check->GetCheck() ){
#      TextOut( "\ndo full chip erase" );
#      $s.= $d.' -ME'."\n";
#      $f_Tab{flash}->flash_FullErase_check->Checked(0);
#    }
#    $s .= $d.' -P "'.$file.'"';
#    if( $f_Tab{flash}->flash_Verify_check->GetCheck() ){
#      TextOut( "\ndo verify" );
#      $s .= ' -V';
#    }
#    $s .= "\n";
#    $s .= $d.' -Rst'."\n";
#    $s .= '@pause'."\n";
    my $s = '"'.$STM32CubeProgrammerPath.'\STM32_Programmer_CLI.exe"';
    $s.= ' -c port=SWD freq=3900';
    if( $f_Tab{flash}->flash_FullErase_check->GetCheck() ){
      TextOut( "\ndo full chip erase" );
      $s.= ' -e all';
      $f_Tab{flash}->flash_FullErase_check->Checked(0);
    }
    $s .= ' -w "'.$file.'"';
    if( $f_Tab{flash}->flash_Verify_check->GetCheck() ){
      TextOut( "\ndo verify" );
      $s .= ' -v';
    }
    $s .= ' -g';
    $s .= "\n";
    $s .= '@pause'."\n";

    open(F, ">$BGCToolRunFile.bat" );
    print F $s;
    close( F );
    TextOut( "\nstart flashing firmware..." );
    $w_Main->ShellExecute('open',"$BGCToolRunFile.bat","",'',1);
    TextOut( " ok" );
    TextOut( "\nFlash firmware... DOS BOX STARTED\n" );
    return 1;
  }
##flash using SystemBootloader, in one or the other way
  # $SystemBootloader or $Storm32UpgradeViaUSB or $NtUpgradeViaSystemBootloader or $NtUpgradeViaUSB

  #open the correct port, i.e. the one called by StmFlashLoader.exe
  # $SystemBootloader or $NtUpgradeViaSystemBootloader => ComPort
  # $Storm32UpgradeViaUSB or $NtUpgradeViaUSB => normal Port
  my $StmFlashLoaderPort;

  if( (($pstr eq $SystemBootloader) and ($boardtype != $BOARDTYPE_IS_STORM32_V3X)) or
      (($boardtype == $BOARDTYPE_IS_NTMODULE) and ($pstr eq $NtUpgradeViaSystemBootloader)) ){
    #these use the [Com Port]
    # so we don't need the connection via the normal Port, and can disconnect here
    SetDoFirstReadOut(0); #we do not want to read back the parameteres
    DisconnectFromBoard(0); #this would happen anyway during a flash
    $StmFlashLoaderPort = ExtractCom( $f_Tab{flash}->flash_ProgrammerComPort->Text() );
    if( $StmFlashLoaderPort eq '' ){
      TextOut( "\nFlash firmware... ABORTED!\nCom port not specified!\n" ); return 1;
    }
    TextOut( "\nuse System Bootloader @ UART1" );
  }elsif( ($pstr eq $SystemBootloader) and ($boardtype == $BOARDTYPE_IS_STORM32_V3X) ){
    #these use the normal Port
    # but we do not need the connection via the normal Port later
    # so we should  disconnect here
    SetDoFirstReadOut(0); #we do not want to read back the parameteres
    DisconnectFromBoard(0); #this would happen anyway during a flash
    $StmFlashLoaderPort = ExtractCom($Port);
    TextOut( "\nuse System Bootloader @ UART1 via STorM32 usb port" );
  }elsif( (($boardtype == $BOARDTYPE_IS_STORM32_V3X) and ($pstr eq $Storm32UpgradeViaUSB)) or
          (($boardtype == $BOARDTYPE_IS_NTMODULE) and ($pstr eq $NtUpgradeViaUSB)) or
          (($boardtype == $BOARDTYPE_IS_NTMODULE) and ($pstr eq $NtFlashViaUSB)) ){
    #these use the normal Port
    # we need the connection via the normal Port later
    # so we should not disconnect here, we will disconnected later
    $StmFlashLoaderPort = ExtractCom($Port);
    TextOut( "\nuse STorM32 usb port" );
  }else{
    #something went wrong!
    TextOut( "\nFlash firmware... ABORTED!\nSorry, something strange happend (1)!\n" ); return 1;
  }

  #alert user if COM > 99 is used, >99 isn't working with "my" flashloader
#  if( substr($StmFlashLoaderPort,3,3) > 99 ){
#    $w_Main->MessageBox(
#        "The selected Com Port has a port number larger than 99, ".
#        "which is not supported by the used STMFlashLoader!\n\n".
#        "Please assign the port to a new port number below 100 (e.g. using Device Manager)."
#        , 'Com Port' );
#    TextOut( "\nFlash firmware... ABORTED!\n" ); return 1;
#  }

  #do all preliminary stuff before calling flashloader
  if( ($boardtype == $BOARDTYPE_IS_NTMODULE) and ($pstr eq $NtUpgradeViaUSB) ){
    my $module = '';
    my $moduleindex = $f_Tab{flash}->flash_ProgrammerModuleId->GetCurSel();
    if( $moduleindex >= 0 ){ $module = $f_Tab{flash}->flash_ProgrammerModuleId->GetString($moduleindex); }
    my ($id,$id_int) = NtModuleNameToId($module);
    if( $id eq '' ){
      TextOut( "\nFlash firmware... ABORTED!\nSorry, something strange happend (2)!\n" ); return 1;
    }
    #check first if module is on bus, get its boardstr, and compare with selection
    TextOut( "\nsearch NT $module module... " );
    if( $id eq 'T' ){ $id = '04'; $id_int = '04'; }
    my $s = ExecuteCmdwCrc( 'Ns', HexstrToStr($id), 35 );
    if( substr($s,length($s)-1,1) ne 'o' ){ TextOut( "FAILED!\nModule not found!\n" ); return 1; }
    my $boardstr = substr($s,17,16);  $boardstr =~ s/\0//g;
    if( length($boardstr) == 0 ){ TextOut( "FAILED!\nModule not found on NT bus!\n" ); return 1; }
    TextOut( "found ".$boardstr );
    my $match = 0;
    foreach my $b (@boardslist){ if( uc($b) eq uc($boardstr) ){ $match = 1 }; }
if(0){ ###XXXX
    if( $match != 1 ){
      TextOut( "\nFlash firmware... ABORTED!\nBoard types don't match!\n" ); return 1;
    }
}
    #send first xQTFLASH+id to set module into bootloader mode
    TextOut( "\nopen tunnel and set NT module into bootloader mode" );
    $s = ExecuteCmd( 'xQ' );
    if( substr($s,length($s)-1,1) ne 'o' ){
      TextOut( "\nFlash firmware... ABORTED!\nConnection to STorM32 board failed!\n" ); return 1;
    }
    WritePort( 'TcNTFLASH'.$id_int );
    _delay_ms(500); #wait a bit and let the STorM32 digest
    SetDoFirstReadOut(0);
    DisconnectFromBoard(0); #this would happen anyway during a flash
    TextOut( "\nDISCONNECTED" );

  }elsif( ($boardtype == $BOARDTYPE_IS_NTMODULE) and ($pstr eq $NtFlashViaUSB) ){ ##THIS DOESN'T WORK FOR SOME REASONS
    #send first xQ to set STorM32 into
    TextOut( "\nopen tunnel" );
    my $s = ExecuteCmd( 'xQ' );
    if( substr($s,length($s)-1,1) ne 'o' ){
      TextOut( "\nFlash firmware... ABORTED!\nConnection to STorM32 board failed!\n" ); return 1;
    }
    WritePort( 'TcNTFLASH00' );
    _delay_ms(100); #wait a bit and let the STorM32 digest
    SetDoFirstReadOut(0);
    DisconnectFromBoard(0); #this would happen anyway during a flash
    TextOut( "\nDISCONNECTED" );
    my $res = $w_Main->MessageBox(
      "Connect NT module to STorM32 board.\n(you have 30 sec time)\n\n".
      "ATTENTION: Only one NT module allowed!",
      'NT Modules First Time Firmware Flashing', 0x0030 );#0x0040 MB_ICONASTERISK (used for information)

  }elsif( ($boardtype == $BOARDTYPE_IS_NTMODULE) and ($pstr eq $NtUpgradeViaSystemBootloader) ){
    #send first STX FLASH to set NT module into bootloader mode
    TextOut( "\nset NT module into bootloader mode" );
    my $p_ntbus = Win32::SerialPort->new( $StmFlashLoaderPort );
    if( (defined $p_ntbus) and ($p_ntbus) ){
      #requires change in Win32:Api::CommPort
      #https://rt.cpan.org/Public/Bug/Display.html?id=73763 #${$hr}{2000000} = 2000000 if ($fmask & BAUD_USER);
      $p_ntbus->baudrate(2000000);
      configport_com($p_ntbus);
      my $stxflash = HexstrToStr( 'F0464C415348' );
      $p_ntbus->owwrite_overlapped_undef( $stxflash );
      _delay_ms(100);
      $p_ntbus->close;
    }

  }elsif( ($boardtype == $BOARDTYPE_IS_STORM32_V3X) and ($pstr eq $Storm32UpgradeViaUSB) ){
    #send first xQSFLASH to set STorM32 board into bootloader mode
    TextOut( "\nset STorM32 v3.x board into bootloader mode" );
    my $s = ExecuteCmd( 'xQ' );
    if( substr($s,length($s)-1,1) ne 'o' ){
      TextOut( "\nFlash firmware... ABORTED!\nConnection to STorM32 board failed!\n" ); return 1;
    }
    WritePort( 'ScFLASH' );
    _delay_ms(500); #wait a bit and let the STorM32 digest
    SetDoFirstReadOut(0);
    DisconnectFromBoard(0); #this would happen anyway during a flash
    TextOut( "\nDISCONNECTED" );
  }

  my $s = '';
if($boardtype == $BOARDTYPE_IS_NTMODULE){
#if(0){
  # STM32CubeProgrammer doesn't work for NT modules, it seems chunks are too big, gives a timeout
  # needs to be investigate more deeply what the issue is
  # so for the moment we use legacy FlashLoader
  #prepare everything for flashloader and run it
  my $STMFlashLoaderPath = 'bin\ST\STMFlashLoader';
  my $d = '"'.$STMFlashLoaderPath.'\\'.'STMFlashLoaderOlliW.exe'.'"';
  $s = $d.' -c --pn '.substr($StmFlashLoaderPort,3,3).' --br 115200';
  $s .= ' -ow'; #uses modified STMFlashLoaderOlliW
  if( $f_Tab{flash}->flash_FullErase_check->GetCheck() ){
    TextOut( "\ndo full chip erase" );
    if( $f_Tab{flash}->flash_RemoveProtections_check->GetCheck() ){
      $s .= ' -p --drp --dwp';
    }
    $s .= ' -e --all'.' -d --fn "'.$file.'"';
    RemoveProtectionsUnCheck();
    $f_Tab{flash}->flash_FullErase_check->Checked(0);
  }else{
    $s .= ' -d --fn "'.$file.'"'.' --ep';
  }
  if( $f_Tab{flash}->flash_Verify_check->GetCheck() ){
    TextOut( "\ndo verify" );
    $s .= ' --v';
  }
  $s .= " -r --a 8000000\n";
  $s .= "\n";
  $s .= '@echo.'."\n";
  $s .= '@pause'."\n";
}else{
  #prepare everything for STM32CubeProgrammer and run it
  $s = '"'.$STM32CubeProgrammerPath.'\STM32_Programmer_CLI.exe"';
  $s.= ' -c port=COM'.substr($StmFlashLoaderPort,3,3).' br=115200';
###  $s.= ' -vb 3 -log "bin\ST\log.txt"';
  if( $f_Tab{flash}->flash_FullErase_check->GetCheck() ){
    TextOut( "\ndo full chip erase" );
    if( $f_Tab{flash}->flash_RemoveProtections_check->GetCheck() ){
      $s .= ' -rdu';
    }
    $s .= ' -e all';
    RemoveProtectionsUnCheck();
    $f_Tab{flash}->flash_FullErase_check->Checked(0);
  }
  $s .= ' -w "'.$file.'"';
  if( $f_Tab{flash}->flash_Verify_check->GetCheck() ){
    TextOut( "\ndo verify" );
    $s .= ' -v';
  }
  $s .= ' -g';
  $s .= "\n";
  $s .= '@pause'."\n";
}
  open(F,">$BGCToolRunFile.bat");
  print F $s;
  close( F );
  TextOut( "\nstart flashing firmware..." );
  $w_Main->ShellExecute('open',"$BGCToolRunFile.bat","",'',1);
  TextOut( " ok" );

  TextOut( "\nFlash firmware... DOS BOX STARTED\n" );
  return 1;
}











#-----------------------------------------------------------------------------#
###############################################################################
###############################################################################
# OBGC Routines
# handles COM port and so on
###############################################################################
###############################################################################
#-----------------------------------------------------------------------------#
#//capability constants
my $BOARD_CAPABILITY_FOC           =  7; #0x0100
my $BOARD_CAPABILITY_MAVCAMERA     =  5; #0x0400


#//status constants
my $STATUS_IMU_PRESENT              =  0; #0x8000
my $STATUS_IMU_OK                   = 10; #0x0020
my $STATUS_IMU2_PRESENT             =  3; #0x1000
my $STATUS_IMU2_HIGHADR             =  4; #0x0800
my $STATUS_IMU2_NTBUS               =  5; #0x0400
my $STATUS_IMU2_OK                  =  9; #0x0040

my $STATUS_BAT_VOLTAGEISLOW         = 11; #0x0010
my $STATUS_BAT_ISCONNECTED          = 12; #0x0008

my $STATUS_LEVEL_FAILED             = 13; #0x0004

my $STATUS_STORM32LINK_PRESENT      =  7; #0x0100
my $STATUS_STORM32LINK_OK           = 14; #0x0002
my $STATUS_STORM32LINK_AVAILABLE    = 15; #0x0001

my $STATUS_PREARMCHECKS_OK          =  1; #0x4000
my $STATUS_PREARMCHECKS_SHOW        =  2; #0x2000

my $STATUS_EMERGENCY                =  8; #0x0080
my $STATUS_ERROR                    =  6; #0x0200   TODO: not yet handled!!!


my $STATUS2_ENCODERS_PRESENT        =  0; #0x8000
my $STATUS2_ENCODERPITCH_OK         =  3; #0x1000
my $STATUS2_ENCODERROLL_OK          =  2; #0x2000
my $STATUS2_ENCODERYAW_OK           =  1; #0x4000
my $STATUS2_ENCODERPITCH_PRESENT    =  6; #0x0200
my $STATUS2_ENCODERROLL_PRESENT     =  5; #0x0400
my $STATUS2_ENCODERYAW_PRESENT      =  4; #0x0800

my $STATUS2_MOTORPITCH_ACTIVE       = 12; #0x0008
my $STATUS2_MOTORROLL_ACTIVE        = 11; #0x0010
my $STATUS2_MOTORYAW_ACTIVE         = 10; #0x0020

my $STATUS2_MAVLINK_PRESENT         =  8; #0x0080
my $STATUS2_VIRTUAL_PRESENT         =  9; #0x0040


my $STATUS3_CAMERA_ISCONNECTED      =  8; #0x0080
my $STATUS3_CAMERA_SHOWCONNECTED    =  9; #0x0040

#my $STATUS3_NTLOGGER_SDCARD_OK      =  3; #0x1000
#my $STATUS3_NTLOGGER_HAS_RTC        =  2; #0x2000
#my $STATUS3_NTLOGGER_RTC_OK         =  1; #0x4000
#my $STATUS3_NTLOGGER_PRESENT        =  0; #0x8000


#//state constants
my $STATE_STARTUP_MOTORS             = 0;
my $STATE_STARTUP_SETTLE             = 1;
my $STATE_STARTUP_CALIBRATE          = 2;
my $STATE_STARTUP_LEVEL              = 3;
my $STATE_STARTUP_MOTORDIRDETECT     = 4;
my $STATE_STARTUP_RELEVEL            = 5;
my $STATE_NORMAL                     = 6;
my $STATE_STARTUP_FASTLEVEL          = 7;
my $STATE_STANDBY                    = 99; #ATTENTION: in the @StateText array it is at position 8, so we need to map here

my @StateText=   ( 'strtMOTOR','SETTLE', 'CALIBRATE','LEVEL',    'AUTODIR',  'RELEVEL',  'NORMAL', 'FASTLEVEL','STANDBY',  'unknown',    'unknown'  );
my @StateColors= ( [255,50,50],[0,0,255],[255,0,255],[80,80,255],[255,0,255],[255,0,255],[0,255,0],[80,80,255],[255,50,50],[128,128,128],[128,128,128], );

my @LipoVoltageText=   ( 'OK', 'LOW',  ' ' );
my @LipoVoltageColors= ( [0,255,0], [255,50,50], [128,128,128]); #grün, rot, grau

my @ImuStatusText=   ( 'ERR', 'OK', 'none', ' ' );
my @ImuStatusColors= ( [255,50,50], [0,255,0], [128,128,128], [128,128,128]); #rot, grün, grau

my @Imu2StatusText=   ( 'ERR', 'OK', 'none', ' ' );
my @Imu2StatusColors= ( [255,50,50], [0,255,0], [128,128,128], [128,128,128]); #rot, grün, grau

my @EncoderStatusText=      ( 'ERR', 'OK', '-', ' ' ); ##'none', ' ' );
my @EncoderStatusColors=    ( [255,50,50], [0,255,0], [128,128,128], [128,128,128]); #rot, grün, grau
my @EncoderAllStatusText=   ( 'ERR', 'OK', 'none', ' ' ); ##'none', ' ' );
my @EncoderAllStatusColors= ( [255,50,50], [0,255,0], [128,128,128], [128,128,128]); #rot, grün, grau

my @STorM32LinkStatusText=   ( 'ERR', 'OK',  'none', 'PSNT', ' ' );
my @STorM32LinkStatusColors= ( [255,50,50], [0,255,0], [128,128,128], [80,80,255], [128,128,128]); #rot, grün, grau


sub GetStateText{
  my $state = shift;
  my $index;
  if( $state <= $STATE_STARTUP_FASTLEVEL ){ $index = $state;  }
  elsif( $state == $STATE_STANDBY ){        $index = 8;       }
  else{                                     $index = -1;      }
  return $StateText[$index];
}

sub GetStateColor{
  my $state = shift;
  my $index;
  if( $state <= $STATE_STARTUP_FASTLEVEL ){ $index = $state;  }
  elsif( $state == $STATE_STANDBY ){        $index = 8;       }
  else{                                     $index = -1;      }
  return $StateColors[$index];
}

#checks if a bit in a bitstring is set
sub CheckStatus{
  if( substr(shift,shift,1) eq '1' ){ return 1; }else{ return 0; }
}

# returns the StateText which corresponds to the state
sub toStateText{
  my $state = UIntToBitstr( shift ); #state
  my $index = oct('0b'.substr($state,8,8));
#  if( $index<=7 ){
#    return $StateText[$index];
#  }else{
#    return $StateText[-1];
#  }
  return GetStateText($index);
}

my %StatusInfoHash;

#this extracts info from the 's' command data stream, and stores it in the StatusInfoHash hash for later use
sub ExtractStatusInfo{
  my @data = unpack( "v$CMD_s_PARAMETER_ZAHL", shift );
  my $state = UIntToBitstr( $data[0] ); #state
#V1:  my $status3 = '00000000'.substr($state,0,8); #status3 = high byte of state shifted to low byte
  my $status = UIntToBitstr( $data[1] ); #status
  my $status2 = UIntToBitstr( $data[2] ); #status2
  my $status3 = UIntToBitstr( $data[3] ); #status3
  my $buserrors = $data[5];
  my $voltage = $data[6];
  my $sa = '';
  my $index = 0;
  # IMU
  if( CheckStatus($status,$STATUS_IMU_PRESENT) ){
    $sa = 'IMU is PRESENT';
    $sa .= ' @ NTBUS'; #$status is always $STATUS_NTBUS_INUSE!
    if( CheckStatus($status,$STATUS_IMU_OK) ){ $index = 1; }else{ $index = 0; }
  }else{
    $sa = 'IMU is not available';
    $index = 2;
  }
  $StatusInfoHash{IMUcondition} = $sa;
  $StatusInfoHash{IMUindex} = $index;
  $StatusInfoHash{IMU} = $ImuStatusText[$index];
  $StatusInfoHash{IMUcolor} = $ImuStatusColors[$index];
  # IMU2
  if( CheckStatus($status,$STATUS_IMU2_PRESENT) ){
    $sa = 'IMU2 is PRESENT';
    if( CheckStatus($status,$STATUS_IMU2_NTBUS) ){
      $sa .= ' @ NTBUS';
    }else{
      if( CheckStatus($status,$STATUS_IMU2_HIGHADR) ){ $sa .= ' @ HIGH ADR = on-board IMU'; }else{ $sa .= ' @ LOW ADR = external IMU'; }
    }
    if( CheckStatus($status,$STATUS_IMU2_OK) ){ $index = 1; }else{ $index = 0; }
  }else{
    $sa = 'IMU2 is not available';
    $index = 2;
  }
  $StatusInfoHash{IMU2condition} = $sa;
  $StatusInfoHash{IMU2index} = $index;
  $StatusInfoHash{IMU2} = $ImuStatusText[$index];
  $StatusInfoHash{IMU2color} = $ImuStatusColors[$index];
  # ENCODERS
  my $enc_count = 0;
  if( CheckStatus($status2,$STATUS2_ENCODERPITCH_PRESENT) ){ $enc_count += 1; }
  if( CheckStatus($status2,$STATUS2_ENCODERROLL_PRESENT) ){ $enc_count += 1; }
  if( CheckStatus($status2,$STATUS2_ENCODERYAW_PRESENT) ){ $enc_count += 1; }
  if( CheckStatus($status2,$STATUS2_ENCODERS_PRESENT) ){
    $sa = 'ENCODERS are PRESENT and READY'; #means present = required
    #$sa .= " ($enc_count)";
  }else{
    $sa = 'ENCODERS are not available or ready';
    #if( $enc_count < 3 ){ $sa .= " (only $enc_count)"; }
  }
  $StatusInfoHash{status2} = $status2;
  $StatusInfoHash{ENCODERcondition} = $sa;
  if( not CheckStatus($status2,$STATUS2_ENCODERPITCH_PRESENT) ){ $index = 2; }
  elsif( CheckStatus($status2,$STATUS2_ENCODERPITCH_OK) ){ $index = 1; }else{ $index = 0; }
  $StatusInfoHash{ENCODERPITCH} = $EncoderStatusText[$index];
  if( not CheckStatus($status2,$STATUS2_ENCODERROLL_PRESENT) ){ $index = 2; }
  elsif( CheckStatus($status2,$STATUS2_ENCODERROLL_OK) ){ $index = 1; }else{ $index = 0; }
  $StatusInfoHash{ENCODERROLL} = $EncoderStatusText[$index];
  if( not CheckStatus($status2,$STATUS2_ENCODERYAW_PRESENT) ){ $index = 2; }
  elsif( CheckStatus($status2,$STATUS2_ENCODERYAW_OK) ){ $index = 1; }else{ $index = 0; }
  $StatusInfoHash{ENCODERYAW} = $EncoderStatusText[$index];
  my $is_encoder_ok = 1;
  if( CheckStatus($status2,$STATUS2_ENCODERPITCH_PRESENT) and not CheckStatus($status2,$STATUS2_ENCODERPITCH_OK) ){
    $is_encoder_ok = 0;
  }
  if( CheckStatus($status2,$STATUS2_ENCODERROLL_PRESENT) and not CheckStatus($status2,$STATUS2_ENCODERROLL_OK) ){
    $is_encoder_ok = 0;
  }
  if( CheckStatus($status2,$STATUS2_ENCODERYAW_PRESENT) and not CheckStatus($status2,$STATUS2_ENCODERYAW_OK) ){
    $is_encoder_ok = 0;
  }
  if( not CheckStatus($status2,$STATUS2_ENCODERS_PRESENT) ){ $index = 2; }
  elsif( $is_encoder_ok ){ $index = 1; }else{ $index = 0; }
  $StatusInfoHash{ENCODERALLindex} = $index;
  $StatusInfoHash{ENCODERALL} = $EncoderAllStatusText[$index];
  $StatusInfoHash{ENCODERALLcolor} = $EncoderAllStatusColors[$index];
  # MOTORS
  $sa = 'MOTORS are';
  if( CheckStatus($status2,$STATUS2_MOTORPITCH_ACTIVE) ){ $sa .= ' ACTIVE'; }else{ $sa .= ' OFF'; }
  if( CheckStatus($status2,$STATUS2_MOTORROLL_ACTIVE) ){ $sa .= ' ACTIVE'; }else{ $sa .= ' OFF'; }
  if( CheckStatus($status2,$STATUS2_MOTORYAW_ACTIVE) ){ $sa .= ' ACTIVE'; }else{ $sa .= ' OFF'; }
  $StatusInfoHash{MOTORcondition} = $sa;
  # LEVEL FAILED
  $sa = '';
  if( CheckStatus($status,$STATUS_LEVEL_FAILED) ){
    $sa = 'LEVEL failed!';
  }
  $StatusInfoHash{LEVELcondition} = $sa;
  # EMRGENCY
  $sa = '';
  if( CheckStatus($status,$STATUS_EMERGENCY) ){
    $sa = 'EMERGENCY shut down!';
  }
  $StatusInfoHash{EMERGENCYcondition} = $sa;
  # STORM-LINK
  if( CheckStatus($status,$STATUS_STORM32LINK_PRESENT) ){
    if( CheckStatus($status,$STATUS_STORM32LINK_AVAILABLE) ){
      $sa = 'STorM32-LINK is AVAILABLE';
      if( CheckStatus($status,$STATUS_STORM32LINK_OK) ){ $index = 1; }else{ $index = 0; }
    }else{
      $sa = 'STorM32-LINK is PRESENT';
      if( CheckStatus($status,$STATUS_STORM32LINK_OK) ){ $index = 1; }else{ $index = 3; }
    }
##    $sa .= " & ".$STorM32LinkStatusText[$index];
  }else{
    $sa = 'STorM32-LINK is not available';
    $index = 2;
  }
  $StatusInfoHash{LINKcondition} = $sa;
  $StatusInfoHash{LINKindex} = $index;
  $StatusInfoHash{LINK} = $STorM32LinkStatusText[$index];
  $StatusInfoHash{LINKcolor} = $STorM32LinkStatusColors[$index];
  # MAVLINK
  if( CheckStatus($status2,$STATUS2_MAVLINK_PRESENT) ){
    $sa = 'MAVLINK is PRESENT';
    #if( CheckStatus($status2,$STATUS2_MAVLINK_V2) ){
    #  $sa .= 'and V2';
    #}
  }else{
    $sa = 'MAVLINK is not available';
  }
  $StatusInfoHash{MAVLINKcondition} = $sa;
  # BAT
  if( CheckStatus($status,$STATUS_BAT_ISCONNECTED) ){
    $sa = 'BAT is CONNECTED';
  }else{
    $sa = 'BAT is not connected';
  }
  $StatusInfoHash{BATcondition} = $sa;
  # STATE
  $index = oct('0b'.substr($state,8,8)); #this blends out the high byte
  $sa = 'STATE is '.uc(GetStateText($index)); #$StateText[$index];
  $StatusInfoHash{STATEcondition} = $sa;
  $StatusInfoHash{STATEindex} = $index;
  $StatusInfoHash{STATE} = GetStateText($index); #$StateText[$index];
  $StatusInfoHash{STATEcolor} = GetStateColor($index); #$StateColors[$index];
  # VOLTAGE
  if( CheckStatus($status,$STATUS_BAT_VOLTAGEISLOW) ){
    $sa = 'VOLTAGE is LOW';
    $index = 1;
  }else{
    $sa = 'VOLTAGE is OK';
    $index = 0;
  }
  my $sv = sprintf("%.2f V", $voltage/1000.0);
  $StatusInfoHash{VOLTAGEcondition} = $sa.': '.$sv;
  $StatusInfoHash{VOLTAGEindex} = $index;
  $StatusInfoHash{VOLTAGE} = $LipoVoltageText[$index];
  $StatusInfoHash{VOLTAGEvalue} = $sv;
  $StatusInfoHash{VOLTAGEcolor} = $LipoVoltageColors[$index];
  # ERRORS
  my $sb = '';
  $sa = 'BUS ERRORS: ';
  $sb = 'Bus Errors';
  $sa .= $buserrors;
  $StatusInfoHash{BUSERRORcondition} = $sa;
  #$StatusInfoHash{BUSERRORindex} = $index;
  $StatusInfoHash{BUSERROR} = $sb;
  $StatusInfoHash{BUSERRORvalue} = $buserrors;
  # PREARM
  $sa = '';
  if( CheckStatus($status,$STATUS_PREARMCHECKS_SHOW) ){
    $sa = 'PREAM CHECKS: ';
    if( CheckStatus($status,$STATUS_PREARMCHECKS_OK) ){ $sa .= 'passed'; }else{ $sa .= 'not passed'; }
  }
  $StatusInfoHash{PREARMcondition} = $sa;
  # CAMERA
  $sa = '';
  if( CheckStatus($status3,$STATUS3_CAMERA_SHOWCONNECTED) ){
    if( CheckStatus($status3,$STATUS3_CAMERA_ISCONNECTED) ){
      $sa = 'CAMERA: connected';
    }else{
      $sa = 'CAMERA: not connected';
    }
  }
  $StatusInfoHash{CAMERAcondition} = $sa;
  # NTLogger
#  $sa = 'NTLogger';
#  if( not CheckStatus($status3,$STATUS3_NTLOGGER_PRESENT) ){
#    $sa .= ' condition unknown';
#  }elsif( CheckStatus($status3,$STATUS3_NTLOGGER_HAS_RTC) ){
#    if( CheckStatus($status3,$STATUS3_NTLOGGER_SDCARD_OK) and CheckStatus($status3,$STATUS3_NTLOGGER_RTC_OK) ){
#      $sa .= ' is OK (SDCard and RTC)';
#    }elsif( CheckStatus($status3,$STATUS3_NTLOGGER_SDCARD_OK) ){
#      $sa .= ' is OK (SDCard ok, RTC err)';
#    }elsif( CheckStatus($status3,$STATUS3_NTLOGGER_RTC_OK) ){
#      $sa .= ' is PRESENT (SDCard err, RTC ok)';
#    }else{
#      $sa .= ' is PRESENT (SDCard err, RTC err)';
#    }
#  }elsif( CheckStatus($status3,$STATUS3_NTLOGGER_SDCARD_OK) ){
#    $sa .= ' is OK (SDCard, no RTC)';
#  }else{
#    $sa .= ' is PRESENT (SDCard err, no RTC)';
#  }
#  $StatusInfoHash{NTLOGGERcondition} = $sa;
}

sub StatusBarStatusText{
  my $s = '';
  $s .= 'IMU: '.$StatusInfoHash{IMU};
  $s .= '    ';
  $s .= 'IMU2: '.$StatusInfoHash{IMU2};
  $s .= '    ';
  $s .= 'VOLTAGE: '.$StatusInfoHash{VOLTAGE}.' '.$StatusInfoHash{VOLTAGEvalue};
  $s .= '    ';
  $s .= 'STATE: '.$StatusInfoHash{STATE};
  $s .= '    ';
  $s .= $StatusInfoHash{BUSERRORcondition};
  if( $StatusInfoHash{EMERGENCYcondition} ne '' ){
    $s .= '    '.'ERROR: '.$StatusInfoHash{EMERGENCYcondition};
  }elsif( $StatusInfoHash{LEVELcondition} ne '' ){
    $s .= '    '.'ERROR: '.$StatusInfoHash{LEVELcondition};
  }
  $w_Main->m_StatusField->Text( $s );
}

sub DashboardStatusTextClearTo{
  $f_Tab{dashboard}->dashboard_Status_a->Text( shift );
  $f_Tab{dashboard}->dashboard_Status_b->Text( '' );
}

sub DashboardStatusText{
  my $s = '';
  $s = $StatusInfoHash{IMUcondition};
  $s .= "\r\n\r\n";
  $s .= $StatusInfoHash{IMU2condition};
  $s .= "\r\n\r\n";
  if( $ActiveBoardConfiguration == $BOARDCONFIGURATION_IS_FOC ){
    $s .= $StatusInfoHash{ENCODERcondition};
    $s .= "\r\n\r\n";
  } else {
    if( CheckStatus($StatusInfoHash{status2},$STATUS2_ENCODERS_PRESENT) ){
      $s .= 'ENCODERS are PRESENT';
      $s .= "\r\n\r\n";
    }
  }
  $s .= $StatusInfoHash{LINKcondition};
  if( $StatusInfoHash{LINKindex} < 2 ){ $s .= ' and '.$StatusInfoHash{LINK}; }
  $s .= "\r\n\r\n";
  $s .= $StatusInfoHash{MAVLINKcondition};
  $s .= "\r\n\r\n";
#XX  if( $StatusInfoHash{NTLOGGERcondition} ne '' ){
#XX    $s .= $StatusInfoHash{NTLOGGERcondition};
#XX    $s .= "\r\n\r\n";
#XX  }
  $s .= $StatusInfoHash{BATcondition};
  $s .= "\r\n\r\n";
  $s .= $StatusInfoHash{MOTORcondition};
  $f_Tab{dashboard}->dashboard_Status_a->Text( $s );

  $s = $StatusInfoHash{STATEcondition};
  $s .= "\r\n\r\n";
  $s .= $StatusInfoHash{VOLTAGEcondition};
  $s .= "\r\n\r\n";
  $s .= 'IMU: '.$StatusInfoHash{IMU};
  $s .= "\r\n\r\n";
  $s .= 'IMU2: '.$StatusInfoHash{IMU2};
  $s .= "\r\n\r\n";
  if( $ActiveBoardConfiguration == $BOARDCONFIGURATION_IS_FOC ){
    $s .= 'ENCODERS: '.$StatusInfoHash{ENCODERPITCH}.' '.$StatusInfoHash{ENCODERROLL}.' '.$StatusInfoHash{ENCODERYAW};
    $s .= "\r\n\r\n";
  }
  $s .= $StatusInfoHash{BUSERRORcondition};
  $s .= "\r\n\r\n";
  if( $StatusInfoHash{PREARMcondition} ne '' ){
    $s .= $StatusInfoHash{PREARMcondition};
    $s .= "\r\n\r\n";
  }
  if( $StatusInfoHash{CAMERAcondition} ne '' ){
    $s .= $StatusInfoHash{CAMERAcondition};
    if( $ActiveBoardConfiguration != $BOARDCONFIGURATION_IS_FOC ){ $s .= "\r\n\r\n"; }
  }
  $s .= "\r\n\r\n";
  if( $StatusInfoHash{EMERGENCYcondition} ne '' ){
    $s .= 'ERROR: '.$StatusInfoHash{EMERGENCYcondition};
  }elsif( $StatusInfoHash{LEVELcondition} ne '' ){
    $s .= 'ERROR: '.$StatusInfoHash{LEVELcondition};
  }
  $f_Tab{dashboard}->dashboard_Status_b->Text( $s );
}

sub ExecuteGetStatusStatusText{
  my $s = '';
  $s .= '  '.$StatusInfoHash{IMUcondition};
  $s .= "\r\n";
  $s .= '  '.$StatusInfoHash{IMU2condition};
  $s .= "\r\n";
  $s .= '  '.$StatusInfoHash{LINKcondition};
  $s .= "\r\n";
  $s .= '  '.$StatusInfoHash{STATEcondition};
  $s .= "\r\n";
  $s .= '  '.$StatusInfoHash{BATcondition};
  $s .= ', '.$StatusInfoHash{VOLTAGEcondition};
  TextOut( $s );
}

############################################################################
# crc
# uses MAVLINK's x25 checksum
# https://github.com/mavlink/pymavlink/blob/master/mavutil.py

sub do_crc{
  my $data = shift; my $len = shift;

  my @buf = unpack( "C".$len, $data );
  my $crc = 0xFFFF;
  foreach my $b (@buf){
     my $tmp = $b ^ ($crc & 0xFF );
     $tmp = ($tmp ^ ($tmp<<4)) & 0xFF;
     $crc = ($crc>>8) ^ ($tmp<<8) ^ ($tmp<<3) ^ ($tmp>>4);
     $crc = $crc & 0xFFFF;
  }
  return $crc;
}

sub check_crc_wextra{
  my $data = shift; my $len = shift; my $crcextra = shift; my $DetailsOut = shift;

#$DetailsOut = 1;
#TextOut( "!check_crc:".$len."!".StrToHexstr($data)."!" );
  my $crc = 0;
  $crc = unpack( "v", substr($data,$len-2,2) );
  if($DetailsOut){ TextOut( " CRC:".UIntToHexstr($crc) ); }
  if( $crcextra >= 0 ){ #that's the method to take into account also the extra crc
    $data = substr($data,0,$len-2).chr($crcextra).substr($data,$len-2,2);
    $len++;
  }
  my $crc2 = do_crc( $data, $len );
  if($DetailsOut){ TextOut( " CRC2:0x".UIntToHexstr($crc2)."!" ); }
  if( $crc2 != 0 ){ return 0; }
  return 1;
}

sub check_crc{
  return check_crc_wextra(shift, shift, -1, shift);
}

sub add_crc_to_data{
  my $data = shift;

  my $crc = do_crc( $data, length($data) );
  $data .= pack( "v", $crc );
  return $data;
}

sub do_crc_wextra_hexstr{
  my $hexstr = shift;  my $crcextra = shift;

  my $len = length($hexstr)/2;
  my $data = HexstrToStr( $hexstr );
  my $crc = 0;
  if( $crcextra >= 0 ){
    #that's the method to take into account also the extra crc
    $crc = do_crc( substr($data,1).chr($crcextra), $len );
  }else{
    $crc = do_crc( substr($data,1), $len-1 );
  }
  return UIntToHexstrSwapped($crc);
}

sub do_crc_hexstr{
  return do_crc_wextra_hexstr(shift, -1);
}



############################################################################
# FLAGS

#sets an increased $timeoutfirst in ReadPort();
my $ExtendedTimoutFirst = 0;
sub SetExtendedTimoutFirst{ $ExtendedTimoutFirst = shift; }

# skips a Read in ConnectToBoard() -> calls GetControllerVersion()
my $SkipExecuteRead = 0;
sub SetSkipExecuteRead{ $SkipExecuteRead = shift; }

#sets if details should be displayed in ExecuteGetCommand()
my $ReadDetailsOut = 1;
sub SetReadDetailsOut{ $ReadDetailsOut = shift; }

#sets if a Delay should be waited before a Read in ExecuteCommandFullwoGet() -> calls ExecuteGetCommand()
my $DelayBeforeGet = 0;
sub SetDelayBeforeGet{ $DelayBeforeGet = shift; }

#sets if a Read should be done in ExecuteCommandFullwoGet() -> calls ExecuteGetCommand()
my $WithGet = 0;
sub SetWithGet{ $WithGet = shift; }

#when a communication process aborts, it's important to reset all flags
sub ResetFlags{
  $ExtendedTimoutFirst = 0; $SkipExecuteRead = 0; $ReadDetailsOut = 1; $DelayBeforeGet = 0; $WithGet = 0;
}

my $ReadCmdDebug = 0;
sub SetReadCmdDebug{
  $ReadCmdDebug = shift;
}


sub MavlinkTunnelIsInUse{
  if( $w_Main->m_Mavlink_check->Checked() ){ return 1; }
  return 0;
}


sub MavlinkTunnelResetUse{
  $w_Main->m_Mavlink_check->Checked(0);
}


############################################################################
# timing stuff

sub _delay_ms{
  my $tmo = shift;
  $tmo += Win32::GetTickCount(); #$p_Serial->get_tick_count(); #timeout in ms
  do{ }while( Win32::GetTickCount() < $tmo ); # $p_Serial->get_tick_count() < $tmo );
}

sub GetTickCount{
  #return Win32::timeGetTime(); not existing
  return Win32::GetTickCount(); #return $p_Serial->get_tick_count(); }
}

############################################################################
# PORT stuff

sub configport_com{
  my $com = shift;
  if( $com ){
    $com->databits(8);
    $com->parity("none");
    $com->stopbits(1);
    $com->handshake("none");
    $com->buffers(4096, 4096);
    $com->write_char_time(100);
    $com->write_const_time(2000);
    #http://msdn.microsoft.com/en-us/library/aa450505.aspx
    #non-blocking asynchronous read
      $com->read_interval(0xffffffff);
      $com->read_char_time(0);
      $com->read_const_time(0);
    $com->write_settings;
    _delay_ms(100);
    $com->purge_all();
    _delay_ms(100);
  }
}

sub ConfigComPort{
  if( $p_Serial ){
    $p_Serial->baudrate($Baudrate);
    configport_com($p_Serial);
  }
}

my $select = new IO::Select();
#$| = 1;

sub OpenPort{
  $Port = $w_Main->m_Port->Text(); #$Port has COM + friendly name
  $PortType = $PORTTYPE_UNDEFINED;
  if( ExtractCom($Port) eq '' ){
    TextOut( "\r\n".'Port not specified!'."\r\n" ); $PortIsOpen = 0; return 0; #this error should never happen
  }
  if( not ComIsESP($Port) ){
    # open normal COM port
    $p_Serial = Win32::SerialPort->new( ExtractCom($Port) );
#TextOut("!".ExtractCom($Port)."!");
    if( (not defined $p_Serial) or (not $p_Serial) ){
      TextOut( "\r\n".'Opening port '.ExtractCom($Port).' FAILED!'."\r\n" ); $PortIsOpen = 0; return 0;
    }
    ConfigComPort();
    $PortType = $PORTTYPE_COM;
    $PortIsOpen = 1;
    return 1;
  }else{
    if( not ESPIsAvailable() ){
      TextOut( "\r\n".'Opening ESP port FAILED! ESP is not connected.'."\r\n" ); $PortIsOpen = 0; return 0;
    }
    # open ESP port
    $p_Socket = new IO::Socket::INET (
      PeerHost => $EspWifiSSID, #'192.168.4.1',
      PeerPort => $EspWifiPort, #'23',
      Proto => 'tcp',
      #Blocking => 0, #this somehow doesn't work
      Timeout => 5,
    );
    if( not $p_Socket ){
      TextOut( "\r\n".'Opening ESP port FAILED!'."\r\n" ); $PortIsOpen = 0; return 0;
    }
    $p_Socket->autoflush(1);
    $PortType = $PORTTYPE_ESP;
    $select->add($p_Socket);
    $PortIsOpen = 1;
    return 1;
  }
  $PortIsOpen = 0;
  return 0;
}

sub ClosePort{
  if( $PortType == $PORTTYPE_COM ){
    if( $p_Serial ){ $p_Serial->close; $PortIsOpen = 0; }
  }
  if( $PortType == $PORTTYPE_ESP ){
    if( $p_Socket ){ $p_Socket->close(); $PortIsOpen = 0; }
  }
}

sub FlushPort_direct{
  if( $PortType == $PORTTYPE_COM ){
    if( $p_Serial ){ $p_Serial->purge_all(); }
  }
  if( $PortType == $PORTTYPE_ESP ){
  }
}

sub WritePort_direct{
  if( $PortType == $PORTTYPE_COM ){
    $p_Serial->owwrite_overlapped_undef( shift );
  }
  if( $PortType == $PORTTYPE_ESP ){
    $p_Socket->send( shift );
  }
}

sub ReadPortOneByte_direct{
  if( $PortType == $PORTTYPE_COM ){
    return $p_Serial->owread_overlapped(1);
  }
  if( $PortType == $PORTTYPE_ESP ){
    while( my @CANREAD = $select->can_read(1) ){
      foreach my $soc (@CANREAD) {
        if( !$soc->connected() ){ $select->remove($soc); next; }
        my $byte;
        my $res = $p_Socket->sysread($byte, 4096);
        if( defined $res ){ return ($res,$byte); }
      }
    }
    return (0,'');
  }
  return (0,'');
}

sub WritePort{
  my $cmd = shift;
  #Win32::GUI::DoEvents();
  if( MavlinkTunnelIsInUse() ){
    WritePort_mavtunnel(StrToHexstr($cmd));
  }else{
    WritePort_direct($cmd);
  }
}

sub FlushPort{
  if( MavlinkTunnelIsInUse() ){
    FlushPort_mavtunnel();
  }else{
    FlushPort_direct();
  }
}

sub ReadPortOneByte{
  #Win32::GUI::DoEvents();
  if( MavlinkTunnelIsInUse() ){
    MavlinkReceiveReadPort();
    return ReadPortOneByte_mavtunnel();
  }else{
    return ReadPortOneByte_direct();
  }
}

sub GetTimeoutsForReading{
  my $timeoutfirst = 20*$ExecuteCmdTimeOutFirst + $ExtendedTimoutFirst;
  $ExtendedTimoutFirst = 0;

  my $timeout = 20*$ExecuteCmdTimeOut; #timeout in 100 ms

  if( $timeout < 200 ){ $timeout = 200; }

  if( $Baudrate <= 38400 ){ $timeout += 20*$ExecuteCmdTimeOut; } #add time for slow connetions

  if( MavlinkTunnelIsInUse() ){
    #$timeoutfirst += 1000;
    #$timeout += 1000;
  }
  return( $timeout, $timeoutfirst );
}

#this is the main communication function
# no parameters: terminates when end char is recieved, can't be used for data transfers!
# one parameter: reads for the expected number of characters, len is exclusive the crc
# port needs to be open, $Port needs to be set
#global parameters
# $ExecuteCmdTimeOutFirst
# $ExecuteCmdTimeOut
#flags:
# $ExtendedTimoutFirst
# allows to momentarily increase the timeout for first char, this is needed for e.g. StoreToEERPOM
# $ReadCmdDebug
#COMMENT: this is not really good: when len=0 where can be a problem when 't''e''c''o' occur inteh data stream!!
sub ReadCmd{
  my $len = 0; #length of response
  if( scalar @_ ){ #there is one parameter
    $len = shift;
    if( not defined $len ){ $len = 0; }elsif( $len < 0 ){ $len = 0; }
  }
  if( $len > 0 ){ $len += 2; } #take CRC into account  #$len>0 indicates that the command returns more than the end char
  #read
  my $res = ''; my $count = 0; my $result = '';
  my ($timeout, $timeoutfirst) = GetTimeoutsForReading();
  my $tmo = GetTickCount() + $timeout;
  my $tmofirst = GetTickCount() + $timeoutfirst;
  do{
    my $t = $tmo;
    if( $count == 0 ){ $t = $tmofirst; }
    if( GetTickCount() > $t ){ return ''; } #timeout!
    my ($i, $s) = ReadPortOneByte(); #read one character
    #if($ReadCmdDebug){ TextOut( "?".StrToHexstr($s)."?" ); } TextOut( ",".StrToHexstr($s) );
    $count += $i;
    $result .= $s;
    if( $len > 0 ){
      if( length($result) >= $len ){ $res = substr($result,$len,500); }else{ $res = ''; } #get the full rest of the string
    }else{
      $res = substr($result,length($result)-1,500); #get last char from string
    }
    if( $res eq 't' ){ return 't'; }
    if( $res eq 'e' ){ return 'e'; }
    if( $res eq 'c' ){ return 'c'; }
  }while( $res ne "o" );
  #if($ReadCmdDebug){ TextOut( StrToHexstr($result)."!" ); }
  #TextOut( "!".StrToHexstr($result)."!" );
  #check crc
  if( $len > 0 ){
    my $crcOK = check_crc($result, $len, 0);
    if( $crcOK != 1 ){ return 'c'; }
  }
  return $result;
}

#is called from outside the DataDisplay
sub ExecuteCmd{
  WritePort( shift ); #consumes first parameter, is the command!
  return ReadCmd( shift ); #consumes second parameter, is the length of expected values!
}

sub ExecuteCmdwCrc{
  my $cmd= shift; my $params= shift; my $reslen= shift;
  return ExecuteCmd( $cmd.add_crc_to_data($params), $reslen );
}

#is called in Timer
sub ExecuteCmdTimer{
  return ExecuteCmd( shift, shift );
}


############################################################################
# TIME SCHEDULER

my $SYSTICKTIME = 40;

sub SetIntTime{
  my $time_ms = shift;
  return int( $time_ms/$SYSTICKTIME + 0.49 );
}

$w_Main->AddTimer( 'm_Timer', 0 );
$w_Main->m_Timer->Interval( $SYSTICKTIME );
my $MainTimerCounter = 1;
my $MainTimerBlinkerCounter = 1;
my $ConnectionLostCounter = 0;
my $AutoWritePIDTimerCounter = 1;


sub m_Timer_Timer{
  if( $Execute_IsRunning ){ return 1; }
  my $s = '';
  $MainTimerCounter--;
  if( $MainTimerCounter < 0 ){ $MainTimerCounter = SetIntTime(250); }
  $MainTimerBlinkerCounter--;
  if( $MainTimerBlinkerCounter < 0 ){ $MainTimerBlinkerCounter = SetIntTime(300); }
  $AutoWritePIDTimerCounter--;
  if( $AutoWritePIDTimerCounter < 0 ){ $AutoWritePIDTimerCounter = SetIntTime(250); }
  #mavlink
  MavlinkReceiveTimer();
  #some others
  if( (not $Connected) and
      (not $ConfigureGimbalTool_IsRunning) and
      (not $Acc16PCalibration_IsRunning) and
      (not $InputsTool_IsRunning) and
      (not $MavlinkInspectorTool_IsRunning)
      ){
    $w_Main->m_StatusField->Text( 'no connection' );
    $w_Main->m_StatusBlinker->Change( -background => [255,0,0] );
    $w_Main->m_StatusBlinker->InvalidateRect( 1 );
    DashboardStatusTextClearTo( 'no connection' );
    return 1;
  }
  #blinker
  if( $MainTimerBlinkerCounter <= 3 ){
    $w_Main->m_StatusBlinker->Change( -background => [0,255,0] );
  }else{
    $w_Main->m_StatusBlinker->Change( -background => [212,212,212] );
  }
  $w_Main->m_StatusBlinker->InvalidateRect( 1 );
  #read required data
  $s = '';
  if( $DataDisplay_IsRunning ){
    FlushPort(); #this is to get back in track in case of issue
    $s = ExecuteCmdTimer( 'd', $CMD_d_PARAMETER_ZAHL*2 );
  }elsif( $Acc16PCalibration_IsRunning ){
    $w_Main->m_StatusField->Text( 'acc calibration' );
    DashboardStatusTextClearTo( 'acc calibration running' );
    return 1;
  }elsif( $InputsTool_IsRunning ){
    $w_Main->m_StatusField->Text( 'inputs tool' );
    DashboardStatusTextClearTo( 'inputs tool running' );
    return 1;
  }elsif( $MavlinkInspectorTool_IsRunning ){
    $w_Main->m_StatusField->Text( 'mavlink inspector tool' );
    DashboardStatusTextClearTo( 'mavlink inspector tool running' );
    return 1;
  }elsif( $ConfigureGimbalTool_IsRunning ){
    $w_Main->m_StatusField->Text( 'configure gimbal tool' );
    DashboardStatusTextClearTo( 'configure gimbal tool running' );
    return 1;
  }else{
    if( $MainTimerCounter != 0 ){ goto EXIT; }
    FlushPort(); #this is to get back in track in case of issue
    $s = ExecuteCmdTimer( 's', $CMD_s_PARAMETER_ZAHL*2 );
  }
#Win32::GUI::DoEvents();
  #check if connection still ok
  if( substr($s,length($s)-1,1) ne 'o' ){
      $ConnectionLostCounter++;
      if( $ConnectionLostCounter > $MaxConnectionLost ){
        TextOut( "\r\n".'CONNECTION is LOST!'."\r\n" );
        DisconnectFromBoard(0);
      }
    return 1;
  }
  $ConnectionLostCounter = 0;
  #do the required things
  ExtractStatusInfo( $s );
  if( $DataDisplay_IsRunning ){
    DataDisplayDoTimer( $s );
  }
  StatusBarStatusText();
  DashboardStatusText();
EXIT:
#  if( $MainTimerCounter==0 ){
  if( 1 ){
    AutoWritePID_CheckIfItShouldBeDone();
    #TextOut("!");
  }
  1;
}

sub ConnectionIsValid{
  if( $Connected != 1 ){ return 0; }
  if( $ConnectionLostCounter > 0 ){ return 0; }
  return 1;
}

#disconnect initiated by button
sub DisconnectFromBoardByButton{
  DisconnectFromBoard(0);
}

#connect initiated by button
sub ConnectToBoardByButton{
  ConnectToBoard();
}

#parameter: 1 = clear text field
sub DisconnectFromBoard{
  DataDisplayHalt();
  DataDisplayClearStatusFields();
  if( $Acc16PCalibration_IsRunning ){ Acc16PCalibrationHalt(); } #in order to not call it when acc calib was not yet created
  if( $InputsTool_IsRunning ){ InputsToolHalt(); } #in order to not call it when acc calib was not yet created
  if( $MavlinkInspectorTool_IsRunning ){ MavlinkInspectorToolHalt(); } #in order to not call it when acc calib was not yet created
  ClosePort();
  $Connected = 0;
  $w_Main->m_StatusField->Text( 'not connected' );
  ClearOptions(shift);
  $w_Main->m_Port->Enable();
  $w_Main->m_Mavlink_check->Enable();
  MavlinkStatusDefault();
  $w_Main->m_Connect->Text( 'Connect' );
  return 1;
}

#flag: $SkipExecuteRead
sub ConnectToBoard{
  my $SkipRead = $SkipExecuteRead;
  $SkipExecuteRead = 0;
  if( $Connected ){ return 1; }
  TextOut_( "\r\n".'Connecting... Please wait!' );
  #open port
  if( not OpenPort() ){ DisconnectFromBoard(0); return 0; }
  #find mavlink gimbal
  my $found = FindGimbal();
  MavlinkSetIgnoreHeartbeats(); #we don't need to bothetr anymore
  if( $found != 1 ){ TextOut( "\r\n".'Read... ABORTED!'."\r\n" ); DisconnectFromBoard(0); return 0; }
  #check connection
  my ($Version,$Name,$Board,$Layout,$Capabilities) = GetControllerVersion();
  if( $Version eq '' ){ DisconnectFromBoard(0); return 0; }
  #check layout version
  my $layoutfound = 0;
#  foreach my $supportedlayout ( @SupportedBGCLayoutVersions ){
#    if( uc($Layout) eq uc($supportedlayout) ){ $layoutfound = 1; last; }
#  }
  if( uc($Layout) eq uc($SupportedBGCLayoutVersion) ){ $layoutfound = 1; }
  if( $layoutfound == 0 ){
    TextOut( "\r\n".'Read... ABORTED!' );
    TextOut( "\r\n".'The connected controller board or its firmware version is not supported!' );
    TextOut( "\r\n".'Retry with GUI version '.$Version."\r\n" );
    DisconnectFromBoard(0);
    return 0;
  }
  #handle the capabilities
  my $FocEnabled = CheckStatus($Capabilities,$BOARD_CAPABILITY_FOC);
  if( $FocEnabled ){
    BoardConfiguration_HandleChange($BOARDCONFIGURATION_IS_FOC); #switch if needed
  }else{
    BoardConfiguration_HandleChange($BOARDCONFIGURATION_IS_DEFAULT); #switch if needed
  }
  #everything is OK
  SetOptionField( $NameToOptionHash{'Firmware Version'}, $Version );
  SetOptionField( $NameToOptionHash{'Board'}, $Board );
  SetOptionField( $NameToOptionHash{'Name'}, $Name );
  Option_SetBackground( $NameToOptionHash{'Firmware Version'}, $OptionValidColor );
  Option_SetBackground( $NameToOptionHash{'Board'}, $OptionValidColor );
  Option_SetBackground( $NameToOptionHash{'Name'}, $OptionValidColor );
  TextOut_( "\r\n".'CONNECTED' );
  $w_Main->m_Connect->Text( 'Disconnect' );
  $w_Main->m_Mavlink_check->Disable();
  $w_Main->m_Port->Disable();
  $f_Tab{calibrateacc}->caac_StoreInEEprom->Enable();
  $ConnectionLostCounter = 0;
  $Connected = 1;
  if( not $SkipRead ){
    TextOut_( "\r\n" );
    if( !ExecuteRead() ){ DisconnectFromBoard(0); return 0; }
  }
#TODO: do also a status ???
  return 1;
}

sub ConnectToBoardwoRead{
  SetSkipExecuteRead(1);
  ConnectToBoard();
}

#is called ONYL from connect board, or maybe other places where connection to the board is made
#flag: none
sub GetControllerVersion{
  my $version= ''; my $name= ''; my $board= ''; my $layout= ''; my $ver =''; my $capabilities= '';
  TextOut_( "\r\n".'v... ' );
  my $s = ExecuteCmd( 'v', (16)*3 +2+2+2 );
  if( substr($s,length($s)-1,1) eq 'o' ){
    $version = substr($s,0,16);
    $version =~ s/[ \s\0]*$//; #remove blanks&cntrls at end
    $name = substr($s,16,16);
    $name =~ s/[ \s\0]*$//; #remove blanks&cntrls at end
    $board = substr($s,32,16);
    $board =~ s/[ \s\0]*$//; #remove blanks&cntrls at end
    ($ver,$layout,$capabilities) = unpack( "v3", substr($s,48,6) );
    $capabilities = UIntToBitstr($capabilities);
    #$capabilities= '0x'.UIntToHexstr($capabilities);
    TextOut_( $version );
    #TextOut( " Ver:".$ver."!" );
    #TextOut( " Layout:".$layout."!" );
    #TextOut( " Capabilities:".$capabilities."!" );
  }else{
    TextOut( "\r\n".'Read... ABORTED!'."\r\n" );
    return ('','','','');
  }
  return ($version,$name,$board,$layout,$capabilities);
EXIT:
  return ('','','','','');
}


sub UpdateMavlinkStatus{
  my $guisysid = shift;
  my $guicompid = shift;
  my $apsysid = shift;
  my $apcompid = shift;
  my $gimbalsysid = shift;
  my $gimbalcompid = shift;
  if( ($gimbalcompid ne '-') and ($gimbalcompid >= 100 ) and ($gimbalcompid <= 105) ){
    $f_Tab{dashboard}->dashboard_MavlinkStatus_n->Text("GUI\r\nautopilot\r\ncamera");
  }else{
    $f_Tab{dashboard}->dashboard_MavlinkStatus_n->Text("GUI\r\nautopilot\r\ngimbal");
  }
  $f_Tab{dashboard}->dashboard_MavlinkStatus_s->Text("system ID: $guisysid\r\nsystem ID: $apsysid\r\nsystem ID: $gimbalsysid");
  $f_Tab{dashboard}->dashboard_MavlinkStatus_c->Text("component ID: $guicompid\r\ncomponent ID: $apcompid\r\ncomponent ID: $gimbalcompid");
}


#returns 1: ok, -1: port not open, -2: timeout
sub FindGimbal{
  if( not MavlinkTunnelIsInUse() ){ return 1; }
  TextOut_( "\r\n".'waiting for gimbal heartbeat...' );
  MavlinkGimbalReset();
  if( not $PortIsOpen ){
    TextOut_( "\r\n".'waiting for gimbal heartbeat... ABORTED! Port not open.' ); return -1;
  }
  my $guisysid = '-'; my $guicompid = '-';
  my $apsysid = '-'; my $apcompid = '-';
  my $gimbalsysid = '-'; my $gimbalcompid = '-';
  UpdateMavlinkStatus($guisysid,$guicompid,$apsysid,$apcompid,$gimbalsysid,$gimbalcompid);
  #theory of operation:
  # nothing after 3 secs => set default SysId, start emitting gui heartbeat with default SysId
  # only autopilot after 3 secs => start emitting gui heartbeat with autopilot SysId
  # no gimbal after 6 secs => abbort
  # both gimbal and autopilot => continue
  # only gimbal within 1.5 sec => continue
  my $tmo = GetTickCount() + 6000;  #6 secs max
  my $minimum_tmo = GetTickCount() + 2000; #wait at least this time, unless both gimbal and autopilot found
  my $findsysid_tmo = GetTickCount() + 3000;
  my $heartbeat_next_tick = GetTickCount() + 500;
  my $autopilotfound = 0;
  my $emitheartbeat = 0;
  while(1){
    if( GetTickCount() > $tmo ){
      TextOut_( "\r\n".'waiting for gimbal heartbeat... ABORTED! Timeout.' ); return -2;
    }
    Win32::GUI::DoEvents();
    MavlinkReceive();
    if( GetTickCount() > $heartbeat_next_tick ){
      $heartbeat_next_tick = GetTickCount() + 500;
      if( $emitheartbeat ){ MavlinkSendGuiHeartbeat(); }
    }
    if( not $autopilotfound and MavlinkAutopilotIsFound() ){
      $autopilotfound = 1;
      MavlinkSetAutopilotSysId();
      my ($sysid) = MavlinkGetGimbalSysComId();
      TextOut_( "\r\n".'autopilot at system ID: '.$sysid );
      $apsysid = $sysid; $apcompid = 1;
      if( not MavlinkGimbalIsFound() and not MavlinkCameraIsFound()){ #we only need to do this if we don't yet have the gimbal
        $emitheartbeat = 1;
        $minimum_tmo = GetTickCount() + 2000;
        TextOut_( "\r\n".'start emitting hearbeat with system ID: '.$sysid.', component ID: '.$MavlinkGuiComponentId );
        $guisysid = $apsysid; $guicompid = $MavlinkGuiComponentId;
        UpdateMavlinkStatus($guisysid,$guicompid,$apsysid,$apcompid,$gimbalsysid,$gimbalcompid);
      }
    }
    if( not MavlinkGimbalIsFound() and not MavlinkCameraIsFound() and not $emitheartbeat and (GetTickCount() > $findsysid_tmo) ){
      MavlinkSetDefaultSysId();
      my ($sysid) = MavlinkGetGimbalSysComId();
      $emitheartbeat = 1;
      $minimum_tmo = GetTickCount() + 2000;
      TextOut_( "\r\n".'start emitting hearbeat with system ID: '.$sysid.', component ID: '.$MavlinkGuiComponentId );
      $tmo += 1000; #extend tmo by 1 sec
      $guisysid = $sysid; $guicompid = $MavlinkGuiComponentId;
      UpdateMavlinkStatus($guisysid,$guicompid,$apsysid,$apcompid,$gimbalsysid,$gimbalcompid);
    }
    if( MavlinkGimbalIsFound() and MavlinkAutopilotIsFound() ){ last; } #done
    if( $emitheartbeat and MavlinkGimbalIsFound() ){ last; }
    if( (GetTickCount() > $minimum_tmo) and MavlinkGimbalIsFound() ){ last; } #we have the gimbal and waited 1.5secs
    if( (GetTickCount() > $minimum_tmo) and not MavlinkGimbalIsFound() and MavlinkCameraIsFound() ){
      MavlinkSetCameraSysCompId();
      last;
    } #we have a camera and waited 1.5secs
  }
  my ($sysid,$compid,$name) = MavlinkGetGimbalSysComId();
  if( $name =~ /Camera/ ){
    TextOut_( "\r\n".'camera at system ID: '.$sysid.', component ID: '.$compid.' = '.$name );
  }else{
    TextOut_( "\r\n".'gimbal at system ID: '.$sysid.', component ID: '.$compid.' = '.$name );
  }
  $guisysid = $gimbalsysid = $sysid; $gimbalcompid = $compid; $guicompid = $MavlinkGuiComponentId;
  if( MavlinkAutopilotIsFound() ){ $apsysid = $sysid; $apcompid = 1; } #should be set already, but can't harm redoing it
  UpdateMavlinkStatus($guisysid,$guicompid,$apsysid,$apcompid,$gimbalsysid,$gimbalcompid);
  return 1;
}




############################################################################
# MAIN COMMUNICATION ROUTINES

#flag: $ReadDetailsOut
sub ExecuteGetCommand{
  my $s=''; my $params='';
  #read options
  TextOut_( "\r\n".'g... ' );
  $s = ExecuteCmd( 'g', $CMD_g_PARAMETER_LEN+$SCRIPTSIZE );
  if( substr($s,length($s)-1,1) eq 'o' ){
    $params = StrToHexstr( substr($s,0,length($s)-3) ); #strip off crc and 'o'
    my $crc = StrToHexstr( substr($s,length($s)-3,2) ); #get crc
    #TextOut("\r\n".$params."\r\n" );
  }else{
    TextOut( "\r\n".'Read... FAILED!'."\r\n" ); goto EXIT;
  }
  TextOut( "ok" );
  $OptionsLoaded = 0; ##is dirty: this prevents that background colors are changed too early
  my $out = 0;
  if( $ReadDetailsOut and $ReadWriteWithFullOutput_Global ){ $out = 1; }
  my $optionscount = 0;
  foreach my $Option (@OptionList){
    if( OptionToSkip($Option) ){ next; } #this is how a STRing is detected, somewhat dirty
    if( $Option->{adr} < 0 ){ next; }
    if( $Option->{adr} < 10 ){ $s = '0'.$Option->{adr}; }else{ $s = $Option->{adr}; }
    if( $out ){ TextOut_( "\r\n".$s.' -> '.$Option->{name}.': ' ); }
    if( $Option->{type} eq 'SCRIPT' ){
      $s = substr($params,2*$CMD_g_PARAMETER_LEN,2*$SCRIPTSIZE);
      if($out){ TextOut_( "script hex code" ); }
    }elsif( $Option->{size} == 2 ){
      $s = substr($params,2*$PosInBuf[$Option->{adr}],2*2);
      $s = substr($s,2,2).substr($s,0,2); #SWAP BYTES!
      my $sx2 = $s;
      $s = HexstrToDez($s);  if($out){ TextOut_( "$s "."(0x".$sx2.")" ); }
    }elsif( $Option->{size} == 1 ){
      $s = substr($params,2*$PosInBuf[$Option->{adr}],2*1);
      my $sx1 = $s;
      $s = HexstrToDez($s);  if($out){ TextOut_( "$s "."(0x".$sx1.")" ); }
    }else{
      TextOut_( "\r\nERROR in ExecuteGetCommand()!\r\n" ); goto EXIT;
    }
    SetOptionField( $Option, $s ); #$s is an unsigend value, is converted to signed if need by the function
    WaitForJobDone();
    $optionscount++;
  }
  #TextOut_( "\r\n".'read number of parameters '.$optionscount );
  $ReadDetailsOut = 1;
  return 1;
EXIT:
  ResetFlags();
  return ('','','','');
}


#flags: $DelayBeforeGet, $WithGet
sub ExecuteCommandFull{
  my $CMD= shift; my $MSG= shift; my $MSG2= shift; my $TEST= shift; my $LEN= shift;
  if( $TEST ){
    TextOut( "\r\n".$MSG.'... Please wait!' );
    if( not ConnectionIsValid() ){ TextOut( "\r\n".$MSG.'... ABORTED!'."\r\n" ); goto EXIT; }
  }
  TextOut_( "\r\n".$CMD.'... ' );
  my $s = ExecuteCmd( $CMD, $LEN );
  if( substr($s,length($s)-1,1) ne 'o' ){ TextOut( "\r\n".$MSG.'... FAILED!'."\r\n" ); goto EXIT; }
  TextOut_( 'ok' );
  if( $DelayBeforeGet > 0 ){
    TextOut( "\r\n".'Please wait a moment... ' ); _delay_ms($DelayBeforeGet); TextOut( 'ok' );
  }
  $DelayBeforeGet = 0;
  if( $WithGet ){
    SetReadDetailsOut(0);
    if( not ExecuteGetCommand() ){ goto EXIT; }
    SetOptionsLoaded(1);
  }
  $WithGet = 0;
  TextOut( "\r\n".$MSG.'... DONE!' );
  if( $MSG2 ne '' ){ TextOut( "\r\n".$MSG2 ); }
  TextOut( "\r\n" );
  return (1,$s);
EXIT:
  ResetFlags();
  return (0,'');
}

sub ExecuteCommandFullwoGet{
  SetWithGet(0);
  return  ExecuteCommandFull( shift, shift, shift, shift, shift );
}

sub ExecuteCommandFullwGet{
  SetWithGet(1);
  return  ExecuteCommandFull( shift, shift, shift, shift, shift );
}

#  if( $v<0 ){ $v = $v+65536; } ??????????
# writing of paramters always includes a CRC over the data field
#flags: none
sub ExecuteCommandWritewoGet{
  my $CMD= shift; my $MSG= shift; my $MSG2= shift; my $PARAMS= shift; my $TEST= shift;
  if( $TEST ){
    TextOut( "\r\n".$MSG.'... Please wait!' );
    if( not ConnectionIsValid() ){ TextOut( "\r\n".$MSG.'... ABORTED!'."\r\n" ); goto EXIT; }
  }
  my $s = add_crc_to_data( $PARAMS );
  TextOut( "\r\n".$CMD.'... ' );
  $s = ExecuteCmd( $CMD.$s );
  my $response = substr($s,length($s)-1,1);
  if( $response ne 'o' ){
    TextOut( "\r\n".$MSG.'... ABORTED! ('.$s.')' );
    if( $response eq 't' ){
      TextOut( "\r\n".'Timeout error while writing to controller board!'."\r\n" );
    }elsif( $response eq 'c' ){
      TextOut( "\r\n".'CRC error while writing to controller board!'."\r\n" );
    }elsif( $response eq 'e' ){
      TextOut( "\r\n".'Command error while writing to controller board!'."\r\n" );
    }else{
      TextOut( "\r\n".'Timeout while writing to controller board!'."\r\n" );
    }
    goto EXIT;
  }
  TextOut( 'ok' );
  TextOut( "\r\n".$MSG.'... DONE!'."\r\n" );
  return 1;
EXIT:
  ResetFlags();
  return 0;
}


sub ExecuteReadwoFirstReturn{
  TextOut( 'Read... Please wait!' );
  if( not ConnectionIsValid() ){ TextOut( "\r\n".'Read... ABORTED!'."\r\n" ); goto EXIT; }
  if( not ExecuteGetCommand() ){ goto EXIT; }
  SetOptionsLoaded(1);
  TextOut( "\r\n".'Read... DONE!'."\r\n" );
  return 1;
EXIT:
  ResetFlags();
  return 0;
}


sub ExecuteRead{
  TextOut( "\r\n" );
  return ExecuteReadwoFirstReturn();
}


sub ExecuteWrite{
  my $store_to_eeprom_flag = shift;
  my $current_tab_only_flag = shift;
  TextOut( "\r\n".'Write... Please wait!' );
  if( not ConnectionIsValid() ){
    TextOut( "\r\n".'Write... ABORTED!'."\r\n" ); goto EXIT;
  }
  my $s = ''; my $params = ''; my @paramslist = ();
  #read options, this is a MUST to ensure that options not handled by GUI are not modified
  TextOut_( "\r\n".'g... ' );
  $s = ExecuteCmd( 'g', $CMD_g_PARAMETER_LEN+$SCRIPTSIZE );
  if( substr($s,length($s)-1,1) ne 'o' ){
    TextOut( "\r\n".'Write... FAILED!'."\r\n" ); goto EXIT;
  }
  $params = StrToHexstr( substr($s,0,length($s)-1) );
  #TextOut_( $params );
  TextOut_( 'ok' );
  #prefill paramslist with values from read, is needed since GUI may not use all parameters
  for(my $i=0; $i<$CMD_g_PARAMETER_ZAHL; $i++){
    $paramslist[$i] = substr($params,2*$PosInBuf[$i],2*SizeOfOptionFromPosInBuf($i));
  }
  $paramslist[$CMD_g_PARAMETER_ZAHL-1] = substr($params,2*$PosInBuf[$CMD_g_PARAMETER_ZAHL-1]); #that's the scripts
  #prepare params for write
  # find currently opened tab windows
  my @openTabWindows = ();
  foreach my $tab (@f_TabWindows){
    if( $tab->{tab}->IsVisible() ){ push(@openTabWindows, $tab->{index}); }
  }
  if( scalar @openTabWindows == 0 ){ #if there is no open, take top tab
    push(@openTabWindows, $w_Main->w_Tab->SelectedItem());
  }
  #TextOut('$');foreach my $i (@curTabs){TextOut($i.',');} TextOut('$');
  my $display = 0;
  if( $ReadWriteWithFullOutput_Global ){ $display = 1; }
  foreach my $Option( @OptionList ){
    if( OptionToSkip($Option) ){ next; } #this is how a STRing is detected, somewhat dirty
    if( $Option->{adr} < 0 ){ next; } #param has been opted out by setting invalid adr

#    if( $current_tab_only_flag ){
#      my $option_tab_index = GetTabIndex($Option->{page});
#TextOut( $option_tab_index.'!' );
#      my $is_top = 0;
#      foreach my $index (@openTabWindows){
#        if( $index == $option_tab_index ){ $is_top = 1; }
#      }
#      if( !$is_top ){ TextOut( 's!' ); next; }
#    }

    if( $Option->{adr} < 10 ){ $s = '0'.$Option->{adr}; }else{ $s = $Option->{adr}; }
    if($display){ TextOut_( "\r\n".$s.' -> '.$Option->{name}.': ' ); }
    $s = GetOptionField( $Option ); #$s is an unsigend value, was converted to unsigned by function
    if( $Option->{type} eq 'SCRIPT' ){
      if($display){ TextOut_( 'script hex code' ); }
      #ensure correct length of script
      $s = substr($s,0,2*$SCRIPTSIZE);
      while( length($s) < 2*$SCRIPTSIZE ){ $s .= 'FF'; }
      #$s was converted by GetOptionField to hex bytes; but add a datavalue beforehand to account for dummy
      $s = '0000'.$s;
    }elsif( $Option->{size} == 2 ){
      if($display){ TextOut_( $s ); }
      $s = UIntToHexstrSwapped($s); #$s= UIntToHexstr($s); $s= substr($s,2,2).substr($s,0,2);
      if($display){ TextOut_( " (0x".$s.")" ); }
    }elsif( $Option->{size} == 1 ){
      if($display){ TextOut_( $s ); }
      $s = UCharToHexstr($s);
      if($display){ TextOut_( " (0x".$s.")" ); }
    }else{
      TextOut_( "\r\nERROR in ExecuteWrite()!\r\n" ); goto EXIT;
    }
    $paramslist[$Option->{adr}] = $s;
  }
  #write
  my $paramsoutstr = ''; $params = '';
  foreach (@paramslist){ $params .= $_; $paramsoutstr .= 'x'.$_;}
  $s = HexstrToStr($params);
  $s = add_crc_to_data( $s );
  TextOut( "\r\n".'p... ' );
  $s = ExecuteCmd( 'p'.$s );
  my $response = substr($s,length($s)-1,1);
  if( $response ne 'o' ){
    TextOut( "\r\n".'Write... FAILED! ('.$s.')'."\r\n" );
    if( $response eq 't' ){
      TextOut( "\r\n".'Timeout error while writing to controller board!'."\r\n" );
    }elsif( $response eq 'c' ){
      TextOut( "\r\n".'CRC error while writing to controller board!'."\r\n" );
    }elsif( $response eq 'e' ){
      TextOut( "\r\n".'Command error while writing to controller board!'."\r\n" );
    }else{
      TextOut( "\r\n".'Timeout while writing to controller board!'."\r\n" );
    }
    goto EXIT;
  }
  SetOptionsLoaded(1);
  TextOut( 'ok' );
  TextOut( "\r\n".'Write... DONE!'."\r\n" );
  if( $store_to_eeprom_flag > 0 ){
    _delay_ms(150);
    ExecuteStoreToEeprom();
  }
  return 1;
EXIT:
  ResetFlags();
  return 0;
}


sub ExecuteGetStatus{
  TextOut( "\r\n".'Get Status... Please wait!' );
  if( not ConnectionIsValid() ){ TextOut( "\r\n".'Get Status... ABORTED!'."\r\n" ); goto EXIT; }
  TextOut_( "\r\n".'s... ' );
  my $s = ExecuteCmd( 's', $CMD_s_PARAMETER_ZAHL*2 );
  if( substr($s,length($s)-1,1) ne 'o' ){
    TextOut( "\r\n".'Get Status... FAILED!'."\r\n" ); goto EXIT;
  }
  TextOut_( 'ok' );
  TextOut( "\r\n" );
  ExtractStatusInfo( $s );
  ExecuteGetStatusStatusText();
  TextOut( "\r\n".'Get Status... DONE!'."\r\n" );
  return 1;
EXIT:
  ResetFlags();
  return 0;
}


sub ExecuteStoreToEeprom{
  SetExtendedTimoutFirst(1000); #StoreToEerpom can take a while! so extend timeout
  return ExecuteCommandFullwoGet( 'xs', 'Store to EEPROM', '', 1 ); #no receive length needed
}

sub ExecuteRetrieveFromEeprom{
  SetDelayBeforeGet(1500); #wait before read
  return ExecuteCommandFullwGet( 'xr', 'Retrieve from EEPROM', '', 1 ); #no receive length needed
}

sub ExecuteEraseEeprom{
  #a restart will also be issued, so no need to do a read here
  return ExecuteCommandFullwoGet( 'xc', 'Erase EEPROM', 'NOTE: Please reset or power up the BGC board for proper operation!', 1 );  #no receive length needed
}

sub ExecuteDefault{
  SetDelayBeforeGet(1500); #wait before read
  return ExecuteCommandFullwGet( 'xd', 'Set to Default', '', 1 ); #no receive length needed
}

sub ExecuteLevelGimbal{
  return ExecuteCommandFullwoGet( 'xl', 'Level gimbal', '', 1 ); #no receive length needed
}

sub ExecuteGetCurrentEncoderPositions{
  return ExecuteCommandFullwGet( 'xp', 'Get current encoder positions', '', 1 ); #no receive length needed
}

sub ExecuteCalibrateRcTrim{
  if( $Execute_IsRunning ){ return 0; }
  $Execute_IsRunning = 1;
  SetDelayBeforeGet(1500); #wait before read
  my $ret = ExecuteCommandFullwGet( 'CR', 'Calibrate rc trims', '', 1 ); #no receive length needed
  $Execute_IsRunning = 0;
  return $ret;
}

sub ExecuteRestartController{
  #handle case if Data Display is running
  my $DataDisplay_WasRunning =  $DataDisplay_IsRunning;
  if( $DataDisplay_IsRunning > 0 ){
    DataDisplayHalt();
    _delay_ms(1000);
  }
  #now execute the "normal" execution route
  SetDelayBeforeGet(1500);  #we will also issue a restart, so wait
  my $ret = ExecuteCommandFullwGet( 'xx', 'Restart controller', '', 1 ); #no receive length needed
  if( not $ret ){ return 0; }
  #handle case if Data Display is running
  if( $DataDisplay_WasRunning > 0 ){
    _delay_ms(1000);
    DataDisplayRun();
  }
  return 1;
}


#not used
sub CheckConnection{
  TextOut_( 'döfksöfksdkfösk' ); return 0;
  TextOut_( "\r\n".'t... ' );
  my $s = ExecuteCmd( 't', 0 );
  if( $s ne 'o' ){
    TextOut(  "\r\n".'Connection to gimbal controller FAILED!'."\r\n" ); return 0;
  }
  TextOut_( 'ok' );
  return 1;
}


# Ende Main Window
###############################################################################









#-----------------------------------------------------------------------------#
###############################################################################
# BITMASK Window
###############################################################################
#-----------------------------------------------------------------------------#
#my $OptionBitmaskBackgroundColor= [96,96,96];

my $OptionBitmaskXsize= 330;
my $OptionBitmaskYsize= 250;

my $w_OptionBitmask = Win32::GUI::DialogBox->new( -name=> 'optionbitmask_Window', -parent => $w_Main, -font=> $StdWinFont,
  -text=> 'Option Bitmask', -size=> [$OptionBitmaskXsize,$OptionBitmaskYsize],
  -helpbox => 0,
#  -background=>$OptionBitmaskBackgroundColor,
);
$w_OptionBitmask->SetIcon($Icon);

my $OptionBitmask_Option; #this is to store the currently handled option

sub optionbitmask_Window_Terminate{ $w_OptionBitmask->Hide(); 0; } #must be all -1 when DoModal() is used!!
sub optionbitmask_Cancel_Click{ $w_OptionBitmask->Hide(); 0; }
sub optionbitmask_OK_Click{ OptionBitmaskCloseOk(); $w_OptionBitmask->Hide(); 0; }

$xpos = 15;
$ypos = 15;
for(my $i = 0; $i < 16; $i++){
  $w_OptionBitmask->AddCheckbox( -name=> 'optionbitmask_check'.$i,
    -text=> 'check'.$i, -pos=> [$xpos,$ypos], -width=> 200, -height=> 26,
  );
  $ypos += 23;
}
$w_OptionBitmask->AddButton( -name=> 'optionbitmask_OK', #-font=> $StdWinFont,
  -text=> 'OK', -pos=> [$OptionBitmaskXsize-100,15], -width=> 80, -height=> 26,
);
$w_OptionBitmask->AddButton( -name=> 'optionbitmask_Cancel', #-font=> $StdWinFont,
  -text=> 'Cancel', -pos=> [$OptionBitmaskXsize-100,15+30], -width=> 80, -height=> 26,
);
$w_OptionBitmask->AddButton( -name=> 'optionbitmask_Preset1', #-font=> $StdWinFont,
  -text=> '', -pos=> [$OptionBitmaskXsize-100,25+2*30], -width=> 80, -height=> 26,
  -onClick=> sub{ OptionBitmaskPresetClick(1); 1;},
);
$w_OptionBitmask->AddButton( -name=> 'optionbitmask_Preset2', #-font=> $StdWinFont,
  -text=> '', -pos=> [$OptionBitmaskXsize-100,25+3*30], -width=> 80, -height=> 26,
  -onClick=> sub{ OptionBitmaskPresetClick(2); 1;},
);
$w_OptionBitmask->AddButton( -name=> 'optionbitmask_Preset3', #-font=> $StdWinFont,
  -text=> '', -pos=> [$OptionBitmaskXsize-100,25+4*30], -width=> 80, -height=> 26,
  -onClick=> sub{ OptionBitmaskPresetClick(3); 1;},
);
$w_OptionBitmask->AddButton( -name=> 'optionbitmask_Preset4', #-font=> $StdWinFont,
  -text=> '', -pos=> [$OptionBitmaskXsize-100,25+5*30], -width=> 80, -height=> 26,
  -onClick=> sub{ OptionBitmaskPresetClick(4); 1;},
);
$w_OptionBitmask->AddButton( -name=> 'optionbitmask_Preset5', #-font=> $StdWinFont,
  -text=> '', -pos=> [$OptionBitmaskXsize-100,25+6*30], -width=> 80, -height=> 26,
  -onClick=> sub{ OptionBitmaskPresetClick(5); 1;},
);
$w_OptionBitmask->{'optionbitmask_Preset1'}->Hide();
$w_OptionBitmask->{'optionbitmask_Preset2'}->Hide();
$w_OptionBitmask->{'optionbitmask_Preset3'}->Hide();
$w_OptionBitmask->{'optionbitmask_Preset4'}->Hide();
$w_OptionBitmask->{'optionbitmask_Preset5'}->Hide();
$w_OptionBitmask->Hide();


my @OptionBitmaskPresetValues = [];


sub OptionBitmaskPresetClick
{
  my $preset_nr = shift;
  my $value = $OptionBitmaskPresetValues[$preset_nr];
  for(my $i = 0; $i < 16; $i++){ $w_OptionBitmask->{'optionbitmask_check'.$i}->Checked(0); }
  my $i = 0;
  my $bitpos = 0;
  foreach my $bit (@{$OptionBitmask_Option->{bits}}){
    if( $bit ne '' ){
      if( $value & (1<<$bitpos) ){ $w_OptionBitmask->{'optionbitmask_check'.$i}->Checked(1); }
      $i++;
    }
    $bitpos++;
  }
}


sub OptionBitmaskShow
{
  $OptionBitmask_Option = shift;
  my $value = shift;

  $w_OptionBitmask->Text('Bitmask for: '.$OptionBitmask_Option->{name});

  for(my $i = 0; $i < 16; $i++){
    $w_OptionBitmask->{'optionbitmask_check'.$i}->Hide();
    $w_OptionBitmask->{'optionbitmask_check'.$i}->Checked(0);
  }
  for(my $i = 1; $i <= 5; $i++){
    $w_OptionBitmask->{'optionbitmask_Preset'.$i}->Hide();
  }

  my $i = 0;
  my $bitpos = 0;
  foreach my $bit (@{$OptionBitmask_Option->{bits}}){
    if( $bit ne '' ){
      $w_OptionBitmask->{'optionbitmask_check'.$i}->Text($bit);
      if( $value & (1<<$bitpos) ){ $w_OptionBitmask->{'optionbitmask_check'.$i}->Checked(1); }
      $w_OptionBitmask->{'optionbitmask_check'.$i}->Show();
      $i++;
    }
    $bitpos++;
  }

  my $preset_cnt = 0;
  if( defined $OptionBitmask_Option->{presets} ){
    #TextOut('presets exist');
    #we can't use hash since it is reordered, so we need to do it the complicated list way
    my $iskey = 1;
    my @presets = @{$OptionBitmask_Option->{presets}};
    foreach my $key (@presets){
      if($iskey){
        $preset_cnt++;
        $w_OptionBitmask->{'optionbitmask_Preset'.$preset_cnt}->Text($key);
        $iskey = 0;
      }else{
        $OptionBitmaskPresetValues[$preset_cnt] = $key;
        $w_OptionBitmask->{'optionbitmask_Preset'.$preset_cnt}->Show();
        $iskey = 1;
      }
    }
  }

  my ($x, $y) = ($w_Main->GetWindowRect())[0..1];
  $w_OptionBitmask->Move($x+150,$y+100 -70);
  if( $i < 4+$preset_cnt ){ $i = 4+$preset_cnt; }
  $w_OptionBitmask->Height(62 + $i*23);

  #$w_OptionBitmask->DoModal();
  $w_OptionBitmask->Show();
}


sub OptionBitmaskCloseOk
{
  my $newvalue = 0;
  my $i = 0;
  my $bitpos = 0;
  foreach my $bit (@{$OptionBitmask_Option->{bits}}){
    if( $bit ne '' ){
      if( $w_OptionBitmask->{'optionbitmask_check'.$i}->Checked() ){
        $newvalue += (1<<$bitpos);
      }
      $i++;
    }
    $bitpos++;
  }

  OptionBitmaskHandleCloseWithOk($OptionBitmask_Option, $newvalue);
}

# Ende # OptionBitmask Window
#####################












#-----------------------------------------------------------------------------#
###############################################################################
# Data Display Window
###############################################################################
#-----------------------------------------------------------------------------#
my $DataDisplay_LiveRecording = 0;
my $DataDisplay_LiveRecordingFile = '';
my $DataDisplay_LiveRecordingDelimiter = "\t";

$xsize = 725;
$ysize = 525;

my $ddBackgroundColor= [96,96,96];

# @DataMatrix is organized as a ring buffer
my $DataPos = 0; #that's there the next data is stored, one ahead of the last data
my $DataMatrixLength = 0; #that's how much data is currently in the ring buffer
my $DataBlockPos = 0;

my $PlotHeight = 131; #this used only in the initialization
my $PlotWidth = 600;
my $PlotMaxWidth = 3200; #1600; #2000; #that's the size of the ring buffer
my $PlotAngleRange = 1500;
my $PlotAngleOffset = 0.0;

# NEWVERSION V2
#V1: my $DataFormatStr= 'uuuuu'.'uu'. 'sss'.'sss' . 'sss'.'sss'.'sss'.'sss'.'sss'.'ss'.'s'.'u';
my $DataFormatStr =     'uuuuuuu'.'u'.'u'.'sss'.'sss'.'sss'.'sss'.'sss'.'sss'.'ss'.'s'.'s'.'u';

if( length($DataFormatStr) != $CMD_d_PARAMETER_ZAHL ){ die;}
#_i is the index in the @DataMatrix, _p is the index in the recieved data format
#  data array:              index in DataMatrix         index in 'd' cmd response str
my @DataMillis= ();         my $DataMillis_i= 0;        my $DataMillis_p= 7;

my @DataState= ();          my $DataState_i= 1;         my $DataState_p= 0;
my @DataStatus= ();         my $DataStatus_i= 2;        my $DataStatus_p= 1;
my @DataStatus2= ();        my $DataStatus2_i= 3;       my $DataStatus2_p= 2;
my @DataStatus3= ();        my $DataStatus3_i= 4;       my $DataStatus3_p= 3;
#my @DataPerformance= ();    my $DataPerformance_i= 6;   my $DataPerformance_p= 4; #comes later
my @DataBusError= ();       my $DataBusError_i= 5;      my $DataBusError_p= 5;
my @DataVoltage= ();        my $DataVoltage_i= 6;       my $DataVoltage_p= 6;

my @DataRx= ();             my $DataRx_i= 7;            my $DataRx_p= 9;
my @DataRy= ();             my $DataRy_i= 8;            my $DataRy_p= 10;
my @DataRz= ();             my $DataRz_i= 9;            my $DataRz_p= 11;

my @DataPitch= ();          my $DataPitch_i= 10;        my $DataPitch_p= 12;
my @DataRoll= ();           my $DataRoll_i= 11;         my $DataRoll_p= 13;
my @DataYaw= ();            my $DataYaw_i= 12;          my $DataYaw_p= 14;

my @DataPitch2= ();         my $DataPitch2_i= 13;       my $DataPitch2_p= 21;
my @DataRoll2= ();          my $DataRoll2_i= 14;        my $DataRoll2_p= 22;
my @DataYaw2= ();           my $DataYaw2_i= 15;         my $DataYaw2_p= 23;

my @DataPitchEncoder= ();   my $DataPitchEncoder_i= 16; my $DataPitchEncoder_p= 24;
my @DataRollEncoder= ();    my $DataRollEncoder_i= 17;  my $DataRollEncoder_p= 25;
my @DataYawEncoder= ();     my $DataYawEncoder_i= 18;   my $DataYawEncoder_p= 26;

my @DataPerformance= ();    my $DataPerformance_i= 19;  my $DataPerformance_p= 4;
my @DataLink1= ();          my $DataLink1_i= 20;        my $DataLink1_p= 27; #STorM32Link 1
my @DataLink2= ();          my $DataLink2_i= 21;        my $DataLink2_p= 28; #STorM32Link 2
my @DataLinkX= ();          my $DataLinkX_i= 22; # generated

my @DataPitchCntrl= ();     my $DataPitchCntrl_i= 23;   my $DataPitchCntrl_p= 15;
my @DataRollCntrl= ();      my $DataRollCntrl_i= 24;    my $DataRollCntrl_p= 16;
my @DataYawCntrl= ();       my $DataYawCntrl_i= 25;     my $DataYawCntrl_p= 17;

my @DataPitchRcIn= ();      my $DataPitchRcIn_i= 26;    my $DataPitchRcIn_p= 18;
my @DataRollRcIn= ();       my $DataRollRcIn_i= 27;     my $DataRollRcIn_p= 19;
my @DataYawRcIn= ();        my $DataYawRcIn_i= 28;      my $DataYawRcIn_p= 20;

my @DataAccAbs= ();         my $DataAccAbs_i= 29;        my $DataAccAbs_p= 29;
my @DataAccConfidence= ();  my $DataAccConfidence_i= 30; my $DataAccConfidence_p= 30;

my @DataLink3= ();          my $DataLink3_i= 31;         my $DataLink3_p= 31; #STorM32Link 3

my @DataIndex= ();          my $DataIndex_i= 32;
my @DataTime= ();           my $DataTime_i= 33;

my $DataCounter= 0; #this counts the number of data points since last clear
my $DataTimeCounter= 0; #this counts the overflows, it is not reset anywhere

my @DataMatrix = (
      \@DataMillis,
      @DataState, @DataStatus, @DataStatus2, @DataStatus3, \@DataBusError, \@DataVoltage,

      \@DataRx, \@DataRy, \@DataRz,
      \@DataPitch, \@DataRoll, \@DataYaw,
#these need to come right after IMU1 angle data for Paint loop to work
      \@DataPitch2, \@DataRoll2, \@DataYaw2,
      \@DataPitchEncoder, \@DataRollEncoder, \@DataYawEncoder,
      \@DataPerformance,
      \@DataPitchCntrl, \@DataRollCntrl, \@DataYawCntrl,

      @DataPitchRcIn, @DataRollRcIn, @DataYawRcIn,
      \@DataAccAbs, \@DataAccConfidence,
      \@DataLink1, \@DataLink2, \@DataLinkX, @DataLink3,

      \@DataIndex, \@DataTime,
  );

my $penPlot = new Win32::GUI::Pen( -color => [0,0,0], -width => 1); #black
my $brushPlot = new Win32::GUI::Brush( [191,191,191] ); #lightgray
my $brushPlotFrame = new Win32::GUI::Brush( [0,0,0] ); #white
my $penGrid = new Win32::GUI::Pen( -color=> [127,127,127], -width=> 1);
my $penZero = new Win32::GUI::Pen( -color=> [0,0,0], -width=> 1);
my $fontLabel = Win32::GUI::Font->new(-name=>'Lucida Console',-size=>9);

#rot, grün, blau, grey, greygrey,
my @GraphColors = ( [255,50,50], [0,255,0], [0,0,255],  [128,128,128], [64,196,196], #[64,64,64]
                    [192,0,0], [0,128,0], [0,255,255], #imu2 angles
                    [128,0,0], [0,192,0], [0,0,128], #encoder angles
                    [204,255,255], #performance
                    [0,128,255], #yaw vehicle
                    [0,128,255], #yaw earth
                    [0,128,255], #yaw2 earth
                    [0,0,0]);


my $w_DataDisplay= Win32::GUI::DialogBox->new( -name=> 'm_datadisplay_Window', #-font=> $StdWinFont,
  -text=> $BGCStr." Data Display",
  -pos=> [$DataDisplayXPos,$DataDisplayYPos],
  -size=> [$xsize+10,$ysize+10],
  -helpbox => 0,
  -background=>$ddBackgroundColor,
  -resizable => 1, #using this makes the window 10px smaller in each direction
  -minsize => [$xsize+10,$ysize+10],
  -maxsize => [$PlotMaxWidth+125,2000+394],
  -hasmaximize => 1,
#  -maximizebox => 1,  -hasminimize => 0,  -minimizebox => 0,
);
$w_DataDisplay->SetIcon($Icon);

sub DataDisplayMinimize{ if( $w_DataDisplay->IsVisible() ){ $w_DataDisplay->Minimize(); } }

sub DataDisplayActivate{ if( $w_DataDisplay->IsIconic() ){ $w_DataDisplay->Show(); } }

sub m_datadisplay_Window_Activate{ $w_Main->Show(); 1; }

$ypos = 15;
$w_DataDisplay->AddLabel( -name=> 'dd_State', -font=> $StdWinFont,
  -text=> $StateText[-1], -pos=> [10,$ypos], -width=> 60, -align=>'center', -background=>$StateColors[-1],
);

$ypos = 15;
$xpos = 80;
$w_DataDisplay->AddButton( -name=> 'dd_Start', -font=> $StdWinFont,
  -text=> 'Start', -pos=> [$xpos+375+10,$ypos-3], -width=> 80,
);
$w_DataDisplay->AddButton( -name=> 'dd_Clear', -font=> $StdWinFont,
  -text=> 'Clear', -pos=> [$xpos+530,$ypos-3], -width=> 35,
);
$w_DataDisplay->AddButton( -name=> 'dd_Save', -font=> $StdWinFont,
  -text=> 'Save', -pos=> [$xpos+565,$ypos-3], -width=> 35,
);
$w_DataDisplay->AddButton( -name=> 'dd_LiveRecording', -font=> $StdWinFont,
  -text=> 'Rec', -pos=> [$xpos+600,$ypos-3], -width=> 35,
);

$xpos = 80-120 + 40;
$w_DataDisplay->AddLabel( -name=> 'dd_Pitch_label', -font=> $StdWinFont,
  -text=> 'Pitch', -pos=> [$xpos+120,$ypos],
  -background=>$ddBackgroundColor,
  -foreground=> [255,255,255],
);
$w_DataDisplay->AddTextfield( -name=> 'dd_Pitch', -font=> $StdWinFont,
  -pos=> [$xpos+120+$w_DataDisplay->dd_Pitch_label->Width()+3,$ypos-3], -size=> [55,23],
  -align=> 'center',
);
$w_DataDisplay->AddLabel( -name=> 'dd_Roll_label', -font=> $StdWinFont,
  -text=> 'Roll', -pos=> [$xpos+215,$ypos],
  -background=>$ddBackgroundColor,
  -foreground=> [255,255,255],
);
$w_DataDisplay->AddTextfield( -name=> 'dd_Roll', -font=> $StdWinFont,
  -pos=> [$xpos+215+$w_DataDisplay->dd_Roll_label->Width()+3,$ypos-3], -size=> [55,23],
  -align=> 'center',
);
$w_DataDisplay->AddLabel( -name=> 'dd_Yaw_label', -font=> $StdWinFont,
  -text=> 'Yaw', -pos=> [$xpos+305,$ypos],
  -background=>$ddBackgroundColor,
  -foreground=> [255,255,255],
);
$w_DataDisplay->AddTextfield( -name=> 'dd_Yaw', -font=> $StdWinFont,
  -pos=> [$xpos+305+$w_DataDisplay->dd_Yaw_label->Width()+3,$ypos-3], -size=> [55,23],
  -align=> 'center',
);
$w_DataDisplay->AddTextfield( -name=> 'dd_YawEarth', -font=> $StdWinFont,
  -pos=> [$xpos+305+$w_DataDisplay->dd_Yaw_label->Width()+60,$ypos-3], -size=> [55,23],
  -align=> 'center',
);

$ypos = $ysize-55; #15;
$xpos = 80;
$w_DataDisplay->AddLabel( -name=> 'dd_LipoVoltage_label', -font=> $StdWinFont,
  -text=> 'Bat. Voltage', -pos=> [$xpos,$ypos],
  -background=>$ddBackgroundColor,
  -foreground=> [255,255,255],
);
$w_DataDisplay->AddLabel( -name=> 'dd_LipoVoltage', -font=> $StdWinFont,
  -pos=> [$xpos+$w_DataDisplay->dd_LipoVoltage_label->Width()+3,$ypos], -width=> 50,
  -background=>$ddBackgroundColor,
  -align=> 'center',
  -text=>'0 V',
);
$w_DataDisplay->AddLabel( -name=> 'dd_LipoVoltageStatus', -font=> $StdWinFont,
  -text=> $LipoVoltageText[-1],
  -pos=> [$xpos+$w_DataDisplay->dd_LipoVoltage_label->Width()+3+50,$ypos], -width=> 28,
  -align=>'center', -background=>, $LipoVoltageColors[-1]
);
$w_DataDisplay->AddLabel( -name=> 'dd_NTBusError_label', -font=> $StdWinFont,
  -text=> 'Bus Errors', -pos=> [$xpos+240-30,$ypos],
  -background=>$ddBackgroundColor,
  -foreground=> [255,255,255],
);
$w_DataDisplay->AddLabel( -name=> 'dd_NTBusError', -font=> $StdWinFont,
  -pos=> [$xpos+240-30+$w_DataDisplay->dd_NTBusError_label->Width()+3,$ypos], -width=> 50,
  -background=>$ddBackgroundColor,
  -align=> 'center',
  -text=>'0',
);
$xpos+= 7 - 60;
$w_DataDisplay->AddLabel( -name=> 'dd_ImuStatus_label', -font=> $StdWinFont,
  -text=> 'IMU', -pos=> [$xpos+420,$ypos],
  -background=>$ddBackgroundColor,
  -foreground=> [255,255,255],
);
$w_DataDisplay->AddLabel( -name=> 'dd_ImuStatus', -font=> $StdWinFont,
  -text=> $ImuStatusText[-1],
  -pos=> [$xpos+420+$w_DataDisplay->dd_ImuStatus_label->Width()+3,$ypos], -width=> 28,
  -align=>'center', -background=>, $Imu2StatusColors[-1]
);
$w_DataDisplay->AddLabel( -name=> 'dd_Imu2Status_label', -font=> $StdWinFont,
  -text=> 'IMU2', -pos=> [$xpos+420+57,$ypos],
  -background=>$ddBackgroundColor,
  -foreground=> [255,255,255],
);
$w_DataDisplay->AddLabel( -name=> 'dd_Imu2Status', -font=> $StdWinFont,
  -text=> $Imu2StatusText[-1],
  -pos=> [$xpos+420+57+$w_DataDisplay->dd_Imu2Status_label->Width()+3,$ypos], -width=> 28,
  -align=>'center', -background=>, $Imu2StatusColors[-1]
);
$w_DataDisplay->AddLabel( -name=> 'dd_EncAllStatus_label', -font=> $StdWinFont,
  -text=> 'ENC', -pos=> [$xpos+420+57,$ypos],
  -background=>$ddBackgroundColor,
  -foreground=> [255,255,255],
);
$w_DataDisplay->AddLabel( -name=> 'dd_EncAllStatus', -font=> $StdWinFont,
  -text=> $EncoderAllStatusText[-1],
  -pos=> [$xpos+420+57+$w_DataDisplay->dd_EncAllStatus_label->Width()+3,$ypos], -width=> 28,
  -align=>'center', -background=>, $EncoderAllStatusColors[-1]
);
$w_DataDisplay->AddLabel( -name=> 'dd_STorM32LinkStatus_label', -font=> $StdWinFont,
  -text=> 'LINK', -pos=> [$xpos+420+120+60,$ypos],
  -background=>$ddBackgroundColor,
  -foreground=> [255,255,255],
);
$w_DataDisplay->AddLabel( -name=> 'dd_STorM32LinkStatus', -font=> $StdWinFont,
  -text=> $STorM32LinkStatusText[-1],
  -pos=> [$xpos+420+120+60+$w_DataDisplay->dd_STorM32LinkStatus_label->Width()+3,$ypos], -width=> 28,
  -align=>'center', -background=>, $STorM32LinkStatusColors[-1]
);
$w_DataDisplay->AddLabel( -name=> 'dd_Storm32LinkA', #-font=> $StdWinFont,
  -text=>'0', -pos=> [$xpos+660,$ypos-8], -width=> 60,
  -background=>$ddBackgroundColor,
  -align=> 'left',
);

$ypos= 45;
$w_DataDisplay->AddLabel( -name=> 'dd_PlotR_label', -font=> $StdWinFont,
  -text=> 'estimated R', -pos=> [10,$ypos],
  -background=>$ddBackgroundColor,
  -foreground=> [255,255,255],
);
$w_DataDisplay->AddLabel( -name=> 'dd_PlotRx_label', -font=> $StdWinFont,
  -text=> 'Rx', -pos=> [10,$ypos+20], -width=> 60, -align=>'center', -background=>$GraphColors[0],
);
$w_DataDisplay->AddLabel( -name=> 'dd_PlotRy_label', -font=> $StdWinFont,
  -text=> 'Ry', -pos=> [10,$ypos+37], -width=> 60, -align=>'center', -background=>$GraphColors[1],
);
$w_DataDisplay->AddLabel( -name=> 'dd_PlotRz_label', -font=> $StdWinFont,
  -text=> 'Rz', -pos=> [10,$ypos+54], -width=> 60, -align=>'center', -background=>[80,80,255],#$GraphColors[2],
);
$w_DataDisplay->AddLabel( -name=> 'dd_PlotAamp_label', -font=> $StdWinFont,
  -text=> 'Acc Amp', -pos=> [10,$ypos+71], -width=> 60, -align=>'center', -background=>[128,128,128],#$GraphColors[2],
);
$w_DataDisplay->AddLabel( -name=> 'dd_PlotAConf_label', -font=> $StdWinFont,
  -text=> 'Acc Conf', -pos=> [10,$ypos+88], -width=> 60, -align=>'center', -background=>[64,196,196],
);
my $w_Plot_R= $w_DataDisplay->AddGraphic( -parent=> $w_DataDisplay, -name=> 'dd_PlotR', -font=> $StdWinFont,
    -pos=> [80,$ypos], -size=> [$PlotWidth,$PlotHeight],
    -interactive=> 1,
    -addexstyle => WS_EX_CLIENTEDGE,
);

$w_DataDisplay->AddLabel( -name=> 'dd_RcInPitch', #-font=> $StdWinFont,
  -text=>'0', -pos=> [$PlotWidth+85,$ypos], -width=> 40,
  -background=>$ddBackgroundColor,
  -align=> 'center',
);
$w_DataDisplay->AddLabel( -name=> 'dd_RcInRoll', #-font=> $StdWinFont,
  -text=>'0', -pos=> [$PlotWidth+85,$ypos+16], -width=> 40,
  -background=>$ddBackgroundColor,
  -align=> 'center',
);
$w_DataDisplay->AddLabel( -name=> 'dd_RcInYaw', #-font=> $StdWinFont,
  -text=>'0', -pos=> [$PlotWidth+85,$ypos+32], -width=> 40,
  -background=>$ddBackgroundColor,
  -align=> 'center',
);

$ypos+= 140;
$w_DataDisplay->AddLabel( -name=> 'dd_PlotA_label', -font=> $StdWinFont,
  -text=> 'Angles', -pos=> [10,$ypos],
  -background=>$ddBackgroundColor,
  -foreground=> [255,255,255],
);
$w_DataDisplay->AddLabel( -name=> 'dd_PlotPitch_label', -font=> $StdWinFont,
  -text=> 'Pitch', -pos=> [10,$ypos+20], -width=> 60, -align=>'center', -background=>$GraphColors[0],
);
$w_DataDisplay->AddLabel( -name=> 'dd_PlotRoll_label', -font=> $StdWinFont,
  -text=> 'Roll', -pos=> [10,$ypos+37], -width=> 60, -align=>'center', -background=>$GraphColors[1],
);
$w_DataDisplay->AddLabel( -name=> 'dd_PlotYaw_label', -font=> $StdWinFont,
  -text=> 'Yaw', -pos=> [10,$ypos+54], -width=> 60, -align=>'center', -background=>[80,80,255],
);
my $w_Plot_Angle= $w_DataDisplay->AddGraphic( -parent=> $w_DataDisplay, -name=> 'dd_PlotA', -font=> $StdWinFont,
    -pos=> [80,$ypos], -size=> [$PlotWidth,$PlotHeight],
    -interactive=> 1,
    -addexstyle => WS_EX_CLIENTEDGE,
##    -onMouseMove => sub{ TextOut("move"); 1; }
);
$w_DataDisplay->AddCheckbox( -name  => 'dd_PlotPitch_check', -font=> $StdWinFont,
  -pos=> [14,$ypos+80-6], -size=> [12,12],
  -onClick=> sub{ DrawAngle(); 1;},
);
$w_DataDisplay->dd_PlotPitch_check->Checked(1);
$w_DataDisplay->AddCheckbox( -name  => 'dd_PlotRoll_check', -font=> $StdWinFont,
  -pos=> [14,$ypos+96-6], -size=> [12,12],
  -onClick=> sub{ DrawAngle(); 1;},
);
$w_DataDisplay->dd_PlotRoll_check->Checked(1);
$w_DataDisplay->AddCheckbox( -name  => 'dd_PlotYaw_check', -font=> $StdWinFont,
  -pos=> [14,$ypos+112-6], -size=> [12,12],
  -onClick=> sub{ DrawAngle(); 1;},
);
$w_DataDisplay->dd_PlotYaw_check->Checked(1);

$w_DataDisplay->AddCheckbox( -name  => 'dd_PlotYawVehicle_check', -font=> $StdWinFont,
  -pos=> [14-6,$ypos+128-6], -size=> [12,12],
  -onClick=> sub{
    $w_DataDisplay->dd_PlotYawEarth_check->Checked(0); $w_DataDisplay->dd_PlotYaw2Earth_check->Checked(0);
    DrawAngle(); 1;},
);
$w_DataDisplay->dd_PlotYawVehicle_check->Checked(0);
$w_DataDisplay->AddCheckbox( -name  => 'dd_PlotYawEarth_check', -font=> $StdWinFont,
  -pos=> [14+7,$ypos+128-6], -size=> [12,12],
  -onClick=> sub{
    $w_DataDisplay->dd_PlotYawVehicle_check->Checked(0); $w_DataDisplay->dd_PlotYaw2Earth_check->Checked(0);
    DrawAngle(); 1;},
);
$w_DataDisplay->dd_PlotYawEarth_check->Checked(0);
$w_DataDisplay->AddCheckbox( -name  => 'dd_PlotYaw2Earth_check', -font=> $StdWinFont,
  -pos=> [14+20,$ypos+128-6], -size=> [12,12],
  -onClick=> sub{
    $w_DataDisplay->dd_PlotYawVehicle_check->Checked(0); $w_DataDisplay->dd_PlotYawEarth_check->Checked(0);
    DrawAngle(); 1;},
);
$w_DataDisplay->dd_PlotYaw2Earth_check->Checked(0);

$w_DataDisplay->AddCheckbox( -name  => 'dd_PlotPitch2_check', -font=> $StdWinFont,
  -pos=> [14+20,$ypos+80-6], -size=> [12,12],
  -onClick=> sub{ DrawAngle(); 1;},
);
$w_DataDisplay->dd_PlotPitch2_check->Checked(0);
$w_DataDisplay->AddCheckbox( -name  => 'dd_PlotRoll2_check', -font=> $StdWinFont,
  -pos=> [14+20,$ypos+96-6], -size=> [12,12],
  -onClick=> sub{ DrawAngle(); 1;},
);
$w_DataDisplay->dd_PlotRoll2_check->Checked(0);
$w_DataDisplay->AddCheckbox( -name  => 'dd_PlotYaw2_check', -font=> $StdWinFont,
  -pos=> [14+20,$ypos+112-6], -size=> [12,12],
  -onClick=> sub{ DrawAngle(); 1;},
);
$w_DataDisplay->dd_PlotYaw2_check->Checked(0);
$w_DataDisplay->AddCheckbox( -name  => 'dd_PlotPitchEnc_check', -font=> $StdWinFont,
  -pos=> [14+40,$ypos+80-6], -size=> [12,12],
  -onClick=> sub{ DrawAngle(); 1;},
);
$w_DataDisplay->dd_PlotPitchEnc_check->Checked(0);
$w_DataDisplay->AddCheckbox( -name  => 'dd_PlotRollEnc_check', -font=> $StdWinFont,
  -pos=> [14+40,$ypos+96-6], -size=> [12,12],
  -onClick=> sub{ DrawAngle(); 1;},
);
$w_DataDisplay->dd_PlotRollEnc_check->Checked(0);
$w_DataDisplay->AddCheckbox( -name  => 'dd_PlotYawEnc_check', -font=> $StdWinFont,
  -pos=> [14+40,$ypos+112-6], -size=> [12,12],
  -onClick=> sub{ DrawAngle(); 1;},
);
$w_DataDisplay->dd_PlotYawEnc_check->Checked(0);
$w_DataDisplay->AddCheckbox( -name  => 'dd_PlotPerformance_check', -font=> $StdWinFont,
  -pos=> [14+40,$ypos+128-6], -size=> [12,12],
  -onClick=> sub{ DrawAngle(); 1;},
);
$w_DataDisplay->dd_PlotPerformance_check->Checked(0);


$w_DataDisplay->AddButton( -name=> 'dd_PlotA_200', -font=> $StdWinFont,
  -text=> '200°', -pos=> [$PlotWidth+85,$ypos], -width=> 30, -height=>19,
  -onClick=> sub{ $PlotAngleRange=20000; DrawAngle(); 1;},
);
$w_DataDisplay->AddButton( -name=> 'dd_PlotA_100', -font=> $StdWinFont,
  -text=> '100°', -pos=> [$PlotWidth+85,$ypos+19], -width=> 30, -height=>19,
  -onClick=> sub{ $PlotAngleRange=10000; DrawAngle(); 1;},
);
$w_DataDisplay->AddButton( -name=> 'dd_PlotA_30', -font=> $StdWinFont,
  -text=> '30°', -pos=> [$PlotWidth+85,$ypos+38], -width=> 30, -height=>19,
  -onClick=> sub{ $PlotAngleRange=3000; DrawAngle(); 1;},
  -foreground=>[0,128,128],
);
$w_DataDisplay->AddButton( -name=> 'dd_PlotA_15', -font=> $StdWinFont,
  -text=> '15°', -pos=> [$PlotWidth+85,$ypos+57], -width=> 30, -height=>19,
  -onClick=> sub{ $PlotAngleRange=1500; DrawAngle(); 1; },
);
$w_DataDisplay->AddButton( -name=> 'dd_PlotA_5', -font=> $StdWinFont,
  -text=> '5°', -pos=> [$PlotWidth+85,$ypos+76], -width=> 30, -height=>19,
  -onClick=> sub{ $PlotAngleRange=500; DrawAngle(); 1;},
);
$w_DataDisplay->AddButton( -name=> 'dd_PlotA_1p5', -font=> $StdWinFont,
  -text=> '1.5°', -pos=> [$PlotWidth+85,$ypos+95], -width=> 30, -height=>19,
  -onClick=> sub{ $PlotAngleRange=150; DrawAngle(); 1;},
);
$w_DataDisplay->AddButton( -name=> 'dd_PlotA_0p5', -font=> $StdWinFont,
  -text=> '0.5°', -pos=> [$PlotWidth+85,$ypos+114], -width=> 30, -height=>19,
  -onClick=> sub{ $PlotAngleRange=50; DrawAngle(); 1;},
);

$ypos+= 140;
$w_DataDisplay->AddLabel( -name=> 'dd_PlotC_label', -font=> $StdWinFont,
  -text=> 'Control', -pos=> [10,$ypos],
  -background=>$ddBackgroundColor,
  -foreground=> [255,255,255],
);
$w_DataDisplay->AddLabel( -name=> 'dd_PlotCntrlPitch_label', -font=> $StdWinFont,
  -text=> 'Cntrl Pitch', -pos=> [10,$ypos+20], -width=> 60, -align=>'center', -background=>$GraphColors[0],
);
$w_DataDisplay->AddLabel( -name=> 'dd_PlotCntrlRoll_label', -font=> $StdWinFont,
  -text=> 'Cntrl Roll', -pos=> [10,$ypos+37], -width=> 60, -align=>'center', -background=>$GraphColors[1],
);
$w_DataDisplay->AddLabel( -name=> 'dd_PlotCntrlYaw_label', -font=> $StdWinFont,
  -text=> 'Cntrl Yaw', -pos=> [10,$ypos+54], -width=> 60, -align=>'center', -background=>[80,80,255],
);

$w_DataDisplay->AddCheckbox( -name  => 'dd_PlotCntrlPitch_check', -font=> $StdWinFont,
  -pos=> [14,$ypos+80-6], -size=> [12,12],
  -onClick=> sub{ DrawCntrl(); 1;},
);
$w_DataDisplay->dd_PlotCntrlPitch_check->Checked(1);
$w_DataDisplay->AddCheckbox( -name  => 'dd_PlotCntrlRoll_check', -font=> $StdWinFont,
  -pos=> [14,$ypos+96-6], -size=> [12,12],
  -onClick=> sub{ DrawCntrl(); 1;},
);
$w_DataDisplay->dd_PlotCntrlRoll_check->Checked(1);
$w_DataDisplay->AddCheckbox( -name  => 'dd_PlotCntrlYaw_check', -font=> $StdWinFont,
  -pos=> [14,$ypos+112-6], -size=> [12,12],
  -onClick=> sub{ DrawCntrl(); 1;},
);
$w_DataDisplay->dd_PlotCntrlYaw_check->Checked(1);

my $w_Plot_Cntrl= $w_DataDisplay->AddGraphic( -parent=> $w_DataDisplay, -name=> 'dd_PlotC', -font=> $StdWinFont,
    -pos=> [80,$ypos], -size=> [$PlotWidth,$PlotHeight],
    -interactive=> 1,
    -addexstyle => WS_EX_CLIENTEDGE,
);

sub DataDisplay_AdaptToBoardConfigurationDefault{
  if( not defined $w_DataDisplay ){ return 1; }
  DataDisplayClear();

  $w_DataDisplay->dd_PlotPitch2_check->Checked(0);
  $w_DataDisplay->dd_PlotRoll2_check->Checked(0);
  $w_DataDisplay->dd_PlotYaw2_check->Checked(0);
  $w_DataDisplay->dd_PlotPitch2_check->Show();
  $w_DataDisplay->dd_PlotRoll2_check->Show();
  $w_DataDisplay->dd_PlotYaw2_check->Show();

  $w_DataDisplay->dd_Imu2Status_label->Show();
  $w_DataDisplay->dd_Imu2Status->Show();

  $w_DataDisplay->dd_PlotPitchEnc_check->Checked(0);
  $w_DataDisplay->dd_PlotRollEnc_check->Checked(0);
  $w_DataDisplay->dd_PlotYawEnc_check->Checked(0);
  $w_DataDisplay->dd_PlotPitchEnc_check->Hide();
  $w_DataDisplay->dd_PlotRollEnc_check->Hide();
  $w_DataDisplay->dd_PlotYawEnc_check->Hide();

  $w_DataDisplay->dd_EncAllStatus_label->Hide();
  $w_DataDisplay->dd_EncAllStatus->Hide();

  $w_DataDisplay->dd_YawEarth->Hide();
  $w_DataDisplay->dd_PlotYawVehicle_check->Hide();
  $w_DataDisplay->dd_PlotYawVehicle_check->Checked(0);
  $w_DataDisplay->dd_PlotYawEarth_check->Hide();
  $w_DataDisplay->dd_PlotYawEarth_check->Checked(0);
  $w_DataDisplay->dd_PlotYaw2Earth_check->Hide();
  $w_DataDisplay->dd_PlotYaw2Earth_check->Checked(0);

  0;
}

sub DataDisplay_AdaptToBoardConfigurationFoc{
  if( not defined $w_DataDisplay ){ return 1; }
  DataDisplayClear();

  $w_DataDisplay->dd_PlotPitch2_check->Checked(0);
  $w_DataDisplay->dd_PlotRoll2_check->Checked(0);
  $w_DataDisplay->dd_PlotYaw2_check->Checked(0);
  $w_DataDisplay->dd_PlotPitch2_check->Hide();
  $w_DataDisplay->dd_PlotRoll2_check->Hide();
  $w_DataDisplay->dd_PlotYaw2_check->Hide();

  $w_DataDisplay->dd_Imu2Status_label->Hide();
  $w_DataDisplay->dd_Imu2Status->Hide();

  $w_DataDisplay->dd_PlotPitchEnc_check->Checked(0);
  $w_DataDisplay->dd_PlotRollEnc_check->Checked(0);
  $w_DataDisplay->dd_PlotYawEnc_check->Checked(0);
  $w_DataDisplay->dd_PlotPitchEnc_check->Show();
  $w_DataDisplay->dd_PlotRollEnc_check->Show();
  $w_DataDisplay->dd_PlotYawEnc_check->Show();

  $w_DataDisplay->dd_EncAllStatus_label->Show();
  $w_DataDisplay->dd_EncAllStatus->Show();

  $w_DataDisplay->dd_YawEarth->Hide();
  $w_DataDisplay->dd_PlotYawVehicle_check->Hide();
  $w_DataDisplay->dd_PlotYawVehicle_check->Checked(0);
  $w_DataDisplay->dd_PlotYawEarth_check->Hide();
  $w_DataDisplay->dd_PlotYawEarth_check->Checked(0);
  $w_DataDisplay->dd_PlotYaw2Earth_check->Hide();
  $w_DataDisplay->dd_PlotYaw2Earth_check->Checked(0);

  0;
}

sub DataDisplay_Imu2_Enable{
  my $flag = 0;
  if( shift ){ $flag = 1; }
  $w_DataDisplay->dd_PlotPitch2_check->Show($flag);
  $w_DataDisplay->dd_PlotRoll2_check->Show($flag);
  $w_DataDisplay->dd_PlotYaw2_check->Show($flag);
}

sub DataDisplay_Enc_Enable{
  my $flag = 0;
  if( shift ){ $flag = 1; }
  $w_DataDisplay->dd_PlotPitchEnc_check->Show($flag);
  $w_DataDisplay->dd_PlotRollEnc_check->Show($flag);
  $w_DataDisplay->dd_PlotYawEnc_check->Show($flag);
}

sub DataDisplay_Link_Enable{
  my $flag = 0;
  if( shift ){ $flag = 1; }
  $w_DataDisplay->dd_YawEarth->Show($flag);
  $w_DataDisplay->dd_PlotYawVehicle_check->Show($flag);
  $w_DataDisplay->dd_PlotYawEarth_check->Show($flag);
  $w_DataDisplay->dd_PlotYaw2Earth_check->Show($flag);
}

sub m_datadisplay_Window_Resize{
  if( not defined $w_DataDisplay ){ return 1; }
  my $mw = $w_DataDisplay->Width();
  my $mh = $w_DataDisplay->Height();
#  TextOut( $mw." ".$mh."\r\n");
#  TextOut( $w_DataDisplay->dd_RcInPitch->Left()."\r\n"); #685 @735
  $w_DataDisplay->dd_RcInPitch->Left( $mw - 50 );
  $w_DataDisplay->dd_RcInRoll->Left( $mw - 50 );
  $w_DataDisplay->dd_RcInYaw->Left( $mw - 50 );
#  TextOut( $w_DataDisplay->dd_PlotA_200->Left()."\r\n"); #685 @735
  $w_DataDisplay->dd_PlotA_200->Left( $mw - 50 );
  $w_DataDisplay->dd_PlotA_100->Left( $mw - 50 );
  $w_DataDisplay->dd_PlotA_30->Left( $mw - 50 );
  $w_DataDisplay->dd_PlotA_15->Left( $mw - 50 );
  $w_DataDisplay->dd_PlotA_5->Left( $mw - 50 );
  $w_DataDisplay->dd_PlotA_1p5->Left( $mw - 50 );
  $w_DataDisplay->dd_PlotA_0p5->Left( $mw - 50 );
#  TextOut( $w_DataDisplay->dd_PlotC->Top()."\r\n"); #325 @535
  $w_DataDisplay->dd_PlotC_label->Top( $mh - (535-325) ); #325 @535
  $w_DataDisplay->dd_PlotCntrlPitch_label->Top( $mh - (535-345) ); #345 @535
  $w_DataDisplay->dd_PlotCntrlRoll_label->Top( $mh - (535-345-(20-3)) ); #365 @535
  $w_DataDisplay->dd_PlotCntrlYaw_label->Top( $mh - (535-345-(40-6)) ); #385 @535
  $w_DataDisplay->dd_PlotCntrlPitch_check->Top( $mh - (535-405) ); #405 @535
  $w_DataDisplay->dd_PlotCntrlRoll_check->Top( $mh - (535-425) ); #425 @535
  $w_DataDisplay->dd_PlotCntrlYaw_check->Top( $mh - (535-445) ); #445 @535
  $w_DataDisplay->dd_PlotC->Top( $mh - (535-325) ); #325 @535
#  TextOut( $w_DataDisplay->dd_PlotC->Width()."\r\n"); #600 @735
#  TextOut( $w_DataDisplay->dd_PlotA->Height()."\r\n"); #131 @535
  $PlotWidth = $mw - (735-600);
  $w_DataDisplay->dd_PlotR->Width( $mw - (735-600) );
  $w_DataDisplay->dd_PlotC->Width( $mw - (735-600) );
  $w_DataDisplay->dd_PlotA->Width( $mw - (735-600) );
  #my $h = $mh - (535-131); if( $h % 2 == 0 ){ $h = $h-1; }
  my $h = 2*int(( $mh - (535-131) +1)/2) - 1; #ensure it's odd
  $w_DataDisplay->dd_PlotA->Height( $h );
#  TextOut( $w_DataDisplay->dd_LipoVoltage_label->Top()."\r\n"); #470 @535
  $w_DataDisplay->dd_LipoVoltage_label->Top( $mh - 65 );
  $w_DataDisplay->dd_LipoVoltage->Top( $mh - 65 );
  $w_DataDisplay->dd_LipoVoltageStatus->Top( $mh - 65 );
  $w_DataDisplay->dd_NTBusError_label->Top( $mh - 65 );
  $w_DataDisplay->dd_NTBusError->Top( $mh - 65 );
  $w_DataDisplay->dd_ImuStatus_label->Top( $mh - 65 );
  $w_DataDisplay->dd_ImuStatus->Top( $mh - 65 );
  $w_DataDisplay->dd_Imu2Status_label->Top( $mh - 65 );
  $w_DataDisplay->dd_Imu2Status->Top( $mh - 65 );
  $w_DataDisplay->dd_EncAllStatus_label->Top( $mh - 65 );
  $w_DataDisplay->dd_EncAllStatus->Top( $mh - 65 );
  $w_DataDisplay->dd_STorM32LinkStatus_label->Top( $mh - 65 );
  $w_DataDisplay->dd_STorM32LinkStatus->Top( $mh - 65 );
  $w_DataDisplay->dd_Storm32LinkA->Top( $mh - 65-8 );
#XX  $w_DataDisplay->dd_Storm32LinkB->Top( $mh - 65+8 );
  #TextOut( "h\r\n");
  #$w_DataDisplay->Resize();
  0;
}

m_datadisplay_Window_Resize();

my $PlotAMouseIsDown = 0;
my $PlotAMouseDownWasAtY = 0;
my $GraphYOffset = 0.0;

sub dd_PlotA_MouseDblClick{
  $GraphYOffset = 0.0;
  $PlotAMouseIsDown = 0;
  TextOut("dbl");
  1;
}

sub dd_PlotA_MouseRightDown{
  $GraphYOffset = 0.0;
  $PlotAMouseIsDown = 0;
  Paint($w_Plot_Angle,$PlotAngleRange);
  1;
}

sub dd_PlotA_MouseDown{
  my ($x, $y) = @_;
  Win32::GUI::ClipCursor( $w_Plot_Angle->GetAbsClientRect() );
  $PlotAMouseIsDown = 1;
  $PlotAMouseDownWasAtY = $y;
  1;
}

sub dd_PlotA_MouseUp{
  Win32::GUI::ClipCursor( );
  $PlotAMouseIsDown = 0;
  1;
}

sub dd_PlotA_MouseMove{
  my ($x, $y) = @_;
  if( $PlotAMouseIsDown == 0 ){ return 1; }
  my $H = ($w_Plot_Angle->GetClientRect())[3];
  $GraphYOffset += 2.0 * $PlotAngleRange * ($y - $PlotAMouseDownWasAtY) / $H ;
  Paint($w_Plot_Angle,$PlotAngleRange);
  $PlotAMouseDownWasAtY = $y;
  1;
}

sub Paint{
  my $Plot= shift;
  my $DC= $Plot->GetDC();
  my $GraphYRange = shift;
  my $GraphYMax = $GraphYRange;
  my $GraphYMin = -$GraphYRange;
  if( $Plot == $w_Plot_Angle ){
    $GraphYMax += $GraphYOffset;
    $GraphYMin += $GraphYOffset;
  }
  # setting of Ranges and Regions
  my ($W, $H)= ($Plot->GetClientRect())[2..3];
  my $plot_region= CreateRectRgn Win32::GUI::Region(0,0,$W,$H);
  # get the DC's
  my $DC2= $DC->CreateCompatibleDC();
  my $bit= $DC->CreateCompatibleBitmap( $W, $H );
  $DC2->SelectObject( $bit );
  # draw the Plot region things: background, labels, xy, plotframe
  $DC2->SelectClipRgn( $plot_region );
  $DC2->SelectObject( $penPlot );
  $DC2->SelectObject( $brushPlot );
  $DC2->PaintRgn( $plot_region );
  $DC2->SelectObject( $fontLabel );
  $DC2->TextColor( [127,127,127] );
  $DC2->BackColor( [191,191,191] );
  # draw the Graph region things: frame, grids, zeros, datapoints
  my $DataNr= 0;
  my $DataIndex= 0;
  $DC2->SelectObject( $penZero );
  my $ly = $H*( 0-$GraphYMax)/($GraphYMin-$GraphYMax);
  $DC2->Line( 0, $ly, $W, $ly );
  $DC2->SelectObject( $penGrid );
  if($Plot==$w_Plot_R){
    $DataNr= 5; $DataIndex= $DataRx_i;
    $ly= $H*( 10000-$GraphYMax)/($GraphYMin-$GraphYMax);
    $DC2->Line( 0, $ly, $W, $ly );
    $DC2->TextOut( $PlotWidth-26, $ly-5, '+1' );
    $ly= $H*( -10000-$GraphYMax)/($GraphYMin-$GraphYMax);
    $DC2->Line( 0, $ly, $W, $ly );
    $DC2->TextOut( $PlotWidth-26, $ly-5, '-1' );
  }elsif($Plot==$w_Plot_Angle){
    $DataNr= 3+3+3+1+3; $DataIndex= $DataPitch_i;
    if($GraphYRange>10000){ # 200°
      $ly= $H*( 9000-$GraphYMax)/($GraphYMin-$GraphYMax);
      $DC2->Line( 0, $ly, $W, $ly );
      $DC2->TextOut( $PlotWidth-40, $ly-5, '+90°' );
      $ly= $H*( -9000-$GraphYMax)/($GraphYMin-$GraphYMax);
      $DC2->Line( 0, $ly, $W, $ly );
      $DC2->TextOut( $PlotWidth-40, $ly-5, '-90°' );
    }elsif($GraphYRange>3000){ # 100°
      $ly= $H*( 3000-$GraphYMax)/($GraphYMin-$GraphYMax);
      $DC2->Line( 0, $ly, $W, $ly );
      $DC2->TextOut( $PlotWidth-40, $ly-5, '+30°' );
      $ly= $H*( -3000-$GraphYMax)/($GraphYMin-$GraphYMax);
      $DC2->Line( 0, $ly, $W, $ly );
      $DC2->TextOut( $PlotWidth-40, $ly-5, '-30°' );
    }elsif($GraphYRange>1000){ # 15°, 30°,
      $ly= $H*( 1000-$GraphYMax)/($GraphYMin-$GraphYMax);
      $DC2->Line( 0, $ly, $W, $ly );
      $DC2->TextOut( $PlotWidth-40, $ly-5, '+10°' );
      $ly= $H*( -1000-$GraphYMax)/($GraphYMin-$GraphYMax);
      $DC2->Line( 0, $ly, $W, $ly );
      $DC2->TextOut( $PlotWidth-40, $ly-5, '-10°' );
    }elsif($GraphYRange>100){ #1.5°, 5°
      $ly= $H*( 100-$GraphYMax)/($GraphYMin-$GraphYMax);
      $DC2->Line( 0, $ly, $W, $ly );
      $DC2->TextOut( $PlotWidth-33, $ly-5, '+1°' );
      $ly= $H*( -100-$GraphYMax)/($GraphYMin-$GraphYMax);
      $DC2->Line( 0, $ly, $W, $ly );
      $DC2->TextOut( $PlotWidth-33, $ly-5, '-1°' );
    }else{ #0.5°
      $ly= $H*( 10-$GraphYMax)/($GraphYMin-$GraphYMax);
      $DC2->Line( 0, $ly, $W, $ly );
      $DC2->TextOut( $PlotWidth-33, $ly-5, '+0.1°' );
      $ly= $H*( -10-$GraphYMax)/($GraphYMin-$GraphYMax);
      $DC2->Line( 0, $ly, $W, $ly );
      $DC2->TextOut( $PlotWidth-33, $ly-5, '-0.1°' );
    }
  }elsif($Plot==$w_Plot_Cntrl){
    $DataNr= 3; $DataIndex= $DataPitchCntrl_i;
    $ly= $H*( 3000-$GraphYMax)/($GraphYMin-$GraphYMax);
    $DC2->Line( 0, $ly, $W, $ly );
    $DC2->TextOut( $PlotWidth-40, $ly-5, '+30°' );
    $ly= $H*( -3000-$GraphYMax)/($GraphYMin-$GraphYMax);
    $DC2->Line( 0, $ly, $W, $ly );
    $DC2->TextOut( $PlotWidth-40, $ly-5, '-30°' );
  }
  # draw the Data points
  # my $DataMatrixLength= scalar @{$DataMatrix[0]};
  # $DataMatrixLength is set in DataDisplayDoTimer()
  for(my $DataOfs=$DataNr-1; $DataOfs>=0; $DataOfs-- ){
    my $i= $DataIndex + $DataOfs;
    if( $Plot == $w_Plot_R ){
      if( $DataOfs==3 ){ $i= $DataAccAbs_i; }
      if( $DataOfs>=4 ){ $i= $DataAccConfidence_i; }
    }
    if( $Plot == $w_Plot_Angle ){
      if(( $DataOfs==0 )and( not $w_DataDisplay->dd_PlotPitch_check->Checked() )){ next; }
      if(( $DataOfs==1 )and( not $w_DataDisplay->dd_PlotRoll_check->Checked() )){ next; }
      if(( $DataOfs==2 )and( not $w_DataDisplay->dd_PlotYaw_check->Checked() )){ next; }

      if(( $DataOfs==3 )and( not $w_DataDisplay->dd_PlotPitch2_check->Checked() )){ next; }
      if(( $DataOfs==4 )and( not $w_DataDisplay->dd_PlotRoll2_check->Checked() )){ next; }
      if(( $DataOfs==5 )and( not $w_DataDisplay->dd_PlotYaw2_check->Checked() )){ next; }

      if(( $DataOfs==6 )and( not $w_DataDisplay->dd_PlotPitchEnc_check->Checked() )){ next; }
      if(( $DataOfs==7 )and( not $w_DataDisplay->dd_PlotRollEnc_check->Checked() )){ next; }
      if(( $DataOfs==8 )and( not $w_DataDisplay->dd_PlotYawEnc_check->Checked() )){ next; }

      if(( $DataOfs==9 )and( not $w_DataDisplay->dd_PlotPerformance_check->Checked() )){ next; }
      if(( $DataOfs==12)and( not $w_DataDisplay->dd_PlotYawVehicle_check->Checked() )){ next; }
      if(( $DataOfs==10)and( not $w_DataDisplay->dd_PlotYawEarth_check->Checked() )){ next; }
      if(( $DataOfs==11)and( not $w_DataDisplay->dd_PlotYaw2Earth_check->Checked() )){ next; }
    }
    if( $Plot == $w_Plot_Cntrl ){
      if(( $DataOfs==0 )and( not $w_DataDisplay->dd_PlotCntrlPitch_check->Checked() )){ next; }
      if(( $DataOfs==1 )and( not $w_DataDisplay->dd_PlotCntrlRoll_check->Checked() )){ next; }
      if(( $DataOfs==2 )and( not $w_DataDisplay->dd_PlotCntrlYaw_check->Checked() )){ next; }
    }
    my $ColorOfs= $DataOfs;
    if( ($Plot == $w_Plot_Angle) and ($DataOfs >= 3) ){ $ColorOfs += 2; } #skip grey+greygrey
    my $pen = new Win32::GUI::Pen( -color => $GraphColors[$ColorOfs], -width => 1);
    $DC2->SelectObject( $pen );
    #determine start pos and length to plot
    my $xstart = 0;
    my $pxlen = 0;
    if( $DataMatrixLength < $PlotWidth ){ #first run, @DataMatrix not full, $DataPos started from zero
      $xstart = 0;
      $pxlen = $DataPos;
    }else{ #second run, @DataMatrix filled beyond $PlotWidth
      $pxlen = $PlotWidth - $DataBlockPos;
      $xstart = $DataPos - $pxlen;
      if( $xstart < 0 ){ $xstart += $DataMatrixLength; }
    }
    for(my $px=0; $px<$pxlen; $px++){
      my $x = $px + $xstart;
      if( $x >= $DataMatrixLength ){ $x-= $DataMatrixLength; }
      my $y = $DataMatrix[$i][$x];
      if( $y > $GraphYMax ){ $y=$GraphYMax; }
      if( $y < $GraphYMin ){ $y=$GraphYMin; }
      my $py = $H*( $y-$GraphYMax)/($GraphYMin-$GraphYMax);
      if( $px == 0 ){ $DC2->MoveTo( $px, $py ); }else{ $DC2->LineTo( $px, $py ); }
      $DC2->Rectangle($px-1,$py-1,$px+1,$py+1);
    }
  }
  # update the screen in one action, and clean up
  $DC->BitBlt(0, 0, $W, $H, $DC2, 0, 0);
  $DC2->DeleteDC();
  $DC->Validate();
}

my $DATA_BLOCK_SIZE = 150; # this is the look ahead lenght in the display

sub DataDisplayDoTimer{
  if( not $DataDisplay_IsRunning ){ return 1; }
  # read data
  my $s = shift;
  my @ddData = unpack( "v$CMD_d_PARAMETER_ZAHL", $s );
  for(my $n=0;$n<$CMD_d_PARAMETER_ZAHL;$n++){
    if( substr($DataFormatStr,$n,1) eq 's' ){ if( $ddData[$n] > 32768-1 ){ $ddData[$n] -= 65536; }  }
  }
  # do widget stuff
  $w_DataDisplay->dd_Pitch->Text( sprintf("%.2f°", $ddData[$DataPitch_p]/100.0) );
  $w_DataDisplay->dd_Roll->Text( sprintf("%.2f°", $ddData[$DataRoll_p]/100.0) );
  $w_DataDisplay->dd_Yaw->Text( sprintf("%.2f°", $ddData[$DataYaw_p]/100.0) );
  $w_DataDisplay->dd_YawEarth->Text( sprintf("%.2f°", $ddData[$DataLink1_p]/100.0) );

  $w_DataDisplay->dd_State->Text( $StatusInfoHash{STATE} );
  $w_DataDisplay->dd_State->Change( -background => $StatusInfoHash{STATEcolor} );

  $w_DataDisplay->dd_NTBusError_label->Text( $StatusInfoHash{BUSERROR} );
  $w_DataDisplay->dd_NTBusError->Text( $StatusInfoHash{BUSERRORvalue} );

  $w_DataDisplay->dd_LipoVoltage->Text( $StatusInfoHash{VOLTAGEvalue} );

  $w_DataDisplay->dd_LipoVoltageStatus->Text( $StatusInfoHash{VOLTAGE} );
  $w_DataDisplay->dd_LipoVoltageStatus->Change( -background => $StatusInfoHash{VOLTAGEcolor} );

  $w_DataDisplay->dd_ImuStatus->Text( $StatusInfoHash{IMU} );
  $w_DataDisplay->dd_ImuStatus->Change( -background => $StatusInfoHash{IMUcolor} );

  $w_DataDisplay->dd_Imu2Status->Text( $StatusInfoHash{IMU2} );
  $w_DataDisplay->dd_Imu2Status->Change( -background => $StatusInfoHash{IMU2color} );

  $w_DataDisplay->dd_EncAllStatus->Text( $StatusInfoHash{ENCODERALL} );
  $w_DataDisplay->dd_EncAllStatus->Change( -background => $StatusInfoHash{ENCODERALLcolor} );

  $w_DataDisplay->dd_STorM32LinkStatus->Text( $StatusInfoHash{LINK} );
  $w_DataDisplay->dd_STorM32LinkStatus->Change( -background => $StatusInfoHash{LINKcolor} );

  # adapt screen layout to some flags
  my $status= UIntToBitstr( $ddData[$DataStatus_p] ); #status
  my $Imu2Present= CheckStatus($status, $STATUS_IMU2_PRESENT);
  my $LinkPresent= CheckStatus($status, $STATUS_STORM32LINK_PRESENT);
  my $status2= UIntToBitstr( $ddData[$DataStatus2_p] ); #status2
  my $EncPresent= CheckStatus($status2, $STATUS2_ENCODERS_PRESENT);
  if( $ActiveBoardConfiguration == $BOARDCONFIGURATION_IS_FOC ){
    # Enc is always enabled
    DataDisplay_Imu2_Enable($LinkPresent); # show Imu2 checkboxes
    DataDisplay_Link_Enable($LinkPresent); # show YawAbsolute fields
  } else {
    # Imu2 is always enabled
    DataDisplay_Link_Enable($LinkPresent); # show YawAbsolute fields
    DataDisplay_Enc_Enable($EncPresent); # show Enc checkboxes, status field
  }

  $w_DataDisplay->dd_RcInPitch->Text( $ddData[$DataPitchRcIn_p] );
  $w_DataDisplay->dd_RcInRoll->Text( $ddData[$DataRollRcIn_p] );
  $w_DataDisplay->dd_RcInYaw->Text( $ddData[$DataYawRcIn_p] );

  $w_DataDisplay->dd_Storm32LinkA->Text( $ddData[$DataLink3_p]." ms" );
#XX  $w_DataDisplay->dd_Storm32LinkB->Text( $ddData[$DataLink2_p] );

  # store data in DataMatrix
  # time
  $DataMatrix[$DataMillis_i][$DataPos]= $ddData[$DataMillis_p];
  $DataMatrix[$DataState_i][$DataPos]= $ddData[$DataState_p];
  $DataMatrix[$DataStatus_i][$DataPos]= $ddData[$DataStatus_p];
  $DataMatrix[$DataStatus2_i][$DataPos]= $ddData[$DataStatus2_p];
  $DataMatrix[$DataStatus3_i][$DataPos]= $ddData[$DataStatus3_p];
  $DataMatrix[$DataPerformance_i][$DataPos]= $ddData[$DataPerformance_p];
  $DataMatrix[$DataBusError_i][$DataPos]= $ddData[$DataBusError_p];
  $DataMatrix[$DataVoltage_i][$DataPos]= $ddData[$DataVoltage_p];
  # Rx, Ry, Rz
  $DataMatrix[$DataRx_i][$DataPos]= $ddData[$DataRx_p];
  $DataMatrix[$DataRy_i][$DataPos]= $ddData[$DataRy_p];
  $DataMatrix[$DataRz_i][$DataPos]= $ddData[$DataRz_p];
  # Acc
  $DataMatrix[$DataAccAbs_i][$DataPos]= $ddData[$DataAccAbs_p];
  $DataMatrix[$DataAccConfidence_i][$DataPos]= $ddData[$DataAccConfidence_p];
  # Pitch, Roll, Yaw
  $DataMatrix[$DataPitch_i][$DataPos]= $ddData[$DataPitch_p]; #100=1°
  $DataMatrix[$DataRoll_i][$DataPos]= $ddData[$DataRoll_p];
  $DataMatrix[$DataYaw_i][$DataPos]= $ddData[$DataYaw_p];
  # CntrlPitch, CntrlRoll, CnrlYaw
  $DataMatrix[$DataPitchCntrl_i][$DataPos]= $ddData[$DataPitchCntrl_p]; #100=1°
  $DataMatrix[$DataRollCntrl_i][$DataPos]= $ddData[$DataRollCntrl_p];
  $DataMatrix[$DataYawCntrl_i][$DataPos]= $ddData[$DataYawCntrl_p];
  # IMU2 Pitch, Roll, Yaw
  $DataMatrix[$DataPitch2_i][$DataPos]= $ddData[$DataPitch2_p]; #100=1°
  $DataMatrix[$DataRoll2_i][$DataPos]= $ddData[$DataRoll2_p];
  $DataMatrix[$DataYaw2_i][$DataPos]= $ddData[$DataYaw2_p];
  # ENCODER Pitch, Roll, Yaw
  $DataMatrix[$DataPitchEncoder_i][$DataPos]= $ddData[$DataPitchEncoder_p]; #100=1°
  $DataMatrix[$DataRollEncoder_i][$DataPos]= $ddData[$DataRollEncoder_p];
  $DataMatrix[$DataYawEncoder_i][$DataPos]= $ddData[$DataYawEncoder_p];
  # Link Yaw
  $DataMatrix[$DataLink1_i][$DataPos]= $ddData[$DataLink1_p]; # R1earthYaw
  $DataMatrix[$DataLink2_i][$DataPos]= $ddData[$DataLink2_p]; # R2earthYaw
  my $R1vehicleYaw = $ddData[$DataLink1_p] - $ddData[$DataLink2_p]; # R1vehicleYaw = R1earthYaw - R2earthYaw
  if ($R1vehicleYaw > 18000) { $R1vehicleYaw -= 36000; }
  if ($R1vehicleYaw <= -18000) { $R1vehicleYaw += 36000; }
  $DataMatrix[$DataLinkX_i][$DataPos]= $R1vehicleYaw;
  $DataMatrix[$DataLink3_i][$DataPos]= $ddData[$DataLink3_p];
  # RcIn
  $DataMatrix[$DataPitchRcIn_i][$DataPos]= $ddData[$DataPitchRcIn_p];
  $DataMatrix[$DataRollRcIn_i][$DataPos]= $ddData[$DataRollRcIn_p];
  $DataMatrix[$DataYawRcIn_i][$DataPos]= $ddData[$DataYawRcIn_p];
  # data counter
  $DataMatrix[$DataIndex_i][$DataPos]= $DataCounter;
  $DataCounter++;
  # "real" time
  if(( $DataPos > 0 )and( $DataMatrix[$DataMillis_i][$DataPos] < $DataMatrix[$DataMillis_i][$DataPos-1] )){
    $DataTimeCounter += 65536;
  }
  $DataMatrix[$DataTime_i][$DataPos]=
    ($DataMatrix[$DataMillis_i][$DataPos] + $DataTimeCounter - $DataMatrix[$DataMillis_i][0])*16.0/1000.0;

  if( $DataDisplay_LiveRecording ){
    if( open(LRF, ">>$DataDisplay_LiveRecordingFile") ){
      if( $DataDisplay_LiveRecordingDelimiter eq 'px4' ){ binmode(LRF); }
      print LRF DataDisplayFormatDataLine( $DataPos, $DataDisplay_LiveRecordingDelimiter );
    }
    close(LRF);
  }

  $DataPos++;
  if( $DataPos >= $PlotMaxWidth ){ $DataPos= 0; } #this is a ring buffer of size $PlotMaxWidth
  $DataMatrixLength = scalar @{$DataMatrix[0]}; #set the new length of the available data

  if( $DataMatrixLength >= $PlotWidth ){ #second run, @DataMatrix filled beyond $PlotWidth
    if( $DataBlockPos ){ $DataBlockPos--; }else{ $DataBlockPos= $DATA_BLOCK_SIZE; }
  }

  Draw();
  return 1;
}

sub DataDisplayClearStatusFields{
  $w_DataDisplay->dd_State->Change( -background => $StateColors[-1] ); #for some reason this has to come before Text()
  $w_DataDisplay->dd_State->Text( $StateText[-1] );
  $w_DataDisplay->dd_LipoVoltageStatus->Change( -background => $LipoVoltageColors[-1] );
  $w_DataDisplay->dd_LipoVoltageStatus->Text( $LipoVoltageText[-1] );
  $w_DataDisplay->dd_ImuStatus->Change( -background => $ImuStatusColors[-1] );
  $w_DataDisplay->dd_ImuStatus->Text( $ImuStatusText[-1] );
  $w_DataDisplay->dd_Imu2Status->Change( -background => $Imu2StatusColors[-1] );
  $w_DataDisplay->dd_Imu2Status->Text( $Imu2StatusText[-1] );
  $w_DataDisplay->dd_EncAllStatus->Change( -background => $EncoderAllStatusColors[-1] );
  $w_DataDisplay->dd_EncAllStatus->Text( $EncoderAllStatusText[-1] );
  $w_DataDisplay->dd_STorM32LinkStatus->Change( -background => $STorM32LinkStatusColors[-1] );
  $w_DataDisplay->dd_STorM32LinkStatus->Text( $STorM32LinkStatusText[-1] );
  #$w_DataDisplay->dd_RcInPitch->Text( '0' );
  #$w_DataDisplay->dd_RcInRoll->Text( '0' );
  #$w_DataDisplay->dd_RcInYaw->Text( '0' );
}

sub DataDisplayClear{
  #clear data stuff
  @DataMillis= (); @DataState= ();
  @DataStatus= (); @DataStatus2= (); @DataStatus3= (); @DataPerformance= (); @DataBusError= (); @DataVoltage= ();
  @DataRx= (); @DataRy= (); @DataRz= ();
  @DataPitch= (); @DataRoll= (); @DataYaw= ();
  @DataPitch2= (); @DataRoll2= (); @DataYaw2= ();
  @DataPitchEncoder= (); @DataRollEncoder= (); @DataYawEncoder= ();
  @DataLink1= (); @DataLink2= (); @DataLinkX = (); @DataLink3 = ();
  @DataPitchCntrl= (); @DataRollCntrl= (); @DataYawCntrl= ();
  @DataPitchRcIn= (); @DataRollRcIn= (); @DataYawRcIn= ();
  @DataAccAbs= (); @DataAccConfidence= ();
  @DataIndex= (); @DataTime= ();
  $DataCounter= 0;
  #clear plot handling stuff
  $DataPos= 0; #that's there the next data is stored, one ahead of the last data
  $DataMatrixLength= 0; #that's how much data is currently in the ring buffer
  $DataBlockPos= 0;
  #widget stuff
  if(not $DataDisplay_IsRunning){ Draw(); }
  DataDisplayClearStatusFields();
}

sub DataDisplayStart{
  if( $DataDisplay_IsRunning ){ DataDisplayHalt(); }else{
    ConnectToBoard();
    DataDisplayRun();
  }
  return 1;
}

sub DataDisplayHalt{
  $w_DataDisplay->dd_Start->Text( 'Start' );
  $w_DataDisplay->dd_Save->Enable();
  $w_DataDisplay->dd_LiveRecording->Enable();
  $DataDisplay_IsRunning = 0;
}

sub DataDisplayRun{
  if( not ConnectionIsValid() ){ return 1; }
  $w_DataDisplay->dd_Start->Text( 'Stop' );
  $w_DataDisplay->dd_Save->Disable();
  $w_DataDisplay->dd_LiveRecording->Disable();
  $DataDisplay_IsRunning = 1;
}

my $Data_RecordingInitialize = 1;
my $Data_RecordingTotalTime = 0;
my $Data_RecordingLastMillis = 0;

sub DataDisplayFormatFirstLine{
  my $delim = shift;
  $Data_RecordingInitialize = 1; #this indicates first time
  return 'i'.$delim.'Time'.$delim.'Millis'.$delim.
           'Rx'.$delim.'Ry'.$delim.'Rz'.$delim.
           'AccAmp'.$delim.'AccConf'.$delim.
           'Pitch'.$delim.'Roll'.$delim.'Yaw'.$delim.
           'PCntrl'.$delim.'RCntrl'.$delim.'YCntrl'.$delim.
           'Pitch2'.$delim.'Roll2'.$delim.'Yaw2'.$delim.
           'PEnc'.$delim.'REnc'.$delim.'YEnc'.$delim.
           'State'."\n";
}

sub DataDisplayFormatDataLine{
  my $x = shift;
  my $delim = shift;
  my $dt = 0.0;
  if( $Data_RecordingInitialize>0 ){
    $Data_RecordingTotalTime = 0;
  }else{
    my $dtMillis = $DataMatrix[$DataMillis_i][$x] - $Data_RecordingLastMillis;
    if( $dtMillis < 0 ){ $dtMillis += 65536; }
    $Data_RecordingTotalTime += $dtMillis;
    $dt = 0.001*$dtMillis; #time in sec
  }
  $Data_RecordingLastMillis = $DataMatrix[$DataMillis_i][$x];

  my $s = '';
    $s .= int($DataMatrix[$DataIndex_i][$x]).$delim;
    $s .= $Data_RecordingTotalTime.$delim;
    $s .= int($DataMatrix[$DataMillis_i][$x]).$delim;
    for(my $n=0; $n<3; $n++ ){ $s .= int($DataMatrix[$DataRx_i+$n][$x]).$delim; }
    $s .= int($DataMatrix[$DataAccAbs_i][$x]).$delim;
    $s .= int($DataMatrix[$DataAccConfidence_i][$x]).$delim;
    for(my $n=0; $n<3; $n++ ){ $s .= int($DataMatrix[$DataPitch_i+$n][$x]).$delim; }
    for(my $n=0; $n<3; $n++ ){ $s .= int($DataMatrix[$DataPitchCntrl_i+$n][$x]).$delim; }
    for(my $n=0; $n<3; $n++ ){ $s .= int($DataMatrix[$DataPitch2_i+$n][$x]).$delim; }
    for(my $n=0; $n<3; $n++ ){ $s .= int($DataMatrix[$DataPitchEncoder_i+$n][$x]).$delim; }
    $s .= UIntToHexstr( $DataMatrix[$DataState_i+0][$x] ).$delim;
    $s .= "\n";

  $Data_RecordingInitialize = -1;
  return $s;
}

sub DrawR{     Paint($w_Plot_R,20000); }
sub DrawAngle{ Paint($w_Plot_Angle,$PlotAngleRange); }
sub DrawCntrl{ Paint($w_Plot_Cntrl,6000); }
sub Draw{      DrawR(); DrawAngle(); DrawCntrl(); }

sub ShowDataDisplay{
  $w_DataDisplay->Show();
  Draw();
  $w_DataDisplay->SetForegroundWindow();
}

#adapt DataDisplay at startup
if( $ActiveBoardConfiguration == $BOARDCONFIGURATION_IS_FOC ){
  DataDisplay_AdaptToBoardConfigurationFoc();
}else{
  DataDisplay_AdaptToBoardConfigurationDefault();
}



#==============================================================================
# Event Handler für Data Display

sub m_datadisplay_Window_Terminate{
  DataDisplayHalt();
  $DataDisplay_LiveRecording = 0;
  $w_DataDisplay->dd_LiveRecording->Text( 'Rec' );
  $w_DataDisplay->Text( $BGCStr.' Data Display' );
  $w_DataDisplay->Hide();
  0;
}

sub dd_PlotR_Paint{
  my $DC = shift;
  DrawR();
  $DC->Validate();
}

sub dd_PlotA_Paint{
  my $DC = shift;
  DrawAngle();
  $DC->Validate();
}

sub dd_PlotC_Paint{
  my $DC = shift;
  DrawCntrl();
  $DC->Validate();
}

sub dd_Start_Click{ DataDisplayStart(); 1; }

sub dd_Clear_Click{ DataDisplayClear(); 1; }

my $DataDisplayFile_lastdir= $ExePath;

sub dd_Save_Click{
  my $file= Win32::GUI::GetSaveFileName( -owner=> $w_DataDisplay, #$w_Main,
    -title=> 'Save DataDisplay Data to File',
    -nochangedir=> 1,
    -directory=> $DataDisplayFile_lastdir,
    -defaultextension=> '.dat',
    -filter=> ['*.dat'=>'*.dat','*.txt'=>'*.txt','*.csv'=>'*.csv','All files'=>'*.*'],
    -pathmustexist=> 1,
    -extensiondifferent=> 1,
    -overwriteprompt=> 1,
    -noreadonlyreturn => 1,
    -explorer=>0,
  );
  if( $file ){
    if( !open(F,">$file") ){ $w_Main->MessageBox( "Some error occured, sorry",'ERROR'); return 1; }
    my $delim = "\t";
    if( $file =~ /\.csv$/i ){ $delim = ','; }
    print F DataDisplayFormatFirstLine($delim);
    #XX change this such that it saves ALL available data!!!
    my $xstart = 0;
    my $pxlen = 0;
    if( $DataMatrixLength<$PlotMaxWidth ){ #the ring buffer is not yet full
      $xstart = 0;
      $pxlen = $DataPos;
    }else{
      $xstart = $DataPos;
      $pxlen = $DataMatrixLength;
    }
    for(my $px=0; $px<$pxlen; $px++){
      my $x = $px + $xstart;
      if( $x >= $DataMatrixLength ){ $x-= $DataMatrixLength; }
      print F DataDisplayFormatDataLine( $x, $delim );
    }
    close(F);
    $DataDisplayFile_lastdir= $file;
  }elsif( Win32::GUI::CommDlgExtendedError() ){ $w_Main->MessageBox("Some error occured, sorry",'ERROR'); return 1;}
  1;
}

sub dd_LiveRecording_Click{
  if( not $DataDisplay_LiveRecording ){
  my $file= Win32::GUI::GetSaveFileName( -owner=> $w_DataDisplay, #$w_Main,
    -title=> 'Select DataDisplay Live Recording File',
    -nochangedir=> 1,
    -directory=> $DataDisplayFile_lastdir,
    -defaultextension=> '.dat',
    -filter=> ['*.dat'=>'*.dat','*.txt'=>'*.txt','*.csv'=>'*.csv','All files'=>'*.*'],
    -pathmustexist=> 1,
    -extensiondifferent=> 1,
    -overwriteprompt=> 1,
    -noreadonlyreturn => 1,
    -explorer=>0,
  );
    if( $file ){
      if( !open(F,">$file") ){ $w_Main->MessageBox( "Some error occured, sorry",'ERROR'); return 1; }
      $DataDisplay_LiveRecordingDelimiter = "\t";
      if( $file =~ /\.csv$/i ){ $DataDisplay_LiveRecordingDelimiter = ','; }
      print F DataDisplayFormatFirstLine($DataDisplay_LiveRecordingDelimiter);
      close(F);
      $DataDisplayFile_lastdir= $file;
      $DataDisplay_LiveRecordingFile = $file;
      $DataDisplay_LiveRecording = 1;
      $w_DataDisplay->dd_LiveRecording->Text( 'Rec !' );
      $w_DataDisplay->Text( $BGCStr.' Data Display'.' : Recording to '.$DataDisplay_LiveRecordingFile );
    }elsif( Win32::GUI::CommDlgExtendedError() ){ $w_Main->MessageBox("Some error occured, sorry",'ERROR'); return 1;}
  }else{
    $DataDisplay_LiveRecording = 0;
    $w_DataDisplay->dd_LiveRecording->Text( 'Rec' );
    $w_DataDisplay->Text( $BGCStr.' Data Display' );
  }
  1;
}


# Ende Data Display Window
###############################################################################
















#-----------------------------------------------------------------------------#
###############################################################################
# SCRIPT Routines and Window
###############################################################################
#-----------------------------------------------------------------------------#

# the infos for handling the script is stored in three "field"
# - option field 'Scripts'
#   this field is a sort of a dummy, it doesn't hold real data,
#   it is used as handle to indicate that the script is accessed
#   and it holds the Win32::GUI handle to the script textfield in {textfield_script}
# - {textfield_script}
#   this field holds the script in Text format
# - $SCRIPT_hexcode_buf
#   this field holds the script in hex format

# the script hex code is generally shortened to FF, it will be cut and expanded in Read and Write

#this MUST match SCRIPTCMDENUM !!!
my @SCRIPT_CMDS= (
    'STOP', 'RESTART',
    'REPEAT', 'CASE#DEFAULT', 'CASE#1', 'CASE#2', 'CASE#3', 'JUMP',
    'RESTOREALL', 'WAIT', 'SET', 'SETMINMAX', 'RESTORE',
    'SETANGLEPITCH', 'SETANGLEROLL', 'SETANGLEYAW', 'SETANGLE',
    'SETPITCH', 'SETROLL', 'SETYAW', 'SETPITCHROLLYAW',
    'SETSTANDBY', 'DOCAMERA', 'DORECENTER', 'SETPWM',
    'SETPANOWAITS', 'SETPANORANGE', 'DOPANO',
    'SETANGLEPITCH_W', 'SETANGLEROLL_W', 'SETANGLEYAW_W',
    'REMOTEENABLE', 'REMOTEDISABLE',
    'BEEP',
    'SETPANOALLOWEXIT',
    'CASE#4',
    'SENDMAVTEXT_18', 'SENDMAVTEXT_15',  'SENDMAVTEXT_12',  'SENDMAVTEXT_9',  'SENDMAVTEXT_6',
    'SENDCAMTEXT_18', 'SENDCAMTEXT_15',  'SENDCAMTEXT_12',  'SENDCAMTEXT_9',  'SENDCAMTEXT_6',
    'DORECENTERPITCH', 'DORECENTERROLL', 'DORECENTERYAW',
    '' );

my $SCRIPT_hexcode_buf; #this is to store the original "raw" script code, in hexstr formatr #don't initialize

sub Script_ClearScriptHexCode{
  $SCRIPT_hexcode_buf = 'FF'.'FF'.'FF'.'FF';
}

#called in SetOptionField()
sub Script_SetScriptHexCode{
  my $script_hex = shift;
  if( length($script_hex) < 2*4 ){
    $script_hex = 'FF'.'FF'.'FF'.'FF';
  }else{
    #don't cut down, since things like 04FFFFFF FF can happen
    #$script_hex =~ s/FF+$/FF/; #cut it down to one FF
  }
  $SCRIPT_hexcode_buf = $script_hex;
}

#called in GetOptionField()
sub Script_GetScriptHexCode{
  my $script_hex = $SCRIPT_hexcode_buf;
  return $script_hex;
}

#helper for convert to text
sub script_U16ToDez{
  my $hex = shift; my $pos = shift;
  my $v = HexstrToDez( substr($hex,$pos+2,2).substr($hex,$pos,2) );
  return $v;
}

sub script_S16ToDez{
  my $hex = shift; my $pos = shift;
  my $v = HexstrToDez( substr($hex,$pos+2,2).substr($hex,$pos,2) );
  if( $v > 32768-1 ){ $v = $v-65536; }
  return $v;
}

sub script_U8ToDez{
  my $hex = shift; my $pos = shift;
  my $v = HexstrToDez( substr($hex,$pos,2) );
  return $v;
}

sub script_S8ToDez{
  my $hex = shift; my $pos = shift;
  my $v = HexstrToDez( substr($hex,$pos,2) );
  if( $v > 128-1 ){ $v = $v-256; }
  return $v;
}

sub script_ValueToText{
  my $Option = shift; my $value = shift;
  if( not defined $Option ){ return '?'; }
  switch( $Option->{type} ){
    case 'LIST' {
      return '"'.$Option->{choices}[$value].'"';
    }
    case ['UINT','UINT8', ] {
      #return '"'.ConvertOptionToStrWUnit($Option, $value).'"';
      return ConvertOptionToStr($Option, $value);
    }
    case 'INT' {
      if( $value > 32768-1 ){ $value = $value-65536; }
      #return '"'.ConvertOptionToStrWUnit($Option, $value).'"';
      return ConvertOptionToStr($Option, $value);
    }
    case 'INT8' {
      if( $value > 128-1 ){ $value = $value-256; }
      #return '"'.ConvertOptionToStrWUnit($Option, $value).'"';
      return ConvertOptionToStr($Option, $value);
    }
  }
}

sub script_CStrToText{
  my $hex = shift; my $pos = shift; my $cnt = shift; #18, 15, 12, 9, 6
  my $v = substr($hex,$pos,2*$cnt);
  #decompress text
#TextOut('$'.$v.'$'."\n");
  my $b = ''; #bits
  for(my $n=0; $n<$cnt; $n++){
    my $c = HexstrToDez(substr($v, 2*$n, 2));
#TextOut('$'.$c.'$'."\n");
    $b .= UCharToBitstr($c);
  }
#TextOut('$'.$b.'$'."\n");
  $v = ''; #text
  $cnt = ($cnt*4)/3;
  for(my $n=0; $n<$cnt; $n++){
    my $c = '00'.substr($b, 6*$n, 6);
#TextOut('$'.$c.'$'."\n");
    $c = ord(pack('B8',$c));
#TextOut('$'.$c.'$'."\n");
    if( $c == 1 ){
      $v .= ' ';
    }elsif( ($c >= 2+0) and ($c < 2+10) ){
      $v .= chr(ord('0') + $c - 2);
    }elsif( ($c >= 12+0) and ($c < 12+26) ){
      $v .= chr(ord('a') + $c - 12);
    }elsif( ($c >= 38+0) and ($c < 38+26) ){
      $v .= chr(ord('A') + $c - 38);
    }
  }
#TextOut( '$'.$v.'$'."\n" );
  return $v;
}

#----
# SCRIPT TEXT CONVERTER
#----
#this converts script code stored in $SCRIPT_hexcode_buf to text, for one script
# parameters: nr of script, format flag e.g. 'nopc'
# first four bytes hold base pc's
# returns
sub Script_ConvertToTextForSingleScript{
  my $script_hex = $SCRIPT_hexcode_buf;
  my $script_nr = shift;
  my $script_showpc_flag = shift;
  if( not defined $script_showpc_flag ){ $script_showpc_flag = ''; }

##TextOut( "!".$script_hex."!" );
  if( length($script_hex) < 2*4 ){ return 'ERR'; }

  my $pc0 = HexstrToDez(substr($script_hex,2*($script_nr-1),2)); #get base pc of script
#TextOut( "!".$pc0."!" );
#TextOut( "!".$script_hex."!" );
  my $script_text = ''; my $pc = 0; my $indent = '';

  if( $pc0 >= $SCRIPTSIZE ){  #0xFF, script is not active
    if($script_showpc_flag ne 'nopc'){ $script_text .= sprintf( "%2d", 0 ).': '.'STOPFF'; }
    return $script_text;
  }

  for( $pc = 2*$pc0; $pc < length($script_hex); $pc += 2 ){
    if($script_showpc_flag ne 'nopc'){ $script_text .= sprintf( "%2d", $pc/2-$pc0 ).': '; }
    my $op = substr($script_hex, $pc, 2);
    if( $op eq 'FF' ){
      if($script_showpc_flag ne 'nopc'){ $script_text .= 'STOPFF'; }
      last;
    }else{
      my $s = $SCRIPT_CMDS[HexstrToDez($op)];

      if( $s eq 'STOP' ){
        $script_text .= $indent.$s; #$indent='';
      }elsif( $s eq 'RESTART' ){
        $script_text .= $indent.$s; #$indent='';

      }elsif( $s eq 'REPEAT' ){
        $script_text .= $indent.$s;
        if($script_showpc_flag ne 'nopc'){ $script_text .= '  ('.script_U8ToDez($script_hex, $pc+2).')'; }
        $pc += 2;
      }elsif( ($s eq 'CASE#DEFAULT') or ($s eq 'CASE#1') or ($s eq 'CASE#2') or ($s eq 'CASE#3') or ($s eq 'CASE#4') ){
        $script_text .= $s;
        if($script_showpc_flag ne 'nopc'){ $script_text .= '  ('.script_U8ToDez($script_hex, $pc+2).')'; }
        $indent = '   ';
        $pc += 2;

      }elsif( $s eq 'RESTOREALL' ){
        $script_text .= $indent.$s;
      }elsif( $s eq 'WAIT' ){
        $script_text .= $indent.$s;
        my $time = script_U8ToDez($script_hex, $pc+2);
        $script_text .= ' '.$time;
        $pc += 2;
      }elsif( $s eq 'SET' ){ # uint8 int16/uint16
#        $script_text .= $indent.$s;
#        my ($name,$type) = FindOptionNameTypeByAdr( script_U8ToDez($script_hex,$pc+2) );
#        $name =~ s/\s*\(.*\)$//;
#        $script_text .= ' "'.$name.'"';
#        my $v = script_U16ToDez($script_hex,$pc+4);
#        if( $type eq 'INT' ){
#          if( $v > 32768-1 ){ $v = $v-65536; }
#        }
        $script_text .= $indent.'SETP';
        my ($option, $name) = FindOptionNameByAdr( script_U8ToDez($script_hex,$pc+2) );
        my $v = script_ValueToText( $option, script_U16ToDez($script_hex, $pc+4) );
        $script_text .= ' "'.$name.'"' .' '. $v;
        $pc += 2+4;
      }elsif( $s eq 'SETMINMAX' ){ # uint8 int16 int16
#        $script_text .= $indent.$s;
#        my $name = FindOptionByAdr( script_U8ToDez($script_hex,$pc+2) )->{name};
#        $script_text .= ' "'.$name.'"';
#        $script_text .= ' '. HexstrToDez( substr($script_hex,$pc+6,2).substr($script_hex,$pc+4,2) );
#        $script_text .= ' '. HexstrToDez( substr($script_hex,$pc+10,2).substr($script_hex,$pc+8,2) );
        $script_text .= $indent.'SETPMINMAX';
        my ($option, $name) = FindOptionNameByAdr( script_U8ToDez($script_hex,$pc+2) );
        my $v1 = script_ValueToText( $option, script_U16ToDez($script_hex, $pc+4) );
        my $v2 = script_ValueToText( $option, script_U16ToDez($script_hex, $pc+8) );
        $script_text .= ' "'.$name.'"' .' '. $v1 .' '. $v2;
        $pc += 2+4+4;
      }elsif( $s eq 'RESTORE' ){ # uint8
        $script_text .= $indent.$s;
        my ($option, $name) = FindOptionNameByAdr( script_U8ToDez($script_hex,$pc+2) );
        $script_text .= ' "'.$name.'"';
        $pc += 2;

      }elsif( ($s eq 'SETANGLEPITCH') or ($s eq 'SETANGLEROLL') or ($s eq 'SETANGLEYAW') ){ # int16
        $script_text .= $indent.$s;
        my $v = script_S16ToDez($script_hex, $pc+2);
        $script_text .= ' '. ($v*0.01);
        $pc += 4;
      }elsif( $s eq 'SETANGLE' ){# int16 int16 int16
        $script_text .= $indent.$s;
        my $v1 = script_S16ToDez($script_hex, $pc+2);
        my $v2 = script_S16ToDez($script_hex, $pc+6);
        my $v3 = script_S16ToDez($script_hex, $pc+10);
        $script_text .= ' '. ($v1*0.01) .' '. ($v2*0.01) .' '. ($v3*0.01);
        $pc += 4+4+4;

      }elsif( ($s eq 'SETPITCH') or ($s eq 'SETROLL') or ($s eq 'SETYAW') ){ # uint16
        $script_text .= $indent.$s;
        my $v = script_U16ToDez($script_hex, $pc+2);
        $script_text .= ' '. $v;
        $pc += 4;
      }elsif( $s eq 'SETPITCHROLLYAW' ){ # uint16 uint16 uint16
        $script_text .= $indent.$s;
        my $v1 = script_U16ToDez($script_hex, $pc+2);
        my $v2 = script_U16ToDez($script_hex, $pc+6);
        my $v3 = script_U16ToDez($script_hex, $pc+10);
        $script_text .= ' '. $v1 .' '. $v2 .' '. $v3;
        $pc += 4+4+4;

      }elsif( $s eq 'SETSTANDBY' ){ # uint8
        $script_text .= $indent.$s;
        my $v = script_U8ToDez($script_hex, $pc+2);
        $script_text .= ' '. $v;
        $pc += 2;
      }elsif( $s eq 'DOCAMERA' ){ # uint8
        $script_text .= $indent.$s;
        my $v = script_U8ToDez($script_hex, $pc+2);
        $script_text .= ' '. $v;
        $pc += 2;
      }elsif( $s eq 'DORECENTER' ){ # no param
        $script_text .= $indent.$s;
      }elsif( $s eq 'SETPWM' ){ # uint16
        $script_text .= $indent.$s;
        my $v = script_U16ToDez($script_hex, $pc+2);
        $script_text .= ' '. $v;
        $pc += 4;

      }elsif( $s eq 'SETPANOWAITS' ){ #//uint8 uint8 uint8
        $script_text .= $indent.$s;
        my $v1 = script_U8ToDez($script_hex, $pc+2);
        my $v2 = script_U8ToDez($script_hex, $pc+4);
        my $v3 = script_U8ToDez($script_hex, $pc+6);
        $script_text .= ' '. $v1 .' '. $v2 .' '. $v3;
        $pc += 2+2+2;
      }elsif( $s eq 'SETPANORANGE' ){ #int16
        $script_text .= $indent.$s;
        my $v = script_S16ToDez($script_hex, $pc+2);
        $script_text .= ' '. $v;
        $pc += 4;
      }elsif( $s eq 'DOPANO' ){ # int8 int8
        $script_text .= $indent.$s;
        my $v1 = script_S8ToDez($script_hex, $pc+2);
        my $v2= script_S8ToDez($script_hex, $pc+4);
        $script_text .= ' '. $v1 .' '. $v2;
        $pc += 2+2;

      }elsif( ($s eq 'SETANGLEPITCH_W') or ($s eq 'SETANGLEROLL_W') or ($s eq 'SETANGLEYAW_W') ){ # int16 uint8
        $script_text .= $indent.$s;
        my $v1 = script_S16ToDez($script_hex, $pc+2);
        my $v2 = script_U8ToDez($script_hex, $pc+6);
        $script_text .= ' '. ($v1*0.01) .' '. $v2;
        $pc += 4+2;

      }elsif( $s eq 'REMOTEENABLE' ){ # no param
        $script_text .= $indent.$s;
      }elsif( $s eq 'REMOTEDISABLE' ){ # no param
        $script_text .= $indent.$s;

      }elsif( $s eq 'BEEP' ){ # no param
        $script_text .= $indent.$s;

      }elsif( $s eq 'SETPANOALLOWEXIT' ){ # no param
        $script_text .= $indent.$s;

      }elsif( $s eq 'SENDMAVTEXT_18' ){ # uint8[18]
        $script_text .= $indent.'SENDMAVTEXT';
        my $text = script_CStrToText($script_hex, $pc+2, 18);
        $script_text .= ' "'.$text.'"';
        $pc += 2*18;
      }elsif( $s eq 'SENDMAVTEXT_15' ){ # uint8[15]
        $script_text .= $indent.'SENDMAVTEXT';
        my $text = script_CStrToText($script_hex, $pc+2, 15);
        $script_text .= ' "'.$text.'"';
        $pc += 2*15;
      }elsif( $s eq 'SENDMAVTEXT_12' ){ # uint8[12]
        $script_text .= $indent.'SENDMAVTEXT';
        my $text = script_CStrToText($script_hex, $pc+2, 12);
        $script_text .= ' "'.$text.'"';
        $pc += 2*12;
      }elsif( $s eq 'SENDMAVTEXT_9' ){ # uint8[9]
        $script_text .= $indent.'SENDMAVTEXT';
        my $text = script_CStrToText($script_hex, $pc+2, 9);
        $script_text .= ' "'.$text.'"';
        $pc += 2*9;
      }elsif( $s eq 'SENDMAVTEXT_6' ){ # uint8[6]
        $script_text .= $indent.'SENDMAVTEXT';
        my $text = script_CStrToText($script_hex, $pc+2, 6);
        $script_text .= ' "'.$text.'"';
        $pc += 2*6;

      }elsif( $s eq 'SENDCAMTEXT_18' ){ # uint8[18]
        $script_text .= $indent.'SENDCAMTEXT';
        my $text = script_CStrToText($script_hex, $pc+2, 18);
        $script_text .= ' "'.$text.'"';
        $pc += 2*18;
      }elsif( $s eq 'SENDCAMTEXT_15' ){ # uint8[15]
        $script_text .= $indent.'SENDCAMTEXT';
        my $text = script_CStrToText($script_hex, $pc+2, 15);
        $script_text .= ' "'.$text.'"';
        $pc += 2*15;
      }elsif( $s eq 'SENDCAMTEXT_12' ){ # uint8[12]
        $script_text .= $indent.'SENDCAMTEXT';
        my $text = script_CStrToText($script_hex, $pc+2, 12);
        $script_text .= ' "'.$text.'"';
        $pc += 2*12;
      }elsif( $s eq 'SENDCAMTEXT_9' ){ # uint8[9]
        $script_text .= $indent.'SENDCAMTEXT';
        my $text = script_CStrToText($script_hex, $pc+2, 9);
        $script_text .= ' "'.$text.'"';
        $pc += 2*9;
      }elsif( $s eq 'SENDCAMTEXT_6' ){ # uint8[6]
        $script_text .= $indent.'SENDCAMTEXT';
        my $text = script_CStrToText($script_hex, $pc+2, 6);
        $script_text .= ' "'.$text.'"';
        $pc += 2*6;

      }elsif( $s eq 'DORECENTERPITCH' ){ # no param
        $script_text .= $indent.$s;
      }elsif( $s eq 'DORECENTERROLL' ){ # no param
        $script_text .= $indent.$s;
      }elsif( $s eq 'DORECENTERYAW' ){ # no param
        $script_text .= $indent.$s;

      }
      $script_text .= "\r\n";
    }

  }
  return $script_text;
}

#----
# SCRIPT COMPILER
#----
sub Script_GetNextCommand{
  my $code= shift;
  $code =~ s/^\s*([a-zA-Z0-9#_]+?)\s(.*)/$2/;
  if( not defined $1 ){ return('',''); }
  return ($code, $1);
}

sub Script_GetParameterAdr{
  my $code= shift;
  $code =~ s/^\s*"([a-zA-Z0-9# ]+?)"\s(.*)/$2/; #finds parameter name string, and removes it
  if( not defined $1 ){ return('',''); }
  my $adr = FindOptionAdrByName( $1 );
  if( $adr < 0 ){ $adr = ''; }
  return ($code, $adr);
}

sub Script_GetParameterAdrType{
  my $code= shift;
  $code =~ s/^\s*"([a-zA-Z0-9# ]+?)"\s(.*)/$2/; #finds parameter name string, and removes it
  if( not defined $1 ){ return('','',''); }
  my ($adr,$type) = FindOptionAdrTypeByName( $1 );
  if( $adr < 0 ){ $adr = ''; }
  return ($code, $adr, $type);
}

sub Script_GetParameterValue{
  my $code = shift;
  $code =~ s/^\s*([-|+]?[0-9]+)\s(.*)/$2/; #also allow negativ values!!!
  if( not defined $1 ){ return('',''); }
  return ($code, $1);
}

sub Script_GetParameterOption{
  my $code= shift;
  $code =~ s/^\s*"([a-zA-Z0-9# ]+?)"\s(.*)/$2/; #finds parameter name string, and removes it
  if( not defined $1 ){ return('','',''); }
  my $option = FindOptionByName( $1 );
  if( not defined $option ){ return ($code, '', undef); }
  return ($code, $option->{adr}, $option);
}

sub script_TextToValue{
  my $Option = shift; my $text = shift;
  if( not defined $Option ){ return (0, 'e1'); }
  switch( $Option->{type} ){
    case 'LIST' {
      $text =~ s/"//g; #remove enclosing "", we can use this to distinguish number from text
      my $i = 0;
      foreach my $t (@{$Option->{choices}}) {
        if( uc($t) eq $text ){ return ($i, ''); }
        $i++;
      }
      return (0, 'e1');
    }
    case 'UINT' {
      for(my $n=0; $n<$Option->{ppos}; $n++){ $text = $text*10;}
      $text = int($text+0.4999);
      if( $text < 0 ){ return (0, 'e2'); }
      if( $text > 65536){ return (0, 'e3'); }
      return ($text, '');
    }
    case 'UINT8' {
      for(my $n=0; $n<$Option->{ppos}; $n++){ $text = $text*10;}
      $text = int($text+0.4999);
      if( $text < 0 ){ return (0, 'e2'); }
      if( $text > 255 ){ return (0, 'e3'); }
      return ($text, '');
    }
    case 'INT' {
      for(my $n=0; $n<$Option->{ppos}; $n++){ $text = $text*10;}
      $text = int($text+0.49);
      if( ($text <-32768) or ($text > 32767) ){ return (0, 'e3'); }
      return ($text, '');
    }
    case 'INT8' {
      for(my $n=0; $n<$Option->{ppos}; $n++){ $text = $text*10;}
      $text = int($text+0.49);
      if( ($text <-128) or ($text > 127) ){ return (0, 'e3'); }
      return ($text, '');
    }
  }
  return (0, 'e1');
}

sub Script_GetParameterText{
  my $code = shift; my $option = shift;
  $code =~ s/^\s*("[a-zA-Z0-9\.\+\-\/°#%: ]+?"|[-|+]?[0-9\.]+)\s(.*)/$2/; #finds parameter name string, or a float/int value, and removes it
  if( not defined $1 ){ return('',''); }
  my ($v,$err) = script_TextToValue($option, $1);
  if( $err eq 'e1' ){ $err = 'Valid parameter value expected!'; }
  if( $err eq 'e2' ){ $err = 'Non-negative parameter value expected!';}
  if( $err eq 'e3' ){ $err = 'Parameter value out of range!';}
  return ($code, $v, $err);
}

sub Script_TokenToWord{
  my $token = shift;
  my $v = UIntToHexstr($token);
  if( $token < 0 ){ $v = substr($v,4,4); } #for some reason UIntToHexstr yields then a 8char result, instead of 4char
  return substr($v,2,2).substr($v,0,2);
}


sub Script_GetUIntValue{
  my $code= shift;
  $code =~ s/^\s*([0-9]+)\s(.*)/$2/;
  if( not defined $1 ){ return('',''); }
  return ($code, $1);
}

sub Script_GetIntValue{
  my $code = shift;
  $code =~ s/^\s*([-|+]?[0-9]+)\s(.*)/$2/; #also allow negativ values!!!
  if( not defined $1 ){ return('',''); }
  return ($code, $1);
}

sub Script_GetFloatValue{
  my $code= shift;
  $code =~ s/^\s*([-|+]?[0-9\.]+)\s(.*)/$2/; #also allow negativ values, and '.'!!!
  if( not defined $1 ){ return('',''); }
  return ($code, $1);
}

sub Script_GetCStr{ #string of up to 24 chars, compressed into 18 uint8
  my $code = shift;
  $code =~ s/^\s*"([a-zA-Z0-9 ]+?)"\s(.*)/$2/; #finds text string
  if( not defined $1 ){ return('','','',0); }
  my $token = $1;
  my $cnt = 24;
  if( length($1) <= 20 ){ $cnt = 20; }
  if( length($1) <= 16 ){ $cnt = 16; }
  if( length($1) <= 12 ){ $cnt = 12; }
  if( length($1) <= 8 ){ $cnt = 8; }
  # compress text
#TextOut( '$'.$1.'$'."\n" );
  my $b = ''; #bits
  for(my $n=0; $n<$cnt; $n++){
    my $c = '';
    if( $n < length($1) ){ $c = substr($1,$n,1); }
#TextOut( '$'.$c.'$'."\n" );
    if( $c eq '' ){
      $b .= substr(UCharToBitstr(0),2,6) .'!';
    }elsif( $c eq ' ' ){
      $b .= substr(UCharToBitstr(1),2,6) .'!';
    }elsif( ($c ge '0') and ($c le '9') ){
      $b .= substr(UCharToBitstr( 2+ord($c)-ord('0') ),2,6) .'!';
    }elsif( ($c ge 'a') and ($c le 'z') ){
      $b .= substr(UCharToBitstr( 12+ord($c)-ord('a') ),2,6) .'!';
    }elsif( ($c ge 'A') and ($c le 'Z') ){
      $b .= substr(UCharToBitstr( 38+ord($c)-ord('A') ),2,6) .'!';
    }else{
      $b .= substr(UCharToBitstr(0),2,6) .'!';
    }
  }
#TextOut( '$'.$b.'$'."\n" );
  $b =~ s/!//g;
  my $v = ''; #hex
  $cnt = int($cnt * 0.75); #for some strange reason ($cnt*3)/4 gives compile error
  for(my $n=0; $n<$cnt; $n++){
    my $c = substr($b,$n*8,8);
    $c = ord(pack('B8',$c));
#TextOut( '$'.$c.'$'."\n" );
    $v .= UCharToHexstr($c);
  }
#TextOut( '$'.$v.'$'."\n" );
  return ($code, $token, $v, $cnt);
}

#this compiles a script code into hex code
# parameters: nr of script, script code in text format
# returns:
sub Script_CompileText{
  my $script_nr = shift;
  my $code = uc( shift ).' ';  #add a white char to simplify regex    #my $code= $w_Script->script_Text->Text();

#TextOut( "!".$code."!\r\n" );
  my $token; my $type; my $option; my $res; my $cnt;
  my $hexcode ='';
  my $state = 'cmd'; my $pc = 0; my $error = ''; my $lastcasepc = 0; my $lastcmd = '';
  my @casepclist = (-1,-1,-1,-1,-1);

  while(1){
    if( $code =~ /^\s*$/ ){ last; } # done
    ($code,$token) = Script_GetNextCommand($code);
#TextOut( '?'.$token."?\r\n" );
#TextOut( "!".$code."!\r\n" );
    if( $token eq '' ){ $error = 'Valid command expected!'; goto ERROR;}

    switch ( $token ){
      case 'STOPFF' {
        last;
      }

      case 'STOP' {
        $lastcmd = $token;
        $hexcode .= '00'; $pc += 2;
      }

      case 'RESTART' {
        $lastcmd = $token;
        $hexcode .= '01'; $pc += 2;
      }

      case 'REPEAT'{
        $lastcmd = $token;
        $hexcode .= '02'; $pc += 2;
        if( $state eq 'case' ){ #we are in a case statement
          $hexcode .= UCharToHexstr($lastcasepc/2); $pc += 2;
        }else{
          $hexcode .= '00'; $pc += 2; #go to start pc
        }
      }

      case 'CASE#DEFAULT' {
        if( $casepclist[0] != -1 ){ $error = 'CASE#DEFAULT used twice!'; goto ERROR;} #was used already before
        $casepclist[0] = 1;
        if( ($state eq 'case') && ($lastcmd ne '') && ($lastcmd ne 'STOP') && ($lastcmd ne 'RESTART') && ($lastcmd ne 'REPEAT') ){
          $hexcode .= '00'; $pc += 2;
        }
        if( $state eq 'case' ){ #we had been in a case statement before
          substr( $hexcode, $lastcasepc+2, 2, UCharToHexstr($pc/2) );
        }
        $lastcmd = $token;
        $lastcasepc = $pc;
        $state = 'case';

        $hexcode .= '03'; $pc += 2;
        $hexcode .= '!!'; $pc += 2;
      }

      case 'CASE#1' {
        if( $casepclist[1] != -1 ){ $error='CASE#1 used twice!'; goto ERROR;} #was used already before
        $casepclist[1] = 1;
        if( $state eq 'case' ){ #we had been in a case statement before
          if( ($lastcmd ne '') && ($lastcmd ne 'STOP') && ($lastcmd ne 'RESTART') && ($lastcmd ne 'REPEAT') ){
            $hexcode .= '00'; $pc += 2;
          }
          substr( $hexcode, $lastcasepc+2, 2, UCharToHexstr($pc/2) );
        }
        $lastcmd = $token;
        $lastcasepc = $pc;
        $state = 'case';

        $hexcode .= '04'; $pc += 2;
        $hexcode .= '!!'; $pc += 2;
      }

      case 'CASE#2' {
        if( $casepclist[2] != -1 ){ $error = 'CASE#2 used twice!'; goto ERROR;} #was used already before
        $casepclist[2] = 1;
        if( $state eq 'case' ){ #we had been in a case statement before
          if( ($lastcmd ne '') && ($lastcmd ne 'STOP') && ($lastcmd ne 'RESTART') && ($lastcmd ne 'REPEAT') ){
            $hexcode .= '00'; $pc += 2;
          }
          substr( $hexcode, $lastcasepc+2, 2, UCharToHexstr($pc/2) );
        }
        $lastcmd = $token;
        $lastcasepc = $pc;
        $state = 'case';

        $hexcode .= '05'; $pc += 2;
        $hexcode .= '!!'; $pc += 2;
      }

      case 'CASE#3' {
        if( $casepclist[3] != -1 ){ $error = 'CASE#3 used twice!'; goto ERROR;} #was used already before
        $casepclist[3] = 1;
        if( $state eq 'case' ){ #we had been in a case statement before
          if( ($lastcmd ne '') && ($lastcmd ne 'STOP') && ($lastcmd ne 'RESTART') && ($lastcmd ne 'REPEAT') ){
            $hexcode .= '00'; $pc += 2;
          }
          substr( $hexcode, $lastcasepc+2, 2, UCharToHexstr($pc/2) );
        }
        $lastcmd = $token;
        $lastcasepc = $pc;
        $state = 'case';

        $hexcode .= '06'; $pc += 2;
        $hexcode .= '!!'; $pc += 2;
      }

      case 'CASE#4' {
        if( $casepclist[4] != -1 ){ $error = 'CASE#4 used twice!'; goto ERROR;} #was used already before
        $casepclist[4] = 1;
        if( $state eq 'case' ){ #we had been in a case statement before
          if( ($lastcmd ne '') && ($lastcmd ne 'STOP') && ($lastcmd ne 'RESTART') && ($lastcmd ne 'REPEAT') ){
            $hexcode .= '00'; $pc += 2;
          }
          substr( $hexcode, $lastcasepc+2, 2, UCharToHexstr($pc/2) );
        }
        $lastcmd = $token;
        $lastcasepc = $pc;
        $state = 'case';

        $hexcode .= '23'; $pc += 2;
        $hexcode .= '!!'; $pc += 2;
      }

      case 'RESTOREALL'{
        $lastcmd = $token;
        $hexcode .= '08'; $pc += 2;
      }

      case 'WAIT'{
        $lastcmd = $token;
        $hexcode .= '09'; $pc += 2;

        ($code,$token) = Script_GetIntValue($code); #value
        if( $token eq '' ){ $error = 'Valid parameter value expected!'; goto ERROR;}
        if( ($token < 0) or ($token > 255) ){ $error = 'Wait time out of range!'; goto ERROR;}
        my $v = UCharToHexstr($token);
        $hexcode.= $v; $pc += 2; #low byte
      }

      case 'SET' {
        $lastcmd = $token;
        $hexcode .= '0A'; $pc += 2;

        ($code,$token,$type) = Script_GetParameterAdrType($code); #parameter nr
        if( $token eq '' ){ $error = 'Valid parameter name expected!'; goto ERROR;}
        $hexcode .= UCharToHexstr($token); $pc += 2;

        ($code,$token) = Script_GetParameterValue($code); #value
        if( $token eq '' ){ $error = 'Valid parameter value expected!'; goto ERROR;}
        if( $token < 0 ){
          if( $type ne 'INT' ){ $error = 'Non-negative parameter value expected!'; goto ERROR;}
        };
        $hexcode .= Script_TokenToWord($token); $pc += 4; #low byte, high byte
      }
      case 'SETMINMAX' {
        $lastcmd = $token;
        $hexcode .= '0B'; $pc += 2;

        ($code,$token) = Script_GetParameterAdr($code); #parameter nr
        if( $token eq '' ){ $error = 'Valid parameter name expected!'; goto ERROR;}
        $hexcode .= UCharToHexstr($token); $pc += 2;

        ($code,$token) = Script_GetParameterValue($code); #min value
        if( $token eq '' ){ $error = 'Valid parameter value expected!'; goto ERROR;}
        $hexcode .= Script_TokenToWord($token); $pc += 4; #low byte, high byte

        ($code,$token) = Script_GetParameterValue($code); #max value
        if( $token eq '' ){ $error = 'Valid parameter value expected!'; goto ERROR;}
        $hexcode .= Script_TokenToWord($token); $pc += 4; #low byte, high byte
      }
      case 'SETP' {
        $lastcmd = $token;
        $hexcode .= '0A'; $pc += 2;

        ($code,$token,$option) = Script_GetParameterOption($code); #parameter nr
        if( $token eq '' ){ $error = 'Valid parameter name expected!'; goto ERROR;}
        $hexcode .= UCharToHexstr($token); $pc += 2;

        ($code,$token,$res) = Script_GetParameterText($code, $option); #value
        if( $res ne '' ){ $error = $res; goto ERROR;}
        $hexcode .= Script_TokenToWord($token); $pc += 4; #low byte, high byte
      }
      case 'SETPMINMAX' {
        $lastcmd = $token;
        $hexcode .= '0B'; $pc += 2;

        ($code,$token,$option) = Script_GetParameterOption($code); #parameter nr
        if( $token eq '' ){ $error = 'Valid parameter name expected!'; goto ERROR;}
        $hexcode .= UCharToHexstr($token); $pc += 2;

        ($code,$token,$res) = Script_GetParameterText($code, $option); #min value
        if( $res ne '' ){ $error = $res; goto ERROR;}
        $hexcode .= Script_TokenToWord($token); $pc += 4;

        ($code,$token,$res) = Script_GetParameterText($code, $option); #max value
        if( $res ne '' ){ $error = $res; goto ERROR;}
        $hexcode .= Script_TokenToWord($token); $pc += 4;
      }

      case 'RESTORE' {
        $lastcmd = $token;
        $hexcode .= '0C'; $pc += 2;

        ($code,$token) = Script_GetParameterAdr($code); #parameter nr
        if( $token eq '' ){ $error = 'Valid parameter name expected!'; goto ERROR;}
        $hexcode .= UCharToHexstr($token); $pc += 2;
      }

      case 'SETANGLEPITCH' {
        $lastcmd = $token;
        $hexcode .= '0D'; $pc += 2;

        ($code,$token) = Script_GetFloatValue($code); #max value
        if( $token eq '' ){ $error = 'Valid angle value expected!'; goto ERROR;}
        if( ($token < -325.0) or ($token > +325.0) ){ $error = 'Angle value out of range!'; goto ERROR;}
        $hexcode .= Script_TokenToWord(100.0*$token); $pc += 4; #low byte, high byte
      }

      case 'SETANGLEROLL' {
        $lastcmd = $token;
        $hexcode .= '0E'; $pc += 2;

        ($code,$token) = Script_GetFloatValue($code); #max value
        if( $token eq '' ){ $error = 'Valid angle value expected!'; goto ERROR;}
        if( ($token < -325.0) or ($token > +325.0) ){ $error = 'Angle value out of range!'; goto ERROR;}
        $hexcode .= Script_TokenToWord(100.0*$token); $pc += 4; #low byte, high byte
      }

      case 'SETANGLEYAW' {
        $lastcmd = $token;
        $hexcode .= '0F'; $pc += 2;

        ($code,$token) = Script_GetFloatValue($code); #max value
        if( $token eq '' ){ $error = 'Valid angle value expected!'; goto ERROR;}
        if( ($token < -325.0) or ($token > +325.0) ){ $error = 'Angle value out of range!'; goto ERROR;}
        $hexcode .= Script_TokenToWord(100.0*$token); $pc += 4; #low byte, high byte
      }

      case 'SETANGLE' {
        $lastcmd = $token;
        $hexcode .= '10'; $pc +=2;

        ($code,$token) = Script_GetFloatValue($code);
        if( $token eq '' ){ $error = 'Valid pitch angle value expected!'; goto ERROR;}
        if( ($token < -325.0) or ($token > +325.0) ){ $error = 'Pitch angle value out of range!'; goto ERROR;}
        $hexcode .= Script_TokenToWord(100.0*$token); $pc += 4; #low byte, high byte

        ($code,$token) = Script_GetFloatValue($code);
        if( $token eq '' ){ $error = 'Valid roll angle value expected!'; goto ERROR;}
        if( ($token < -325.0) or ($token > +325.0) ){ $error = 'Roll angle value out of range!'; goto ERROR;}
        $hexcode .= Script_TokenToWord(100.0*$token); $pc += 4; #low byte, high byte

        ($code,$token) = Script_GetFloatValue($code);
        if( $token eq '' ){ $error = 'Valid yaw angle value expected!'; goto ERROR;}
        if( ($token < -325.0) or ($token > +325.0) ){ $error = 'Yaw angle value out of range!'; goto ERROR;}
        $hexcode .= Script_TokenToWord(100.0*$token); $pc += 4; #low byte, high byte
      }

      case 'SETSTANDBY' {
        $lastcmd = $token;
        $hexcode .= '15'; $pc += 2;

        ($code,$token) = Script_GetUIntValue($code);
        if( $token eq '' ){ $error = 'Valid parameter value expected!'; goto ERROR;}
        my $v = '00';
        if( $token > 0 ){ $v = '01';}
        $hexcode .= $v; $pc += 2; #one byte
      }

      case 'DOCAMERA' {
        $lastcmd = $token;
        $hexcode .= '16'; $pc += 2;

        ($code,$token) = Script_GetUIntValue($code);
        if( $token eq '' ){ $error = 'Valid parameter value expected!'; goto ERROR;}
        if( ($token < 0.0) or ($token > 4.4) ){ $error = 'Camera cmd value out of range!'; goto ERROR;}
        my $v = UCharToHexstr($token);
        $hexcode .= $v; $pc += 2; #one byte
      }

      case 'DORECENTER' {
        $lastcmd = $token;
        $hexcode .= '17'; $pc += 2;
      }

      case 'SETPWM' {
        $lastcmd = $token;
        $hexcode .= '18'; $pc += 2;

        ($code,$token) = Script_GetUIntValue($code);
        if( $token eq '' ){ $error = 'Valid pwm value expected!'; goto ERROR;}
        if( ($token < 700) or ($token > 2300) ){ $error = 'PWM value out of range!'; goto ERROR;}
        $hexcode .= Script_TokenToWord($token); $pc += 4; #low byte, high byte
      }

      case 'SETPANOWAITS' { #//uint8 pitchtime (in 100ms) uint8 yawtime (in 100ms) uint8 shottime (in 100ms)
        $lastcmd = $token;
        $hexcode .= '19'; $pc += 2;

        ($code,$token) = Script_GetUIntValue($code);
        if( $token eq '' ){ $error = 'Valid pitch wait time expected!'; goto ERROR;}
        if( ($token < 0) or ($token > 255) ){ $error = 'Pitch wait time out of range!'; goto ERROR;}
        $hexcode .= UCharToHexstr($token); $pc += 2;

        ($code,$token) = Script_GetUIntValue($code); #yaw time
        if( $token eq '' ){ $error = 'Valid yaw wait time expected!'; goto ERROR;}
        if( ($token < 0) or ($token > 255) ){ $error = 'Yaw wait time out of range!'; goto ERROR;}
        $hexcode .= UCharToHexstr($token); $pc += 2;

        ($code,$token) = Script_GetUIntValue($code); #shot time
        if( $token eq '' ){ $error = 'Valid shot wait time expected!'; goto ERROR;}
        if( ($token < 0) or ($token > 255) ){ $error = 'Shot wait time out of range!'; goto ERROR;}
        $hexcode .= UCharToHexstr($token); $pc += 2;
      }

      case 'SETPANORANGE' { #//uint16 yawrange (in degrees)
        $lastcmd = $token;
        $hexcode .= '1A'; $pc += 2;

        ($code,$token) = Script_GetUIntValue($code); #yaw range
        if( $token eq '' ){ $error = 'Valid yaw range value expected!'; goto ERROR;}
        if( ($token < 0) or ($token > +720) ){ $error = 'Yaw range value out of range!'; goto ERROR;}
        $hexcode .= Script_TokenToWord($token); $pc += 4; #low byte, high byte
      }

      case 'DOPANO' { #//int8 pitch (in degrees)  int8 yawsteps
        $lastcmd = $token;
        $hexcode .= '1B'; $pc += 2;

        ($code,$token) = Script_GetIntValue($code); #pitch
        if( $token eq '' ){ $error = 'Valid pitch angle value expected!'; goto ERROR;}
        if( ($token < -128) or ($token > +127) ){ $error = 'Pitch angle value out of range!'; goto ERROR;}
        my $v = UCharToHexstr($token);
        if( $token < 0 ){ $v = substr($v,6,2); } #for some reason UCharToHexstr yields then a 8char result, instead of 4char
        $hexcode .= $v; $pc += 2;

        ($code,$token) = Script_GetIntValue($code); #yaw steps
        if( $token eq '' ){ $error='Valid yaw steps value expected!'; goto ERROR;}
        if( ($token < -128) or ($token > +127) ){ $error = 'Yaw steps value out of range!'; goto ERROR;}
        $v = UCharToHexstr($token);
        if( $token < 0 ){ $v = substr($v,6,2); } #for some reason UCharToHexstr yields then a 8char result, instead of 4char
        $hexcode .= $v; $pc += 2;
      }

      case 'SETANGLEPITCH_W' {
        $lastcmd = $token;
        $hexcode .= '1C'; $pc += 2;

        ($code,$token) = Script_GetFloatValue($code); #max value
        if( $token eq '' ){ $error = 'Valid angle value expected!'; goto ERROR;}
        if( ($token < -325.0) or ($token > +325.0) ){ $error = 'Angle value out of range!'; goto ERROR;}
        $hexcode .= Script_TokenToWord(100.0*$token); $pc += 4; #low byte, high byte

        ($code,$token) = Script_GetUIntValue($code);
        if( $token eq '' ){ $error = 'Valid wait time expected!'; goto ERROR;}
        if( ($token < 0) or ($token > 255) ){ $error = 'Wait time out of range!'; goto ERROR;}
        $hexcode .= UCharToHexstr($token); $pc += 2;
      }
      case 'SETANGLEROLL_W' {
        $lastcmd = $token;
        $hexcode .= '1D'; $pc += 2;

        ($code,$token) = Script_GetFloatValue($code); #max value
        if( $token eq '' ){ $error = 'Valid angle value expected!'; goto ERROR;}
        if( ($token < -325.0) or ($token > +325.0) ){ $error = 'Angle value out of range!'; goto ERROR;}
        $hexcode .= Script_TokenToWord(100.0*$token); $pc += 4; #low byte, high byte

        ($code,$token) = Script_GetUIntValue($code);
        if( $token eq '' ){ $error = 'Valid wait time expected!'; goto ERROR;}
        if( ($token < 0) or ($token > 255) ){ $error = 'Wait time out of range!'; goto ERROR;}
        $hexcode .= UCharToHexstr($token); $pc += 2;
      }
      case 'SETANGLEYAW_W' {
        $lastcmd = $token;
        $hexcode .= '1E'; $pc += 2;

        ($code,$token) = Script_GetFloatValue($code); #max value
        if( $token eq '' ){ $error = 'Valid angle value expected!'; goto ERROR;}
        if( ($token < -325.0) or ($token > +325.0) ){ $error = 'Angle value out of range!'; goto ERROR;}
        $hexcode.= Script_TokenToWord(100.0*$token); $pc += 4; #low byte, high byte

        ($code,$token) = Script_GetUIntValue($code);
        if( $token eq '' ){ $error = 'Valid wait time expected!'; goto ERROR;}
        if( ($token < 0) or ($token > 255) ){ $error = 'Wait time out of range!'; goto ERROR;}
        $hexcode .= UCharToHexstr($token); $pc += 2;
      }

      case 'REMOTEENABLE' {
        $lastcmd = $token;
        $hexcode .= '1F'; $pc += 2;
      }
      case 'REMOTEDISABLE' {
        $lastcmd = $token;
        $hexcode .= '20'; $pc += 2;
      }

      case 'BEEP' {
        $lastcmd = $token;
        $hexcode .= '21'; $pc += 2;
      }

      case 'SETPANOALLOWEXIT' {
        $lastcmd = $token;
        $hexcode .= '22'; $pc += 2;
      }

      case 'SENDMAVTEXT' {
        $lastcmd = $token;
        ($code,$token,$res,$cnt) = Script_GetCStr($code); #string of up to 24 chars, compressed into 18 uint8
        if( $token eq '' ){ $error = 'Valid parameter value expected!'; goto ERROR;}
        #if( ($token < 0) or ($token > 255) ){ $error = 'Wait time out of range!'; goto ERROR;}
        if( $cnt == 18 ){
          $hexcode .= '24'; $pc += 2;
          $hexcode .= $res; $pc += 2*18;
        }elsif( $cnt == 15 ){
          $hexcode .= '25'; $pc += 2;
          $hexcode .= $res; $pc += 2*15;
        }elsif( $cnt == 12 ){
          $hexcode .= '26'; $pc += 2;
          $hexcode .= $res; $pc += 2*12;
        }elsif( $cnt == 9 ){
          $hexcode .= '27'; $pc += 2;
          $hexcode .= $res; $pc += 2*9;
        }else{
          $hexcode .= '28'; $pc += 2;
          $hexcode .= $res; $pc += 2*6;
        }
      }

      case 'SENDCAMTEXT' {
        $lastcmd = $token;
        ($code,$token,$res,$cnt) = Script_GetCStr($code); #string of up to 24 chars, compressed into 18 uint8
        if( $token eq '' ){ $error = 'Valid parameter value expected!'; goto ERROR;}
        #if( ($token < 0) or ($token > 255) ){ $error = 'Wait time out of range!'; goto ERROR;}
        if( $cnt == 18 ){
          $hexcode .= '29'; $pc += 2;
          $hexcode .= $res; $pc += 2*18;
        }elsif( $cnt == 15 ){
          $hexcode .= '2A'; $pc += 2;
          $hexcode .= $res; $pc += 2*15;
        }elsif( $cnt == 12 ){
          $hexcode .= '2B'; $pc += 2;
          $hexcode .= $res; $pc += 2*12;
        }elsif( $cnt == 9 ){
          $hexcode .= '2C'; $pc += 2;
          $hexcode .= $res; $pc += 2*9;
        }else{
          $hexcode .= '2D'; $pc += 2;
          $hexcode .= $res; $pc += 2*6;
        }
      }

      case 'DORECENTERPITCH' {
        $lastcmd = $token;
        $hexcode .= '2E'; $pc += 2;
      }
      case 'DORECENTERROLL' {
        $lastcmd = $token;
        $hexcode .= '2F'; $pc += 2;
      }
      case 'DORECENTERYAW' {
        $lastcmd = $token;
        $hexcode .= '30'; $pc += 2;
      }

      else{ $error = 'Valid command expected!'; goto ERROR;}
    }
#TextOut( $hexcode."\r\n\r\n" );
    if( length($hexcode) > 2*$SCRIPTSIZE-4 ){ $error = 'Code is too long!'; goto ERROR;}
  }
  if( $state eq 'case' ){ #we had been in a case statement before
    if( ($lastcmd ne '') && ($lastcmd ne 'STOP') && ($lastcmd ne 'RESTART') && ($lastcmd ne 'REPEAT') ){
      $hexcode .= '00'; $pc += 2;
    }
    substr( $hexcode, $lastcasepc+2, 2, UCharToHexstr($pc/2) );
  }
  $hexcode .= 'FF';
  #check consistency of states
  # every case must occur only once, if any occurs it must start with CASE#1, and no holes must occur
  if( $casepclist[4] > 0 ){
    if( ($casepclist[0] < 0) or ($casepclist[1] < 0) or ($casepclist[2] < 0) or ($casepclist[3] < 0) ){
      $error = 'CASE#4 used without other cases!'; goto ERROR;
    }
  }elsif( $casepclist[3] > 0 ){
    if( ($casepclist[0] < 0) or ($casepclist[1] < 0) or ($casepclist[2] < 0) ){
      $error = 'CASE#3 used without other cases!'; goto ERROR;
    }
  }elsif( $casepclist[2] > 0 ){
    if( ($casepclist[0] < 0) or ($casepclist[1] < 0) ){
      $error = 'CASE#2 used without CASE#DEFAULT and CASE#1!'; goto ERROR;
    }
  }elsif( $casepclist[1] > 0 ){
    if( $casepclist[0] < 0 ){
      $error = 'CASE#1 used without CASE#DEFAULT!'; goto ERROR;
    }
  }elsif( $casepclist[0] > 0 ){
    $error = 'CASE#DEFAULT used but no other cases'; goto ERROR;
  }

  TextOut( "\r\n".'Compile... DONE!'."\r\n".$hexcode."\r\n" );
ERROR:
  if( $error ne '' ){ TextOut( "\r\n".'Compile... ERROR!'."\r\n".$error."\r\n" ); }
  return ($hexcode,$error);
}

#----
# SCRIPT GUI TAB
#----
sub Script_CreateTextFields{
  my $script_nr = shift;
  my $i = 0+($script_nr-1);
  my $j = 1;
  my $xpos= 20+($i)*$OPTIONSWIDTH_X;
  my $ypos= 10 + ($j)*$OPTIONSWIDTH_Y;
  my %textfieldparams=( -name=> 'OptionField_script'.$script_nr, -font=> $StdScriptFont, #$StdWinFont,
    -pos=> [$xpos+1,$ypos+1+13], -size=> [155+5,165+3], #[315,155+3], #-size=> [300,200], #-size=> [300,245],
    -vscroll=> 1, -multiline=> 1, -readonly => 1,
    -background => $OptionInvalidColor,
  );
  return $f_Tab{scripts}->AddTextfield(%textfieldparams);
}

$xpos= 20 ;#+(2)*$OPTIONSWIDTH_X;
$ypos= 10 ;#+ (5)*$OPTIONSWIDTH_Y;
$f_Tab{scripts}->AddLabel( -name=> 'm_Script1_Label', -font=> $StdWinFont,
  -text=> 'Script1', -pos=> [$xpos+0*$OPTIONSWIDTH_X,$ypos-1+1*$OPTIONSWIDTH_Y],-size=> [145,15]
);
$f_Tab{scripts}->AddLabel( -name=> 'm_Script2_Label', -font=> $StdWinFont,
  -text=> 'Script2', -pos=> [$xpos+1*$OPTIONSWIDTH_X,$ypos-1+1*$OPTIONSWIDTH_Y],-size=> [145,15]
);
$f_Tab{scripts}->AddLabel( -name=> 'm_Script3_Label', -font=> $StdWinFont,
  -text=> 'Script3', -pos=> [$xpos+2*$OPTIONSWIDTH_X,$ypos-1+1*$OPTIONSWIDTH_Y],-size=> [145,15]
);
$f_Tab{scripts}->AddLabel( -name=> 'm_Script4_Label', -font=> $StdWinFont,
  -text=> 'Script4', -pos=> [$xpos+3*$OPTIONSWIDTH_X,$ypos-1+1*$OPTIONSWIDTH_Y],-size=> [145,15]
);
$ypos= 20 ;#+ (5)*$OPTIONSWIDTH_Y;
$f_Tab{scripts}->AddButton( -name=> 'm_EditScript1', -font=> $StdWinFont,
  -text=> 'Edit Script1', -pos=> [$xpos+0*$OPTIONSWIDTH_X,$ypos+4+5*$OPTIONSWIDTH_Y], -width=> 120,
  -onClick=> sub{ ScriptEditorShow(1); 1;},
);
$f_Tab{scripts}->AddButton( -name=> 'm_EditScript2', -font=> $StdWinFont,
  -text=> 'Edit Script2', -pos=> [$xpos+1*$OPTIONSWIDTH_X,$ypos+4+5*$OPTIONSWIDTH_Y], -width=> 120,
  -onClick=> sub{ ScriptEditorShow(2); 1;},
);
$f_Tab{scripts}->AddButton( -name=> 'm_EditScript3', -font=> $StdWinFont,
  -text=> 'Edit Script3', -pos=> [$xpos+2*$OPTIONSWIDTH_X,$ypos+4+5*$OPTIONSWIDTH_Y], -width=> 120,
  -onClick=> sub{ ScriptEditorShow(3); 1;},
);
$f_Tab{scripts}->AddButton( -name=> 'm_EditScript4', -font=> $StdWinFont,
  -text=> 'Edit Script4', -pos=> [$xpos+3*$OPTIONSWIDTH_X,$ypos+4+5*$OPTIONSWIDTH_Y], -width=> 120,
  -onClick=> sub{ ScriptEditorShow(4); 1;},
);

#----
# SCRIPT EDITOR WINDOW(S)
#----
my $ScriptXPos = 80;
my $ScriptYPos = 80;
my $ScriptXSize = 380;
my $ScriptYSize = 360;

$xsize= $ScriptXSize;
$ysize= $ScriptYSize;

my $ScriptBackgroundColor = [96,96,96];
my $ScriptEditorTextFont = Win32::GUI::Font->new(-name=>'Lucida Console', -size=>10 );

my $ScriptEditorScriptNr;

my $w_Script_Menubar= Win32::GUI::Menu-> new(
  'Scripts' => '',
    '>New', 'script_New',
    '>Load from File...', 'script_Load',
    '>Save to File...', 'script_Save',
    '>-', 0,
    '>Compile', 'script_Compile',
    '>-', 0,
    '>Accept and Exit', 'script_Accept',
    '>Cancel', 'script_Cancel',
);

#my $w_Script= Win32::GUI::DialogBox->new( -name=> 'script_Window', -parent => $w_Main, -font=> $StdWinFont,
my $w_Script= Win32::GUI::Window->new( -name=> 'script_Window', -parent => $w_Main, -font=> $StdWinFont,
  -text=> $BGCStr." Script Editor", -pos=> [$ScriptXPos,$ScriptYPos], -size=> [$ScriptXSize,$ScriptYSize],
  -helpbox => 0,
  -background=>$ScriptBackgroundColor,
  -menu=> $w_Script_Menubar,
  -dialogui => 0,
  -hasminimize => 0, -minimizebox => 0, -hasmaximize => 0, -maximizebox => 0,
);
$w_Script->SetIcon($Icon);

sub script_Window_Resize {
  my $mw = $w_Script->ScaleWidth();
  my $mh = $w_Script->ScaleHeight();
  my $lh = $w_Script->script_Title->Height();
  $w_Script->script_Blank->Width( $mw - 160 );
  $w_Script->script_Title->Width( $mw - 170 );
  $w_Script->script_Text->Width( $mw+2 );
  $w_Script->script_Text->Height( $mh-$lh+1);
}

sub script_Window_Terminate{ $w_Script->Hide(); 0; }
sub script_Cancel_Click{ $w_Script->Hide(); 0; }
sub script_New_Click{ $w_Script->script_Text->Text(''); 0; }
sub script_Compile_Click{ Script_CompileText($ScriptEditorScriptNr,$w_Script->script_Text->Text); 0; }

sub script_Accept_Click{
  ScriptAccept($ScriptEditorScriptNr, $w_Script->script_Text->Text);
  $w_Script->Hide();
  0;
}

sub ScriptAccept{
  my $ScriptEditorScriptNr = shift;
  my $ScriptText = shift;
  my($hexcode,$error) = Script_CompileText($ScriptEditorScriptNr, $ScriptText);
  if( ($error eq '') && (defined $NameToOptionHash{'Scripts'}) ){
#TextOut("\r\n!".$hexcode."!");
    my $script_hex = $SCRIPT_hexcode_buf;
    my @script_hexcodes;
    my $pc0; my $s;
    #split $SCRIPT_hexcode_buf and insert hexcode
    for(my $script_nr=4; $script_nr>=1; $script_nr--){
      #TextOut( "?".$script_nr );
      $pc0 = HexstrToDez(substr($script_hex,2*( $script_nr-1 ),2)); #get base pc of script
      $s = '';
      if( $pc0 >= $SCRIPTSIZE ){  #0xFF, there is no script
      }else{
        $s = substr( $script_hex, 2*$pc0, 500 );
        #TextOut( "?".$s );
        $script_hex = substr( $script_hex, 0, 2*$pc0  );
        #TextOut( "?".$script_hex );
      }
      $s .= 'FF'; #ensure 'FF' at end
      $s =~ s/FF+$/FF/; #cut down to one FF at the end
      $script_hexcodes[$script_nr] = $s;
      #TextOut( "?".$s."!" );
    }
#TextOut( "!?".$script_hexcodes[1]."-".$script_hexcodes[2]."-".$script_hexcodes[3]."-".$script_hexcodes[4]."!" );
    #insert new hexcode
    $hexcode .= 'FF';
    $hexcode =~ s/FF+$/FF/; #cut it short
    $script_hexcodes[$ScriptEditorScriptNr] = $hexcode;
#TextOut( "!?".$script_hexcodes[1]."-".$script_hexcodes[2]."-".$script_hexcodes[3]."-".$script_hexcodes[4]."!" );
    #combine hexcodes to $SCRIPT_hexcode_buf
    $script_hex = ''; $pc0 = 4;
    for(my $script_nr=1; $script_nr<=4; $script_nr++){
      if( substr($script_hexcodes[$script_nr],0,2) eq 'FF' ){
        $script_hex .= 'FF';
        $script_hexcodes[$script_nr] = '';
      }else{
        $script_hex .= UCharToHexstr( $pc0 ); #pc0 script1
        $pc0 += length( $script_hexcodes[$script_nr] )/2;
      }
    }
    for(my $script_nr=1; $script_nr<=4; $script_nr++){
      $script_hex .= $script_hexcodes[$script_nr];
    }
#TextOut( "!?".$script_hex."!" );
    #TextOut( 'Scripts'."\r\n".substr($script_hex,0,2 * 4 ).' '.substr($script_hex,2*4,400)."\r\n" );
    TextOut( substr($script_hex,0,2*4)."\r\n" );
    for(my $script_nr=1; $script_nr<=4; $script_nr++){
      my $s = $script_hexcodes[$script_nr];
      if( length($s) < 1 ){ $s .= '-'; }
      TextOut( $s."\r\n" );
    }
    my $codelength = length($script_hex)/2;
    TextOut( "$codelength of $SCRIPTSIZE bytes used"."\r\n" );
    #set options
    my $Option = $NameToOptionHash{'Scripts'};
    $Option->{'textfield_script'.$ScriptEditorScriptNr}->Text( '' ); #not sure why it works, but makes the whole area to accept the new color
    SetOptionField( $Option , $script_hex );  #this copies it also to $SCRIPT_hexcode_buf
    $Option->{'textfield_script'.$ScriptEditorScriptNr}->Change( -background => $OptionModifiedColor );
  }
}

my $ScriptEditorFile_lastdir= $ExePath;

sub script_Load_Click{
  my $file= Win32::GUI::GetOpenFileName( -owner=> $w_Main,
    -title=> 'Load Script from File',
    -nochangedir=> 1,
    -directory=> $SettingsFile_lastdir, #$ScriptEditorFile_lastdir, #".\\",
    -defaultextension=> '.scr',
    -filter=> ['*.scr'=>'*.scr','*.cfgx'=>'*.cfgx','All files' => '*.*'],
    -pathmustexist=> 1,
    -filemustexist=> 1,
  );
  if( $file ){
    if( !open(F,"<$file") ){ $w_Main->MessageBox( "Some error occured, sorry",'ERROR'); return; }
    my $s=''; while(<F>){ $s.= $_; } close(F);
    if( ($s =~ /\%SettingsHash/) or ($s =~ /\%SettingsHashV2/) or ($s =~ /\$Script/) ){
      my %SettingsHash = (); my %SettingsHashV2 = ();
      my $Script1 = 'e'; my $Script2 = 'e'; my $Script3 = 'e'; my $Script4 = 'e';
      my %CalibrationConstants = ();
      my %Imu1 = (); my %Imu2 = (); my %Imu3 = ();
      my %MotorPitch = (); my %MotorRoll = (); my %MotorYaw = (); my %Logger = ();
      $s =~ s/\r//g;
      $s =~ s/\n/\r\n/g;
      eval "$s";
      if($@){ $Script1 = 'e'; $Script2 = 'e'; $Script3 = 'e'; $Script4 = 'e'; }
      if( ($Script1 ne 'e') or ($Script2 ne 'e') or ($Script3 ne 'e') or ($Script4 ne 'e') ){
        if( ($ScriptEditorScriptNr == 1) and ($Script1 ne 'e') ){ $w_Script->script_Text->Text($Script1); }
        if( ($ScriptEditorScriptNr == 2) and ($Script2 ne 'e') ){ $w_Script->script_Text->Text($Script2); }
        if( ($ScriptEditorScriptNr == 3) and ($Script3 ne 'e') ){ $w_Script->script_Text->Text($Script3); }
        if( ($ScriptEditorScriptNr == 4) and ($Script4 ne 'e') ){ $w_Script->script_Text->Text($Script4); }
      }
    }else{
      $w_Script->script_Text->Text( $s );
    }
  }elsif( Win32::GUI::CommDlgExtendedError() ){ $w_Main->MessageBox("Some error occured, sorry",'ERROR'); }
  1;
}

sub script_Save_Click{
  my $file= Win32::GUI::GetSaveFileName( -owner=> $w_Main,
    -title=> 'Save Script to File',
    -nochangedir=> 1,
    -directory=> $SettingsFile_lastdir, #$ScriptEditorFile_lastdir, #".\\",
    -defaultextension=> '.scr',
    -filter=> ['*.scr'=>'*.scr','All files' => '*.*'],
    -pathmustexist=> 1,
    -overwriteprompt=> 1,
    -noreadonlyreturn => 1,
    -explorer=>0,
  );
  if( $file ){
    if( !open(F,">$file") ){ $w_Main->MessageBox("Some error occured, sorry",'ERROR'); return; }
    print F $w_Script->script_Text->Text();
    close(F);
  }elsif( Win32::GUI::CommDlgExtendedError() ){$w_Main->MessageBox("Some error occured, sorry",'ERROR');}
  1;
}

#$w_Script->AddButton( -name=> 'script_New', -font=> $StdWinFont,
#  -text=> 'New',
#  -pos=> [0,0], -width=>35, -height=>16, # -width=> $xsize-6, -height=>15,
#);
$w_Script->AddButton( -name=> 'script_Load', -font=> $StdWinFont,
  -text=> 'Load',
  -pos=> [0,0], -width=>40, -height=>20, # -width=> $xsize-6, -height=>15,
);
$w_Script->AddButton( -name=> 'script_Save', -font=> $StdWinFont,
  -text=> 'Save',
  -pos=> [40,0], -width=>40, -height=>20, # -width=> $xsize-6, -height=>15,
);
$w_Script->AddButton( -name=> 'script_Compile', -font=> $StdWinFont,
  -text=> 'Comp',
  -pos=> [80,0], -width=>40, -height=>20, # -width=> $xsize-6, -height=>15,
);
$w_Script->AddButton( -name=> 'script_Accept', -font=> $StdWinFont,
  -text=> 'Accpt',
  -pos=> [120,0], -width=>40, -height=>20, # -width=> $xsize-6, -height=>15,
);

$w_Script->AddLabel( -name=> 'script_Blank', -font=> $StdWinFont,
  -pos=> [160,0], -width=> $xsize-170-6, -height=>20-1,
);

$w_Script->AddLabel( -name=> 'script_Title', -font=> $StdWinFont,
  -text=> 'Script 1',
  -pos=> [160,3], -width=> $xsize-180-6, -height=>20-1,
  -align=>'center', #-background=>$CBlue,
);

$w_Script-> AddTextfield( -name=> 'script_Text', -font=> $ScriptEditorTextFont, #-font=> $StdWinFont,
  -pos=> [-1,20-1], -size=> [$xsize-4,$ysize-40-20], #-size=> [$xsize-14,$ysize-52],
  -hscroll=> 1, -vscroll=> 1,
  -autovscroll=> 1, -autohscroll=> 1,
  -keepselection => 1,
  -multiline=> 1,
);

sub ScriptEditorShow{
  $ScriptEditorScriptNr = shift;
  my ($x, $y) = ($w_Main->GetWindowRect())[0..1];
  $w_Script->Move($x+190,$y+100);
  $w_Script->script_Title->Text( 'Script '.$ScriptEditorScriptNr );
  $w_Script->script_Text->Text( Script_ConvertToTextForSingleScript($ScriptEditorScriptNr,'nopc') );
  $w_Script->Show();
}

#-----------------------------------------------------------------------------#
# some helper routines
#-----------------------------------------------------------------------------#
sub FindOptionByName{
  my $name = uc(shift);
  $name = CleanLeftRightStr($name);
  foreach my $option (@OptionList){
    if( not defined $option->{name} ){ next; }
    my $optname = uc($option->{name});
    if( $name eq $optname ){ return $option; }
  }
  return undef;
}

sub FindOptionAdrByName{
  my $name= uc(shift);
  $name = CleanLeftRightStr( $name );
  foreach my $option (@OptionList){
    if( not defined $option->{name} ){ next; }
    my $optname = uc($option->{name});
    if( $name eq $optname ){ return $option->{adr}; }
  }
  return '';
}

sub FindOptionAdrTypeByName{
  my $name= uc(shift);
  $name = CleanLeftRightStr( $name );
  foreach my $option (@OptionList){
    if( not defined $option->{name} ){ next; }
    my $optname = uc($option->{name});
    if( $name eq $optname ){ return( $option->{adr}, $option->{type} ); }
  }
  return ('','');
}

sub FindOptionNameByAdr{
  my $adr = shift;
  foreach my $option (@OptionList){
    if( (defined $option->{adr}) && ($option->{adr} == $adr) ){
      return ($option, $option->{name});
    }
  }
  return (undef, '?');
}


my $CWHITE   = [255,255,255];
my $CBLUE    = [128,128,255];
my $CRED     = [255,50,50];
my $CGREY128 = [128,128,128];


my $CMD_Cd_PARAMETER_ZAHL = 14;
my $CDDATAFORMATSTR = 'sss'.'sss'.'s'.'sss'.'sss'.'s';
if( length($CDDATAFORMATSTR) != $CMD_Cd_PARAMETER_ZAHL ){ die;}


sub LoadPackage{
  my $file = shift;
  if( !open(F, '<', $file) ){
    TextOut("\nPackage $file could not be loaded"."\n"); return 0;
  }
  my $code = ''; while( <F> ){ $code .= $_ } close(F);
  eval $code;
  if($@){
    TextOut("\nPackage $file could not be initialized"."\n".$@."\n"); return 0;
  }
  return 1;
}


#-----------------------------------------------------------------------------#
###############################################################################
# CONFIGURE GIMBAL Tool Window
###############################################################################
#-----------------------------------------------------------------------------#
my $ConfigureGimbalIsInitialized = 0;
my $ConfigureGimbalPackageFile = "o323BGCPackage_ConfigureGimbalTool.pl";
if( $PackagesDir ne '' ){ $ConfigureGimbalPackageFile = $PackagesDir.'\\'.$ConfigureGimbalPackageFile; }

sub gimbalconfig_ConfigureGimbal_Click{
  if( $ConfigureGimbalIsInitialized == 0 ){
    if( !LoadPackage($ConfigureGimbalPackageFile) ){ return 0; }
    $ConfigureGimbalIsInitialized = 1;
    ConfigureGimbalInit();
  }
  ConfigureGimbalShow();
  0;
}

#adapt to encoder version, for the moment simply disable unusable options
# must come after connect, so that $ActiveBoardConfiguration is correctly set
sub ConfigureGimbal_AdaptToBoardConfigurationFoc{
  if( not $ConfigureGimbalIsInitialized ){ return; }
  ConfigureGimbal_AdaptToBoardConfigurationFoc_Handler();
}

sub ConfigureGimbal_AdaptToBoardConfigurationDefault{
  if( not $ConfigureGimbalIsInitialized ){ return; }
  ConfigureGimbal_AdaptToBoardConfigurationDefault_Handler();
}


#-----------------------------------------------------------------------------#
###############################################################################
# ACC 1-POINT CALIBRATION Tool Window
###############################################################################
#-----------------------------------------------------------------------------#
my $Acc16PCalIsInitialized = 0;
my $Acc16PCalPackageFile = "o323BGCPackage_AccCalibration.pl";
if( $PackagesDir ne '' ){ $Acc16PCalPackageFile = $PackagesDir.'\\'.$Acc16PCalPackageFile; }

sub caac_Run1PointCalibration_Click{
  if( $Acc16PCalIsInitialized == 0 ){
    if( !LoadPackage($Acc16PCalPackageFile) ){ return 1; }
    $Acc16PCalIsInitialized = 1;
    Acc16PCalInit(1);
  }
  Acc16PCalibrationShow(1);
  1;
}

sub caac_Run6PointCalibration_Click{
  if( $Acc16PCalIsInitialized == 0 ){
    if( !LoadPackage($Acc16PCalPackageFile) ){ return 1; }
    $Acc16PCalIsInitialized = 1;
    Acc16PCalInit(0);
  }
  Acc16PCalibrationShow(0);
  1;
}


#-----------------------------------------------------------------------------#
###############################################################################
# GYRO CALIBRATION Tool Window
###############################################################################
#-----------------------------------------------------------------------------#
my $GyroCalIsInitialized = 0;
my $GyroCalPackageFile = "o323BGCPackage_GyroCalibration.pl";
if( $PackagesDir ne '' ){ $GyroCalPackageFile = $PackagesDir.'\\'.$GyroCalPackageFile; }

sub caac_RunGyroCalibration_Click{
  if( $GyroCalIsInitialized == 0 ){
    if( !LoadPackage($GyroCalPackageFile) ){ return 1; }
    $GyroCalIsInitialized = 1;
    GyroCalInit();
  }
  GyroCalibrationShow();
  1;
}



#-----------------------------------------------------------------------------#
###############################################################################
# INPUTS Tool Window
###############################################################################
#-----------------------------------------------------------------------------#
my $InputsToolIsInitialized = 0;
my $InputsToolPackageFile = "o323BGCPackage_InputsTool.pl";
if( $PackagesDir ne '' ){ $InputsToolPackageFile = $PackagesDir.'\\'.$InputsToolPackageFile; }

sub t_InputsTool_Click{
  if( $InputsToolIsInitialized == 0 ){
    if( !LoadPackage($InputsToolPackageFile) ){ return 1; }
    $InputsToolIsInitialized = 1;
    InputsToolInit();
  }
  InputsToolShow();
  1;
}



#-----------------------------------------------------------------------------#
###############################################################################
# MAVLINK INSPECTOR Tool Window
###############################################################################
#-----------------------------------------------------------------------------#
my $MavlinkInspectorToolIsInitialized = 0;
my $MavlinkInspectorToolPackageFile = "o323BGCPackage_MavlinkInspectorTool.pl";
if( $PackagesDir ne '' ){ $MavlinkInspectorToolPackageFile = $PackagesDir.'\\'.$MavlinkInspectorToolPackageFile; }

sub t_MavlinkInspectorTool_Click{
  if( $MavlinkInspectorToolIsInitialized == 0 ){
    if( !LoadPackage($MavlinkInspectorToolPackageFile) ){ return 1; }
    $MavlinkInspectorToolIsInitialized = 1;
    MavlinkInspectorToolInit();
  }
  MavlinkInspectorToolShow();
  1;
}



#-----------------------------------------------------------------------------#
###############################################################################
# SHARE SETTINGS Tool Window
# CHECK NT MODULE VERSIONS Tool Window
# CHANGE BOARD CONFIGURATION Tool Window
# EDIT BOARD NAME Tool Window
# CHANGE UART BAUDRATE Tool Window
# NTLogger RTC Configuration Tool Window
# UPDATE Tool Window
# NT Module CLI Tool Window
###############################################################################
#-----------------------------------------------------------------------------#
my $ToolsPackageIsInitialized = 0;
my $ToolsPackageFile = "o323BGCPackage_Tools.pl";
if( $PackagesDir ne '' ){ $ToolsPackageFile = $PackagesDir.'\\'.$ToolsPackageFile; }

sub LoadToolsPackage{
  if( $ToolsPackageIsInitialized == 0 ){
    if( !LoadPackage($ToolsPackageFile) ){ return 0; }
    $ToolsPackageIsInitialized = 1;
  }
  return 1;
}

sub m_ShareSettings_Click{
  if( !LoadToolsPackage() ){ return 0; }
  ShareSettingsInit();
  ShareSettingsShow();
  0;
}

sub m_CheckNtVersions{
  if( !LoadToolsPackage() ){ return 0; }
  CheckNtVersionsInit();
  CheckNtVersionsShow(shift);
  0;
}

sub t_ChangeBoardConfiguration_Click{
  if( !LoadToolsPackage() ){ return 0; }
  ChangeBoardConfigurationInit();
  ChangeBoardConfigurationShow();
  0;
}

sub t_EditBoardName_Click{
  if( !LoadToolsPackage() ){ return 0; }
  EditBoardNameInit();
  EditBoardNameShow();
  0;
}

sub t_GuiBaudrate_Click{
  if( !LoadToolsPackage() ){ return 0; }
  GuiBaudrateInit();
  GuiBaudrateShow();
  0;
}

sub t_RTCConfigTool_Click{
  if( !LoadToolsPackage() ){ return 0; }
  RTCConfigInit();
  RTCConfigShow();
  0;
}

sub m_Update_Click{
  if( !LoadToolsPackage() ){ return 0; }
  UpdateInit();
  UpdateShow();
  0;
}

sub t_NtCliTool_Click{
  if( !LoadToolsPackage() ){ return 0; }
  NtCliInit();
  NtCliShow();
  1;
}



#-----------------------------------------------------------------------------#
###############################################################################
# RCCMD write & read
###############################################################################
#-----------------------------------------------------------------------------#

my $RCCMD_INSTX = 'FA';
my $RCCMD_INSTXNORESPONSE = 'F9';
my $RCCMD_OUTSTX = 'FB';

my $RCCMD_GETVERSION = '01';
my $RCCMD_GETVERSION_RESPONSE_LEN = 11;
my $RCCMD_GETVERSIONSTR = '02';
my $RCCMD_GETVERSIONSTR_RESPONSE_LEN = 3 + 3*16 + 2;
my $RCCMD_GETPARAMETER = '03';
my $RCCMD_GETPARAMETER_RESPONSE_LEN = 9;
my $RCCMD_GETDATA = '05';
my $RCCMD_GETDATA_RESPONSE_LEN = 3 + 2+2*$CMD_d_PARAMETER_ZAHL + 2;
my $RCCMD_GETDATAFIELDS = '06'; #length is variable!!!
my $RCCMD_ACK_LEN = 6;

my $RcCmdNoResponse = 0;
my $RcCmdConnectionTest = 1;
my $RcCmdDetailsOut = 1;

=pod
sub ExecuteRcCmd{
  my $msg = shift; #command + payload
  my $doread = shift; #this is the number of bytes expected as response, it is 6 for the default ACK message
  my $DetailsOut = $RcCmdDetailsOut; $RcCmdDetailsOut = 1;
  my $NoResponse = $RcCmdNoResponse; $RcCmdNoResponse = 0;
  #prepare
  my $msglen = UCharToHexstr( length($msg)/2 - 1 ); #don't count the msg_id byte
#TextOut( "!$msglen!" );
  my $instx = $RCCMD_INSTX;
  if( $NoResponse ){ $instx = $RCCMD_INSTXNORESPONSE; }
  my $cmd = $instx . $msglen . $msg . '33'.'34'; #crc check is not activated, hence dummy crc
  if( not defined $doread ){
    my $rccmd_id = substr($msg,0,2);
#TextOut( "!$rccmd_id!" );
    if( $rccmd_id eq $RCCMD_GETPARAMETER  ){
      $doread = $RCCMD_GETPARAMETER_RESPONSE_LEN;
    }elsif( $rccmd_id eq $RCCMD_GETVERSION  ){
      $doread = $RCCMD_GETVERSION_RESPONSE_LEN;
    }elsif( $rccmd_id eq $RCCMD_GETVERSIONSTR  ){
      $doread = $RCCMD_GETVERSIONSTR_RESPONSE_LEN;
    }elsif( $rccmd_id eq $RCCMD_GETDATA  ){
      $doread = $RCCMD_GETDATA_RESPONSE_LEN;
    }elsif( $rccmd_id eq $RCCMD_GETDATAFIELDS  ){
      if($DetailsOut){ TextOut( 'No length specified, RC command is ignored!'."\r\n" ); }
    }else{
      $doread = $RCCMD_ACK_LEN; #6 is is the default CMD_ACK
    }
#TextOut( "!$doread!" );
  }
  #write
  if($DetailsOut){ TextOut( $cmd."\r\n" ); }
  WritePort( HexstrToStr($cmd) );
  if( $NoResponse ){ return 'o'; }
  #read
  my $count = 0; my $result = '';
  my ($timeout, $timeoutfirst) = GetTimeoutsForReading();
  my $tmo = GetTickCount() + $timeout;
  my $tmofirst = GetTickCount() + $timeoutfirst;
  if( $doread >= 0 ){
    do{
      my $t = $tmo;
      if( $count == 0 ){ $t = $tmofirst; }
      if( GetTickCount() > $t ){ return 't'; } #timeout!
      my ($i, $s) = ReadPortOneByte(); #read one character
      $count += $i;
      $result .= $s;
      if($DetailsOut){ TextOut( StrToHexstr($s) ); }
    }while( $count < $doread );
  }else{
    #we read for as long as until 'FB019600622E' is detected or timeout occurs
    $tmo = GetTickCount() + 2000; #timeout of 2secs
    while( GetTickCount() < $tmo ){ #last doesn't work in do{}while() loop
      my ($i, $s) = ReadPortOneByte(); #read one character
      $result .= $s;
      my $rest = substr($result, -6);
#TextOut( "!".StrToHexstr($rest)."!" );
      if( StrToHexstr($rest) eq 'FB019600622E' ){ $result = $rest; $count = $RCCMD_ACK_LEN; last; }
    }
#TextOut( StrToHexstr($result) );
    if( $result eq '' ){ $result = 't'; } #indicate timeout
    $count = length($result);
  }
  #check crc
##  my $crc = 0;
##  $crc = unpack( "v", substr($result,$count-2,2) );
##  if($DetailsOut){ TextOut( " CRC:".UIntToHexstr($crc) ); }
##  my $crc2 = do_crc( substr($result,1), $count );
##  if($DetailsOut){ TextOut( " CRC2:0x".UIntToHexstr($crc2)."!" ); }
##  if( $crc2 != 0 ){ return 'c'; }
  my $crcOK = check_crc( substr($result,1), $count, $DetailsOut );
  if( $crcOK != 1 ){ return 'c'; }
  #finalize
  $result = StrToHexstr($result);
  if($DetailsOut){ TextOut( "\r\n" ); }
#TextOut( "!".$result."!" );
#TextOut( "!".ExtractPayloadFromRcCmd($result)."!" );
  return $result;
}

sub ExecuteRcCmdwoOut{
  $RcCmdDetailsOut = 0;
  return ExecuteRcCmd( shift, shift );
}

sub ExecuteRcCmdConnect{
  $RcCmdDetailsOut = 0;
  return ExecuteRcCmd( shift, -1 );
}
=cut


sub SendRcCmd{
  my $msg = shift; #command + payload
  my $doread = shift; #this is the number of bytes expected as response, it is 6 for the default ACK message

  my $NoResponse = $RcCmdNoResponse; $RcCmdNoResponse = 0;
  my $DetailsOut = $RcCmdDetailsOut; $RcCmdDetailsOut = 1;
  my $ConnectionTest = $RcCmdConnectionTest; $RcCmdConnectionTest = 1;

  my $msglen = UCharToHexstr( length($msg)/2 - 1 ); #don't count the msg_id byte
#TextOut( "!$msglen!" );
  my $instx = $RCCMD_INSTX;
  if( $NoResponse ){ $instx = $RCCMD_INSTXNORESPONSE; }
#  my $cmd = $instx . $msglen . $msg . '33'.'34'; #crc check is not activated, hence dummy crc
  my $cmd_body = $instx . $msglen . $msg; #wo crc
  my $cmd = $cmd_body . do_crc_hexstr($cmd_body);
  if( not defined $doread ){
    my $rc_cmd_id = substr($msg,0,2);
#TextOut( "!$rc_cmd_id!" );
    if( $rc_cmd_id eq $RCCMD_GETPARAMETER ){      $doread = $RCCMD_GETPARAMETER_RESPONSE_LEN;
    }elsif( $rc_cmd_id eq $RCCMD_GETVERSION ){    $doread = $RCCMD_GETVERSION_RESPONSE_LEN;
    }elsif( $rc_cmd_id eq $RCCMD_GETVERSIONSTR ){ $doread = $RCCMD_GETVERSIONSTR_RESPONSE_LEN;
    }elsif( $rc_cmd_id eq $RCCMD_GETDATA ){       $doread = $RCCMD_GETDATA_RESPONSE_LEN;
    }elsif( $rc_cmd_id eq $RCCMD_GETDATAFIELDS ){
      if($DetailsOut){ TextOut( 'No length specified, RC command is ignored!'."\r\n" ); }
    }else{
      $doread = $RCCMD_ACK_LEN; #6 is is the default CMD_ACK
    }
#TextOut( "!$doread!" );
  }
#TextOut( "!".$cmd."!" );TextOut( "!".$doread."!\r\n" );
  if( $ConnectionTest ){
    if( not ConnectionIsValid() ){
      if($DetailsOut){ TextOut( 'No connection to board, RC command is ignored!'."\r\n" ); }
      return '';
    }
  }
  if($DetailsOut){ TextOut( $cmd."\r\n" ); }
  WritePort( HexstrToStr($cmd) );
  if( $NoResponse ){ return 'o'; }
  my $count = 0;
  my $result = '';
  my ($timeout, $timeoutfirst) = GetTimeoutsForReading();
  my $tmo = GetTickCount() + $timeout;
  do{
    if( GetTickCount() > $tmo  ){ if($DetailsOut){TextOut('t');} return 't'; }
    my ($i, $s) = ReadPortOneByte();
    $count += $i;
    $result .= $s;
    if($DetailsOut){ TextOut( StrToHexstr($s) ); }
  }while( $count < $doread );
  my $crcOK = check_crc( substr($result,1), $count-1, $DetailsOut );
  if( $crcOK != 1 ){ return 'c'; }
  $result = StrToHexstr($result);
  if($DetailsOut){ TextOut( "\r\n" ); }
  return $result;
}


sub SendRcCmdwOut{
  $RcCmdDetailsOut = 1;
  #$RcCmdConnectionTest = 0;
  return SendRcCmd( shift, shift );
}


sub SendRcCmdwoOut{
  $RcCmdDetailsOut = 0;
  return SendRcCmd( shift, shift );
}


#whenever the result of a RcCmd is used, it MUST be digested with ExtractPayloadFromRcCmd() !!!!
sub ExtractPayloadFromRcCmd{
  my $msg = shift;
  my $len = HexstrToDez(substr($msg,2,2));
  return substr($msg,2*3,2*$len);
}


#-----------------------------------------------------------------------------#
###############################################################################
# RCCMD Test Window
###############################################################################
#-----------------------------------------------------------------------------#
my $RcCmdXPos= 100;
my $RcCmdYPos= 100;

my $RcCmdXsize= 670;
my $RcCmdYsize= 420;

my $w_RcCmd= Win32::GUI::DialogBox->new( -name=> 'rccmd_Window',  -parent => $w_Main, -font=> $StdWinFont,
    -text=> "RC Command Tool",
    -pos=> [$RcCmdXPos,$RcCmdYPos],
    -size=> [$RcCmdXsize,$RcCmdYsize],
   -helpbox => 0,
);
$w_RcCmd->SetIcon($Icon);

sub t_RcCmdTool_Click{ RcCmdInit(); RcCmdShow(); 1; }

sub rccmd_Window_Terminate{ $w_RcCmd->Hide(); 0; }

sub RcCmdShow{
#DataDisplayHalt();
  my ($x, $y) = ($w_Main->GetWindowRect())[0..1];
  $w_RcCmd->Move($x+100,$y+100);
  $w_RcCmd->Show();
  if( not ConnectionIsValid() ){ return 0; }
  return 1;
}

sub SendRcCmdTool{
  SendRcCmd(shift);
}

my $RcCmdIsInitialized = 0;

sub RcCmdInit{
  if( $RcCmdIsInitialized>0 ){ return; }
  $RcCmdIsInitialized = 1;
  my $xpos= 20;
  my $ypos= 20;
  $w_RcCmd->AddButton( -name=> 'rccmd_PitchUp', -font=> $StdWinFont,
    -text=> 'PitchUp', -pos=> [$xpos,$ypos-3], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."PitchUp"."\r\n" ); SendRcCmdTool( '0A' . 'E803' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_PitchMid', -font=> $StdWinFont,
    -text=> 'PitchMid', -pos=> [$xpos,$ypos-3+25], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."PitchMid"."\r\n" ); SendRcCmdTool( '0A' . 'DC05' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_PitchDown', -font=> $StdWinFont,
    -text=> 'PitchDown', -pos=> [$xpos,$ypos-3+50], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."PitchDown"."\r\n" ); SendRcCmdTool( '0A' . 'D007' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_PitchReCenter', -font=> $StdWinFont,
    -text=> 'PitchReCenter', -pos=> [$xpos,$ypos-3+75], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."PitchReCenter"."\r\n" ); SendRcCmdTool( '0A' . '0000' ); 1; },
  );
  $xpos+= 120;
  $w_RcCmd->AddButton( -name=> 'rccmd_RollUp', -font=> $StdWinFont,
    -text=> 'RollUp', -pos=> [$xpos,$ypos-3], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."RollUp"."\r\n" ); SendRcCmdTool( '0B' . 'E803' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_RollMid', -font=> $StdWinFont,
    -text=> 'RollMid', -pos=> [$xpos,$ypos-3+25], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."RollMid"."\r\n" ); SendRcCmdTool( '0B' . 'DC05' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_RollDown', -font=> $StdWinFont,
    -text=> 'RollDown', -pos=> [$xpos,$ypos-3+50], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."RollDown"."\r\n" ); SendRcCmdTool( '0B' . 'D007' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_RollReCenter', -font=> $StdWinFont,
    -text=> 'RollReCenter', -pos=> [$xpos,$ypos-3+75], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."RollReCenter"."\r\n" ); SendRcCmdTool( '0B' . '0000' ); 1; },
  );
  $xpos+= 120;
  $w_RcCmd->AddButton( -name=> 'rccmd_YawDown', -font=> $StdWinFont,
    -text=> 'YawLeft', -pos=> [$xpos,$ypos-3+0], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."YawDown"."\r\n" ); SendRcCmdTool( '0C' . 'D007' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_YawMid', -font=> $StdWinFont,
    -text=> 'YawMid', -pos=> [$xpos,$ypos-3+25], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."YawMid"."\r\n" ); SendRcCmdTool( '0C' . 'DC05' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_YawUp', -font=> $StdWinFont,
    -text=> 'YawRight', -pos=> [$xpos,$ypos-3+50], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."YawUp"."\r\n" ); SendRcCmdTool( '0C' . 'E803' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_YawReCenter', -font=> $StdWinFont,
    -text=> 'YawReCenter', -pos=> [$xpos,$ypos-3+75], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."YawReCenter"."\r\n" ); SendRcCmdTool( '0C' . '0000' ); 1; },
  );
  $xpos+= 120;
  $w_RcCmd->AddButton( -name=> 'rccmd_SetAngle', -font=> $StdWinFont,
    -text=> 'SetAngle', -pos=> [$xpos,$ypos-3], -width=> 90,
  );
  $w_RcCmd->AddTextfield( -name=> 'rccmd_SetAngle_Pitch', -font=> $StdWinFont,
    -text=> '0', -pos=> [$xpos,$ypos-3+25], -size=> [90,23],
  );
  $w_RcCmd->AddTextfield( -name=> 'rccmd_SetAngle_Roll', -font=> $StdWinFont,
    -text=> '0', -pos=> [$xpos,$ypos-3+50], -size=> [90,23],
  );
  $w_RcCmd->AddTextfield( -name=> 'rccmd_SetAngle_Yaw', -font=> $StdWinFont,
    -text=> '0', -pos=> [$xpos,$ypos-3+75], -size=> [90,23],
  );
  $xpos+= 110;
  $w_RcCmd->AddButton( -name=> 'rccmd_SetAngleUnrestricted', -font=> $StdWinFont,
    -text=> 'SetAngle unres.', -pos=> [$xpos,$ypos-3], -width=> 100,
  );
  $w_RcCmd->AddTextfield( -name=> 'rccmd_SetAngleUnrestricted_Pitch', -font=> $StdWinFont,
    -text=> '0', -pos=> [$xpos,$ypos-3+25], -size=> [70,23],
  );
  $w_RcCmd->AddTextfield( -name=> 'rccmd_SetAngleUnrestricted_Roll', -font=> $StdWinFont,
    -text=> '0', -pos=> [$xpos,$ypos-3+50], -size=> [70,23],
  );
  $w_RcCmd->AddTextfield( -name=> 'rccmd_SetAngleUnrestricted_Yaw', -font=> $StdWinFont,
    -text=> '0', -pos=> [$xpos,$ypos-3+75], -size=> [70,23],
  );
  $w_RcCmd->AddTextfield( -name=> 'rccmd_SetAngleUnrestricted_RatePitch', -font=> $StdWinFont,
    -text=> '0', -pos=> [$xpos+80,$ypos-3+25], -size=> [70,23],
  );
  $w_RcCmd->AddTextfield( -name=> 'rccmd_SetAngleUnrestricted_RateRoll', -font=> $StdWinFont,
    -text=> '0', -pos=> [$xpos+80,$ypos-3+50], -size=> [70,23],
  );
  $w_RcCmd->AddTextfield( -name=> 'rccmd_SetAngleUnrestricted_RateYaw', -font=> $StdWinFont,
    -text=> '0', -pos=> [$xpos+80,$ypos-3+75], -size=> [70,23],
  );

  $xpos= 20;
  $ypos= 20 + 50+ 25+25+20+20;
  $w_RcCmd->AddButton( -name=> 'rccmd_AuxKeyMode0', -font=> $StdWinFont,
    -text=> 'ActivePanMode Default', -pos=> [$xpos,$ypos-3], -width=> 140,
    -onClick=> sub{ TextOut( "\r\n"."Aux Key off-off"."\r\n" ); SendRcCmdTool( '64' . '00' ); 1; },
  );
  $ypos+= 25;
  $w_RcCmd->AddButton( -name=> 'rccmd_AuxKeyMode1', -font=> $StdWinFont,
    -text=> 'ActivePanModeSetting #1', -pos=> [$xpos,$ypos-3], -width=> 140,
    -onClick=> sub{ TextOut( "\r\n"."Aux Key off-on"."\r\n" ); SendRcCmdTool( '64' . '01' ); 1; },
  );
  $ypos+= 25;
  $w_RcCmd->AddButton( -name=> 'rccmd_AuxKeyMode2', -font=> $StdWinFont,
    -text=> 'ActivePanModeSetting #2', -pos=> [$xpos,$ypos-3], -width=> 140,
    -onClick=> sub{ TextOut( "\r\n"."Aux Key on-off"."\r\n" ); SendRcCmdTool( '64' . '02' ); 1; },
  );
  $ypos+= 25;
  $w_RcCmd->AddButton( -name=> 'rccmd_AuxKeyMode3', -font=> $StdWinFont,
    -text=> 'ActivePanModeSetting #3', -pos=> [$xpos,$ypos-3], -width=> 140,
    -onClick=> sub{ TextOut( "\r\n"."Aux Key on-on"."\r\n" ); SendRcCmdTool( '64' . '03' ); 1; },
  );
  $xpos+= 160;
  $ypos= 20 + 50+ 25+25+20+20;
  $w_RcCmd->AddButton( -name=> 'rccmd_SetStandBy', -font=> $StdWinFont,
    -text=> 'Set StandBy', -pos=> [$xpos,$ypos-3], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."Set StandBy"."\r\n" ); SendRcCmdTool( '0E' . '01' ); 1; },
  );
  $ypos+= 25;
  $w_RcCmd->AddButton( -name=> 'rccmd_ResetStandBy', -font=> $StdWinFont,
    -text=> 'Reset StandBy', -pos=> [$xpos,$ypos-3], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."Reset StandBy"."\r\n" ); SendRcCmdTool( '0E' . '00' ); 1; },
  );
  $xpos+= 120;
  $ypos= 20 + 50+ 25+25+20+20;
  $w_RcCmd->AddButton( -name=> 'rccmd_CameraShutter', -font=> $StdWinFont,
    -text=> 'Shutter', -pos=> [$xpos,$ypos-3], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."Shutter"."\r\n" ); SendRcCmdTool( '0F'. 'aa'.'01'.'aaaaaaaa' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_CameraVideoOn', -font=> $StdWinFont,
    -text=> 'Video On', -pos=> [$xpos,$ypos-3+50 -25], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."Video On"."\r\n" ); SendRcCmdTool( '0F'. 'aa'.'03'.'aaaaaaaa' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_CameraVideoOff', -font=> $StdWinFont,
    -text=> 'Video Off', -pos=> [$xpos,$ypos-3+75 -25], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."Video Off"."\r\n" ); SendRcCmdTool( '0F'. 'aa'.'04'.'aaaaaaaa' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_CameraReset', -font=> $StdWinFont,
    -text=> 'Reset', -pos=> [$xpos,$ypos-3+100  -25], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."Camera Reset"."\r\n" ); SendRcCmdTool( '0F'. 'aa'.'00'.'aaaaaaaa' ); 1; },
  );
  $ypos+= 100;
  $w_RcCmd->AddButton( -name=> 'rccmd_SetCameraInput', -font=> $StdWinFont,
    -text=> 'Set CameraInput', -pos=> [$xpos,$ypos-3], -width=> 100,
  );
  $w_RcCmd->AddTextfield( -name=> 'rccmd_SetCameraInput_Value', -font=> $StdWinFont,
    -text=>'0', -pos=> [$xpos +20,$ypos-3 +25], -size=> [60,23],
  );
  $w_RcCmd->AddTextfield( -name=> 'rccmd_SetCameraInput2_Value', -font=> $StdWinFont,
    -text=>'0', -pos=> [$xpos +20,$ypos-3 +50], -size=> [60,23],
  );

  $xpos-= 120;
  $ypos-= 25;
  $w_RcCmd->AddButton( -name=> 'rccmd_SetPwmOut', -font=> $StdWinFont,
    -text=> 'Set PwmOut', -pos=> [$xpos,$ypos-3], -width=> 100,
  );
  $w_RcCmd->AddTextfield( -name=> 'rccmd_SetPwmOut_Value', -font=> $StdWinFont,
    -text=>'1500', -pos=> [$xpos +20,$ypos-3 +25], -size=> [60,23],
  );

  $xpos+= 240;
  $ypos= 20 + 50+ 25+25+20+20;
  $w_RcCmd->AddButton( -name=> 'rccmd_Script1Default', -font=> $StdWinFont,
    -text=> 'Script1 Default', -pos=> [$xpos,$ypos-3], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."Script1 Default"."\r\n" ); SendRcCmdTool( '10'. '00'.'01' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_Script1Case1', -font=> $StdWinFont,
    -text=> 'Script1 Case#1', -pos=> [$xpos,$ypos-3+25], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."Script1 Case#1"."\r\n" ); SendRcCmdTool( '10'. '00'.'02' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_Script1Case2', -font=> $StdWinFont,
    -text=> 'Script1 Case#2', -pos=> [$xpos,$ypos-3+50], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."Script1 Case#2"."\r\n" ); SendRcCmdTool( '10'. '00'.'03' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_Script1Case3', -font=> $StdWinFont,
    -text=> 'Script1 Case#3', -pos=> [$xpos,$ypos-3+75], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."Script1 Case#3"."\r\n" ); SendRcCmdTool( '10'. '00'.'04' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_Script1Case4', -font=> $StdWinFont,
    -text=> 'Script1 Case#4', -pos=> [$xpos,$ypos-3+100], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."Script1 Case#4"."\r\n" ); SendRcCmdTool( '10'. '00'.'05' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_Script1Off', -font=> $StdWinFont,
    -text=> 'Release', -pos=> [$xpos,$ypos-3+125], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."Script1 Release"."\r\n" ); SendRcCmdTool( '10'. '00'.'00' ); 1; },
  );

  $xpos+= 120;
  $w_RcCmd->AddButton( -name=> 'rccmd_Script2Default', -font=> $StdWinFont,
    -text=> 'Script2 Default', -pos=> [$xpos,$ypos-3], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."Script2 Default"."\r\n" ); SendRcCmdTool( '10'. '01'.'01' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_Script2Case1', -font=> $StdWinFont,
    -text=> 'Script2 Case#1', -pos=> [$xpos,$ypos-3+25], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."Script2 Case#1"."\r\n" ); SendRcCmdTool( '10'. '01'.'02' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_Script2Case2', -font=> $StdWinFont,
    -text=> 'Script2 Case#2', -pos=> [$xpos,$ypos-3+50], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."Script2 Case#2"."\r\n" ); SendRcCmdTool( '10'. '01'.'03' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_Script2Case3', -font=> $StdWinFont,
    -text=> 'Script2 Case#3', -pos=> [$xpos,$ypos-3+75], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."Script2 Case#3"."\r\n" ); SendRcCmdTool( '10'. '01'.'04' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_Script2Case4', -font=> $StdWinFont,
    -text=> 'Script2 Case#4', -pos=> [$xpos,$ypos-3+100], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."Script2 Case#4"."\r\n" ); SendRcCmdTool( '10'. '01'.'05' ); 1; },
  );
  $w_RcCmd->AddButton( -name=> 'rccmd_Script2Off', -font=> $StdWinFont,
    -text=> 'Release', -pos=> [$xpos,$ypos-3+125], -width=> 100,
    -onClick=> sub{ TextOut( "\r\n"."Script2 Release"."\r\n" ); SendRcCmdTool( '10'. '01'.'00' ); 1; },
  );

  $xpos= 20;
  $ypos= 20 + 50+ 25+25+20+20 + 100 + 25;
  $w_RcCmd->AddButton( -name=> 'rccmd_GetVersion', -font=> $StdWinFont,
    -text=> 'Get Version', -pos=> [$xpos,$ypos-3], -width=> 140,
    -onClick=> sub{ TextOut( "\r\n"."Get Version"."\r\n" ); SendRcCmdTool( '01' ); 1; },
  );
  $ypos+= 25;
  $w_RcCmd->AddButton( -name=> 'rccmd_GetParameter', -font=> $StdWinFont,
    -text=> 'Get Parameter', -pos=> [$xpos,$ypos-3], -width=> 140,
  );
  $w_RcCmd->AddLabel( -name=> 'rccmd_GetParameter_label', -font=> $StdWinFont,
    -text=> "Nr", -pos=> [$xpos+150,$ypos],
  );
  $w_RcCmd->AddTextfield( -name=> 'rccmd_GetParameter_Nr', -font=> $StdWinFont,
    -pos=> [$xpos+150+$w_RcCmd->rccmd_GetParameter_label->Width()+3,$ypos-3], -size=> [40,23],
  );
  $w_RcCmd->rccmd_GetParameter_Nr->Text(0);
  $ypos+= 25;
  $w_RcCmd->AddButton( -name=> 'rccmd_SetParameter', -font=> $StdWinFont,
    -text=> 'Set Parameter', -pos=> [$xpos,$ypos-3], -width=> 140,
  );
  $w_RcCmd->AddLabel( -name=> 'rccmd_SetParameterNr_label', -font=> $StdWinFont,
    -text=> "Nr", -pos=> [$xpos+150,$ypos],
  );
  $w_RcCmd->AddTextfield( -name=> 'rccmd_SetParameter_Nr', -font=> $StdWinFont,
    -pos=> [$xpos+150+$w_RcCmd->rccmd_SetParameterNr_label->Width()+3,$ypos-3], -size=> [40,23],
  );
  $w_RcCmd->rccmd_SetParameter_Nr->Text(0);
  $w_RcCmd->AddLabel( -name=> 'rccmd_SetParameterValue_label', -font=> $StdWinFont,
    -text=> "Value", -pos=> [$xpos+210,$ypos],
  );
  $w_RcCmd->AddTextfield( -name=> 'rccmd_SetParameter_Value', -font=> $StdWinFont,
    -pos=> [$xpos+210+$w_RcCmd->rccmd_SetParameterValue_label->Width()+3,$ypos-3], -size=> [40,23],
  );
  $w_RcCmd->rccmd_SetParameter_Value->Text(0);
  $ypos+= 25;
  $w_RcCmd->AddButton( -name=> 'rccmd_GetData', -font=> $StdWinFont,
    -text=> 'Get Data', -pos=> [$xpos,$ypos-3], -width=> 140,
  );

}

sub rccmd_SetAngle_Click{
  TextOut( "\r\n".'SetAngle'."\r\n" );
  my $pitch = sprintf("%.5E",$w_RcCmd->rccmd_SetAngle_Pitch->Text());
  my $roll = sprintf("%.5E",$w_RcCmd->rccmd_SetAngle_Roll->Text());
  my $yaw = sprintf("%.5E",$w_RcCmd->rccmd_SetAngle_Yaw->Text());
  TextOut( $pitch.','.$roll.','.$yaw.',0,0!'."\r\n" );
  my $pitchf = FloatToHexstrSwapped($pitch);
  my $rollf = FloatToHexstrSwapped($roll);
  my $yawf = FloatToHexstrSwapped($yaw);
  my $flags = '00'; #angles are unlimited
  my $type = '00'; # type is proper gimbal Euler angles in STorM32 frame (NWU)
#TextOut('!'.$pitchf.','.$rollf.','.$yawf.','.$flags.','.$type.'!');
  SendRcCmdTool( '11' . $pitchf . $rollf . $yawf . $flags . $type ); # '11' = #17

##message interval test
# float param1; ///< Parameter 1, as defined by MAV_CMD enum.
# float param2; ///< Parameter 2, as defined by MAV_CMD enum.
# float param3; ///< Parameter 3, as defined by MAV_CMD enum.
# float param4; ///< Parameter 4, as defined by MAV_CMD enum.
# float param5; ///< Parameter 5, as defined by MAV_CMD enum.
# float param6; ///< Parameter 6, as defined by MAV_CMD enum.
# float param7; ///< Parameter 7, as defined by MAV_CMD enum.
# uint16_t command; ///< Command ID, as defined by MAV_CMD enum.
# uint8_t target_system; ///< System which should execute the command
# uint8_t target_component; ///< Component which should execute the command, 0 for all components
# uint8_t confirmation; ///< 0: First transmission of this command. 1-255: Confirmation transmissions (e.g. for kill command)
#  my $msgid = FloatToHexstrSwapped(30); ##attitude
#  my $rate = FloatToHexstrSwapped(25000);
#  SendNativeMavlinkCmdwWriteOnly(
#    'FF'.'BE', #this is my GCS
#    UCharToHexstr($MAVLINK_MSG_ID_COMMAND_LONG), #command_long, #76
#      $msgid . $rate . '00000000'. '00000000'. '00000000'. '00000000'. '00000000' .
#      'FF01' . #command #511 MAV_CMD_SET_MESSAGE_INTERVAL
#      '47' . '43' . # sys ID 71, CompID 67 #this is the STorM32
#      '00',
#    $MAVLINK_MSG_ID_COMMAND_LONG_CRC,
#  );

# float param1; ///< Parameter 1, as defined by MAV_CMD enum.
# float param2; ///< Parameter 2, as defined by MAV_CMD enum.
# float param3; ///< Parameter 3, as defined by MAV_CMD enum.
# float param4; ///< Parameter 4, as defined by MAV_CMD enum.
# float param5; ///< Parameter 5, as defined by MAV_CMD enum.
# float param6; ///< Parameter 6, as defined by MAV_CMD enum.
# float param7; ///< Parameter 7, as defined by MAV_CMD enum.
# uint16_t command; ///< Command ID, as defined by MAV_CMD enum.
# uint8_t target_system; ///< System which should execute the command
# uint8_t target_component; ///< Component which should execute the command, 0 for all components
# uint8_t confirmation; ///< 0: First transmission of this command. 1-255: Confirmation transmissions (e.g. for kill command)
#  SendNativeMavlinkCmdwWriteOnly(
#    'FF'.'BE', #this is my GCS
#    UCharToHexstr($MAVLINK_MSG_ID_COMMAND_LONG), #command_long, #76
#      $pitchf . $rollf . $yawf . '00000000'. '00000000'. $flags.$type.'0000' . '00000000' .
#      'CD00' . #command #205 DO_MOUNT
#      '47' . '43' . # sys ID 71, CompID 67 #this is the STorM32
#      '00',
#    $MAVLINK_MSG_ID_COMMAND_LONG_CRC,
#  );
#  SendNativeMavlinkCmd(
#    $GCS_SYSCOMP_ID, #'FF'.'BE', #this is my GCS
#    UCharToHexstr($MAVLINK_MSG_ID_COMMAND_TARGET_SPECIFIC),
#      $STORM32_SYSCOMP_ID . #'47' . '43' . # sys ID 71, CompID 67 #this is the STorM32
#      '76', #UCharToHexstr(StrToDez('v')),
#    $MAVLINK_MSG_ID_COMMAND_TARGET_SPECIFIC_CRC,
#    $MAVLINK_MSG_ID_COMMAND_TARGET_SPECIFIC_ACK_CRC,
#    #-1 #nothing to read
#    #0 #do read, unknown response length
#    59 + 8,
#  );

## send to Pixhawk (01,01), mimicking Misson Planner (FF,BE)
# int32_t input_a; ///< pitch(deg*100) or lat, depending on mount mode
# int32_t input_b; ///< roll(deg*100) or lon depending on mount mode
# int32_t input_c; ///< yaw(deg*100) or alt (in cm) depending on mount mode
# uint8_t target_system; ///< System ID
# uint8_t target_component; ///< Component ID
# uint8_t save_position; ///< if "1" it will save current trimmed position on EEPROM (just valid for NEUTRAL and LANDING)
#  my $pitchi32 = Int32ToHexstrSwapped($pitch*100);
#  my $rolli32 = Int32ToHexstrSwapped($roll*100);
#  my $yawi32 = Int32ToHexstrSwapped($yaw*100);
#TextOut( $pitchi32.','.$rolli32.','.$yawi32.',!' );

###$Baudrate = 57600;OpenPort();
# TEST of sending "new" mount_control to pixhawk, digested and forwarded to STorM32
#  SendNativeMavlinkCmdwWriteOnly(
#    'FF'.'BE', #this is my GCS
#    UCharToHexstr($MAVLINK_MSG_ID_MOUNT_CONFIGURE), #mount_configure, #156
#      '0101'.
#      '00'. #RETRACT
#      #'01'. #NEUTRAL
#      #'02'. #MAVLINK_TARGETING
#      #'03'. #RC_TARGETING
#      '000000',
#    $MAVLINK_MSG_ID_MOUNT_CONFIGURE_CRC,
#  );
#  SendNativeMavlinkCmdwWriteOnly(
#    'FF'.'BE', #this is my GCS
#    UCharToHexstr($MAVLINK_MSG_ID_MOUNT_CONTROL), #mount_control, #157
#      $pitchi32 . $rolli32 . $yawi32 .
#      '0101' . # sys ID 1, CompID 0   #'47' . '43' . # sys ID 71, CompID 67
#      '90', #10000000
#    $MAVLINK_MSG_ID_MOUNT_CONTROL_CRC,
#  );

# TEST of passing cmd_long_do_mount_control through pixhawk to STorM32
#  SendNativeMavlinkCmdwWriteOnly(
#    '52'.'43', #this is the GUI
#    #'FF'.'BE', #this is my GCS
#    UCharToHexstr($MAVLINK_MSG_ID_COMMAND_LONG), #command_long, #76
#      $pitchf . $rollf . $yawf . '00000000'. '00000000'. $flags.$type.'0000' . '00000000' .
#      'CD00' . #command #205 DO_MOUNT
#      '47' . '43' . # sys ID 71, CompID 67 #this is the STorM32
#      '00',
#    $MAVLINK_MSG_ID_COMMAND_LONG_CRC,
#  );

# TEST of passing empeded MavRC Set_Angle through pixhawk to STorM32
#  sending directly to STorM32 works
#  sending to pixhawk works, with code changes
#  the recieving data needs more careful treatment, since there might be other messages coming into its way
#  SendNativeMavlinkCmdwWriteOnly(
#    '52'.'43', #this is the GUI
#    #'FF'.'BE', #this is my GCS
#    UCharToHexstr($MAVLINK_MSG_ID_COMMAND_TARGET_SPECIFIC),
#      '47' . '43' . # sys ID 71, CompID 67 #this is the STorM32
#      '11' . #MAVLINKRC_CMD_SETANGLE #17
#      $pitchf . $rollf . $yawf .
#      $flags . $type ,
#    $MAVLINK_MSG_ID_COMMAND_TARGET_SPECIFIC_CRC,
#  );
###ClosePort();
  1;
}

sub rccmd_SetAngleUnrestricted_Click{
  TextOut( "\r\n".'SetAngleUnrestricted'."\r\n" );
  my $pitch = sprintf("%.5E",$w_RcCmd->rccmd_SetAngleUnrestricted_Pitch->Text());
  my $roll = sprintf("%.5E",$w_RcCmd->rccmd_SetAngleUnrestricted_Roll->Text());
  my $yaw = sprintf("%.5E",$w_RcCmd->rccmd_SetAngleUnrestricted_Yaw->Text());
  my $ratepitch = sprintf("%.5E",$w_RcCmd->rccmd_SetAngleUnrestricted_RatePitch->Text());
  my $rateroll = sprintf("%.5E",$w_RcCmd->rccmd_SetAngleUnrestricted_RateRoll->Text());
  my $rateyaw = sprintf("%.5E",$w_RcCmd->rccmd_SetAngleUnrestricted_RateYaw->Text());
  TextOut( $pitch.','.$roll.','.$yaw.','.$ratepitch.','.$rateroll.','.$rateyaw."\r\n" );
  my $pitchf = FloatToHexstrSwapped($pitch);
  my $rollf = FloatToHexstrSwapped($roll);
  my $yawf = FloatToHexstrSwapped($yaw);
  my $ratepitchf = FloatToHexstrSwapped($ratepitch);
  my $raterollf = FloatToHexstrSwapped($rateroll);
  my $rateyawf = FloatToHexstrSwapped($rateyaw);
  SendRcCmdTool( '1C' . $pitchf . $rollf . $yawf . $ratepitchf . $raterollf . $rateyawf );  # '1C' = #28
  1;
}

sub rccmd_GetParameter_Click{
  TextOut( "\r\n".'Get Parameter'."\r\n" );
  my $s = $w_RcCmd->rccmd_GetParameter_Nr->Text();
  #TextOut( UCharToHexstr($s) );
  ## SendRcCmdTool( '03'. UCharToHexstr($s).'00', 8+2*2 );
  SendRcCmdTool( '03'. UCharToHexstr($s).'00' );
  1;
}

sub rccmd_SetParameter_Click{
  TextOut( "\r\n".'Set Parameter'."\r\n" );
  my $s = $w_RcCmd->rccmd_SetParameter_Nr->Text();
  $s = UCharToHexstr($s).'00';
  TextOut( $s.'!' );
  my $v = $w_RcCmd->rccmd_SetParameter_Value->Text();
  if( $v < 0 ){ $v = $v + 65536; }
  $v = UIntToHexstrSwapped($v); #$v= UIntToHexstr($v); $v= substr($v,2,2).substr($v,0,2);
  TextOut( $v.'!' );
  SendRcCmdTool( '04'. $s.$v ); #SendMavlinkCmd( '02'. '0000'.'6400' );
  1;
}

sub rccmd_GetData_Click{
  TextOut( "\r\n".'Get Data'."\r\n" );
  SendRcCmdTool( '05'. '00' );#, 8 + 2 + 2*$CMD_d_PARAMETER_ZAHL);   #8 +2 + 2*32 = 74  #type & data
  1;
}

sub rccmd_SetCameraInput_Click{
  TextOut( "\r\n".'SetCameraInput'."\r\n" );
  my $v1 = $w_RcCmd->rccmd_SetCameraInput_Value->Text();
  my $v2 = $w_RcCmd->rccmd_SetCameraInput2_Value->Text();
  TextOut( $v1.','.$v2.'!' );
  $v1 = UIntToHexstrSwapped($v1);
  $v2 = UIntToHexstrSwapped($v2);
  TextOut( $v1.','.$v2.'!' );
  SendRcCmdTool( '1A'. $v1 . $v2 );
  1;
}

sub rccmd_SetPwmOut_Click{
  TextOut( "\r\n".'SetPwmOut'."\r\n" );
  my $v = $w_RcCmd->rccmd_SetPwmOut_Value->Text();
  TextOut( $v.'!' );
  $v = UIntToHexstrSwapped($v); #$v= UIntToHexstr($v); $v= substr($v,2,2).substr($v,0,2);
  TextOut( $v.'!' );
  SendRcCmdTool( '13'. $v );
  1;
}


#-----------------------------------------------------------------------------#
###############################################################################
# MAVLINKCMD Test Window
###############################################################################
#-----------------------------------------------------------------------------#
my $MavlinkCmdXPos= 100;
my $MavlinkCmdYPos= 100;

my $MavlinkCmdXsize= 510;
my $MavlinkCmdYsize= 300; #400+20;

my $w_MavlinkCmd= Win32::GUI::DialogBox->new( -name=> 'mavlinkcmd_Window',  -parent => $w_Main, -font=> $StdWinFont,
    -text=> "Mavlink Command Tool",
    -pos=> [$MavlinkCmdXPos,$MavlinkCmdYPos],
    -size=> [$MavlinkCmdXsize,$MavlinkCmdYsize],
   -helpbox => 0,
);
$w_MavlinkCmd->SetIcon($Icon);

sub t_MavlinkCmdTool_Click{ MavlinkCmdInit(); MavlinkCmdShow(); 1; }

sub mavlinkcmd_Window_Terminate{ $w_MavlinkCmd->Hide(); 0; }

sub MavlinkCmdShow{
  my ($x, $y) = ($w_Main->GetWindowRect())[0..1];
  $w_MavlinkCmd->Move($x+100,$y+100);
  $w_MavlinkCmd->Show();
  if( not ConnectionIsValid() ){ return 0; }
  return 1;
}

sub SendMavlinkCmdTool{
  SendMavlinkCmd(shift);
}

my $MavlinkCmdIsInitialized = 0;

sub MavlinkCmdInit{
  if( $MavlinkCmdIsInitialized>0 ){ return; }
  $MavlinkCmdIsInitialized = 1;
  my $xpos= 20;
  my $ypos= 20;
  $w_MavlinkCmd->AddButton( -name=> 'mavlinkcmd_RequestCameraCaptureStatus', -font=> $StdWinFont,
    -text=> 'Request CameraCaptureStatus', -pos=> [$xpos,$ypos-3], -width=> 180,
#    -onClick=> sub{ TextOut( "\r\n"."PitchUp"."\r\n" ); SendRcCmdTool( '0A' . 'E803' ); 1; },
  );
}


my $MAVLINK_MSG_ID_COMMAND_LONG = 76;
my $MAVLINK_MSG_ID_COMMAND_LONG_CRC = 152;
my $MAVLINK_MSG_ID_CAMERA_CAPTURE_STATUS = 262;
my $MAVLINK_MSG_ID_CAMERA_CAPTURE_STATUS_CRC = 12;

sub WriteMav2CommandLong1{
  my $sysid = shift; # integer
  my $compid = shift; # integer
  my $cmd = shift; # integer
  my $param1 = shift; #  my $pitchf = FloatToHexstrSwapped($pitch);

  my $msgid = UIntToHexstrSwapped($MAVLINK_MSG_ID_COMMAND_LONG).'00';
  my $msgpayload = $param1.'00000000'.'00000000'.'00000000'.'00000000'.'00000000'.'00000000'.
                   UIntToHexstrSwapped($cmd).
                   '00'.'00'.'00'; #target sysid, tagert compid, confirmation
                   #do we need to worry about MAVlink2 truncation ????
  WriteMav2Message($sysid, $compid, $msgid, $msgpayload, $MAVLINK_MSG_ID_COMMAND_LONG_CRC);
}

sub mavlinkcmd_RequestCameraCaptureStatus_Click{
  TextOut( "\r\n".'Mavlink: request CameraCaptureStatus' );
  my ($MavlinkGimbal_SysId, $MavlinkGuiComponentId) = MavlinkGetGuiSysComId();
#  if( $PortIsOpen and MavlinkTunnelIsInUse() and ($MavlinkGimbal_SysId > 0) ){
  if( $PortIsOpen ){
    WriteMav2CommandLong1($MavlinkGimbal_SysId, $MavlinkGuiComponentId, 527, FloatToHexstrSwapped(1.0));
  }else{
    TextOut( "\r\n".'fail');
  }
  TextOut( "\r\n" );
  1;
}




#MAVLink common stuff
my $MavDetailsOut = 0;

# some constants
my $MAVSTX = 'FE';
my $MAVSTX2 = 'FD';
my $MAV_AUTOPILOT_INVALID = 8;
my $MAV_TYPE_GCS = 6;
my $MAV_TYPE_GIMBAL = 26;
my $MAV_TYPE_CAMERA = 30;
my $MAV_STATE_ACTIVE = 4;
my $MAV_COMP_ID_AUTOPILOT1 = 1;
#not needed my $MAV_COMP_ID_USER42 = 66;
my $MAV_COMP_ID_CAMERA = 100;
my $MAV_COMP_ID_CAMERA2 = 101;
my $MAV_COMP_ID_CAMERA3 = 102;
my $MAV_COMP_ID_CAMERA4 = 103;
my $MAV_COMP_ID_CAMERA5 = 104;
my $MAV_COMP_ID_CAMERA6 = 105;
my $MAV_COMP_ID_GIMBAL = 154;
my $MAV_COMP_ID_GIMBAL2 = 171;
my $MAV_COMP_ID_GIMBAL3 = 172;
my $MAV_COMP_ID_GIMBAL4 = 173;
my $MAV_COMP_ID_GIMBAL5 = 174;
my $MAV_COMP_ID_GIMBAL6 = 175;
my $MAV_COMP_ID_TUNNEL_NODE = 242;
my $MAV_TUNNEL_PAYLOAD_TYPE_STORM32_RESERVED0 = 200;
my $MAV_TUNNEL_PAYLOAD_TYPE_STORM32_RESERVED1 = 201;
my $MAV_TUNNEL_PAYLOAD_TYPE_STORM32_RESERVED2 = 202;
my $MAV_TUNNEL_PAYLOAD_TYPE_STORM32_RESERVED3 = 203;
my $MAVLINK_MSG_ID_HEARTBEAT = 0;
my $MAVLINK_MSG_ID_HEARTBEAT_CRC = 50;
my $MAVLINK_MSG_ID_TUNNEL = 385;
my $MAVLINK_MSG_ID_TUNNEL_CRC = 147;

my $MAV_TUNNEL_PAYLOAD_TYPE_STORM32_CHANNEL1 = $MAV_TUNNEL_PAYLOAD_TYPE_STORM32_RESERVED0;

my $MAV_TUNNEL_PAYLOAD_TYPE_STORM32_CHANNEL1_IN = $MAV_TUNNEL_PAYLOAD_TYPE_STORM32_CHANNEL1;
my $MAV_TUNNEL_PAYLOAD_TYPE_STORM32_CHANNEL1_OUT = $MAV_TUNNEL_PAYLOAD_TYPE_STORM32_CHANNEL1_IN+1;


#check of forward declarations
if( $MAV_COMP_ID_GIMBAL_forward != $MAV_COMP_ID_GIMBAL ){ exit(); }
if( $MAV_COMP_ID_TUNNEL_NODE_forward != $MAV_COMP_ID_TUNNEL_NODE ){ exit(); }

# 'internal' status/control flags
my $MavlinkAutopilot_Found = 0; # true implies that the SysId has been set to valid values
my $MavlinkCamera_Found = 0; # true implies that both SysId and CompId have been set to valid values
my $MavlinkGimbal_Found = 0; # true implies that both SysId and CompId have been set to valid values
my $MavlinkAutopilot_SysId = 0;
my $MavlinkCamera_SysId = 0;
my $MavlinkCamera_CompId = 0;
my $MavlinkGimbal_SysId = 0;
my $MavlinkGimbal_CompId = 0;

my $Mavlink_IgnoreHeartbeats = 0; # allows to cut of handling of received hearbet

my $MavlinkGimbal_tunnelrxdata = '';


sub MavlinkGetGuiSysComId{
  return ($MavlinkGimbal_SysId, $MavlinkGuiComponentId);
}

sub MavlinkGimbalReset{
  $MavlinkAutopilot_Found = 0;
  $MavlinkAutopilot_SysId = 0;
  $MavlinkCamera_Found = 0;
  $MavlinkCamera_SysId = 0;
  $MavlinkCamera_CompId = 0;
  $MavlinkGimbal_Found = 0;
  $MavlinkGimbal_SysId = 0;
  $MavlinkGimbal_CompId = 0;
  $Mavlink_IgnoreHeartbeats = 0;
}

sub MavlinkAutopilotIsFound{
  return $MavlinkAutopilot_Found;
}

sub MavlinkCameraIsFound{
  return $MavlinkCamera_Found;
}

sub MavlinkGimbalIsFound{
  return $MavlinkGimbal_Found;
}

sub MavlinkSetAutopilotSysId{
  $MavlinkGimbal_SysId = $MavlinkAutopilot_SysId;
}

sub MavlinkSetDefaultSysId{
  $MavlinkGimbal_SysId = $MavlinkDefaultSystemId;
}

sub MavlinkSetCameraSysCompId{
  $MavlinkGimbal_SysId = $MavlinkCamera_SysId;
  $MavlinkGimbal_CompId = $MavlinkCamera_CompId;
  $MavlinkGimbal_Found = 1; #this is required to enable incomming packets for camera also
}

sub MavlinkSetIgnoreHeartbeats{
  $Mavlink_IgnoreHeartbeats = 1;
}

sub MavlinkGetGimbalSysComId{
  my $name = '';
  if( $MavlinkGimbal_CompId == $MAV_COMP_ID_CAMERA ){ $name = 'Camera #1'; }
  if( $MavlinkGimbal_CompId == $MAV_COMP_ID_CAMERA2 ){ $name = 'Camera #2'; }
  if( $MavlinkGimbal_CompId == $MAV_COMP_ID_CAMERA3 ){ $name = 'Camera #3'; }
  if( $MavlinkGimbal_CompId == $MAV_COMP_ID_CAMERA4 ){ $name = 'Camera #4'; }
  if( $MavlinkGimbal_CompId == $MAV_COMP_ID_CAMERA5 ){ $name = 'Camera #5'; }
  if( $MavlinkGimbal_CompId == $MAV_COMP_ID_CAMERA6 ){ $name = 'Camera #6'; }
  if( $MavlinkGimbal_CompId == $MAV_COMP_ID_GIMBAL ){ $name = 'Gimbal #1'; }
  if( $MavlinkGimbal_CompId == $MAV_COMP_ID_GIMBAL2 ){ $name = 'Gimbal #2'; }
  if( $MavlinkGimbal_CompId == $MAV_COMP_ID_GIMBAL3 ){ $name = 'Gimbal #3'; }
  if( $MavlinkGimbal_CompId == $MAV_COMP_ID_GIMBAL4 ){ $name = 'Gimbal #4'; }
  if( $MavlinkGimbal_CompId == $MAV_COMP_ID_GIMBAL5 ){ $name = 'Gimbal #5'; }
  if( $MavlinkGimbal_CompId == $MAV_COMP_ID_GIMBAL6 ){ $name = 'Gimbal #6'; }
  return ($MavlinkGimbal_SysId, $MavlinkGimbal_CompId, $name);
}

#this needs the SysId to be set
sub MavlinkSendGuiHeartbeat{
  if( $PortIsOpen and MavlinkTunnelIsInUse() and ($MavlinkGimbal_SysId > 0) ){
    WriteMav2HeartbeatMessage($MavlinkGimbal_SysId, $MavlinkGuiComponentId); #source
  }
}

#called in timer
sub MavlinkReceiveTimer{
  if( $PortIsOpen and MavlinkTunnelIsInUse() ){
    MavlinkReceive();
  }
}

#called in ReadPortOneByte
sub MavlinkReceiveReadPort{
  MavlinkReceive();
}


#low-level tunnel port handler

# WritePort must be only called when sysid and compid of gimbal are known!
sub WritePort_mavtunnel{
  my $cmd = shift; #hexstr

  #TextOut("\n".'$'.$cmd.'('.(length($cmd)/2).')$');
  do{
    my $s = substr($cmd, 0, 64*2);
    if( length($cmd) > 64*2 ){
      $cmd = substr($cmd, 64*2);
    }else{
      $cmd = '';
    }
    #TextOut("\n".'$ '.length($s).','.length($cmd).' $');
    WriteMav2TunnelMessage($MavlinkGimbal_SysId, $MavlinkGuiComponentId, #source
                           $MavlinkGimbal_SysId, $MavlinkGimbal_CompId, #target
                           $s);
  }while( length($cmd) > 0 );
}

sub FlushPort_mavtunnel{
  #FlushPort_direct();
  $MavlinkGimbal_tunnelrxdata = '';
}

sub ReadPortOneByte_mavtunnel{
  if( $MavlinkGimbal_tunnelrxdata ne '' ){
    my $s = substr($MavlinkGimbal_tunnelrxdata,0,1);
    $MavlinkGimbal_tunnelrxdata = substr($MavlinkGimbal_tunnelrxdata,1);
    return (1,$s);
  }else{
    return (0,'');
  }
}


#MAVLink handler

sub WriteMav2Message{
  my $sysid = shift; # integer
  my $compid = shift; # integer
  my $msgid = shift; # hex str
  my $msgpayload = shift; #hex str
  my $crcextra = shift; # integer

  my $msglen = UCharToHexstr( length($msgpayload)/2 ) ;
  my $cmd = $MAVSTX2.$msglen.'000000'.UCharToHexstr($sysid).UCharToHexstr($compid).$msgid.$msgpayload;
  $cmd .= do_crc_wextra_hexstr( $cmd, $crcextra );
  if($MavDetailsOut){ TextOut( "\n!out ".$cmd.' ' ); }
  WritePort_direct( HexstrToStr($cmd) );
}

sub WriteMav2HeartbeatMessage{
  my $sysid = shift; # integer
  my $compid = shift; # integer

  my $msgid = UIntToHexstrSwapped($MAVLINK_MSG_ID_HEARTBEAT).'00';
  my $msgpayload = '00000000'.
                   UCharToHexstr($MAV_TYPE_GCS).UCharToHexstr($MAV_AUTOPILOT_INVALID).
                   '00'.UCharToHexstr($MAV_STATE_ACTIVE).
                   UCharToHexstr(3); #thx to this we don't need to worry about MAVlink2 truncation
  WriteMav2Message($sysid, $compid, $msgid, $msgpayload, $MAVLINK_MSG_ID_HEARTBEAT_CRC);
}

sub WriteMav2TunnelMessage{
  my $sysid = shift; # integer
  my $compid = shift; # integer
  my $target_sysid = shift; # integer
  my $target_compid = shift; # integer
  my $tunnel_payload = shift; #hex str

  my $tunnel_payload_length = length($tunnel_payload)/2;
  #TextOut( "\n".'!!'.$tunnel_payload.'('.$tunnel_payload_length.')');
  my $msgid = UIntToHexstrSwapped($MAVLINK_MSG_ID_TUNNEL).'00';
  my $msgpayload = UIntToHexstrSwapped($MAV_TUNNEL_PAYLOAD_TYPE_STORM32_CHANNEL1_IN).
                   UCharToHexstr($target_sysid).UCharToHexstr($target_compid).
                   UCharToHexstr($tunnel_payload_length).
                   $tunnel_payload.
                   'FF'; #we add a payload end marker, but don't count it, to get around MAVLink2 truncation
  WriteMav2Message($sysid, $compid, $msgid, $msgpayload, $MAVLINK_MSG_ID_TUNNEL_CRC);
}


my $MavlinkParse_STATE_IDLE = 0;
my $MavlinkParse_STATE_LENGTH = 1;
my $MavlinkParse_STATE_INCOMPFLAGS = 2;
my $MavlinkParse_STATE_COMPFLAGS = 3;
my $MavlinkParse_STATE_SEQUENCE = 4;
my $MavlinkParse_STATE_SYSID = 5;
my $MavlinkParse_STATE_COMPID = 6;
my $MavlinkParse_STATE_MSGID0 = 7;
my $MavlinkParse_STATE_MSGID1 = 8;
my $MavlinkParse_STATE_MSGID2 = 9;
my $MavlinkParse_STATE_PAYLOAD = 10;
my $MavlinkParse_STATE_CRC0 = 11;
my $MavlinkParse_STATE_CRC1 = 12;
my $MavlinkParse_STATE_RECEIVED = 13;

my $MavlinkPacket_version = 0;
my $MavlinkPacket_len = 0;
my $MavlinkPacket_sysid = 0;
my $MavlinkPacket_compid = 0;
my $MavlinkPacket_msgid = 0;
my $MavlinkPacket_payload = '';
my $MavlinkPacket_crc = 0;

my $MavlinkParse_state = 0;
my $MavlinkParse_payload_cnt = 0;


sub MavlinkParseNextChar{
  my $s = shift;

  if( $MavlinkParse_state == $MavlinkParse_STATE_IDLE ){
    my $r = StrToHexstr($s);
    if( $r eq $MAVSTX ){
      $MavlinkPacket_version = 1;
      $MavlinkParse_state = $MavlinkParse_STATE_LENGTH;
      $MavlinkParse_payload_cnt = 0;
      $MavlinkPacket_payload = '';
    }elsif( $r eq $MAVSTX2 ){
      $MavlinkPacket_version = 2;
      $MavlinkParse_state = $MavlinkParse_STATE_LENGTH;
      $MavlinkParse_payload_cnt = 0;
      $MavlinkPacket_payload = '';
    }

  }elsif( $MavlinkParse_state == $MavlinkParse_STATE_LENGTH ){
    $MavlinkPacket_len = unpack( "C", $s );
    if( $MavlinkPacket_version == 1 ){
      $MavlinkParse_state = $MavlinkParse_STATE_SEQUENCE;
    }else{
      $MavlinkParse_state = $MavlinkParse_STATE_INCOMPFLAGS;
    }

  }elsif( $MavlinkParse_state == $MavlinkParse_STATE_INCOMPFLAGS ){
    $MavlinkParse_state = $MavlinkParse_STATE_COMPFLAGS;

  }elsif( $MavlinkParse_state == $MavlinkParse_STATE_COMPFLAGS ){
    $MavlinkParse_state = $MavlinkParse_STATE_SEQUENCE;

  }elsif( $MavlinkParse_state == $MavlinkParse_STATE_SEQUENCE ){
    $MavlinkParse_state = $MavlinkParse_STATE_SYSID;

  }elsif( $MavlinkParse_state == $MavlinkParse_STATE_SYSID ){
    $MavlinkPacket_sysid = unpack( "C", $s );
    $MavlinkParse_state = $MavlinkParse_STATE_COMPID;

  }elsif( $MavlinkParse_state == $MavlinkParse_STATE_COMPID ){
    $MavlinkPacket_compid = unpack( "C", $s );
    $MavlinkParse_state = $MavlinkParse_STATE_MSGID0;

  }elsif( $MavlinkParse_state == $MavlinkParse_STATE_MSGID0 ){
    $MavlinkPacket_msgid = unpack( "C", $s );
    if( $MavlinkPacket_version == 1 ){
      $MavlinkParse_state = $MavlinkParse_STATE_PAYLOAD;
    }else{
      $MavlinkParse_state = $MavlinkParse_STATE_MSGID1;
    }

  }elsif( $MavlinkParse_state == $MavlinkParse_STATE_MSGID1 ){
    $MavlinkPacket_msgid += 256*(unpack( "C", $s ));
    $MavlinkParse_state = $MavlinkParse_STATE_MSGID2;

  }elsif( $MavlinkParse_state == $MavlinkParse_STATE_MSGID2 ){
    $MavlinkPacket_msgid += (256*256)*(unpack( "C", $s ));
    $MavlinkParse_state = $MavlinkParse_STATE_PAYLOAD;

  }elsif( $MavlinkParse_state == $MavlinkParse_STATE_PAYLOAD ){
    $MavlinkPacket_payload .= $s;
    $MavlinkParse_payload_cnt += 1;
    if( $MavlinkParse_payload_cnt >= $MavlinkPacket_len ){
      $MavlinkParse_state = $MavlinkParse_STATE_CRC0;
    }

  }elsif( $MavlinkParse_state == $MavlinkParse_STATE_CRC0 ){
    $MavlinkPacket_crc = unpack( "C", $s );
    $MavlinkParse_state = $MavlinkParse_STATE_CRC1;

  }elsif( $MavlinkParse_state == $MavlinkParse_STATE_CRC1 ){
    $MavlinkPacket_crc += 256*unpack( "C", $s );
    $MavlinkParse_state = $MavlinkParse_STATE_RECEIVED;
  }
}


# $MavlinkDefaultSystemId
# logic:
#   if there is a gimbal HB => end and OK
#   if there is no gimbal HB:
#     if there is a camera HB => end and OK
#     if there is a autopilot => set SysId and activate GUI HB
#     if there is none withing tmo => set SysId=$MavlinkDefaultSystemId and activate GUI HB
# $MavlinkGimbalDefaultComponentId
# logic:
#   if there is only one gimbal HB, use the one found
#   if there are several gimbal HBs, use the one specified by $MavlinkGimbalDefaultComponentId
sub MavlinkHandleMessage{
  # incoming HEARTBEAT
  if( $MavlinkPacket_msgid == $MAVLINK_MSG_ID_HEARTBEAT ){
    if($MavDetailsOut){ TextOut( "\n!  HB ".$MavlinkPacket_sysid.','.$MavlinkPacket_compid ); }

    if( $Mavlink_IgnoreHeartbeats ){ return; }

    my $type = unpack("C",substr($MavlinkPacket_payload,4,1));
    my $autopilot = unpack("C",substr($MavlinkPacket_payload,5,1));

    #check if it's a autopilot
    if( not $MavlinkAutopilot_Found ){
      my $found = 0;
      if( $autopilot != $MAV_AUTOPILOT_INVALID ){ #MAV_AUTOPILOT is OK
        $found++;
      }
      if( $MavlinkPacket_compid == $MAV_COMP_ID_AUTOPILOT1 ){ #comp id is OK
        $found++;
      }
      if( $found >= 2 ){
        $MavlinkAutopilot_SysId = $MavlinkPacket_sysid;
        $MavlinkAutopilot_Found = 1;
        if($MavDetailsOut){ TextOut(" -> AUTOPILOT FOUND "); }
      }
    }

    #check if it's a camera, if so assume it's the STorM32
    if( not $MavlinkCamera_Found ){
      my $found = 0;
      if( $autopilot == $MAV_AUTOPILOT_INVALID ){ #MAV_AUTOPILOT is OK
        $found++;
      }
      if( $type == $MAV_TYPE_CAMERA ){ #MAV_TYPE is OK
        $found++;
      }
      if( ($MavlinkPacket_compid == $MAV_COMP_ID_CAMERA) or
          ($MavlinkPacket_compid == $MAV_COMP_ID_CAMERA2) or
          ($MavlinkPacket_compid == $MAV_COMP_ID_CAMERA3) or
          ($MavlinkPacket_compid == $MAV_COMP_ID_CAMERA4) or
          ($MavlinkPacket_compid == $MAV_COMP_ID_CAMERA5) or
          ($MavlinkPacket_compid == $MAV_COMP_ID_CAMERA6) ){ #comp id is OK
        $found++;
      }
      if( $found >= 3 ){
        $MavlinkCamera_SysId = $MavlinkPacket_sysid;
        $MavlinkCamera_CompId = $MavlinkPacket_compid;
        $MavlinkCamera_Found = 1;
        if($MavDetailsOut){ TextOut(" -> CAMERA FOUND "); }
      }
    }

    #check if it's a gimbal, if so assume it's the STorM32
    if( not $MavlinkGimbal_Found ){
      my $found = 0;
      if( $autopilot == $MAV_AUTOPILOT_INVALID ){ #MAV_AUTOPILOT is OK
        $found++;
      }
      if( $type == $MAV_TYPE_GIMBAL ){ #MAV_TYPE is OK
        $found++;
      }
      if( ($MavlinkPacket_compid == $MAV_COMP_ID_GIMBAL) or
          ($MavlinkPacket_compid == $MAV_COMP_ID_GIMBAL2) or
          ($MavlinkPacket_compid == $MAV_COMP_ID_GIMBAL3) or
          ($MavlinkPacket_compid == $MAV_COMP_ID_GIMBAL4) or
          ($MavlinkPacket_compid == $MAV_COMP_ID_GIMBAL5) or
          ($MavlinkPacket_compid == $MAV_COMP_ID_GIMBAL6) ){ #comp id is OK
        $found++;
      }
      if( $found >= 3 ){
        $MavlinkGimbal_SysId = $MavlinkPacket_sysid;
        $MavlinkGimbal_CompId = $MavlinkPacket_compid;
        $MavlinkGimbal_Found = 1;
        if($MavDetailsOut){ TextOut(" -> GIMBAL FOUND "); }
      }
    }

  # incoming TUNNEL
  }elsif( $MavlinkPacket_msgid == $MAVLINK_MSG_ID_TUNNEL ){
    if($MavDetailsOut){TextOut("\n!  TNL ".$MavlinkPacket_sysid.','.$MavlinkPacket_compid);}

    my $target_sysid = unpack("C",substr($MavlinkPacket_payload,2,1));
    my $target_compid = unpack("C",substr($MavlinkPacket_payload,3,1));
    my $payload_type = unpack("C",substr($MavlinkPacket_payload,0,1)) + 256*unpack("C",substr($MavlinkPacket_payload,1,1));
    my $payload_length = unpack("C",substr($MavlinkPacket_payload,4,1));

    if($MavDetailsOut){TextOut(' '.$target_sysid.','.$target_compid.','.$payload_type.' ('.$payload_length.')');}

    if( ($MavlinkGimbal_Found > 0) and
        ($target_sysid == $MavlinkGimbal_SysId) and ($target_compid == $MavlinkGuiComponentId) and
        ($payload_type == $MAV_TUNNEL_PAYLOAD_TYPE_STORM32_CHANNEL1_OUT) ){

      #the payload has a payload end marker, so we do not need to worry about MAvlink2 truncation
      if( $payload_length > length($MavlinkPacket_payload)-5 ){ TextOut("\n!! flhjfhsdkfhsdhfsdhf !!"); }
      my $payload = substr($MavlinkPacket_payload,5,$payload_length);
      $MavlinkGimbal_tunnelrxdata .= $payload;
      if($MavDetailsOut){ TextOut(" -> for us "); }
##TextOut( '!'.StrToHexstr($payload).' ' );
    }
  }
}


sub MavlinkReceive{
  #it works better without a timeout mechanism, so removed
  while(1){
    my ($i, $s) = ReadPortOneByte_direct();
    if( $i == 0 ){ last; }
    #TextOut( StrToHexstr($s) );
    MavlinkParseNextChar( $s );
    if( $MavlinkParse_state == $MavlinkParse_STATE_RECEIVED ){
      $MavlinkParse_state = $MavlinkParse_STATE_IDLE;
      if($MavDetailsOut){ TextOut( "\n!in ".$MavlinkPacket_sysid.','.$MavlinkPacket_compid.' '.$MavlinkPacket_msgid.' ('.$MavlinkPacket_len.') ' ); }
      #TextOut( '!'.StrToHexstr($MavlinkPacket_payload).' ' );
      MavlinkHandleMessage();
    }
  };
}




###############################################################################
# Dialog Handler
# und fehlende Eventhandler
###############################################################################

$w_Main-> Show();
if( $ShowUpdateNotesAtStartup ){
  m_UpdateNotes_Click();
}
Win32::GUI::Dialog();
if( $p_Serial ){ $p_Serial->close; }
undef $p_Serial;


if( not defined $IniFile ){
  open(F,">$IniFileName");
  print F "[SYSTEM]\n\n";
  close( F );
  $IniFile = new Config::IniFiles( -file => $IniFileName );
}
if( defined $IniFile ){

$IniFile->newval( 'SYSTEM', 'XPos', $w_Main->AbsLeft() );
$IniFile->newval( 'SYSTEM', 'YPos', $w_Main->AbsTop() );

$IniFile->newval( 'SYSTEM', 'DataDisplayXPos', $w_DataDisplay->AbsLeft() );
$IniFile->newval( 'SYSTEM', 'DataDisplayYPos', $w_DataDisplay->AbsTop() );
$IniFile->newval( 'SYSTEM', 'FontName', $StdWinFontName );
$IniFile->newval( 'SYSTEM', 'FontSize', $StdWinFontSize );
$IniFile->newval( 'SYSTEM', 'TextFontSize', $StdTextFontSize );
$ShowUpdateNotesAtStartup = 0; #this is to deactivae after first call
if( $f_Tab{pid}->AutoWritePIDChanges->Checked() ){ $UseAutoWritePIDChanges = 1; }else{ $UseAutoWritePIDChanges = 0; }
$IniFile->newval( 'SYSTEM', 'UseAutoWritePIDChanges', $UseAutoWritePIDChanges );
$IniFile->newval( 'SYSTEM', 'ShowNotesAtStartup', $ShowUpdateNotesAtStartup );

$IniFile->newval( 'PORT', 'Port', ExtractCom($w_Main->m_Port->Text()) );
$IniFile->newval( 'PORT', 'BaudRate', $Baudrate );

$IniFile->newval( 'PROTOCOL', 'MavlinkGuiComponentId', $MavlinkGuiComponentId );
$IniFile->newval( 'PROTOCOL', 'MavlinkDefaultSystemId', $MavlinkDefaultSystemId );
$IniFile->newval( 'PROTOCOL', 'MavlinkGimbalDefaultComponentId', $MavlinkGimbalDefaultComponentId );
$IniFile->newval( 'PROTOCOL', 'MavlinkComPorts', join(',',@MavlinkComPorts) );

$IniFile->newval( 'TIMING', 'ExecuteCmdTimeOutFirst', $ExecuteCmdTimeOutFirst );
$IniFile->newval( 'TIMING', 'ExecuteCmdTimeOut', $ExecuteCmdTimeOut );
$IniFile->newval( 'TIMING', 'MaxConnectionLost', $MaxConnectionLost );

$IniFile->newval( 'DIALOG', 'OptionInvalidColor', '0x'.sprintf("%06x",$OptionInvalidColor) );
$IniFile->newval( 'DIALOG', 'OptionValidColor', '0x'.sprintf("%06x",$OptionValidColor) );
$IniFile->newval( 'DIALOG', 'OptionModifiedColor', '0x'.sprintf("%06x",$OptionModifiedColor) );

$IniFile->newval( 'FLASH', 'Board', $f_Tab{flash}->flash_Board->Text() );
$IniFile->newval( 'FLASH', 'HexFileDir', $FirmwareHexFileDir );
$IniFile->newval( 'FLASH', 'Version', $f_Tab{flash}->flash_Version->Text() );
$IniFile->newval( 'FLASH', 'Stm32Programmer', $Storm32Programmer );
$IniFile->newval( 'FLASH', 'Stm32ProgrammerV3X', $Storm32ProgrammerV3X );
$IniFile->newval( 'FLASH', 'NtProgrammer', $NtProgrammer );
if( $f_Tab{flash}->flash_CheckNtVersions_check->Checked() ){ $CheckNtModuleVersions = 1; }else{ $CheckNtModuleVersions = 0; }
$IniFile->newval( 'FLASH', 'CheckNtModuleVersions', $CheckNtModuleVersions );
$IniFile->newval( 'FLASH', 'STM32CubeProgrammerPath', $STM32CubeProgrammerPath );

$IniFile->newval( 'LINKS', 'HelpLink', $HelpLink );
$IniFile->newval( 'LINKS', 'ConfigureGimbalStepIIHelpLink', $ConfigureGimbalStepIIHelpLink );

$IniFile->newval( 'PACKAGES', 'PackagesDir', $PackagesDir );

$IniFile->newval( 'BOARDCONFIGURATION','LastActiveConfiguration', $ActiveBoardConfiguration );

$IniFile->RewriteConfig();
undef $IniFile;
}


###############################################################################
###############################################################################
