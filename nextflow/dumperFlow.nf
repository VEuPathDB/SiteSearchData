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
    ['OrthoMCL', 'OrthoMCL'],
    ['EDA', 'ClinEpiDB']
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
  metadataComplete = dumpDocumentMetadataBatches(metadataCohorts, params.envFile, cacheComplete)

  projectsComplete = dumpWdkDataBatches(projects, params.envFile, cacheComplete)

  // Drop the cache after all data dumps complete (recreate=true creates new empty cache)
  dropCache(params.envFile, [metadataComplete.collect(), projectsComplete.collect()])
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

process dumpDocumentMetadataBatches {
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
  mkdir -p /output/${cohort}/metadata

  ${WdkUtils.startWdkServer(port, "/output/${cohort}/metadata/server.log", "for ${cohort} metadata")}

  # Create document categories batch if not already complete
  CAT_BATCH=\$(ls -d /output/${cohort}/metadata/solr-json-batch_document-categories_all_* 2>/dev/null | tail -1)
  if [ -n "\$CAT_BATCH" ] && [ -f "\$CAT_BATCH/DONE" ]; then
    echo "Document categories batch already exists and is complete for ${cohort}, skipping"
  else
    echo "Creating document categories batch for ${cohort}"
    ssCreateDocumentCategoriesBatch ${cohort} /output/${cohort}/metadata &> /output/${cohort}/metadata/docCat.log
  fi

  # Create document fields batch if not already complete
  FIELD_BATCH=\$(ls -d /output/${cohort}/metadata/solr-json-batch_document-fields_all_* 2>/dev/null | tail -1)
  if [ -n "\$FIELD_BATCH" ] && [ -f "\$FIELD_BATCH/DONE" ]; then
    echo "Document fields batch already exists and is complete for ${cohort}, skipping"
  else
    echo "Creating document fields batch for ${cohort}"
    ssCreateDocumentFieldsBatch http://localhost:${port} ${cohort} /output/${cohort}/metadata &> /output/${cohort}/metadata/docField.log
  fi

  ${WdkUtils.stopWdkServer()}
  """
}

process dumpWdkDataBatches {
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

  // Portal cohort outputs go under ApiCommon directory
  def outputCohort = (cohort == 'Portal') ? 'ApiCommon' : cohort

  // Select appropriate dump script and arguments based on cohort
  def dumpScript
  def dumpArgs
  if (cohort == 'ApiCommon' || cohort == 'Portal') {
    dumpScript = "dumpApiCommonWdkBatchesForSolr"
    dumpArgs = "--wdkServiceUrl \"http://localhost:${port}\" --targetDir /output/${outputCohort}/${projectId} --projectId ${projectId} --numberOfOrganisms ${params.numberOfOrganisms}"
  } else if (cohort == 'OrthoMCL') {
    dumpScript = "dumpOrthomclWdkBatchesForSolr"
    dumpArgs = "--wdkServiceUrl \"http://localhost:${port}\" --targetDir /output/${outputCohort}/${projectId}"
  } else if (cohort == 'EDA') {
    dumpScript = "dumpEdaWdkBatchesForSolr"
    dumpArgs = "--wdkServiceUrl \"http://localhost:${port}\" --targetDir /output/${outputCohort}/${projectId}"
  }

  """
  mkdir -p /output/${outputCohort}/${projectId}

  ${WdkUtils.startWdkServer(port, "/output/${outputCohort}/${projectId}/server.log")}

  # Run the appropriate dump script(s) based on cohort
  echo "Running ${dumpScript} for ${cohort} cohort, project ${projectId}"
  ${dumpScript} ${dumpArgs} &>> /output/${outputCohort}/${projectId}/dumper.log

  # For ApiCommon, also run EDA dump script
  if [ "${cohort}" = "ApiCommon" ]; then
    echo "Running dumpEdaWdkBatchesForSolr for ${cohort} cohort, project ${projectId}"
    dumpEdaWdkBatchesForSolr --wdkServiceUrl "http://localhost:${port}" --targetDir /output/${outputCohort}/${projectId} &>> /output/${outputCohort}/${projectId}/dumper.log
  fi

  ${WdkUtils.stopWdkServer()}
  """
}

process dropCache {
  errorStrategy 'terminate'
  containerOptions "--env-file ${params.envFile} -e COHORT=ApiCommon -e PROJECT_ID=PlasmoDB"

  publishDir "${params.outputDir}", mode: 'copy'

  input:
    path(envFile)
    val(dependencies)  // Can accept single value or list of completion values

  output:
    path 'cache-drop.done'

  script:
  """
  set -euo pipefail

  echo "Dropping WDK cache..."
  wdkCache -model SiteSearchData -drop
  echo "WDK cache dropped successfully"

  echo "Creating empty WDK cache..."
  wdkCache -model SiteSearchData -new
  echo "Empty WDK made successfully"  

  # Create sentinel file to track completion
  touch cache-drop.done
  """
}
