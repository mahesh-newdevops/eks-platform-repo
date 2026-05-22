FROM nginx:1.27.4-alpine

RUN apk upgrade --no-cache \
    && sed -i 's/listen       80;/listen       8080;/' /etc/nginx/conf.d/default.conf

COPY index.html /usr/share/nginx/html/index.html

USER nginx

EXPOSE 8080
