The files in this directory are executable programs used to create solr-compatible json files, from various sources, and to load those files into solr. 

Since all site search data is loaded into solr in trackable batches, these commands all deal in such batches. (See [SiteSearchData](../../../..))

Each file has a help option explaining its usage in detail.

Here is a summary:
* `dumpQaWdkMetaBatches`
  * calls `ssCreateWdkMetaBatch` for a hard-coded list of genomics components.  Accesses each component's QA site REST service.
* `dumpWdkBatchesForSolr`
  * dumps pathways, compounds, organisms, datasets and popset isolates for a given component.  Connects to the component database found in $GUS_HOME/config/gus.config, and queries it to find the list of organisms to dump.  Connects to a running SiteSearchData wdk service to generate the reports.
* `ssCreateDocumentCategoriesBatch`
  * creates a (metadata) batch describing the types of documents we will have in solr, and their categories.  Reads the [../data/documentTypeCategories.json](../data/documentTypeCategories.json) file and includes its contents in a `jsonblob` field in a `document-types` document.
* `ssCreateDocumentFieldsBatch`
  * creates a (metadata) batch describing 
* `ssCreateWdkMetaBatch`
* `ssCreateWdkRecordsBatch`
* `ssLoadBatch`
* `ssLoadMultipleBatches`
