FROM nginx:stable-alpine

RUN apk upgrade --no-cache libexpat

COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80