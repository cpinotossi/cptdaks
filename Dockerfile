FROM node:14-alpine
ENV PORT=8080 SCOLOR=green
RUN apk --no-cache add curl nano
WORKDIR /usr/src/app
COPY ["package.json", "package-lock.json*", "npm-shrinkwrap.json*", "./"]
RUN npm install --production --silent && mv node_modules ../
COPY . .
EXPOSE ${PORT}
RUN chown -R node /usr/src/app
USER node
CMD ["npm", "start"]
