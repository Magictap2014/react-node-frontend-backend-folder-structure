// Prints every serial port the OS can see, to find the value for DIGIRUN_SERIAL_PORT (e.g. COM3, /dev/ttyACM0).
const { SerialPort } = require('serialport');

SerialPort.list()
  .then((ports) => {
    if (!ports.length) return console.log('No serial ports found. Is the Arduino plugged in?');
    for (const p of ports) {
      console.log(`${p.path.padEnd(16)} ${p.manufacturer || ''} ${p.friendlyName || ''} vid=${p.vendorId || '-'} pid=${p.productId || '-'}`);
    }
  })
  .catch((err) => {
    console.error('Could not list ports:', err.message);
    process.exit(1);
  });
