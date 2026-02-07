#!/usr/bin/env nextflow
nextflow.enable.dsl=2

//--------------------------------------------------------------------------
// Param Checking
//--------------------------------------------------------------------------

if(!params.outputDir) {
  throw new Exception("Missing params.outputDir")
}

if(!params.envFile) {
  throw new Exception("Missing params.envFile")
}

if(!params.numberOfOrganisms) {
  throw new Exception("Missing params.numberOfOrganisms")
}

//--------------------------------------------------------------------------
// Main Workflow
//--------------------------------------------------------------------------

workflow {
  projects = Channel.of(
    ['Portal', 'UniDB'],
    ['ApiCommon', 'FungiDB'],
    ['ApiCommon', 'TriTrypDB'],
    ['ApiCommon', 'PlasmoDB'],
    ['ApiCommon', 'VectorBase'],
    ['ApiCommon', 'ToxoDB'],
    ['ApiCommon', 'HostDB'],
    ['ApiCommon', 'AmoebaDB'],
    ['ApiCommon', 'CryptoDB'],
    ['ApiCommon', 'GiardiaDB'],
    ['ApiCommon', 'MicrosporidiaDB'],
    ['ApiCommon', 'PiroplasmaDB'],
    ['ApiCommon', 'TrichDB'],
    ['OrthoMCL', 'OrthoMCL']
//    ['EDA', 'ClinEpiDB'],
//    ['EDA', 'MicrobiomeDB']
  )

  // Use a representative project from each cohort for config generation
  metadataCohorts = Channel.of(
    ['ApiCommon', 'PlasmoDB'],   // Use PlasmoDB as representative for ApiCommon
    ['OrthoMCL', 'OrthoMCL'],
    ['EDA', 'PlasmoDB']         // Use PlasmoDB as representative for EDA
  )

  // Recreate WDK cache (runs once at the start)
  cacheComplete = recreateCache(params.envFile)

  // Create metadata batches for each cohort (runs in parallel with project dumps, but after cache)
  createMetadataBatches(metadataCohorts, params.envFile, cacheComplete)

  runSiteSearchData(projects, params.envFile, cacheComplete)
}

process recreateCache {
  errorStrategy 'terminate'
  containerOptions "--env-file ${params.envFile} -e COHORT=ApiCommon -e PROJECT_ID=PlasmoDB"

  publishDir "${params.outputDir}", mode: 'copy'

  input:
    path(envFile)

  output:
    path 'cache.done'

  script:
  """
  set -euo pipefail

  echo "Recreating WDK cache..."
  wdkCache -model SiteSearchData -recreate
  echo "WDK cache recreated successfully"

  # Create sentinel file to track completion
  touch cache.done
  """
}

process createMetadataBatches {
  errorStrategy 'finish'
  containerOptions "-v ${params.outputDir}:/output --env-file ${params.envFile} -e COHORT=${cohort} -e PROJECT_ID=${projectId}"

  input:
    tuple val(cohort), val(projectId)
    path(envFile)
    path(cacheDone)

  output:
    val cohort

  script:
  // Use ports 8900+ for metadata servers (separate from project dump ports 9000+)
  // task.index assigns unique port per parallel execution slot
  def port = 8900 + task.index
  """
  mkdir -p /output/metadata/${cohort}

  # Start WDK server on dedicated port in the background
  wdkServer SiteSearchData http://0.0.0.0:${port} &> /output/metadata/${cohort}/server.log &
  SERVER_PID=\$!

  # Wait for server to be ready
  echo "Waiting for WDK server to start on port ${port} for ${cohort} metadata..."
  for i in {1..60}; do
    HTTP_CODE=\$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${port} || echo "000")
    echo "Attempt \$i: HTTP_CODE=\$HTTP_CODE"
    if [ "\$HTTP_CODE" -ge 200 ] && [ "\$HTTP_CODE" -lt 300 ]; then
      echo "Server is ready on port ${port}"
      break
    elif [ "\$HTTP_CODE" -ge 400 ] && [ "\$HTTP_CODE" -lt 600 ]; then
      echo "Server returned error \$HTTP_CODE on port ${port}"
      exit 1
    fi
    sleep 2
  done

  # Create document categories batch if not already complete
  CAT_BATCH=\$(ls -d /output/metadata/${cohort}/solr-json-batch_document-categories_all_* 2>/dev/null | tail -1)
  if [ -n "\$CAT_BATCH" ] && [ -f "\$CAT_BATCH/DONE" ]; then
    echo "Document categories batch already exists and is complete for ${cohort}, skipping"
  else
    echo "Creating document categories batch for ${cohort}"
    ssCreateDocumentCategoriesBatch ${cohort} /output/metadata/${cohort} &> /output/metadata/${cohort}/docCat.log
  fi

  # Create document fields batch if not already complete
  FIELD_BATCH=\$(ls -d /output/metadata/${cohort}/solr-json-batch_document-fields_all_* 2>/dev/null | tail -1)
  if [ -n "\$FIELD_BATCH" ] && [ -f "\$FIELD_BATCH/DONE" ]; then
    echo "Document fields batch already exists and is complete for ${cohort}, skipping"
  else
    echo "Creating document fields batch for ${cohort}"
    ssCreateDocumentFieldsBatch http://localhost:${port} ${cohort} /output/metadata/${cohort} &> /output/metadata/${cohort}/docField.log
  fi

  # Stop the server
  kill \$SERVER_PID || true
  """
}

process runSiteSearchData {
  errorStrategy 'finish'
  containerOptions "-v ${params.outputDir}:/output --env-file ${params.envFile} -e COHORT=${cohort} -e PROJECT_ID=${projectId}"

  input:
    tuple val(cohort), val(projectId)
    path(envFile)
    path(cacheDone)

  output:
    val projectId

  script:
  // Assign port based on parallel execution slot (task.index ranges from 0 to maxForks-1)
  def port = 9000 + task.index

  // Select appropriate dump script and arguments based on cohort
  def dumpScript
  def dumpArgs
  if (cohort == 'ApiCommon') {
    dumpScript = "dumpApiCommonWdkBatchesForSolr"
    dumpArgs = "--wdkServiceUrl \"http://localhost:${port}\" --targetDir /output/${projectId} --projectId ${projectId} --numberOfOrganisms ${params.numberOfOrganisms}"
  } else if (cohort == 'OrthoMCL') {
    dumpScript = "dumpOrthomclWdkBatchesForSolr"
    dumpArgs = "--wdkServiceUrl \"http://localhost:${port}\" --targetDir /output/${projectId}"
  } else if (cohort == 'EDA') {
    dumpScript = "dumpEdaWdkBatchesForSolr"
    dumpArgs = "--wdkServiceUrl \"http://localhost:${port}\" --targetDir /output/${projectId}"
  }

  """
  mkdir -p /output/${projectId}

  # Start WDK server on dedicated port in the background, logging to output dir
  wdkServer SiteSearchData http://0.0.0.0:${port}  &> /output/${projectId}/server.log &
  SERVER_PID=\$!

  # Wait for server to be ready
  echo "Waiting for WDK server to start on port ${port}..."
  for i in {1..60}; do
    HTTP_CODE=\$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${port} || echo "000")
    echo "Attempt \$i: HTTP_CODE=\$HTTP_CODE"
    if [ "\$HTTP_CODE" -ge 200 ] && [ "\$HTTP_CODE" -lt 300 ]; then
      echo "Server is ready on port ${port}"
      break
    elif [ "\$HTTP_CODE" -ge 400 ] && [ "\$HTTP_CODE" -lt 600 ]; then
      echo "Server returned error \$HTTP_CODE on port ${port}"
      exit 1
    fi
    sleep 2
  done

  # Run the appropriate dump script(s) based on cohort
  echo "Running ${dumpScript} for ${cohort} cohort, project ${projectId}"
  ${dumpScript} ${dumpArgs} &>> /output/${projectId}/dumper.log

  # For ApiCommon, also run EDA dump script
  if [ "${cohort}" = "ApiCommon" ]; then
    echo "Running dumpEdaWdkBatchesForSolr for ${cohort} cohort, project ${projectId}"
    dumpEdaWdkBatchesForSolr --wdkServiceUrl "http://localhost:${port}" --targetDir /output/${projectId} &>> /output/${projectId}/dumper.log
  fi

  # Stop the server
  kill \$SERVER_PID || true
  """
}
