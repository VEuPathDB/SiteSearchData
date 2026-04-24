  #!/usr/bin/env nextflow

  process testSolrConnection {
      container 'docker.io/veupathdb/site-search-data:latest'

      output:
      stdout

      script:
      """
      curl "https://solr-sitesearch-load.local.apidb.org:8443/solr/site_search/select?q=batch-name:all&fq=document-type:(document-categories)&rows=50"
      """
  }

  workflow {
      testSolrConnection | view
  }
