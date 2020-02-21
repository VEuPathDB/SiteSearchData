#!/usr/bin/env python3

import requests
import json
import sys
import os.path
import glob
#import shutil
#import time
#import datetime

TARGETDIRPREFIX = 'solr-json-batch_'

def failIfPreviousBatchDir(parentDir, batchType, batchName):
    dirs = glob(parentDir + "/" + TARGETDIRPREFIX + batchType + "_" + batchName + "_")
    if len(dirs) != 0:
        error("A previous batch of this type exists in " + parentDir + ".  Delete it first")

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
    except:
        error("It looks like you are not running the SiteSearchModel WDK service at url " + wdkServiceUrl)


def validateParentDir(parentDir):
    if not os.path.exists(parentDir) or not os.path.isdir(parentDir):
        error("parentDir '" + parentDir + "' does not exist or is not a directory")

def createWorkingDir(parentDir, batchId):
    newDirPath = parentDir + "/" + TARGETDIRPREFIX + batchId
    try:
        os.mkdir(newDirPath)
    except OSError:
        error("Could not create directory " + 'newDirPath')
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
