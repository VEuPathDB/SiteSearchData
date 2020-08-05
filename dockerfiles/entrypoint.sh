#!/bin/sh

# Populate config templates
envsubst < /tmp/site-search-config.tpl.json > /tmp/site-search-config.json

# run CMD, or whatever is specified by run
exec "$@"
