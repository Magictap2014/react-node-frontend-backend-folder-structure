# Jigsaw Puzzle Backend

Express + MongoDB (Mongoose) + Socket.io API.

## Setup

```bash
npm install
cp .env.example .env   # fill in MONGODB_URI, AWS_* credentials, etc.
npm run dev
```

## Structure

- `src/config` — env, database, and S3 client setup
- `src/controllers` — request handlers
- `src/middleware` — Express middleware (error handling, auth, etc.)
- `src/models` — Mongoose schemas
- `src/routes` — Express routers
- `src/services` — business logic used by controllers/sockets
- `src/sockets` — Socket.io namespace/event setup
- `src/utils` — shared helpers
- `src/validators` — request payload validation
- `tests` — backend tests
