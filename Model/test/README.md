# Unit Tests
## test_siteSearchLoadBatch
This script tests `../bin/siteSearchLoadBatch`. If `siteSearchLoadBatch` is moved, this testing script must be updated to reflect its new path.

To run tests, do
```
./test_siteSearchLoadBatch [core_url]
```
where `core_url` is the URL to the Solr core to use for testing. For safety purposes, this script requires that the core used for testing does **not** already contain data.

If the Solr instance is secured by the basic authentication plugin, be sure to set the environment variables `SOLR_USER` and `SOLR_PASSWORD` accordingly.
