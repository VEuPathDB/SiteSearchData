#!/bin/sh

set -e
set -x


SERVER_PORT=7782
DESTINATION_DIRECTORY=/tmp/output

# start server
wdkServer SiteSearchData -cleanCacheAtStartup $SERVER_PORT &

echo 'waiting for server to be available'

while true
do
  echo "checking port $SERVER_PORT..."
  if nc -zv localhost:$SERVER_PORT 
    then
     echo 'server available'
     break
  fi
  sleep 1
done
  
# make output dir and run commands to produce output

mkdir $DESTINATION_DIRECTORY &&\
ssCreateWdkRecordsBatch dataset-presenter $PROJECT_ID http://localhost:$SERVER_PORT $DESTINATION_DIRECTORY &&\
ssCreateWdkMetaBatch $SITE_BASE_URL/service/ $PROJECT_ID $DESTINATION_DIRECTORY

echo "produced files:"
echo
find $DESTINATION_DIRECTORY -type f -print0 | xargs -0 ls -al

# load produced output into solr

ssLoadMultipleBatches $SOLR_URL $DESTINATION_DIRECTORY --replace

kill %1
