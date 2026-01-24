#!/usr/bin/env nextflow
nextflow.enable.dsl=2

//--------------------------------------------------------------------------
// Param Checking
//--------------------------------------------------------------------------

if(!params.outputDir) {
  throw new Exception("Missing params.outputDir")
}

if(!params.dbLdapName) {
  throw new Exception("Missing params.dbLdapName (e.g., 'plasmo-inc-n')")
}

if(!params.numberOfOrganisms) {
  throw new Exception("Missing params.numberOfOrganisms")
}

if(!params.maxForks) {
  throw new Exception("Missing params.maxForks (degree of parallelism)")
}

//--------------------------------------------------------------------------
// Main Workflow
//--------------------------------------------------------------------------

workflow {
  // Define the list of projects to process
  projects = Channel.of('PlasmoDB', 'ToxoDB', 'HostDB', 'AmoebaDB',
                        'CryptoDB', 'FungiDB', 'GiardiaDB', 'MicrosporidiaDB',
                        'PiroplasmaDB', 'TriTrypDB', 'TrichDB', 'VectorBase')

  // Generate config files for each project
  configs = generateConfigs(projects, params.dbLdapName)

  // Run the workflow for each project
  results = runSiteSearchData(configs)
}

process generateConfigs {
  input:
    val projectId
    val dbLdapName

  output:
    tuple val(projectId), path('model-config.xml'), path('model.prop')

  script:
  """
  # Copy model-config.xml template and substitute APPDB_LDAP_CN
  cp ${projectDir}/Model/config/SiteSearchData/model-config.xml.tmpl model-config.xml
  sed -i 's/\$APPDB_LDAP_CN/${dbLdapName}/g' model-config.xml

  # Copy model.prop template and substitute PROJECT_ID
  cp ${projectDir}/Model/config/SiteSearchData/model.prop.tmpl model.prop
  sed -i 's/\$PROJECT_ID/${projectId}/g' model.prop
  """
}

process runSiteSearchData {
  container = 'veupathdb/site-search-data:1.2.0'
  containerOptions "-v ${params.outputDir}:/output"
  maxForks params.maxForks

  input:
    tuple val(projectId), path(modelConfig), path(modelProp)

  output:
    val projectId

  script:
  // Assign port based on parallel execution slot (task.index ranges from 0 to maxForks-1)
  def port = 9000 + task.index
  """
  mkdir -p /tmp/base_gus/gus_home/config/SiteSearchData
  mkdir -p /output/${projectId}

  cp ${modelConfig} /tmp/base_gus/gus_home/config/SiteSearchData/model-config.xml
  cp ${modelProp} /tmp/base_gus/gus_home/config/SiteSearchData/model.prop

  # Start WDK server on dedicated port in the background, logging to output dir
  wdkServer SiteSearchData http://0.0.0.0:${port} -cleanCacheAtStartup &> /output/${projectId}/server.log &
  SERVER_PID=\$!

  # Wait for server to be ready
  echo "Waiting for WDK server to start on port ${port}..."
  for i in {1..60}; do
    if curl -s http://localhost:${port} > /dev/null 2>&1; then
      echo "Server is ready on port ${port}"
      break
    fi
    sleep 2
  done

  # Run the dump script for ApiCommon sites, writing directly to mounted volume
  dumpApiCommonWdkBatchesForSolr --wdkServiceUrl "http://localhost:${port}" --targetDir /output/${projectId} --numberOfOrganisms ${params.numberOfOrganisms} &>> /output/${projectId}/dumper.log

  # Stop the server
  kill \$SERVER_PID || true
  """
}
