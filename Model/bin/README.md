The files in this directory are executable programs used to create solr-compatible json files, from various sources, and to load those files into solr. 

Each file has a help option explaining its usage in detail.

Here is a summary:
* `dumpQaWdkMetaBatches`
  * has a hard-coded list of genomics components, and calls `ssCreateWdkMetaBatch` for each one.  Accesses each QA site's REST service.
* `dumpWdkBatchesForSolr`
  * dumps pathways, compounds, organisms, datasets and popset isolates for a given component.  Connects to the component database found in $GUS_HOME/config/gus.config, and queries it to find the list of organisms to dump.  Connects to a running SiteSearchData wdk service to generate the reports.
* ssCreateDocumentCategoriesBatch
* ssCreateDocumentFieldsBatch
* ssCreateWdkMetaBatch
* ssCreateWdkRecordsBatch
* ssLoadBatch
* ssLoadMultipleBatches
