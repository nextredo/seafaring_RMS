#! /usr/bin/bash

# Change COM1 and COM2 in wine apps to ttyACM0 and ttyACM1 respectively
    # Necessary for connecting to the gimbal
cd ~/.wine/dosdevices/
ln -sf /dev/ttyACM0 com1
ln -sf /dev/ttyACM1 com2
ls ./com1 ./com2 -lah

# Run the gui tool in Wine :)
wine ~/Desktop/o323bgc-release-v096-v20160319/o323BGCTool_v096.exe
