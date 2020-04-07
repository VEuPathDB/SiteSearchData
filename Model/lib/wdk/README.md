# The WDK Model for Site Search Data

This folder contains the WDK model used to produce the data for site search.  This model was manually derived from the full genomics sites model (ApiCommonModel and EbrcModelCommon).  Each record class in the genomics sites model that should belongs in site search has a parallel record class in the SiteSearchData model.  The record classes here are much simplified, containing only attributes and tables (and table columns) that are useful to site search.

There are three reasons why an attribute or table column is included in the SiteSearchData model:
1. it has text that is valuable to search against.  For example, an EC number.
1. it has text that is valuable to display in site search results.  In most cases these are also valuable to search.
1. it is needed as an internal value by a service that reads solr, for example the [Site Search Service](https://github.com/VEuPathDB/SiteSearch) or the [User Comment Updater](fix.me)

The folder has these files:
* `siteSearchModel.xml` - the parent XML file.  Just imports the other files
* `siteSearchRecords.xml` - defines all the record classes.  __This file has many rules.  Read its documentation carefully__
* `*Queries.xml` - the ID, vocab, attribute and table queries for a particular site search data record.
