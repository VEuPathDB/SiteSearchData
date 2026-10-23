#!/usr/bin/env nextflow
nextflow.enable.dsl=2

//--------------------------------------------------------------------------
// Module Imports
//--------------------------------------------------------------------------

include { loadBatchesToSolr } from './modules/loadBatches'
//include { buildSuggester } from './modules/buildSuggester'

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

// Log files (written under params.outputDir) by the comment updater process
USER_COMMENT_LOG = 'usercomment.log'
APOLLO_COMMENT_LOG = 'apollocomment.log'

workflow {
  projects = Channel.of(
    ['ApiCommon', 'UniDB'],
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
  loadBatchesToSolr(dumpComplete, params.envFile)
    .map { cohort, projectId, batchCount ->
      // Collect results for summary
      loadResults << [projectId, batchCount]

      // Note: Portal uses ApiCommon Solr core, so map Portal -> ApiCommon
      def solrCohort = (cohort == 'Portal') ? 'ApiCommon' : cohort
      [solrCohort, projectId, batchCount]
    }
    .groupTuple(by: 0)
    .set { cohortGroups }

  // Update user and apollo comments.
  commentsComplete = commentUpdater(params.envFile)

  // Build suggester once per cohort
  // combine pairs every cohort with the single comments-done signal
  buildSuggester(cohortGroups.combine(commentsComplete))
}

workflow.onError {
  println "\n" + "=" * 80
  println "ERROR: Workflow execution failed!"
  println "=" * 80
  

  ErrorHandler.printCohortLogs(params.outputDir, ['ApiCommon', 'EDA'], params.cleanupOnExit, [USER_COMMENT_LOG, APOLLO_COMMENT_LOG])
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

process buildSuggester {
  errorStrategy 'terminate'

  input:
    tuple val(cohort), val(projectIds), val(batchCounts), val(complete)

  script:
  def coreName = WdkUtils.getSolrCoreName(cohort)
  def solrCoreUrl = "${params.solrBaseUrl}/${coreName}"
  def projectList = projectIds.join(', ')

  """
  set -euo pipefail

  echo "Building suggester index for ${cohort} cohort (${projectList})"
  echo "Solr URL: ${solrCoreUrl}"
  curl -f -s "${solrCoreUrl}/suggest?suggest.build=true" || { echo "ERROR: Failed to build suggester index"; exit 1; }
  echo "Suggester index built successfully for ${cohort}"
  """
}

process commentUpdater {
  errorStrategy 'terminate'
  containerOptions "-v ${params.outputDir}:/output --env-file ${params.envFile} -e SOLR_URL=${params.solrBaseUrl}/${WdkUtils.getSolrCoreName('ApiCommon')}"

  input:
    path(envFile)

  output:
    val('commentsDone')

  script:
  """
  set -euo pipefail

  echo "Running user comment updater"
  fgpJava org.veupathdb.sitesearch.usercomments.UserCommentUpdaterCli --doUpdate  &> /output/${USER_COMMENT_LOG}
  echo "Done user comment updater"

  echo "Running apollo comment updater"
  fgpJava org.veupathdb.sitesearch.usercomments.ApolloCommentUpdaterCli --doUpdate  &> /output/${APOLLO_COMMENT_LOG}
  echo "Done apollo comment updater"
  """
}
