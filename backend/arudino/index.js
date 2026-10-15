/**
 * arduino/ — reusable Arduino serial layer
 *
 * Drop this folder into any Node.js project. Zero project-specific dependencies.
 * Requires `serialport` npm package for real hardware (auto-detected or path-specified).
 *
 * Usage:
 *
 *   const { SerialManager } = require('./arudino');
 *
 *   const serial = new SerialManager({
 *     path: '',          // empty = auto-detect first Arduino-like USB device
 *     baudRate: 9600,
 *     mock: false,       // true = no hardware needed
 *     playerCount: 2,
 *     maxSpeed: 40,
 *     speedScale: 1,
 *   });
 *
 *   serial.on('speed', ({ player, speed, at }) => { ... });
 *   serial.on('status', (status) => { ... });
 *   serial.start();
 *
 * Works on Windows (COMx), Linux (/dev/ttyACM0, /dev/ttyUSB0) and macOS (/dev/tty.usbmodem*).
 */
const { SerialManager } = require('./serialManager');
const { parseLine, normalizeReading } = require('./parser');
const { MockRunner, PHASE_EFFORT } = require('./mockRunner');

module.exports = { SerialManager, parseLine, normalizeReading, MockRunner, PHASE_EFFORT };
