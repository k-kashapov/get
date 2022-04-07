import RPi.GPIO as IO
import time

#================== <Setup> ===================
IO.setmode (IO.BCM)

dac_pins = [26, 19, 13, 6, 5, 11, 9, 10]
IO.setup (dac_pins, IO.OUT)

led_pins = [21, 20, 16, 12, 7, 8, 25, 24]
IO.setup (led_pins, IO.OUT, IO.PUD_OFF, IO.LOW)

troyka = 17
IO.setup (troyka, IO.OUT, IO.PUD_OFF, IO.HIGH)

comp_pin = 4
IO.setup (comp_pin, IO.IN)

#========== <Decimal to Binary function> ======
def DecToBin (num, arr_len):
    res = [0] * arr_len
    bit = 0
    while (num):
        res[arr_len - 1 - bit] = num & 1
        num >>= 1
        bit += 1

        if (bit >= arr_len): break

    if (num): print ('\nValue does not fit into', arr_len, 'bits')

    return res

#=========== <Integer to Bits> ================
def DecToBitMask (num, arr_len):
    return (DecToBin((1 << int (8.0 * num / (1 << arr_len)) + 1) - 1, arr_len))
    
#============ <Voltage to float> ==============
def V2F (int_voltage, max_voltage):
    return max_voltage * (int_voltage % 256) / 256

#=========== <Binary voltage search> =========
def adc ():
    top_volt = 255
    bot_volt = 0

    while top_volt - bot_volt > 1:
        mid_volt = int ((top_volt + bot_volt) / 2)
        IO.output (dac_pins, DecToBin (mid_volt, 8))

        time.sleep (0.001)
        
        cmp_res = IO.input (comp_pin)

        if cmp_res == 0:
            top_volt = mid_volt
        else:
            bot_volt = mid_volt
    
    return bot_volt

#================= <Main Loop> ================
try:
    while (True):
        curr_volt = adc()

        IO.output (led_pins, DecToBitMask (curr_volt, 8))

        print ('\rInput voltage = {:5.2f} V'.format (V2F (curr_volt, 3.3)), end = "")
      

except KeyboardInterrupt:
    print ('\n\nKeyboard interrupted\n')

#================== <Loop end> ================
finally:
    IO.output (dac_pins, 0)
    IO.output (troyka,   0)
    IO.cleanup()
