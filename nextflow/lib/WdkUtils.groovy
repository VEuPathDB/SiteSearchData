/**
 * Utility class for WDK server management in Nextflow processes
 *
 * Functions in this class are automatically available to all workflows
 * without needing explicit imports (via Nextflow's lib/ directory pattern)
 */
class WdkUtils {

  /**
   * Generates bash code to start a WDK server and wait for it to be ready
   *
   * @param port The port number for the server
   * @param logFile The log file path for server output
   * @param context Optional context message for logging (e.g., "for ApiCommon metadata")
   * @return Bash script snippet as a string
   */
  static String startWdkServer(port, logFile, context = '') {
    def contextMsg = context ? " ${context}" : ""

    return """\
    # Start WDK server on dedicated port in the background
    wdkServer SiteSearchData http://0.0.0.0:${port} &> ${logFile} &
    SERVER_PID=\$!

    # Wait for server to be ready
    echo "Waiting for WDK server to start on port ${port}${contextMsg}..."
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
    """.stripIndent()
  }

  /**
   * Generates bash code to stop the WDK server
   * @return Bash script snippet as a string
   */
  static String stopWdkServer() {
    return """\
    # Stop the server
    kill \$SERVER_PID || true
    """.stripIndent()
  }

  /**
   * Maps cohort name to Solr core name
   *
   * @param cohort The cohort name (Portal, ApiCommon, OrthoMCL, or EDA)
   * @return The corresponding Solr core name
   */
  static String getSolrCoreName(cohort) {
    def cohortToCoreMap = [
      'Portal': 'site_search',
      'ApiCommon': 'site_search',
      'OrthoMCL': 'orthosearch',
      'EDA': 'edasearch'
    ]

    def coreName = cohortToCoreMap[cohort]
    if (!coreName) {
      throw new Exception("Unknown cohort: ${cohort}. Must be one of: ${cohortToCoreMap.keySet().join(', ')}")
    }
    return coreName
  }
}
