#!/bin/sh
set -e -u

DEST=openstreetmap-carto-data

# check essential applications
exists()
{
  command -v "$1" >/dev/null 2>&1
}

for application in curl; do
  if exists $application; then
    echo $application 'detected...'
  else
    echo 'ERROR:' $application 'not detected, you need to install it first!'
    exit 1
  fi
done

# create and populate data dir
mkdir -p ${DEST}

# world_boundaries
echo "downloading world_boundaries..."
curl -z "${DEST}/world_boundaries-spherical.tgz" -L -o "${DEST}/world_boundaries-spherical.tgz" "http://planet.openstreetmap.org/historical-shapefiles/world_boundaries-spherical.tgz"

# simplified-land-polygons-complete-3857
echo "downloading simplified-land-polygons-complete-3857..."
curl -z "${DEST}/simplified-land-polygons-complete-3857.zip" -L -o "${DEST}/simplified-land-polygons-complete-3857.zip" "http://data.openstreetmapdata.com/simplified-land-polygons-complete-3857.zip"

# ne_110m_admin_0_boundary_lines_land
echo "downloading ne_110m_admin_0_boundary_lines_land..."
curl -z "${DEST}/ne_110m_admin_0_boundary_lines_land.zip" -L -o "${DEST}/ne_110m_admin_0_boundary_lines_land.zip" http://www.naturalearthdata.com/http//www.naturalearthdata.com/download/110m/cultural/ne_110m_admin_0_boundary_lines_land.zip

# land-polygons-split-3857
echo "downloading land-polygons-split-3857..."
curl -z "${DEST}/land-polygons-split-3857.zip" -L -o "${DEST}/land-polygons-split-3857.zip" "http://data.openstreetmapdata.com/land-polygons-split-3857.zip"

# antarctica-icesheet-polygons-3857
echo "downloading antarctica-icesheet-polygons-3857..."
curl -z "${DEST}/antarctica-icesheet-polygons-3857.zip" -L -o "${DEST}/antarctica-icesheet-polygons-3857.zip" "http://data.openstreetmapdata.com/antarctica-icesheet-polygons-3857.zip"

# antarctica-icesheet-outlines-3857
echo "downloading antarctica-icesheet-outlines-3857..."
curl -z "${DEST}/antarctica-icesheet-outlines-3857.zip" -L -o "${DEST}/antarctica-icesheet-outlines-3857.zip" "http://data.openstreetmapdata.com/antarctica-icesheet-outlines-3857.zip"

#finish
echo "...done!"
