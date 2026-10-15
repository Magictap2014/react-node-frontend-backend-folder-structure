const { EventEmitter } = require('events');
const { parseLine } = require('./parser');
const { MockRunner } = require('./mockRunner');

// USB vendor IDs of common Arduino boards and the USB-serial chips used on clones.
const ARDUINO_VENDOR_IDS = ['2341', '2a03', '1a86', '0403', '10c4', '239a'];

/**
 * Manages the Arduino serial connection (or a mock runner that replaces it).
 * Works on Windows, Linux and macOS with any architecture — the underlying
 * `serialport` npm package handles OS/arch differences at install time.
 *
 * Events:
 *   'speed'  -> { player, speed, at }   one normalised reading per player per tick
 *   'status' -> getStatus()             emitted whenever the connection state changes
 *
 * @param {object}  options
 * @param {string}  [options.path='']           Serial port path. Empty = auto-detect.
 * @param {number}  [options.baudRate=9600]
 * @param {number}  [options.reconnectMs=3000]  Delay before retrying after a disconnect.
 * @param {boolean} [options.mock=false]        Skip hardware; use MockRunner instead.
 * @param {number}  [options.playerCount=2]     Forwarded to parser and mock runner.
 * @param {number}  [options.maxSpeed=40]       Forwarded to parser (km/h clamp).
 * @param {number}  [options.speedScale=1]      Forwarded to parser (calibration multiplier).
 * @param {number}  [options.mockIntervalMs=100] Forwarded to MockRunner.
 */
class SerialManager extends EventEmitter {
  constructor(options = {}) {
    super();
    this.path = options.path ?? '';
    this.baudRate = options.baudRate ?? 9600;
    this.reconnectMs = options.reconnectMs ?? 3000;
    this.mock = options.mock ?? false;
    this.parserOptions = {
      playerCount: options.playerCount ?? 2,
      maxSpeed: options.maxSpeed ?? 40,
      scale: options.speedScale ?? 1,
    };
    this.mockIntervalMs = options.mockIntervalMs ?? 100;

    this.port = null;
    this.mockRunner = null;
    this.reconnectTimer = null;
    this.stopped = true;
    this.status = {
      mode: this.mock ? 'mock' : 'serial',
      connected: false,
      port: null,
      baudRate: this.baudRate,
      error: null,
      lastDataAt: null,
    };
  }

  getStatus() {
    return { ...this.status };
  }

  setStatus(patch) {
    this.status = { ...this.status, ...patch };
    this.emit('status', this.getStatus());
  }

  start() {
    this.stopped = false;
    if (this.mock) this._startMock();
    else this._connectSerial();
  }

  stop() {
    this.stopped = true;
    clearTimeout(this.reconnectTimer);
    this.reconnectTimer = null;
    this._stopMock();
    this._closeSerial();
  }

  /** Switch between mock and real hardware at runtime without restarting the process. */
  setMockMode(enabled) {
    const next = Boolean(enabled);
    if (next === this.mock) return;
    this.stop();
    this.mock = next;
    this.setStatus({ mode: next ? 'mock' : 'serial', connected: false, port: null, error: null });
    this.start();
  }

  /** Forward the current game phase so the mock runner adjusts simulated effort. */
  setGamePhase(phase) {
    this.mockRunner?.setPhase(phase);
  }

  _handleLine(line) {
    const readings = parseLine(line, this.parserOptions);
    if (!readings.length) return;
    const at = Date.now();
    this.status.lastDataAt = at;
    for (const reading of readings) this.emit('speed', { ...reading, at });
  }

  // ── mock ──────────────────────────────────────────────────────────────────

  _startMock() {
    this.mockRunner = new MockRunner({
      onLine: (line) => this._handleLine(line),
      intervalMs: this.mockIntervalMs,
      playerCount: this.parserOptions.playerCount,
    });
    this.mockRunner.start();
    this.setStatus({ mode: 'mock', connected: true, port: 'MOCK', error: null });
    console.log('[SerialManager] MOCK mode: simulating runner speeds');
  }

  _stopMock() {
    this.mockRunner?.stop();
    this.mockRunner = null;
  }

  // ── hardware ──────────────────────────────────────────────────────────────

  _loadSerialport() {
    try {
      return require('serialport');
    } catch (err) {
      this.setStatus({ connected: false, error: `serialport module unavailable: ${err.message}` });
      return null;
    }
  }

  async _resolvePath(SerialPort) {
    if (this.path) return this.path;
    const ports = await SerialPort.list();
    const match =
      ports.find((p) => ARDUINO_VENDOR_IDS.includes(String(p.vendorId || '').toLowerCase())) ||
      ports.find((p) => /arduino|ch340|usb.?serial/i.test(`${p.manufacturer} ${p.friendlyName}`));
    return match?.path ?? null;
  }

  async _connectSerial() {
    if (this.stopped || this.mock) return;
    const lib = this._loadSerialport();
    if (!lib) return this._scheduleReconnect();
    const { SerialPort, ReadlineParser } = lib;

    let path;
    try {
      path = await this._resolvePath(SerialPort);
    } catch (err) {
      this.setStatus({ connected: false, error: `Could not list serial ports: ${err.message}` });
      return this._scheduleReconnect();
    }
    if (!path) {
      this.setStatus({ connected: false, port: null, error: 'No Arduino found. Set the port path in options.' });
      return this._scheduleReconnect();
    }

    const port = new SerialPort({ path, baudRate: this.baudRate, autoOpen: false });
    this.port = port;

    port.open((err) => {
      if (err) {
        this.port = null;
        this.setStatus({ connected: false, port: path, error: err.message });
        return this._scheduleReconnect();
      }
      console.log(`[SerialManager] connected to ${path} @ ${this.baudRate} baud`);
      this.setStatus({ connected: true, port: path, error: null });
    });

    const parser = port.pipe(new ReadlineParser({ delimiter: '\n' }));
    parser.on('data', (line) => this._handleLine(line));
    port.on('error', (err) => this.setStatus({ connected: false, error: err.message }));
    port.on('close', () => {
      if (this.port !== port) return;
      this.port = null;
      console.warn('[SerialManager] port closed, retrying...');
      this.setStatus({ connected: false, error: 'Serial port closed (cable unplugged?)' });
      this._scheduleReconnect();
    });
  }

  _closeSerial() {
    const port = this.port;
    this.port = null;
    if (port?.isOpen) port.close(() => {});
  }

  _scheduleReconnect() {
    if (this.stopped || this.mock || this.reconnectTimer) return;
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      this._connectSerial();
    }, this.reconnectMs);
  }
}

module.exports = { SerialManager };
