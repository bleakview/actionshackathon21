from machine import Pin, Timer,SPI, SoftI2C
from time import sleep_ms
import ubluetooth
import time
import machine
import micropython_dotstar as dotstar
#this code is based on work by
#https://github.com/mattytrentini/micropython-dotstar
#https://github.com/2black0/MicroPython-ESP32-BLE
#connect DI to esp32 port 13
#connect CI to esp32 port 12

striplength=60
spi = SPI(sck=Pin(12), mosi=Pin(13), miso=Pin(18)) # Configure SPI - note: miso is unused
dots = dotstar.DotStar(spi, striplength, brightness=0.2)
n_dots = len(dots)
class BLE():
    def __init__(self, name):
        self.name = name
        self.ble = ubluetooth.BLE()
        self.ble.active(True)

        self.led = Pin(2, Pin.OUT)
        self.timer1 = Timer(0)
        self.timer2 = Timer(1)

        self.disconnected()
        self.ble.irq(self.ble_irq)
        self.register()
        self.advertiser()

    def connected(self):
        self.timer1.deinit()
        self.timer2.deinit()

    def disconnected(self):
        self.timer1.init(period=1000, mode=Timer.PERIODIC, callback=lambda t: self.led(1))
        sleep_ms(200)
        self.timer2.init(period=1000, mode=Timer.PERIODIC, callback=lambda t: self.led(0))

    def ble_irq(self, event, data):
        if event == 1:
            '''Central disconnected'''
            self.connected()
            self.led(1)

        elif event == 2:
            '''Central disconnected'''
            self.advertiser()
            self.disconnected()

        elif event == 3:
            '''New message received'''
            buffer = self.ble.gatts_read(self.rx)
            message = buffer.decode('UTF-8').strip()
            print(message)
            command= message.split('_')[0]
            commandValue= message.split('_')[1]
            print(command)
            print(commandValue)
            if command == 'dial':
                print(command)
                status=int(commandValue)
                if(status==0):
                    for dot in range(striplength):
                        dots[dot] = (0, 0, 0)

                elif(145<status) and (status<=180):
                    for dot in range(striplength+1):
                        dots[dot] = (224, 0, 0)
                else :
                    to=(striplength*status)/144
                    for dot in range(0,int(to)):
                        dots[dot] = (0,224,0 )
                    for dot in range(int(to+1),striplength+1):
                        dots[dot] = (224, 224, 0)


    def register(self):
        # Nordic UART Service (NUS)
        NUS_UUID = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E'
        RX_UUID = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E'
        TX_UUID = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E'

        BLE_NUS = ubluetooth.UUID(NUS_UUID)
        BLE_RX = (ubluetooth.UUID(RX_UUID), ubluetooth.FLAG_WRITE)
        BLE_TX = (ubluetooth.UUID(TX_UUID), ubluetooth.FLAG_NOTIFY)

        BLE_UART = (BLE_NUS, (BLE_TX, BLE_RX,))
        SERVICES = (BLE_UART, )
        ((self.tx, self.rx,), ) = self.ble.gatts_register_services(SERVICES)

    def send(self, data):
        self.ble.gatts_notify(0, self.tx, data + '\n')

    def advertiser(self):
        name = bytes(self.name, 'UTF-8')
        self.ble.gap_advertise(100, bytearray('\x02\x01\x02') + bytearray((len(name) + 1, 0x09)) + name)

# test
ble = BLE("GITHUB_ACTION_IOT")