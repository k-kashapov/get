import RPi.GPIO as IO

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

try:
    while (True):
        val = input('\nEnter a number [0-255]: ')
        try:
            int_input = int (val)
            if int_input > 255:
                print ('Value does not fit into 8 bits')
                continue

            if int_input < 0:
                print ('\nIncorrect value: less than zero')
                continue

        except ValueError:
            if val == 'q':
                print ('Quit the program')
                break

            print ('Incorrect value type')
            continue

        IO.output (dac_pins, DecToBin (int_input, 8))
        out_voltage = 3.3 * (int_input % 256) / 256
        print ('Output voltage = {:5.2f} V'.format (out_voltage))

except KeyboardInterrupt:
    print ('\n\nKeyboard interrupted\n')

finally:
    IO.output (dac_pins, 0)
    IO.cleanup()
