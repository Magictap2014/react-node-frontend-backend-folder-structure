FROM node:24-alpine AS builder

WORKDIR /app

COPY package*.json ./

RUN npm ci 

FROM node:24-alpine

RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001

WORKDIR /app

COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --chown=nodejs:nodejs . .

USER nodejs

EXPOSE 5000

CMD ["npm", "run", "dev"]