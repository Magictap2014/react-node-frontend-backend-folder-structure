// Format 1 (firmware target): "PLAYER1:12.4"
const READING_RE = /^\s*(?:PLAYER|P)\s*(\d+)\s*[:=]\s*(-?\d+(?:\.\d+)?)\s*$/i;

// Format 2 (current hardware): "{p1,p2}" or "p1,p2" — pulse counts for both players on one line.
const PULSE_PAIR_RE = /^\s*\{?\s*(\d+)\s*,\s*(\d+)\s*\}?\s*$/;

/**
 * Clamp/round a raw value into a normalised { player, speed } payload.
 *
 * @param {number|string} player   1-based player index from the Arduino line.
 * @param {number|string} rawSpeed Raw speed value from the Arduino.
 * @param {object}        options
 * @param {number}        [options.playerCount=2]   Maximum valid player index.
 * @param {number}        [options.maxSpeed=40]     Values are clamped to this (km/h).
 * @param {number}        [options.scale=1]         Multiplied before clamping (calibration).
 * @returns {{ player: number, speed: number } | null}
 */
function normalizeReading(player, rawSpeed, options = {}) {
  const playerCount = options.playerCount ?? 2;
  const maxSpeed = options.maxSpeed ?? 40;
  const scale = options.scale ?? 1;

  const id = Number(player);
  const value = Number(rawSpeed) * scale;
  if (!Number.isInteger(id) || id < 1 || id > playerCount) return null;
  if (!Number.isFinite(value)) return null;

  const speed = Math.min(Math.max(value, 0), maxSpeed);
  return { player: id, speed: Math.round(speed * 100) / 100 };
}

/**
 * Parse one line from the Arduino serial output.
 * Supports two formats:
 *   Format 1: "PLAYER1:12.4" or "PLAYER1:12.4,PLAYER2:9.8" (target firmware)
 *   Format 2: "{p1,p2}" or "p1,p2" — raw pulse counts, converted to km/h
 *
 * @param {string} line    Raw line from the serial port.
 * @param {object} options
 * @param {number} [options.intervalMs=100]         Arduino send interval in ms (for pulse->km/h).
 * @param {number} [options.circumference=0.20]     Roller circumference in metres.
 * @param {number} [options.pulsesPerRev=1]         Pulses per roller revolution.
 * @returns {Array<{ player: number, speed: number }>}
 */
function parseLine(line, options = {}) {
  if (typeof line !== 'string') return [];

  // Format 2: "{p1,p2}" or "p1,p2"
  const pairMatch = PULSE_PAIR_RE.exec(line);
  if (pairMatch) {
    const intervalMs = options.intervalMs ?? 100;
    const circumference = options.circumference ?? 0.20;
    const pulsesPerRev = options.pulsesPerRev ?? 1;
    const toKmh = (pulses) => {
      const meters = (pulses / pulsesPerRev) * circumference;
      return (meters / (intervalMs / 1000)) * 3.6;
    };
    return [pairMatch[1], pairMatch[2]]
      .map((pulses, i) => normalizeReading(i + 1, toKmh(Number(pulses)), options))
      .filter(Boolean);
  }

  // Format 1: "PLAYER1:12.4"
  return line
    .split(/[,;|]/)
    .map((chunk) => READING_RE.exec(chunk))
    .filter(Boolean)
    .map((match) => normalizeReading(match[1], match[2], options))
    .filter(Boolean);
}

module.exports = { parseLine, normalizeReading };
