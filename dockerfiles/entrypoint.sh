#!/bin/sh

# setup config file from env vars

# NOTE: this is POC, and is sub-optimal for a variety of ways.  It is just here
# to show that another step is needed to generate the file from env vars.  This
# could be done in many different ways, and ideally the template (and
# templating) should be stored with the application code, not in an entrypoint
# script

# left as a horrible reminder that actual config needs to take place
cat > /tmp/site-search-config.json <<EOF
{
  "solrUrl": "${SOLR_URL}"
}
EOF

# run CMD, or whatever is specified by run
exec "$@"
