/* Snippet of C code for the gimbal firmware
 * Since firmware isn't open source, this is all you're getting
 * For v0.96
 */

#include <stdio.h>
#include <math.h>

#define u16 unsigned short int
#define s16   signed short int

// send 32 data values
uart_prepare_transmit();
((u16*)fbuf)[(*len)++]= STATE; //state
((u16*)fbuf)[(*len)++]= status; //status
((u16*)fbuf)[(*len)++]= status2; //status2
((u16*)fbuf)[(*len)++]= i2c_geterrorcntofdevice(IMU_I2CDEVNR)+i2c_geterrorcntofdevice(IMU2_I2CDEVNR);
((u16*)fbuf)[(*len)++]= adc_lipovoltage(); //lipo_voltage;
((u16*)fbuf)[(*len)++]= (u16)systicks; //timestamp
((u16*)fbuf)[(*len)++]= (u16)(1.0E6*fdT); //cycle time
((u16*)fbuf)[(*len)++]= (s16)(fImu1.imu.gx);
((u16*)fbuf)[(*len)++]= (s16)(fImu1.imu.gy);
((u16*)fbuf)[(*len)++]= (s16)(fImu1.imu.gz);
((u16*)fbuf)[(*len)++]= (s16)(10000.0f*fImu1.imu.ax);
((u16*)fbuf)[(*len)++]= (s16)(10000.0f*fImu1.imu.ay);
((u16*)fbuf)[(*len)++]= (s16)(10000.0f*fImu1.imu.az);
((u16*)fbuf)[(*len)++]= (s16)(10000.0f*fImu1AHRS.R.x);
((u16*)fbuf)[(*len)++]= (s16)(10000.0f*fImu1AHRS.R.y);
((u16*)fbuf)[(*len)++]= (s16)(10000.0f*fImu1AHRS.R.z);
((u16*)fbuf)[(*len)++]= (s16)(100.0f*fImu1Angle.Pitch);
((u16*)fbuf)[(*len)++]= (s16)(100.0f*fImu1Angle.Roll);
((u16*)fbuf)[(*len)++]= (s16)(100.0f*fImu1Angle.Yaw);
((u16*)fbuf)[(*len)++]= (s16)(100.0f*cPID[PITCH].Cntrl);
((u16*)fbuf)[(*len)++]= (s16)(100.0f*cPID[ROLL].Cntrl);
((u16*)fbuf)[(*len)++]= (s16)(100.0f*cPID[YAW].Cntrl);
((u16*)fbuf)[(*len)++]= InputSrc.Pitch;
((u16*)fbuf)[(*len)++]= InputSrc.Roll;
((u16*)fbuf)[(*len)++]= InputSrc.Yaw;
((u16*)fbuf)[(*len)++]= (s16)(100.0f*fImu2Angle.Pitch);
((u16*)fbuf)[(*len)++]= (s16)(100.0f*fImu2Angle.Roll);
((u16*)fbuf)[(*len)++]= (s16)(100.0f*fImu2Angle.Yaw);
((u16*)fbuf)[(*len)++]= (s16)(100.0f*fMag2Angle.Yaw);
((u16*)fbuf)[(*len)++]= (s16)(100.0f*fMag2Angle.Pitch);
((u16*)fbuf)[(*len)++]= (s16)(10000.0f*fImu1AHRS._imu_acc_confidence);
((u16*)fbuf)[(*len)++] = pack_functioninputvalues(&FunctionInputPulse);
(*len)*=2;
//add crc
uint16_t crc= do_crc( fbuf, fbuf_len );
fbuf[fbuf_len++]= (u8)crc; //low byte
fbuf[fbuf_len++]= (u8)(crc>>8); //high byte
//end character
uart_transmit_ackchar( closewith ); //this sends a 'o'
