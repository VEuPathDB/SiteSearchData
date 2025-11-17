#!/bin/sh

# Populate config templates
# this should be a loop, or something more sane, but we're dealing with sh here.

# the portal uses Portal/SiteSearchData model, but only here.  This is
# templated to use the COHORT var, but COHORT for the portal is Apicommon,
# which is not used here.

# which leads us to this exception, where we set the COHORT var if PROJECT_ID
# is EupathDB

export MODEL_DIR=$COHORT

# expect COHORT to be ApiCommon|ClinEpi|Microbiome|OrthoMCL

#if [ "${PROJECT_ID}" = "EuPathDB" ]
#then
#    export MODEL_LOCATION=Portal
#fi

if [ "${COHORT}" = "ClinEpi" ]
then
    export MODEL_DIR=EDA
fi

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
