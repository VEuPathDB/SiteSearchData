#!/bin/sh

set -e
set -x


SERVER_PORT=7782
DESTINATION_DIRECTORY=/tmp/output

# start server
wdkServer SiteSearchData $SERVER_PORT -cleanCacheAtStartup &

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
#   OrthoMCL only needs WDK Meta (ie, Searches)
#   EDA sites only need dataset presenters
#   genomics sites, including portal need both
if [ "$PROJECT_ID" = "OrthoMCL" ]; 
then
  mkdir $DESTINATION_DIRECTORY &&\
  ssCreateWdkMetaBatch $SITE_BASE_URL/service/ $PROJECT_ID $DESTINATION_DIRECTORY

elif [ "$PROJECT_ID" = "ClinEpiDB" ] || [ "$PROJECT_ID" = "MicrobiomeDB" ];
then
mkdir $DESTINATION_DIRECTORY &&\
  ssCreateWdkRecordsBatch dataset-presenter $PROJECT_ID http://localhost:$SERVER_PORT $DESTINATION_DIRECTORY

else
  mkdir $DESTINATION_DIRECTORY &&\
  ssCreateWdkRecordsBatch dataset-presenter $PROJECT_ID http://localhost:$SERVER_PORT $DESTINATION_DIRECTORY &&\
  ssCreateWdkMetaBatch $SITE_BASE_URL/service/ $PROJECT_ID $DESTINATION_DIRECTORY
fi



echo "produced files:"
echo
find $DESTINATION_DIRECTORY -type f -print0 | xargs -0 ls -al

# load produced output into solr

ssLoadMultipleBatches $SOLR_URL $DESTINATION_DIRECTORY --replace

kill %1
