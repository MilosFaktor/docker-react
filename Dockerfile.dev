FROM node:20-alpine3.23

WORKDIR /app

COPY package.json .
RUN npm install
COPY . .

CMD ["npm", "run", "start"]