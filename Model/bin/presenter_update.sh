#!/bin/sh

set -e


SERVER_PORT=7782
DESTINATION_DIRECTORY=/tmp/output

# start server
wdkServer SiteSearchData $SERVER_PORT &

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
ssCreateDocumentCategoriesBatch $DESTINATION_DIRECTORY &&\
ssCreateDocumentFieldsBatch http://localhost:$SERVER_PORT $DESTINATION_DIRECTORY &&\
ssCreateWdkRecordsBatch dataset-presenter all http://localhost:$SERVER_PORT $DESTINATION_DIRECTORY &&\
ssCreateWdkMetaBatch $SITE_BASE_URL/service/ $PROJECT_NAME $DESTINATION_DIRECTORY

echo "produced files:"
echo
find $DESTINATION_DIRECTORY -type f -print0 | xargs -0 ls -al

# load produced output into solr

ssLoadMultipleBatches $SOLR_URL $DESTINATION_FOLDER --replace

kill %1
