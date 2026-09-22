FROM alpine:3.14
RUN apk add --no-cache bash
WORKDIR /var/www
COPY script.sh /usr/local/bin/script.sh
RUN chmod +x /usr/local/bin/script.sh
CMD ["/usr/local/bin/script.sh", "userName"]

