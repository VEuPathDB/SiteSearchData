/**
 * Utility class for error handling in Nextflow workflows
 *
 * Functions in this class are automatically available to all workflows
 * without needing explicit imports (via Nextflow's lib/ directory pattern)
 */
class ErrorHandler {

  /**
   * Prints all .log files from specified cohort directories
   *
   * @param outputDir The base output directory
   * @param cohorts List of cohort names (e.g., ['ApiCommon', 'EDA', 'OrthoMCL'])
   */
  static void printCohortLogs(String outputDir, List<String> cohorts) {
    def output = new File(outputDir)

    if (!output.exists()) {
      println "Output directory not found: ${outputDir}"
      return
    }

    println "\n--- Searching for .log files in output directory ---"

    def totalLogCount = 0

    cohorts.each { cohort ->
      def cohortDir = new File("${outputDir}/${cohort}")
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
    println "\n" + "=" * 80
    println "End of error logs"
    println "=" * 80 + "\n"
  }
}
