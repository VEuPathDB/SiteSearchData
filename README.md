# SiteSearchData
This project contains the fixings to produce data for a VEuPathDB site search solr core, and to load that data.

All data produced and loaded complies with the [VEuPathDB Site Search solr schema](https://github.com/VEuPathDB/SolrDeployment/blob/master/configsets/site-search/conf).

Its main pieces are:
* a dedicated [WDK model](/Model/lib/wdk) that describes the way we represent data from the component database as documents in solr
* a [set of programs](Model/bin) to create both data and metadata documents to load into solr (using that WDK model), and programs to do the loading.
* additional [hard-coded metadata](Model/data) to load that describes in solr the document types we have and their fields


