import RPi.GPIO as IO
import time

EPS = 1e-6
FREQ = 1000
pin = 24

IO.setmode (IO.BCM)
IO.setup (pin, IO.OUT)
pwmPin = IO.PWM (pin, FREQ)

pwmPin.start(0)

int_input = 0

try:
    while (True):
        val = input('\nEnter a number [0-100]: ')
        try:
            int_input = int (val)
            if int_input > 100:
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

        out_voltage = 3.3 * int_input / 100
        print ('Output voltage = {:5.2f} V'.format (out_voltage))
        pwmPin.start (int_input)


except KeyboardInterrupt:
    print ('\n\nKeyboard interrupted\n')

finally:
    pwmPin.stop()
    IO.output (pin, 0)
    IO.cleanup()
