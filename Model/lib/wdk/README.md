
# Rules of the Site Search WDK Model

This is a special WDK model used to serve data to process that generates JSON files for Site Search.
    
It follows very specific rules needed for successful production of that data.
    
**ONLY EXPERTS should change the XML in these folders.**
    
Each record class must:
- have exactly one associated `<Question>`
- have an `urlName` that exactly matches the `urlName` of the parallel record class in the website's WDK model
- include exactly one reporter, the `SolrLoaderReporter`
- have a `displayName` using sentence case
- have a `<propertyList>` with a "batch" property, indicating what type of batch that record class should be bundled with
- should have only `<attributeQueryRef>`s and `<table>`s
- might include an internal `project` attribute if in solr we should segment these records by project
- might include an internal `organismsForFilter` table if searches for this record can be filtered by organism(s)
- might include an internal `display_name` attribute.  This is used when we need to include display_name in the primary key attribute.
  
We want only one searchable `display_name`, so we make the original attribute `internal="true"`  (see the Dataset record for an example)
  
Each `<querySet>` must set `isCacheable="false"`.  No queries should set isCacheable to true.
  
Each `<attributeQueryRef>` must:
- always and only include `name` and `displayName`.
- never have its name changed.  Doing so will invalidate strategies in the UserDB.  (They are used as parameter values)
- the `displayName` should use sentence case
- may use a few special attributes are labeled `internal=true`.  These serve special purposes in site search land, and are commented accordingly.  They are not exposed to end users in presentations of searchable fields.
  - `project`: for recordclasses that stored in solr separately per project (eg pathways)
  - `organism`: for recordclasses that can be filtered on organism
  - `hyperlinkName`: non-searchable attribute to use as text in the hyperlink for this recordclass in search results
- may include a `<propertyList>` for `isSummary` indicating that this field is used in the UI to briefly describe this record
- may include a `<propertyList>` for `isSubtitle` indicating that this field is used in the UI to briefly describe this record, and displays as a subtitle
- may include a `<propertyList>` for `isSearchable` indicating, when 'false', that this field can be returned as a summary field (isSummary), but is not searchable.
- may include a `<propertyList>` for `includeProjects` indicating which projects to include this field in.  default is all, if absent
- may include a `<propertyList>` for `boost` indicating a multiplier used to boost score of documents that match this field (default is 1)

Each `<table>` must follow the same rules as `attributeQueryRef>`s, plus:
- the table's `<columnAttribute>`s should include only name.  (The user will never see their display name or help, etc)
- property `isSubtitle` is not applicable, because tables can't sensibly be a subtitle
- only include text-searchable columns (no numbers, eg)

Each `<Question>` must:
- have exactly zero or one parameters
- not bother with help (it would never been seen), and its displayName is irrelevant
