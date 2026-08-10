import { io, Socket } from 'socket.io-client';

const SOCKET_URL = import.meta.env.VITE_SOCKET_URL || 'http://localhost:8000';

let socket: Socket | null = null;

export const socketService = {
  connect(page?: string) {
    if (!socket) {
      socket = io(`${SOCKET_URL}/puzzle`, {
        transports: ['websocket'],
        upgrade: false,
        autoConnect: true,
        reconnection: true,
        reconnectionAttempts: Infinity,
        reconnectionDelay: 1000,
        auth: { page },
      });

      socket.on('connect', () => {
        console.log(`Socket connected from ${page || 'unknown'}`);
      });

      socket.on('disconnect', () => {
        console.log(`Socket disconnected from ${page || 'unknown'}`);
      });
    }
    return socket;
  },

  joinRoom(room: string) {
    socket?.emit('join_room', { room });
  },

  disconnect() {
    socket?.disconnect();
    socket = null;
  },
};
