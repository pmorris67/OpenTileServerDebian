#!/bin/sh
set -e -u

UNZIP_OPTS=-qqun
SRC=openstreetmap-carto-data
DATA=/usr/share/openstreetmap-carto-common/data

# check essential applications
exists()
{
  command -v "$1" >/dev/null 2>&1
}

for application in tar unzip; do
  if exists $application; then
    echo $application 'detected...'
  else
    echo 'ERROR:' $application 'not detected, you need to install it first!'
    exit 1
  fi
done

# create and populate data dir
mkdir -p ${DATA}/
mkdir -p ${DATA}/world_boundaries
mkdir -p ${DATA}/simplified-land-polygons-complete-3857
mkdir -p ${DATA}/ne_110m_admin_0_boundary_lines_land
mkdir -p ${DATA}/land-polygons-split-3857

# world_boundaries
echo "expanding world_boundaries..."
tar -xzf ${SRC}/world_boundaries-spherical.tgz -C ${DATA}/

# simplified-land-polygons-complete-3857
echo "simplified-land-polygons-complete-3857..."
unzip $UNZIP_OPTS ${SRC}/simplified-land-polygons-complete-3857.zip \
  simplified-land-polygons-complete-3857/simplified_land_polygons.shp \
  simplified-land-polygons-complete-3857/simplified_land_polygons.shx \
  simplified-land-polygons-complete-3857/simplified_land_polygons.prj \
  simplified-land-polygons-complete-3857/simplified_land_polygons.dbf \
  simplified-land-polygons-complete-3857/simplified_land_polygons.cpg \
  -d ${DATA}/

# ne_110m_admin_0_boundary_lines_land
echo "expanding ne_110m_admin_0_boundary_lines_land..."
unzip $UNZIP_OPTS ${SRC}/ne_110m_admin_0_boundary_lines_land.zip \
  ne_110m_admin_0_boundary_lines_land.shp \
  ne_110m_admin_0_boundary_lines_land.shx \
  ne_110m_admin_0_boundary_lines_land.prj \
  ne_110m_admin_0_boundary_lines_land.dbf \
  -d ${DATA}/ne_110m_admin_0_boundary_lines_land/

# land-polygons-split-3857
echo "expanding land-polygons-split-3857..."
unzip $UNZIP_OPTS ${SRC}/land-polygons-split-3857.zip \
  land-polygons-split-3857/land_polygons.shp \
  land-polygons-split-3857/land_polygons.shx \
  land-polygons-split-3857/land_polygons.prj \
  land-polygons-split-3857/land_polygons.dbf \
  land-polygons-split-3857/land_polygons.cpg \
  -d ${DATA}/

# antarctica-icesheet-polygons-3857
echo "expanding antarctica-icesheet-polygons-3857..."
unzip $UNZIP_OPTS ${SRC}/antarctica-icesheet-polygons-3857.zip \
  antarctica-icesheet-polygons-3857/icesheet_polygons.shp \
  antarctica-icesheet-polygons-3857/icesheet_polygons.shx \
  antarctica-icesheet-polygons-3857/icesheet_polygons.prj \
  antarctica-icesheet-polygons-3857/icesheet_polygons.dbf \
  -d ${DATA}/

# antarctica-icesheet-outlines-3857
echo "expanding antarctica-icesheet-outlines-3857..."
unzip $UNZIP_OPTS ${SRC}/antarctica-icesheet-outlines-3857.zip \
  antarctica-icesheet-outlines-3857/icesheet_outlines.shp \
  antarctica-icesheet-outlines-3857/icesheet_outlines.shx \
  antarctica-icesheet-outlines-3857/icesheet_outlines.prj \
  antarctica-icesheet-outlines-3857/icesheet_outlines.dbf \
  -d ${DATA}/

#index
echo "indexing shapefiles"
shapeindex --shape_files \
${DATA}/simplified-land-polygons-complete-3857/simplified_land_polygons.shp \
${DATA}/land-polygons-split-3857/land_polygons.shp \
${DATA}/antarctica-icesheet-polygons-3857/icesheet_polygons.shp \
${DATA}/antarctica-icesheet-outlines-3857/icesheet_outlines.shp \
${DATA}/ne_110m_admin_0_boundary_lines_land/ne_110m_admin_0_boundary_lines_land.shp

#finish
echo "...done!"
