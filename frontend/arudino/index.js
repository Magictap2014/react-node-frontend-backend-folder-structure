/**
 * arudino/ — reusable Arduino socket layer for any frontend project.
 *
 * Drop this folder into any Vite/webpack/etc. project that uses socket.io-client.
 * Zero project-specific dependencies.
 *
 * Usage:
 *
 *   import { createArduinoSocket, SOCKET_EVENTS } from './arudino';
 *
 *   const { socket, dispose } = createArduinoSocket({
 *     url: 'http://localhost:8000/race',
 *     role: 'display',   // or 'operator'
 *     key: '',           // operator key if DIGIRUN_OPERATOR_KEY is set on the backend
 *   });
 *
 *   socket.on(SOCKET_EVENTS.RUNNER_SPEED, ({ player, speed, at }) => { ... });
 *   socket.on(SOCKET_EVENTS.SERIAL_STATUS, (status) => { ... });
 *
 *   // cleanup
 *   dispose();
 */
export { createArduinoSocket } from './socketClient';
export { SOCKET_EVENTS } from './events';
