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

if(!params.solrUrl) {
  throw new Exception("Missing params.solrUrl (e.g., http://localhost:8983/solr)")
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

  // Create batches for all projects
  dumpComplete = dumpBatches(projects, params.envFile)

//  loadBatchesToSolr(dumpComplete, params.envFile)
}

workflow.onError {
  println "\n" + "=" * 80
  println "ERROR: Workflow execution failed!"
  println "=" * 80

  // Search for .log files in output directory for specified cohorts
  def outputDir = new File("${params.outputDir}")
  def cohorts = ['ApiCommon', 'EDA']

  if (outputDir.exists()) {
    println "\n--- Searching for .log files in output directory ---"
    def totalLogCount = 0

    cohorts.each { cohort ->
      def cohortDir = new File("${params.outputDir}/${cohort}")
      if (cohortDir.exists()) {
        println "\n>> Checking ${cohort} logs..."
        def logCount = 0
        cohortDir.eachFileRecurse { file ->
          if (file.name.endsWith('.log')) {
            logCount++
            totalLogCount++
            println "\n" + "=" * 80
            println "LOG FILE: ${file.path}"
            println "=" * 80
            try {
              println file.text
            } catch (Exception e) {
              println "Error reading file: ${e.message}"
            }
          }
        }
        if (logCount == 0) {
          println "   No .log files found for ${cohort}"
        } else {
          println "   Found ${logCount} log file(s) for ${cohort}"
        }
      } else {
        println "\n>> ${cohort} directory not found: ${cohortDir.path}"
      }
    }

    println "\nTotal log files found: ${totalLogCount}"
  } else {
    println "Output directory not found: ${outputDir.path}"
  }

  println "\n" + "=" * 80
  println "End of error logs"
  println "=" * 80 + "\n"
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
  mkdir -p /output/${outputCohort}/${projectId}

  ${WdkUtils.startWdkServer(port, "/output/${outputCohort}/${projectId}/server.log")}

  echo "Creating community-datasets batch for ${projectId}"
  ssCreateWdkRecordsBatch community-datasets ${projectId} http://localhost:${port} /output/${outputCohort}/${projectId} &>> /output/${outputCohort}/${projectId}/presenter.log

  ${WdkUtils.stopWdkServer()}
  """
}
