The proposal is to load into solr the following two meta documents
a document of type "document-categories" describing the categorized listing.  
this document will be produced manually
it will have a field called "categories" that is of string type, and includes a JSON blob.
https://stackoverflow.com/questions/39392062/what-is-the-solr-field-type-for-storing-json-object/39404016
the JSON blob will have:
an array of categories.
each category will be an array of document-types.  
each document-type will have: 
document-type-id
display name.
if a wdk record:
record class urlSegment
text search urlSegment (unless we use a convention for this)
a set of documents of type "wdk-recordclass"
this set of documents will be produced programmatically (python) by reading the WDK model from a grizzly server running the SiteSearchData wdk model  
each document will have these fields
document-type of "wdk-recordclass"
record class urlSegment (this will be the same value as the document-type field in instances of this record in solr)
record class meta info in a JSON blob:
an array of {attribute name, attribute display name, is_summary_field, boost_factor}
an array of {table name, table display name, boost_factor}
(attributes and tables must be kept separate because of how we define our schema in solr)
(we can have a <property> in the SiteSearchData wdk model for each attribute indicating if it is a summary field)
(we can have an optional <property> for attributes and tables indicating non-unity boost factor)
