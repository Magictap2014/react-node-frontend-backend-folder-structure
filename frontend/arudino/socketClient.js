import { io } from 'socket.io-client';

/**
 * Creates a Socket.io connection to the Arduino/race backend namespace.
 * Framework-agnostic — works in plain JS, React, Vue, Svelte, etc.
 *
 * The connection is deferred by one tick so React StrictMode's double-mount
 * in dev never opens (and immediately aborts) a WebSocket.
 *
 * @param {object} options
 * @param {string} options.url              Full namespace URL, e.g. "http://localhost:8000/race".
 * @param {string} [options.role='display'] 'display' or 'operator'.
 * @param {string} [options.key='']         Operator key (passed in socket handshake auth).
 * @returns {{ socket: import('socket.io-client').Socket, dispose: Function }}
 *
 * @example
 *   const { socket, dispose } = createArduinoSocket({
 *     url: 'http://localhost:8000/race',
 *     role: 'display',
 *   });
 *   socket.on('runner:speed', ({ player, speed }) => console.log(player, speed));
 *   // later:
 *   dispose();
 */
export function createArduinoSocket({ url, role = 'display', key = '' }) {
  const socket = io(url, {
    auth: { role, key },
    transports: ['websocket', 'polling'],
    reconnectionDelay: 500,
    reconnectionDelayMax: 3000,
    autoConnect: false,
  });
  const timer = setTimeout(() => socket.connect(), 0);
  const dispose = () => {
    clearTimeout(timer);
    socket.disconnect();
  };
  return { socket, dispose };
}
