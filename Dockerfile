FROM node:20-alpine3.23 AS builder

WORKDIR /app

COPY package.json .
RUN npm install
COPY . .

RUN npm run build

FROM nginx:alpine
EXPOSE 80
COPY --from=builder /app/build /usr/share/nginx/html

# dont need CMD because its default in NGNINX