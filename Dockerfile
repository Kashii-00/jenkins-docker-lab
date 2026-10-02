FROM nginx:stable-alpine

RUN apk upgrade --no-cache libexpat

COPY --chmod=644 index.html /usr/share/nginx/html/

EXPOSE 80