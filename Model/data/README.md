These folders contain two files that manually describe metadata for site search.
* `documentTypeCategories`
  * describes and categorizes all document types we load into solr
  * document types are nested under their category.  (Categories are displayed in the **Filter results** panel in the UI.)
  * the properties in the json are self-evident, except:
    * `id` must agree with document-type in the solr json, and the recordclass name in the SiteSearchData WDK model (if a wdk doc)
    * `wdkSearchUrlName` is the urlName of the text search in the genomics site WDK model that will find wdk records of the same type as this document.  It is required for wdk document types, and must be absent for non-wdk document types
* `nonWdkDocumentFields`
  * describes the fields of all document types not provided by the SiteSearchData WDK Model.  (We get the latter by querying the WDK)
  * the properties in the json are self-evident, and have the same meaning as in, e.g., [ApiCommon/siteSearchRecords.xml](../lib/wdk/ApiCommon/siteSearchRecords.xml)
  
