FROM alpine:3.14

# утсанавливаем bash, nodejs и npm
RUN apk add --no-cache bash nodejs npm

# установка статического веб сервера
RUN npm install -g http-server

WORKDIR /var/www

COPY script.sh /usr/local/bin/script.sh
RUN chmod +x /usr/local/bin/script.sh

CMD ["/bin/bash", "-c", "/usr/local/bin/script.sh & exec http-server -p 8080"]

