#!/usr/bin/env nextflow
nextflow.enable.dsl=2

//--------------------------------------------------------------------------
// Param Checking
//--------------------------------------------------------------------------

if(!params.outputDir) {
  throw new Exception("Missing params.outputDir")
}

if(!params.envFile) {
  throw new Exception("Missing params.envFile")
}

if(!params.dbName) {
  throw new Exception("Missing params.dbName (e.g., 'plasmo-inc-n')")
}

if(!params.numberOfOrganisms) {
  throw new Exception("Missing params.numberOfOrganisms")
}

//--------------------------------------------------------------------------
// Main Workflow
//--------------------------------------------------------------------------

workflow {
  // Define projects grouped by cohort
  // Each tuple is: [cohort, projectId]
  projects = Channel.of(
    ['ApiCommon', 'PlasmoDB'],
    ['ApiCommon', 'ToxoDB'],
    ['ApiCommon', 'HostDB'],
    ['ApiCommon', 'AmoebaDB'],
    ['ApiCommon', 'CryptoDB'],
    ['ApiCommon', 'FungiDB'],
    ['ApiCommon', 'GiardiaDB'],
    ['ApiCommon', 'MicrosporidiaDB'],
    ['ApiCommon', 'PiroplasmaDB'],
    ['ApiCommon', 'TriTrypDB'],
    ['ApiCommon', 'TrichDB'],
    ['ApiCommon', 'VectorBase'],
    ['OrthoMCL', 'OrthoMCL'],
    ['EDA', 'ClinEpiDB'],
    ['EDA', 'MicrobiomeDB']
  )

  projects = Channel.of(
    ['ApiCommon', 'PlasmoDB']
  )

  // Get unique cohorts for metadata batch creation
  // Use a representative project from each cohort for config generation
  metadataCohorts = Channel.of(
    ['ApiCommon', 'PlasmoDB'],   // Use PlasmoDB as representative for ApiCommon
    ['OrthoMCL', 'OrthoMCL'],
    ['EDA', 'ClinEpiDB']         // Use ClinEpiDB as representative for EDA
  )

  // Generate config files for each project
  configs = generateConfigs(projects, params.dbName)

  // Generate config files for metadata batches
  metadataConfigs = generateMetaConfigs(metadataCohorts, params.dbName)

  // Create metadata batches for each cohort (runs in parallel with project dumps)
  createMetadataBatches(metadataConfigs, params.envFile)

  // Run the workflow for each project
  results = runSiteSearchData(configs, params.envFile)
}

process generateConfigs {
  input:
    tuple val(cohort), val(projectId)
    val dbName

  output:
    tuple val(cohort), val(projectId), path('gus.config'), path('model-config.xml'), path('model.prop')

  script:
  """
  # Generate gus.config for Postgres
  cat > gus.config <<EOF
# provide connection info for the application database.
# this is used by perl scripts that are part of dumping/loading
dbiDsn=dbi:Pg:host=\${DB_HOST};port=\${DB_PORT};dbname=${dbName}
databaseLogin=\${DB_LOGIN}
databasePassword=\${DB_PASSWORD}
perl=/usr/bin/perl
EOF

  # Copy model-config.xml template and substitute APPDB_LDAP_CN
  cp ${projectDir}/Model/config/SiteSearchData/model-config.xml.tmpl model-config.xml
  sed -i 's/\$APPDB_LDAP_CN/${dbName}/g' model-config.xml

  # Copy model.prop template and substitute PROJECT_ID
  cp ${projectDir}/Model/config/SiteSearchData/model.prop.tmpl model.prop
  sed -i 's/\$PROJECT_ID/${projectId}/g' model.prop
  """
}

process generateMetaConfigs {
  input:
    tuple val(cohort), val(projectId)
    val dbName

  output:
    tuple val(cohort), val(projectId), path('gus.config'), path('model-config.xml'), path('model.prop')

  script:
  """
  # Generate gus.config for Postgres
  cat > gus.config <<EOF
# provide connection info for the application database.
# this is used by perl scripts that are part of dumping/loading
dbiDsn=dbi:Pg:host=\${DB_HOST};port=\${DB_PORT};dbname=${dbName}
databaseLogin=\${DB_LOGIN}
databasePassword=\${DB_PASSWORD}
perl=/usr/bin/perl
EOF

  # Copy model-config.xml template and substitute APPDB_LDAP_CN
  cp ${projectDir}/Model/config/SiteSearchData/model-config.xml.tmpl model-config.xml
  sed -i 's/\$APPDB_LDAP_CN/${dbName}/g' model-config.xml

  # Copy model.prop template and substitute PROJECT_ID
  cp ${projectDir}/Model/config/SiteSearchData/model.prop.tmpl model.prop
  sed -i 's/\$PROJECT_ID/${projectId}/g' model.prop
  """
}

process createMetadataBatches {
  containerOptions "-v ${params.outputDir}:/output"
  errorStrategy 'ignore'

  input:
    tuple val(cohort), val(projectId), path(gusConfig), path(modelConfig), path(modelProp)
    path(envFile)

  output:
    val cohort

  script:
  // Use ports 8900+ for metadata servers (separate from project dump ports 9000+)
  // task.index assigns unique port per parallel execution slot
  def port = 8900 + task.index
  """
  source $envFile

  mkdir -p /output/metadata/${cohort}

  cp ${gusConfig} \${GUS_HOME}/config/gus.config
  cp ${modelConfig} \${GUS_HOME}/config/SiteSearchData/model-config.xml
  cp ${modelProp} \${GUS_HOME}/config/SiteSearchData/model.prop

  # Start WDK server on dedicated port in the background
  wdkServer SiteSearchData http://0.0.0.0:${port} -cleanCacheAtStartup &> /output/metadata/${cohort}/server.log &
  SERVER_PID=\$!

  # Wait for server to be ready
  echo "Waiting for WDK server to start on port ${port} for ${cohort} metadata..."
  for i in {1..60}; do
    if curl -s http://localhost:${port} > /dev/null 2>&1; then
      echo "Server is ready on port ${port}"
      break
    fi
    sleep 2
  done

  # Create document categories batch
  echo "Creating document categories batch for ${cohort}"
  ssCreateDocumentCategoriesBatch ${cohort} /output/metadata/${cohort} &> /output/metadata/${cohort}/docCat.log

  # Create document fields batch
  echo "Creating document fields batch for ${cohort}"
  ssCreateDocumentFieldsBatch http://localhost:${port} ${cohort} /output/metadata/${cohort} &> /output/metadata/${cohort}/docField.log

  # Stop the server
  kill \$SERVER_PID || true
  """
}

process runSiteSearchData {
  containerOptions "-v ${params.outputDir}:/output"
  errorStrategy 'ignore'

  input:
    tuple val(cohort), val(projectId), path(gusConfig), path(modelConfig), path(modelProp)
    path(envFile)

  output:
    val projectId

  script:
  // Assign port based on parallel execution slot (task.index ranges from 0 to maxForks-1)
  def port = 9000 + task.index

  // Select appropriate dump script and arguments based on cohort
  def dumpScript
  def dumpArgs
  if (cohort == 'ApiCommon') {
    dumpScript = "dumpApiCommonWdkBatchesForSolr"
    dumpArgs = "--wdkServiceUrl \"http://localhost:${port}\" --targetDir /output/${projectId} --numberOfOrganisms ${params.numberOfOrganisms}"
  } else if (cohort == 'OrthoMCL') {
    dumpScript = "dumpOrthomclWdkBatchesForSolr"
    dumpArgs = "--wdkServiceUrl \"http://localhost:${port}\" --targetDir /output/${projectId}"
  } else if (cohort == 'EDA') {
    dumpScript = "dumpEdaWdkBatchesForSolr"
    dumpArgs = "--wdkServiceUrl \"http://localhost:${port}\" --targetDir /output/${projectId}"
  }

  """
  source $envFile

  mkdir -p /output/${projectId}

  cp ${gusConfig} \${GUS_HOME}/config/gus.config
  cp ${modelConfig} \${GUS_HOME}/config/SiteSearchData/model-config.xml
  cp ${modelProp} \${GUS_HOME}/config/SiteSearchData/model.prop

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

  # Run the appropriate dump script based on cohort
  echo "Running ${dumpScript} for ${cohort} cohort, project ${projectId}"
  ${dumpScript} ${dumpArgs} &>> /output/${projectId}/dumper.log

  # Stop the server
  kill \$SERVER_PID || true
  """
}
