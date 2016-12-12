FROM alpine:latest

RUN apk add --no-cache bash jq

COPY pop /usr/bin/pop
COPY check.sh /opt/resource/check
COPY in.sh /opt/resource/in
COPY out.sh /opt/resource/out
RUN chmod +x /opt/resource/check /opt/resource/in /opt/resource/out
