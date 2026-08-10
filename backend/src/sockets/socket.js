const { Server } = require('socket.io');
const env = require('../config/env');

const DEFAULT_ROOM = 'puzzle-room';

function initSocket(httpServer) {
  const io = new Server(httpServer, {
    cors: { origin: env.CORS_ORIGIN },
  });

  const puzzleNamespace = io.of('/puzzle');

  puzzleNamespace.on('connection', (socket) => {
    socket.on('join_room', (data) => {
      const room = data?.room || DEFAULT_ROOM;
      socket.join(room);
      socket.data.room = room;
    });
  });

  return io;
}

module.exports = initSocket;
