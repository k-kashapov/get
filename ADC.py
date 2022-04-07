import RPi.GPIO as IO
import time

#================== <Setup> ===================
IO.setmode (IO.BCM)

dac_pins = [26, 19, 13, 6, 5, 11, 9, 10]
IO.setup (dac_pins, IO.OUT)

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

    if (num): print ('Value does not fit into', arr_len, 'bits')

    return res

#============ <Voltage to float> ==============
def V2F (int_voltage, max_voltage):
    return max_voltage * (int_voltage % 256) / 256

#=========== <Linear voltage search> =========
def adc ():
    curr_volt = 0

    while curr_volt < 255:
        IO.output (dac_pins, DecToBin (curr_volt, 8))
        time.sleep (0.001)
        
        cmp_res = IO.input (comp_pin)

        if cmp_res == 0: break
        curr_volt += 1
    
    return curr_volt

#================= <Main Loop> ================
try:
    while (True):
        curr_volt = adc()
        print ('\rInput voltage = {:5.2f} V'.format (V2F (curr_volt, 3.3)), end = "")
      

except KeyboardInterrupt:
    print ('\n\nKeyboard interrupted\n')

#================== <Loop end> ================
finally:
    IO.output (dac_pins, 0)
    IO.output (troyka,   0)
    IO.cleanup()
