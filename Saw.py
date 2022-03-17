import RPi.GPIO as IO
import time

IO.setmode (IO.BCM)
dac_pins = [26, 19, 13, 6, 5, 11, 9, 10]
IO.setup (dac_pins, IO.OUT)

def DecToBin (num, arr_len):
    res = [0] * arr_len
    bit = 0
    while (num):
        res[arr_len - 1 - bit] = num & 1
        num >>= 1
        bit += 1

        if (bit >= arr_len): break

    if (num): print ('Value does not fit into', arr_len, 'bits')

    return res

EPS = 1e-6
period = 0.5

try:
    while (True):
        for step in range (0, 255):
            IO.output (dac_pins, DecToBin (step, 8))
            time.sleep(period / 512)

        for step in range (254, 1, -1):
            IO.output (dac_pins, DecToBin (step, 8))
            time.sleep(period / 512)

except KeyboardInterrupt:
    print ('\n\nKeyboard interrupted\n')

finally:
    IO.output (dac_pins, 0)
    IO.cleanup()
