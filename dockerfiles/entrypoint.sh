#!/bin/sh

# Populate config templates
envsubst < /tmp/site-search-config.tpl.json > /tmp/site-search-config.json
envsubst < /tmp/ldap.tpl.ora > ${ORACLE_HOME}/network/admin/ldap.ora

# run CMD, or whatever is specified by run
exec "$@"
