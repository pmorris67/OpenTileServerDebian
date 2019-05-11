#!/bin/bash

apt install --download-only --install-recommends -y -q \
	ttf-unifont \
    fonts-arphic-ukai \
    fonts-arphic-uming \
    fonts-thai-tlwg \
    postgresql \
    postgresql-contrib \
    postgresql-server-dev-all \
    postgis \
    osm2pgsql \
    osmosis \
    apache2 \
    libapache2-mod-wsgi \
    javascript-common \
    libjs-leaflet \
    openstreetmap-carto \
    git build-essential \
    fakeroot \
    devscripts \
    apache2-dev \
    libmapnik-dev
