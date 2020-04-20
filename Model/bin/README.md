The files in this directory are executable programs used to create solr-compatible json files, from various sources, and to load those files into solr. 

Since all site search data is loaded into solr in trackable batches, these commands all deal in such batches. (See [SiteSearchData](../../../..))

Each file has a help option explaining its usage in detail.

Here is a summary:
* `dumpQaWdkMetaBatches`
  * calls `ssCreateWdkMetaBatch` for a hard-coded list of genomics components.  Accesses each component's QA site REST service.
* `dumpWdkBatchesForSolr`
  * dumps pathways, compounds, organisms, datasets and popset isolates for a given component.  Connects to the component database found in $GUS_HOME/config/gus.config, and queries it to find the list of organisms to dump.  Connects to a running SiteSearchData wdk service to generate the reports.
* `ssCreateDocumentCategoriesBatch`
  * creates a (metadata) batch describing the types of documents we will have in solr, and their categories.  Reads the [../data/documentTypeCategories.json](../data/documentTypeCategories.json) file and includes its contents in a `jsonblob` field in a `document-types.json` solr-ready file.  This metadata is used by the SiteSearchService to form its solr queries, and by the web client to format the left **Filter results** panel.
* `ssCreateDocumentFieldsBatch`
  * creates a (metadata) batch describing the fields in each solr document.  Queries the SiteSearchData WDK Model (via a WDK service running that model) to discover the fields (attributes and tables) in each record type, and their properties.  Also reads the [../data/nonWdkDocumentFields.json](../data/nonWdkDocumentFields.json) file to discover field metadata for documents that are not supplied by the SiteSearchData WDK model (e.g., Jekyll documents).  Writes this information to a `document-fields.json` solr-ready file.  This metadata is used by the SiteSearchService to form its solr queries, and by the web client to format the left **Filter results** panel.
* `ssCreateWdkMetaBatch`
  * creates a batch describing meta information about the genomics sites WDK model.  So far this includes the WDK searches in the genomics model.  Queries the QA site for the specified component.  Writes this information to a `wdkmeta.json` solr-ready file.  This information is used for standard Site Search Service searches.
* `ssCreateWdkRecordsBatch`
  * creates a batch describing wdk records.  Uses the SiteSearchData WDK Model (via a WDK service running that model) to run WDK reports (the SolrJsonReporter) to dump the wdk records in solr-ready json format.  Is parameterized by a batch-type, and includes only record-types from the SiteSearchData model that have that batch-type as a property.  For example, the batch-type "organism" includes Genes, ESTs and Genomic Sequences.
* `ssLoadBatch`
  * loads a batch of files into solr.  Validates the batch, ensuring that all document files contain only documents with the same batch type, name and timestamp as is found in the batch's `batch.json` file.  If a batch of this type, name and timestamp is already in solr, does not load the batch.  If a batch of this type and name, but a different timestamp, is in solr, throws an error, unless the `--replace` flag is set; if set, it replaces the batch in solr.
  * this script has a testing script located at [SiteSearchData/Model/test/test_ssLoadBatch](SiteSearchData/Model/test/test_ssLoadBatch). Run the testing script after making any changes to this one.
* `ssLoadMultipleBatches`
  * reads a directory structure and recursively discovers solr batch directories.  For each one, calls `ssLoadBatch`.
