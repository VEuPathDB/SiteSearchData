#!/usr/bin/env nextflow
nextflow.enable.dsl=2

//--------------------------------------------------------------------------
// Module Imports
//--------------------------------------------------------------------------

include { loadBatchesToSolr } from './modules/loadBatches'

//--------------------------------------------------------------------------
// Param Checking
//--------------------------------------------------------------------------

if(!params.outputDir) {
  throw new Exception("Missing params.outputDir")
}

if(!params.envFile) {
  throw new Exception("Missing params.envFile")
}

if(!params.siteBaseUrl) {
  throw new Exception("Missing params.siteBaseUrl (e.g., https://plasmodb.org)")
}

if(!params.cohort) {
  throw new Exception("Missing params.cohort (e.g., ApiCommon)")
}

if(!params.projectId) {
  throw new Exception("Missing params.projectId (e.g., PlasmoDB, FungiDB, UniDB)")
}

if(!(params.solrUrl || params.solrBaseUrl)) {
  throw new Exception("Missing params.solrUrl (e.g., http://localhost:8983/solr/site_search) or params.solrBaseUrl (e.g., http://localhost:8983/solr)")
}


//--------------------------------------------------------------------------
// Main Workflow
//--------------------------------------------------------------------------

// Global variable to collect load results for summary
loadResults = []

workflow {
  // Create single-project channel based on parameter
  project = Channel.of([params.cohort, params.projectId])

  dumpComplete = dumpBatches(project, params.envFile)

  // Load batches and collect results
  loadBatchesToSolr(dumpComplete, params.envFile).subscribe { result ->
    loadResults << result
  }
}

workflow.onError {
  println "\n" + "=" * 80
  println "ERROR: Workflow execution failed!"
  println "=" * 80

  ErrorHandler.printCohortLogs(params.outputDir, ['ApiCommon', 'EDA', 'OrthoMCL'], params.cleanupOnExit)
}

workflow.onComplete {
  WorkflowSummary.printCompletionSummary(workflow, params, loadResults)
}

process dumpBatches {
  errorStrategy 'finish'
  containerOptions "-v ${params.outputDir}:/output --env-file ${params.envFile} -e COHORT=${cohort} -e PROJECT_ID=${projectId}"

  input:
    tuple val(cohort), val(projectId)
    path(envFile)

  output:
    tuple val(cohort), val(projectId)

  script:
  // Assign port based on parallel execution slot (task.index ranges from 0 to maxForks-1)
  // avoid collision with nightlyFlow
  def port = 9100 + task.index

  // Portal cohort outputs go under ApiCommon directory
  def outputCohort = (cohort == 'Portal') ? 'ApiCommon' : cohort

  """
  set -euo pipefail

  mkdir -p /output/${outputCohort}/${projectId}

  ${WdkUtils.startWdkServer(port, "/output/${outputCohort}/${projectId}/server.log")}

  # Create dataset-presenter batch for this project
  if [ "${outputCohort}" != 'OrthoMCL' ]; then
    echo "Creating dataset-presenter batch for ${projectId}"
    ssCreateWdkRecordsBatch dataset-presenter ${projectId} http://localhost:${port} /output/${outputCohort}/${projectId} &>> /output/${outputCohort}/${projectId}/presenter.log
  fi

  # Create WDK metadata batch for this project
  if [ "${outputCohort}" != 'EDA' ]; then
    echo "Creating WDK meta batch for ${projectId}"
    ssCreateWdkMetaBatch ${params.siteBaseUrl}/service/ ${projectId} /output/${outputCohort}/${projectId} &>> /output/${outputCohort}/${projectId}/wdkmeta.log
  fi
  
  ${WdkUtils.stopWdkServer()}
  """
}
