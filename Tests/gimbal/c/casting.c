/* File to test bit transformations during casting
 * As an effort to understand how data is encoded in packets received from the gimbal
 * https://www.h-schmidt.net/FloatConverter/IEEE754.html
 */
#include <stdio.h>
#include <limits.h>

#define u16 unsigned short int // format spec. %hu
#define s16   signed short int // format spec. %hi or %hd

int main()
{
    // Simulated angle
    float sampleAngle = -32.2546386719;
    // 0b01000010000000010000010011000000
    // 0x420104c0

    // Intermediate storage for debugging
    float sampleAngle100x = 0;
    s16   outBufDataSnippet = 0;

    // Operation as a whole
    // (s16)(100.0f*sampleAngle);

    // Operation by parts
    printf("Original angle --> %f\n", sampleAngle);

    sampleAngle100x = (100.0f*sampleAngle);
    printf("100x angle --> %f\n", sampleAngle100x);

    outBufDataSnippet = (s16)sampleAngle100x;
    printf("cast angle --> %hd\n", outBufDataSnippet);

    return 0;
}

/* Notes
 * Take angle (presumably in range [0, 360))
 * x100
 * Cast to 16-bit int (truncate decimal places)
 * * s16 has range:
 * * = [SHRT_MIN     , SHRT_MAX]
 * * = [-SHRT_MAX - 1, SHRT_MAX]
 * * = [0x8FFE       , 0x7FFF]
 */

/* Notes 2
 * Angle [0, 360]
 */
