FROM nginx:stable-alpine

RUN apk upgrade --no-cache libexpat

COPY index.html /usr/share/nginx/html/index.html

RUN chmod 755 /usr/share/nginx/html && \
    chmod 644 /usr/share/nginx/html/index.html

EXPOSE 80