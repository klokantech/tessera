FROM node:5-slim
MAINTAINER Tim Dorr <timdorr@showcaseidx.com>

RUN apt-get update \
  && apt-get install -y \
    build-essential \
    make \
    git \
  && rm -rf /var/lib/apt/lists/*

# make sure the mapbox fonts are available on the system
RUN mkdir -p /tmp/mapbox-studio-default-fonts && \
    mkdir -p /fonts && \
    git clone https://github.com/mapbox/mapbox-studio-default-fonts.git /tmp/mapbox-studio-default-fonts && \
    cp /tmp/mapbox-studio-default-fonts/**/*.otf /fonts && \
    cp /tmp/mapbox-studio-default-fonts/**/*.ttf /fonts && \
    rm -rf /tmp/mapbox-studio-default-fonts

# download fonts required for osm bright
RUN wget -q -P /fonts https://github.com/aaronlidman/Toner-for-Tilemill/raw/master/toner4tilemill/fonts/Arial-Bold.ttf && \
    wget -q -P /fonts https://github.com/aaronlidman/Toner-for-Tilemill/raw/master/toner4tilemill/fonts/Arial-Regular.ttf && \
    wget -q -P /fonts https://github.com/aaronlidman/Toner-for-Tilemill/raw/master/toner4tilemill/fonts/Arial-Unicode-Bold-Italic.ttf && \
    wget -q -P /fonts https://github.com/aaronlidman/Toner-for-Tilemill/raw/master/toner4tilemill/fonts/Arial-Unicode-Bold.ttf && \
    wget -q -P /fonts https://github.com/aaronlidman/Toner-for-Tilemill/raw/master/toner4tilemill/fonts/Arial-Unicode-Italic.ttf && \
    wget -q -P /fonts https://github.com/aaronlidman/Toner-for-Tilemill/raw/master/toner4tilemill/fonts/Arial-Unicode-Regular.ttf

RUN mkdir -p /usr/src/app && mkdir -p /project
WORKDIR /usr/src/app

COPY / /usr/src/app

RUN npm install

VOLUME /data
EXPOSE 80
ENV SOURCE_DATA_DIR=/data \
    DEST_DATA_DIR=/project \
    PORT=80 \
    MAPNIK_FONT_PATH=/fonts \
    DOMAINS=

CMD ["/usr/src/app/run.sh"]
