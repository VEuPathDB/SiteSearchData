#!/usr/bin/env nextflow
nextflow.enable.dsl=2

//--------------------------------------------------------------------------
// Load Batches to Solr Process
// Shared by nightlyFlow.nf and websiteBuildFlow.nf
//--------------------------------------------------------------------------

process loadBatchesToSolr {
  errorStrategy 'terminate'
  containerOptions "-v ${params.outputDir}:/output --env-file ${params.envFile} -e COHORT=${cohort} -e PROJECT_ID=${projectId}"

  publishDir "${params.outputDir}", mode: 'copy'

  input:
    tuple val(cohort), val(projectId)
    path(envFile)

  output:
    val projectId

  script:
  // Portal cohort outputs go under ApiCommon directory
  def outputCohort = (cohort == 'Portal') ? 'ApiCommon' : cohort

  // Get Solr core name for this cohort and append to base URL
  def coreName = WdkUtils.getSolrCoreName(cohort)
  def solrCoreUrl = "${params.solrUrl}/${coreName}"

  """
  set -euo pipefail

  echo "Loading batches to Solr for ${projectId}"
  echo "Cohort: ${cohort}"
  echo "Solr core: ${coreName}"
  echo "Solr URL: ${solrCoreUrl}"
  echo "Batch directory: /output/${outputCohort}/${projectId}"

  # Load batches into Solr
  ssLoadMultipleBatches ${solrCoreUrl} /output/${outputCohort}/${projectId} --replace &> /output/${outputCohort}/${projectId}/load.log

  echo "Batches loaded successfully for ${projectId}"
  """
}
