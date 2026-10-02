FROM nginx:stable-alpine

RUN apk upgrade --no-cache libexpat

COPY --chmod=0644 index.html /usr/share/nginx/html/index.html

EXPOSE 80

RUN apk upgrade --no-cache