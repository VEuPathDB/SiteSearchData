# SiteSearchData
This project contains the fixings to produce data for a VEuPathDB site search solr core, and to load that data.

All data produced and loaded complies with the [VEuPathDB Site Search solr schema](https://github.com/VEuPathDB/SolrDeployment/blob/master/configsets/site-search/conf).

Its main pieces are:
* a dedicated [WDK model](/Model/lib/wdk) that describes the way we represent data from the component database as documents in solr
* a [set of programs](Model/bin) to create both data and metadata documents to load into solr (using that WDK model), and programs to do the loading.
* additional [hard-coded metadata](Model/data) to load that describes in solr the document types we have and their fields

(Please see those folders for detailed documentation.)

## Batches
 A batch:
* is housed in a directory of the form `solr-json-batch_xxxxxxxx_yyyyyyyy_nnnnnnnn` where:
  * `xxxxxxxx` is the batch type (eg, organism)
  * `yyyyyyyy` is the batch name (eg, pfal3D7)
  * `nnnnnnnn` is a timestamp in seconds since epoch
* has an arbitrary number of `zzzzzzzz.json` files (where `zzzzzzzz` is a document type name). These files contain documents with the data (such as Genes) to be loaded.  Each document has metadata describing the batch it was loaded in (batch type, name and timestamp).
* a single `batch.json` file.  This file has information describing the batch.  Its presence in solr indicates that the batch was successfully loaded.  Querying solr for these meta documents shows which batches are present in solr.
* a single `DONE` file


