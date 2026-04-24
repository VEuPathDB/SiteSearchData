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

if(!params.projectId) {
  throw new Exception("Missing params.projectId (e.g., PlasmoDB, FungiDB, UniDB)")
}

if(!params.solrUrl) {
  throw new Exception("Missing params.solrUrl (e.g., http://localhost:8983/solr)")
}

//--------------------------------------------------------------------------
// Helper Functions
//--------------------------------------------------------------------------

// Map projectId to cohort
def getCohort(projectId) {
  // Project to cohort mapping
  def projectToCohort = [
    'UniDB': 'Portal',
    'FungiDB': 'ApiCommon',
    'TriTrypDB': 'ApiCommon',
    'PlasmoDB': 'ApiCommon',
    'VectorBase': 'ApiCommon',
    'ToxoDB': 'ApiCommon',
    'HostDB': 'ApiCommon',
    'AmoebaDB': 'ApiCommon',
    'CryptoDB': 'ApiCommon',
    'GiardiaDB': 'ApiCommon',
    'MicrosporidiaDB': 'ApiCommon',
    'PiroplasmaDB': 'ApiCommon',
    'TrichDB': 'ApiCommon'
  ]

  def cohort = projectToCohort[projectId]
  if (!cohort) {
    throw new Exception("Unknown projectId: ${projectId}. Must be one of: ${projectToCohort.keySet().join(', ')}")
  }
  return cohort
}

//--------------------------------------------------------------------------
// Main Workflow
//--------------------------------------------------------------------------

workflow {
  // Create single-project channel based on parameter
  def cohort = getCohort(params.projectId)
  project = Channel.of([cohort, params.projectId])

  dumpComplete = dumpBatches(project, params.envFile)

  loadBatchesToSolr(dumpComplete, params.envFile)
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
  mkdir -p /output/${outputCohort}/${projectId}

  ${WdkUtils.startWdkServer(port, "/output/${outputCohort}/${projectId}/server.log")}

  # Create dataset-presenter batch for this project
  echo "Creating dataset-presenter batch for ${projectId}"
  ssCreateWdkRecordsBatch dataset-presenter ${projectId} http://localhost:${port} /output/${outputCohort}/${projectId} &>> /output/${outputCohort}/${projectId}/presenter.log

  # Create WDK metadata batch for this project
  echo "Creating WDK meta batch for ${projectId}"
  ssCreateWdkMetaBatch ${params.siteBaseUrl}/service/ ${projectId} /output/${outputCohort}/${projectId} &>> /output/${outputCohort}/${projectId}/presenter.log

  ${WdkUtils.stopWdkServer()}
  """
}
