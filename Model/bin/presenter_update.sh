#!/bin/sh

set -e
set -x

SERVER_PORT=7782
DESTINATION_DIRECTORY=/tmp/output

# start WDK server
echo "$(date -u) starting server"
wdkServer SiteSearchData $SERVER_PORT -cleanCacheAtStartup &

echo "waiting for server to be available"

start=$(date +%s)
while [ $(($(date +%s) - $start)) -lt 180 ]
# while true
do
  echo "checking port $SERVER_PORT..."
  if nc -zv localhost:$SERVER_PORT 
    then
     echo 'server available'
     break
  fi
  sleep 1
done
echo "$(date -u) server available"
  
# make output dir and run commands to produce output

mkdir $DESTINATION_DIRECTORY &&\
echo "$(date -u) starting ssCreateWdkRecordsBatch" &&\
ssCreateWdkRecordsBatch dataset-presenter $PROJECT_ID http://localhost:$SERVER_PORT $DESTINATION_DIRECTORY &&\
echo "$(date -u) starting ssCreateWdkMetaBatch" &&\
ssCreateWdkMetaBatch $SITE_BASE_URL/service/ $PROJECT_ID $DESTINATION_DIRECTORY

echo "produced files:"
echo
find $DESTINATION_DIRECTORY -type f -print0 | xargs -0 ls -al

# load produced output into solr
echo "$(date -u) starting ssLoadMultipleBatches"
ssLoadMultipleBatches $SOLR_URL $DESTINATION_DIRECTORY --replace

# shut down running WDK server started above
echo "$(date -u) Shutting down WDK"
kill %1

echo "$(date -u) DONE presenter_update"
