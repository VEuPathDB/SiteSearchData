#!/usr/bin/env python3

import requests
import json
import sys
import os.path
import subprocess
import glob
from pathlib import Path

TARGETDIRPREFIX = 'solr-json-batch_'

def failIfPreviousBatchDir(parentDir, batchType, batchName):
    dirs = glob.glob(parentDir + "/" + TARGETDIRPREFIX + batchType + "_" + batchName + "_*")
    if len(dirs) != 0:
        error("A previous batch of this type exists in " + parentDir + ".  Please delete it first")

def error(msg):
        sys.stderr.write("ERROR: " + msg + "\n")
        sys.exit(1)

def httpGet(url, params):
    response = requests.get(url=url, params=params)
    if (response.status_code != 200):
        error("Received " + str(response.status_code) + " status from HTTP GET to " + url + " with parameters: " + str(params))
    return response
             
def validateWebServiceUrl(wdkServiceUrl):
    try:
        requests.get(url=wdkServiceUrl, params={})
    except Exception as e:
        error(f"Failed to connect to WDK service at {wdkServiceUrl}. Reason: {type(e).__name__}: {str(e)}")


def validateParentDir(parentDir):
    if not os.path.exists(parentDir) or not os.path.isdir(parentDir):
        error("parentDir '" + parentDir + "' does not exist or is not a directory")

def createWorkingDir(parentDir, batchId):
    newDirPath = parentDir + "/" + TARGETDIRPREFIX + batchId
    try:
        os.mkdir(newDirPath)
    except OSError:
        error("Could not create directory '" + newDirPath + "'")
    return newDirPath

def getRecordTypeNames(wdkServiceUrl):
    recordTypesUrl = wdkServiceUrl + '/record-types'
    response = httpGet(recordTypesUrl, {})
    return response.json()
    
def getRecordType(wdkServiceUrl, recordTypeName):
    recordTypeUrl = wdkServiceUrl + '/record-types/' + recordTypeName
    response = httpGet(recordTypeUrl, {})
    recordType = response.json()
    return recordType

def writeBatchJsonFile(batchType, batchName, batchTimestamp, batchId, outputDir):
    batch = {}
    batch['batch-type'] = batchType
    batch['batch-name'] = batchName
    batch['document-type'] = "batch-meta"
    batch['batch-timestamp'] = batchTimestamp
    batch['batch-id'] = batchId
    batch['id'] = batch['batch-id']
    batches = [batch]
    batchJson = json.dumps(batches)
    with open(outputDir + "/batch.json", "w") as text_file:
        text_file.write(batchJson)
    Path(outputDir + "/DONE").touch()  # write flag indicating a complete batch

# validate that the json file ends in an a ']'
def validateDocumentsJsonFile(jsonFileName):
    output = subprocess.getoutput("tail -c 1 " + jsonFileName)
    if output != ']':			
       error("File " + jsonFileName + " is not valid.  It does not end in ']'.  Try 'tail -c 500' to see the end of that file")

