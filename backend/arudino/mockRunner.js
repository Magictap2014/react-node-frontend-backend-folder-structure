// How hard the simulated runners push in each game phase (fraction of their race pace).
const PHASE_EFFORT = {
  IDLE: 0,
  READY: 0.25,
  COUNTDOWN: 0.45,
  RUNNING: 1,
  FINISHED: 0.1,
};

function randomBetween(min, max) {
  return min + Math.random() * (max - min);
}

/**
 * Simulates N people on running platforms.
 * Produces the exact line format the Arduino sends ("PLAYER1:12.4") so mock data
 * travels through the same parser as real hardware.
 *
 * @param {object}   options
 * @param {Function} options.onLine          Called with each simulated serial line.
 * @param {number}   [options.intervalMs=100] Tick rate in ms (matches Arduino sample rate).
 * @param {number}   [options.playerCount=2]  Number of simulated runners.
 */
class MockRunner {
  constructor({ onLine, intervalMs = 100, playerCount = 2 } = {}) {
    this.onLine = onLine;
    this.intervalMs = intervalMs;
    this.phase = 'READY';
    this.timer = null;
    this.runners = Array.from({ length: playerCount }, (_, i) => ({
      id: i + 1,
      pace: randomBetween(10, 15),
      speed: 0,
    }));
  }

  /** Update the game phase so simulated effort matches the real race state. */
  setPhase(phase) {
    if (!(phase in PHASE_EFFORT) || phase === this.phase) return;
    if (phase === 'COUNTDOWN') {
      this.runners.forEach((r) => { r.pace = randomBetween(10, 15); });
    }
    this.phase = phase;
  }

  tick() {
    const effort = PHASE_EFFORT[this.phase] ?? 0;
    for (const runner of this.runners) {
      const target = runner.pace * effort;
      runner.speed += (target - runner.speed) * 0.15;
      let reading = runner.speed + randomBetween(-1.2, 1.2) * effort;
      if (effort > 0 && Math.random() < 0.03) reading *= 0.4;
      reading = Math.max(0, reading);
      this.onLine?.(`PLAYER${runner.id}:${reading.toFixed(1)}`);
    }
  }

  start() {
    if (this.timer) return;
    this.timer = setInterval(() => this.tick(), this.intervalMs);
  }

  stop() {
    clearInterval(this.timer);
    this.timer = null;
  }
}

module.exports = { MockRunner, PHASE_EFFORT };
