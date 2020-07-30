#!/bin/sh

# Populate config templates
mkdir -p /tmp/etc
envsubst < /tmp/site-search-config.tpl.json > /tmp/site-search-config.json
envsubst < /tmp/conifer_site_vars.tpl.yml > /tmp/etc/conifer_site_vars.yml
envsubst < /tmp/ldap.tpl.ora > ${TNS_ADMIN}/ldap.ora

# Populate model config
${GUS_HOME}/bin/conifer configure SiteSearchData

# run CMD, or whatever is specified by run
exec "$@"
