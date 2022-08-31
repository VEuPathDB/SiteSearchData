
# Rules of the Site Search WDK Model

This is a special WDK model used to serve data to the reporter that generates JSON files for Site Search.
    
It follows very specific rules needed for successful production of that data.
    
**ONLY EXPERTS should change the XML in these folders.**
    
Each record class must:
- have exactly one associated `<Question>`
- have an `urlName` that exactly matches the `urlName` of the parallel record class in the website's WDK model
- include exactly one reporter, the `SolrLoaderReporter`
- have a `displayName` using sentence case
- have a `<propertyList>` with a "batch" property, indicating what type of batch that record class should be bundled with
  - the allowed list of batch values comes from [enumsConfig.xml](https://github.com/VEuPathDB/SolrDeployment/blob/master/configsets/site-search/conf/enumsConfig.xml)
- should have only `<attributeQueryRef>`s and `<table>`s
- must include an internal `project` attribute if and only if in solr we should segment these records by project.  (These are records that cannot be segmented by organism, for example Pathways or News).
- must include an internal `organismsForFilter` table if and only if searches for this record can be filtered by organism(s).  (For, eg, Genes)
- must include an internal `display_name` attribute.  This is used when include `display_name` in the `<idAttribute name="primary_key">`
  
We want only one searchable `display_name`.  The primary key attriute is searchable, so if it includes `$$display_name$$` we make the original attribute `internal="true"`  (see the Dataset record for an example)
  
Each `<querySet>` must set `isCacheable="false"`.  No queries should set `isCacheable="true"`.
  
Each `<attributeQueryRef>` must:
- always and only include `name` and `displayName` as xml properties.
- never have its `name` changed.  Doing so will invalidate strategies in the UserDB.  (They are used as values in the `Fields` vocabulary parameter)
- the `displayName` should use sentence case
- may use a few special attributes that are labeled `internal=true`.  These serve special purposes in site search land, and are commented accordingly.  They are not exposed to end users.
  - `project`: for recordclasses that are stores in solr separately per project (eg pathways)
  - `organism`: for recordclasses that can be filtered on organism
  - `hyperlinkName`: a non-searchable attribute to use as text in the hyperlink for this recordclass in search results
- may include a `<propertyList name="isSummary">` with value `true` indicating that this field is used in the site search results UI to briefly describe this record
- may include a `<propertyList name="isSubtitle">` with value `true` indicating that this field is used in the site search results UI to briefly describe this record. (It is and displayed as a subtitle.)
- may include a `<propertyList name="isSearchable">` indicating, when `false`, that this field *can* be returned as a summary field (isSummary), but is *not* searchable.
- may include a `<propertyList name="includeProjects">` indicating which projects to include this field in.  Default is all, if absent.
  - We use this in the rare case that an attribute applies only to a few projects.  An example is Rodent Malaria Phenotype, which is only available in PlasmoDB.  By using this property we indicate that:
    - this field should only be included in solr documents of this specified projects
    - the Site Search UI should only show this field in the **Fields** filter option for the specified projects.
    - the WDK Text Search should only include this field in its **Fields to Search** parameter for the specified projects.
- may include a `<propertyList name="boost">` indicating a multiplier used to boost score of documents that match this field (default is 1)

Each `<table>` must follow the same rules as `attributeQueryRef>`s, plus:
- the table's `<columnAttribute>`s should include only the `name` xml property.  (The user will never see the display name or help, etc)
- the property `isSubtitle` is not applicable, because tables can't sensibly be a subtitle
- only include text-searchable columns (eg, no numbers)

Each `<Question>` must:
- have exactly zero or one parameters
- not bother with help (it would never been seen), and its displayName is irrelevant
