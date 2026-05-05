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

if(!params.solrBaseUrl) {
  throw new Exception("Missing params.solrBaseUrl (e.g., http://localhost:8983/solr)")
}

//--------------------------------------------------------------------------
// Main Workflow
//--------------------------------------------------------------------------

// Global variable to collect load results for summary
loadResults = []

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

  // Create batches for all projects
  dumpComplete = dumpBatches(projects, params.envFile)

  // Load batches and collect results
  loadBatchesToSolr(dumpComplete, params.envFile).subscribe { result ->
    loadResults << result
  }
}

workflow.onError {
  println "\n" + "=" * 80
  println "ERROR: Workflow execution failed!"
  println "=" * 80

  ErrorHandler.printCohortLogs(params.outputDir, ['ApiCommon', 'EDA'])
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
  // avoid collision with websiteBuildFlow
  def port = 9000 + task.index

  // Portal cohort outputs go under ApiCommon directory
  def outputCohort = (cohort == 'Portal') ? 'ApiCommon' : cohort

  """
  set -euo pipefail

  mkdir -p /output/${outputCohort}/${projectId}

  ${WdkUtils.startWdkServer(port, "/output/${outputCohort}/${projectId}/server.log")}

  echo "Creating community-datasets batch for ${projectId}"
  ssCreateWdkRecordsBatch community-datasets ${projectId} http://localhost:${port} /output/${outputCohort}/${projectId} &>> /output/${outputCohort}/${projectId}/dump.log

  ${WdkUtils.stopWdkServer()}
  """
}
