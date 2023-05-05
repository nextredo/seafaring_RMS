# Log from GUI

- To help reverse engineer packets

```text
Please do first a read to get controller settings!

Connecting... Please wait!
v... v0.96
CONNECTED
Read... Please wait!
g... ok
100 -> Gyro LPF: 1 (0x0001)
99 -> Imu2 FeedForward LPF: 1 (0x0001)
18 -> Low Voltage Limit: 1 (0x0001)
19 -> Voltage Correction: 0 (0x0000)
00 -> Pitch P: 310 (0x0136)
01 -> Pitch I: 1750 (0x06D6)
02 -> Pitch D: 200 (0x00C8)
03 -> Pitch Motor Vmax: 89 (0x0059)
06 -> Roll P: 460 (0x01CC)
07 -> Roll I: 1250 (0x04E2)
08 -> Roll D: 450 (0x01C2)
09 -> Roll Motor Vmax: 98 (0x0062)
12 -> Yaw P: 640 (0x0280)
13 -> Yaw I: 2100 (0x0834)
14 -> Yaw D: 950 (0x03B6)
15 -> Yaw Motor Vmax: 77 (0x004D)
65 -> Pan Mode Control: 7 (0x0007)
66 -> Pan Mode Default Setting: 1 (0x0001)
67 -> Pan Mode Setting #1: 2 (0x0002)
68 -> Pan Mode Setting #2: 6 (0x0006)
69 -> Pan Mode Setting #3: 6 (0x0006)
04 -> Pitch Pan (0 = hold): 20 (0x0014)
05 -> Pitch Pan Deadband: 30 (0x001E)
102 -> Pitch Pan Expo: 0 (0x0000)
10 -> Roll Pan (0 = hold): 20 (0x0014)
11 -> Roll Pan Deadband: 30 (0x001E)
103 -> Roll Pan Expo: 0 (0x0000)
16 -> Yaw Pan (0 = hold): 39 (0x0027)
17 -> Yaw Pan Deadband: 40 (0x0028)
104 -> Yaw Pan Expo: 0 (0x0000)
118 -> Yaw Pan Deadband LPF: 0 (0x0000)
97 -> Yaw Pan Deadband Hysteresis: 0 (0x0000)
43 -> Rc Dead Band: 10 (0x000A)
105 -> Rc Hysteresis: 5 (0x0005)
46 -> Rc Pitch Trim: 0 (0x0000)
53 -> Rc Roll Trim: 0 (0x0000)
60 -> Rc Yaw Trim: 0 (0x0000)
44 -> Rc Pitch: 4 (0x0004)
45 -> Rc Pitch Mode: 0 (0x0000)
47 -> Rc Pitch Min: 64586 (0xFC4A)
48 -> Rc Pitch Max: 950 (0x03B6)
49 -> Rc Pitch Speed Limit (0 = off): 400 (0x0190)
50 -> Rc Pitch Accel Limit (0 = off): 300 (0x012C)
51 -> Rc Roll: 5 (0x0005)
52 -> Rc Roll Mode: 0 (0x0000)
54 -> Rc Roll Min: 65286 (0xFF06)
55 -> Rc Roll Max: 250 (0x00FA)
56 -> Rc Roll Speed Limit (0 = off): 400 (0x0190)
57 -> Rc Roll Accel Limit (0 = off): 300 (0x012C)
58 -> Rc Yaw: 6 (0x0006)
59 -> Rc Yaw Mode: 0 (0x0000)
61 -> Rc Yaw Min: 64586 (0xFC4A)
62 -> Rc Yaw Max: 950 (0x03B6)
63 -> Rc Yaw Speed Limit (0 = off): 400 (0x0190)
64 -> Rc Yaw Accel Limit (0 = off): 300 (0x012C)
70 -> Standby: 0 (0x0000)
76 -> Re-center Camera: 0 (0x0000)
71 -> IR Camera Control: 0 (0x0000)
72 -> Camera Model: 0 (0x0000)
73 -> IR Camera Setting #1: 0 (0x0000)
74 -> IR Camera Setting #2: 2 (0x0002)
75 -> Time Interval (0 = off): 0 (0x0000)
113 -> Pwm Out Control: 0 (0x0000)
114 -> Pwm Out Mid: 1500 (0x05DC)
115 -> Pwm Out Min: 1100 (0x044C)
116 -> Pwm Out Max: 1900 (0x076C)
117 -> Pwm Out Speed Limit (0 = off): 0 (0x0000)
120 -> Script1 Control: 0 (0x0000)
121 -> Script2 Control: 0 (0x0000)
122 -> Script3 Control: 0 (0x0000)
123 -> Script4 Control: 0 (0x0000)
124 -> Scripts: script hex code
94 -> Imu2 Configuration: 1 (0x0001)
88 -> Acc Compensation Method: 1 (0x0001)
81 -> Imu AHRS: 1000 (0x03E8)
41 -> Virtual Channel Configuration: 0 (0x0000)
42 -> Pwm Out Configuration: 0 (0x0000)
106 -> Rc Pitch Offset: 0 (0x0000)
107 -> Rc Roll Offset: 0 (0x0000)
108 -> Rc Yaw Offset: 0 (0x0000)
98 -> Beep with Motors: 1 (0x0001)
78 -> Pitch Motor Usage: 0 (0x0000)
79 -> Roll Motor Usage: 0 (0x0000)
80 -> Yaw Motor Usage: 0 (0x0000)
39 -> Imu Orientation: 14 (0x000E)
95 -> Imu2 Orientation: 1 (0x0001)
20 -> Pitch Motor Poles: 14 (0x000E)
21 -> Pitch Motor Direction: 0 (0x0000)
23 -> Pitch Startup Motor Pos: 185 (0x00B9)
22 -> Pitch Offset: 0 (0x0000)
26 -> Roll Motor Poles: 14 (0x000E)
27 -> Roll Motor Direction: 0 (0x0000)
29 -> Roll Startup Motor Pos: 268 (0x010C)
28 -> Roll Offset: 0 (0x0000)
32 -> Yaw Motor Poles: 14 (0x000E)
33 -> Yaw Motor Direction: 1 (0x0001)
35 -> Yaw Startup Motor Pos: 370 (0x0172)
34 -> Yaw Offset: 0 (0x0000)
85 -> Acc LPF: 2 (0x0002)
86 -> Imu DLPF: 0 (0x0000)
96 -> Rc Adc LPF: 0 (0x0000)
87 -> Hold To Pan Transition Time: 250 (0x00FA)
84 -> Imu Acc Threshold (0 = off): 25 (0x0019)
89 -> Acc Noise Level: 40 (0x0028)
90 -> Acc Threshold (0 = off): 50 (0x0032)
91 -> Acc Vertical Weight: 25 (0x0019)
92 -> Acc Zentrifugal Correction: 30 (0x001E)
93 -> Acc Recover Time: 250 (0x00FA)
40 -> Motor Mapping: 0 (0x0000)
109 -> Imu Mapping: 0 (0x0000)
101 -> ADC Calibration: 1550 (0x060E)
77 -> NT Logging: 0 (0x0000)
38 -> Imu3 Configuration: 0 (0x0000)
83 -> Imu3 Orientation: 0 (0x0000)
112 -> Mavlink Configuration: 0 (0x0000)
110 -> Mavlink System ID: 71 (0x0047)
111 -> Mavlink Component ID: 67 (0x0043)
Read... DONE!

Get Status... Please wait!
s... ok
  IMU is PRESENT @ LOW ADR
  IMU2 is PRESENT @ LOW ADR = external IMU
  MAG is not available
  STorM32-LINK is not available
  STATE is NORMAL
  BAT is not connected, VOLTAGE is LOW: 0.00 V
Get Status... DONE!

Get Parameter // getting param with ID 0
FA020300003334
FB040300003601EBF6 LEN:4 COUNT:9 CRC:F6EB CRC2:0x0000!

Get Parameter // id 5
FA020305003334
FB040305001E00C664 LEN:4 COUNT:9 CRC:64C6 CRC2:0x0000!

Get Parameter // id 50
FA020338003334
FB040338009001EEA4 LEN:4 COUNT:9 CRC:A4EE CRC2:0x0000!

Get Version
FA00013334
FB060160005F0003FFA63B LEN:6 COUNT:11 CRC:3BA6 CRC2:0x0000!

Get Data
FA0105003334
FB42050000060070900000000000003C63DC050500030004005BF05DFE271CF6ECE6FD1022630BD1FED3FE0000000000000000000000007800890040D80000AA05983A0000531E LEN:66 COUNT:71 CRC:1E53 CRC2:0x0000!

```
