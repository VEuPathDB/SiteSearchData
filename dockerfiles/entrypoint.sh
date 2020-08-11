#!/bin/sh

# Populate config templates
# this should be a loop, or something more sane, but we're dealing with sh here.

if [ ! -f ${GUS_HOME}/config/SiteSearchData/model-config.xml ];
then
    envsubst < ${GUS_HOME}/config/SiteSearchData/model-config.xml.tmpl > ${GUS_HOME}/config/SiteSearchData/model-config.xml 
fi

if [ ! -f ${GUS_HOME}/config/SiteSearchData/model.prop ];
then
    envsubst < ${GUS_HOME}/config/SiteSearchData/model.prop.tmpl > ${GUS_HOME}/config/SiteSearchData/model.prop
fi

#envsubst < /tmp/site-search-config.tpl.json > /tmp/site-search-config.json

# run CMD, or whatever is specified by run
exec "$@"
