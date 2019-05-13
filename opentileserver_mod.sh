#!/bin/bash
# Version: 0.9.3pm
# Date   : 2019-04-29
#
# Forked from https://github.com/lsimediasarl/OpenTileServerDebian to support
# installation on an isolated network with a Debian mirror. In which case it does
# not support updates.
#
# This script is inspired from https://github.com/AcuGIS/OpenTileServer
# Also inspired by documentation at https://wiki.debian.org/OSM/tileserver/jessie
#
# Simple tile server installation script with  mod_tile as main backend
# for Debian Stretch (start with barbone install with ssh server only).
#
# This script will install open street map data and prepare the mod_tile/renderd
# to render the tiles directly via apache2
#
# The database will be stored under the defined user ("osm" by default) and the
# tiles will be stored in default /var/lib/mod_tile
#
# The script must be run as root
#
# Usage: ./opentileserver_mod.sh {pbf_file} {mod_tile_zip}"
#
# Example
# ./opentileserver_mod.sh delaware-latest.osm.pbf master.zip
# ./opentileserver_mod.sh http://download.geofabrik.de/europe/switzerland-latest.osm.pbf
# ./opentileserver_mod.sh https://planet.openstreetmap.org/pbf/planet-latest.osm.pbf master.zip
#
# Licence
#
#    Original - Copyright (C) 2017 LSI Media Sarl
#    Isolated network support - Copyright (C) 2018 Philip Morris
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Change these values if needed
OSM_USER="osm" #linux and db user
OSM_DB="gis" #database name
VHOST=$(hostname -f)

#-------------------------------------------------------------------------------
#--- 0. Introduction
#-------------------------------------------------------------------------------
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 {pbf_file} {mod_tile_zip}"; exit 1;
fi

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root";  exit 1;
fi

# Internal variables - OSM data
URL_REGEX='(https?|ftp)://'
if [[ ${1} =~ ${URL_REGEX} ]]; then
	PBF_URL=${1}
	PBF_FILE="/home/${OSM_USER}/OpenStreetMap/${PBF_URL##*/}"
	UPDATE_URL="$(echo ${PBF_URL} | sed 's/latest.osm.pbf/updates/')"
	if [[ ${PBF_URL} =~ "planet" ]]; then
	    # For planet file, hard code the update url
	    UPDATE_URL = "https://planet.openstreetmap.org/replication/day"
	fi
else
	# Reference PBF by absolute file path
	PBF_URL=""
	PBF_FILE=$(readlink -e ${1})
	UPDATE_URL=""
	if [ ! -f ${PBF_FILE} ]; then
		echo "PBF data file ${PBF_FILE} does not exist"
		return 1
	fi
fi

# Internal variables - mod_tile source code
if [ "$#" -eq 2 ]; then
	MOD_TILE_ZIP=$(readlink -e ${2})
	if [ ! -f ${MOD_TILE_ZIP} ]; then
		echo "mod_tile source archive ${MOD_TILE_ZIP} does not exist"
		exit 1
	fi
else
	MOD_TILE_ZIP=""
fi

if [ -n "${MOD_TILE_ZIP}" -a -z "${PBF_URL}" ]; then
	ISOLATED="true"
	FETCH_SHAPES="false"
else
	ISOLATED="false"
	FETCH_SHAPES="true"
fi

NP=$(grep -c 'model name' /proc/cpuinfo)

cat <<EOF

The values for the installation are
User          : ${OSM_USER}
Database name : ${OSM_DB}
Server name   : ${VHOST}
Backend       : mod_tile
PBF URL       : ${PBF_URL}
PBF file      : ${PBF_FILE}
mod_tile ZIP  : ${MOD_TILE_ZIP}
ISOLATED      : ${ISOLATED}
To change these values, edit the script file

If the values are not correct, break this script (CTRL-C) now or wait 10s to continue

Some package will ask you some question, answer with the default values which
have been modified to represent your values.

EOF
sleep 10s

#-------------------------------------------------------------------------------
#--- 1. Install package
#-------------------------------------------------------------------------------
echo ""
echo "1. Install needed packages"
echo "=========================="
#export DEBIAN_FRONTEND=noninteractive
apt install --install-recommends -y -q ttf-unifont \
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
	libjs-openlayers \
    libjs-leaflet
#--- prepare the answer for database and automatic download of shape files
echo "openstreetmap-carto openstreetmap-carto/database-name string ${OSM_DB}" | debconf-set-selections
echo "openstreetmap-carto-common openstreetmap-carto/fetch-data boolean ${FETCH_SHAPES}" | debconf-set-selections
apt install -y openstreetmap-carto
apt install -y git build-essential \
     fakeroot \
     devscripts \
     apache2-dev \
     libmapnik-dev
apt clean

# To avoid the label cut between tiles, add the avoid-edges in the default style
sed -i 's/<Map srs=/<Map\ buffer-size=\"512\" srs=/g' /usr/share/openstreetmap-carto/style.xml
# This line is not needed for the moment
#sed -i 's/<ShieldSymbolizer/<ShieldSymbolizer\ avoid-edges=\"true\"\ /g' /usr/share/openstreetmap-carto/style.xml

#-------------------------------------------------------------------------------
#--- 1a. Post process openstreetmap-carto shapes if we didnt download them
#-------------------------------------------------------------------------------
if [ "${ISOLATED}" = "true" ]; then
	echo "Processing openstreetmap-carto shapefiles"
	./process-shapefiles.sh
fi

#-------------------------------------------------------------------------------
#--- 2. Create system user
#-------------------------------------------------------------------------------
echo ""
echo "2. Create the user"
echo "===================="
if [ $(grep -c ${OSM_USER} /etc/passwd) -eq 0 ]; then	#if we don't have the OSM user
    # Password is disabled by default, so no access is possible
    useradd -m ${OSM_USER} -s /bin/bash -c "OpenStreetMap"
fi

#-------------------------------------------------------------------------------
#--- 3. Prepare database
#-------------------------------------------------------------------------------
echo ""
echo "3. Prepare database"
echo "==================="
# Create the database schema (as postgres user)
su postgres <<EOF
cd ~
createuser ${OSM_USER}
createdb -E UTF8 -O ${OSM_USER} ${OSM_DB}
psql -c "CREATE EXTENSION hstore;" -d ${OSM_DB}
psql -c "CREATE EXTENSION postgis;" -d ${OSM_DB}
EOF

#-------------------------------------------------------------------------------
#--- 4. Download file and inject in database
#-------------------------------------------------------------------------------
echo ""
echo "4. Populate database"
echo "======================"
let C_MEM=$(free -m | grep -i 'mem:' | sed 's/[ \t]\+/ /g' | cut -f4,7 -d' ' | tr ' ' '+')-200
su ${OSM_USER} <<EOF
mkdir -p /home/${OSM_USER}/OpenStreetMap
cd /home/${OSM_USER}/OpenStreetMap
if [ -n "${UPDATE_URL}" ]; then
	# Download the latest state file first
	wget -O state.txt ${UPDATE_URL}/state.txt
fi
if [ -n "${PBF_URL}" ]; then
	# Download main data file
	wget ${PBF_URL}
fi
# Prepare osmosis working dir and config file
osmosis --read-replication-interval-init workingDirectory=.
sed -i.save "s|#\?baseUrl=.*|baseUrl=${UPDATE_URL}|" configuration.txt
# Inject in database (could be very long for the planet)
osm2pgsql --slim -d ${OSM_DB} -C ${C_MEM} --number-processes ${NP} --hstore -S /usr/share/osm2pgsql/default.style ${PBF_FILE}
#rm ${PBF_FILE}
EOF

# Prepare the daily cron job for data update
if [ -n "${UPDATE_URL}" ]; then

cat > /etc/cron.daily/osm-update <<EOF
#!/bin/bash
# Switch to osm user
su ${OSM_USER} <<CRONEOF
cd /home/${OSM_USER}/OpenStreetMap
while [ \\\$(cat /home/${OSM_USER}/OpenStreetMap/state.txt | grep '^sequenceNumber=') != \\\$(curl -sL ${UPDATE_URL}/state.txt | grep '^sequenceNumber=') ]
do    
	echo "--- Updating data (Local: \$(cat /home/${OSM_USER}/OpenStreetMap/state.txt | grep '^sequenceNumber='), Online: \$(curl -sL ${UPDATE_URL}/state.txt | grep '^sequenceNumber='))"
	osmosis --read-replication-interval --simplify-change --write-xml-change changes.osc.gz
	# Get available memory just before we call osm2pgsql!
	let C_MEM=\\\$(free -m | grep -i 'mem:' | sed 's/[ \t]\+/ /g' | cut -f4,7 -d' ' | tr ' ' '+')-200
	osm2pgsql --append --slim -d ${OSM_DB} -C \\\${C_MEM} --number-processes ${NP} -e15 -o expire.list --hstore changes.osc.gz
	sleep 2s
	# If the mod_tile is used, the render_expired command exist and use it to
	# mark dirty tile (will be re-render again)
	cat expire.list | render_expired --min-zoom=15 --touch-from=15 >/dev/null
	sleep 60s
done
echo "--- Data is up to date."
CRONEOF
EOF

chmod +x /etc/cron.daily/osm-update

fi

#-------------------------------------------------------------------------------
#--- 5. Configure backend
#-------------------------------------------------------------------------------
echo ""
echo "5. Preparing backend"
echo "===================="
#---Configure mod_tile and renderd
echo "Configure mod_tile,renderd and apache"

# Prepare and compile mod_tile
if [ -n "${MOD_TILE_ZIP}" ]; then
	# Unzip release downloaded from github and rename folder 
	rm -fr mod_tile
	MOD_TILE_EXTDIR=$(mktemp -d)
	unzip ${MOD_TILE_ZIP} -d ${MOD_TILE_EXTDIR}
	mv ${MOD_TILE_EXTDIR}/mod_tile* mod_tile
	rmdir ${MOD_TILE_EXTDIR}
	unset MOD_TILE_EXTDIR
else
	# Clone direct from github
	git clone https://github.com/openstreetmap/mod_tile.git
fi
cd mod_tile
dpkg-buildpackage -i -b -uc -us
cd ..
# Prepare default answer to activate new apache module
echo "libapache2-mod-tile libapache2-mod-tile/enablesite boolean true" | debconf-set-selections
# Install build packages
dpkg -i renderd_*.deb
dpkg -i libapache2-mod-tile_*.deb
# Clean it
rm *.deb
rm libapache2-mod-tile*.*

echo "Configure renderd"
cat > /etc/default/renderd <<EOF
# Override some default value
RUNASUSER=${OSM_USER}
#DAEMON_ARGS=""
EOF

mkdir -p /var/run/renderd
chmod og+w /var/run/renderd
mkdir -p /var/lib/mod_tile
chmod og+w /var/lib/mod_tile

cat > /etc/renderd.conf <<EOF
[renderd]
stats_file=/var/run/renderd/renderd.stats
socketname=/var/run/renderd/renderd.sock
num_threads=${NP}
tile_dir=/var/lib/mod_tile

[mapnik]
plugins_dir=$(mapnik-config --input-plugins)
font_dir=/usr/share/fonts/truetype
font_dir_recurse=true
;TILEDIR=/home/${OSM_USER}/www/mod_tile

[default]
plugins_dir=$(mapnik-config --input-plugins)
font_dir=/usr/share/fonts/truetype
font_dir_recurse=true
;TILEDIR=/home/${OSM_USER}/www/mod_tile
URI=/osm/
XML=/usr/share/openstreetmap-carto/style.xml
DESCRIPTION=This is the standard osm mapnik style
;ATTRIBUTION=&copy;<a href=\"https://www.openstreetmap.org/\">OpenStreetMap</a> and <a href=\"http://wiki.openstreetmap.org/wiki/Contributors\">contributors</a>, <a href=\"http://creativecommons.org/licenses/by-sa/2.0/\">CC-BY-SA</a>
;HOST=tile.openstreetmap.org
;SERVER_ALIAS=https://a.tile.openstreetmap.org
;SERVER_ALIAS=https://b.tile.openstreetmap.org
;HTCPHOST=proxy.openstreetmap.org
EOF

# Patch the demo to use the offline files
ln -s /usr/share/javascript/openlayers /var/www/osm/openlayers
sed -i 's/http:\/\/openlayers.org\/api/openlayers/' /var/www/osm/slippymap.html

service renderd restart

echo ""
echo "5. Installing demo pages"
echo "========================"
cat <<EOF

You can find your an example at
http://${VHOST}/osm

The rendered/downloaded tiles are stored in
/var/lib/mod_tile

The main renderd config is
/etc/renderd.cfg
/etc/default/renderd
EOF

service apache2 restart
echo "--- Finished installation"
