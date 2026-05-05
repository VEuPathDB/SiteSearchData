/**
 * Utility class for printing workflow completion summaries
 *
 * Functions in this class are automatically available to all workflows
 * without needing explicit imports (via Nextflow's lib/ directory pattern)
 */
class WorkflowSummary {

  /**
   * Prints a standardized workflow completion summary
   *
   * @param workflow The Nextflow workflow object
   * @param params The workflow parameters object
   * @param loadResults Channel/Collection of load results (tuples of [projectId, batchCount])
   */
  static void printCompletionSummary(workflow, params, loadResults) {
    println "---------------------------"
    println "Pipeline execution summary"
    println "---------------------------"
    println "Completed at: ${workflow.complete}"
    println "Duration    : ${workflow.duration}"
    println "Success     : ${workflow.success ? 'OK' : 'FAIL'}"

    // Calculate project and batch statistics from load results
    if (loadResults) {
      def projectCount = 0
      def totalBatches = 0

      loadResults.each { result ->
        if (result instanceof List && result.size() == 2) {
          projectCount++
          totalBatches += result[1] as Integer
        }
      }

      println "\nProjects processed: ${projectCount}"
      println "Total batches loaded: ${totalBatches}"
    }

    // Handle cleanup if requested
    if (params.cleanupOnExit) {
      def outputDir = new File(params.outputDir)
      if (outputDir.exists()) {
        println "\nCleaning up outputDir: ${params.outputDir}"
        outputDir.deleteDir()
        println "Deleted: ${params.outputDir}"
      }
    }
  }
}
