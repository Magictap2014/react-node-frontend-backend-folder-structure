/**
 * Socket.io event names shared between the backend and every frontend client.
 * Import this wherever you need to listen to or emit Arduino-related events.
 */
export const SOCKET_EVENTS = Object.freeze({
  RUNNER_SPEED: 'runner:speed',   // server -> client  { player, speed, at }
  SERIAL_STATUS: 'serial:status', // server -> client  { mode, connected, port, error, lastDataAt }
  GAME_COMMAND: 'game:command',   // bidirectional     { action, payload }
  GAME_STATE: 'game:state',       // display -> server -> operator
  GAME_PROGRESS: 'game:progress', // display -> server -> operator
});
