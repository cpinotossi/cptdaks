FROM node:14-alpine
ENV PORTHTTP=8080 PORTSSL=4040 SCOLOR=green
RUN apk --no-cache add curl nano
WORKDIR /usr/src/app
COPY ["package.json", "package-lock.json*", "./"]
RUN npm install --silent && mv node_modules ../
COPY . .
EXPOSE ${PORTHTTP}
RUN chown -R node /usr/src/app
USER node
CMD ["npm", "start"]