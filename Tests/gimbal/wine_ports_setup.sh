#! /usr/bin/bash

# Script to change COM1 and COM2 in wine apps to ttyACM0 and ttyACM1 respectively in wine apps

cd ~/.wine/dosdevices/
ln -sf /dev/ttyACM0 com1
ln -sf /dev/ttyACM1 com2
ls ./com1 ./com2 -lah
