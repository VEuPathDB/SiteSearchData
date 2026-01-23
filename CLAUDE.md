# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SiteSearchData produces and loads data for VEuPathDB site search Solr cores. It consists of a specialized WDK (Web Development Kit) model that represents component database data as Solr documents, along with programs to generate and load these documents.

The data complies with the [VEuPathDB Site Search solr schema](https://github.com/VEuPathDB/SolrDeployment/blob/master/configsets/site-search/conf).

## Architecture

### Core Components

1. **WDK Model** (`Model/lib/wdk/`)
   - Specialized WDK model describing how component database data is represented as Solr documents
   - Separated by cohort/project type:
     - `ApiCommon/` - Genomics sites (genes, ESTs, pathways, organisms, etc.)
     - `OrthoMCL/` - OrthoMCL-specific records (groups, sequences)
     - `EDA/` - EDA (Exploratory Data Analysis) sites
     - `Portal/` - Portal-specific records
     - `Shared/` - Shared records (datasets)
   - Each cohort has:
     - `siteSearchModel.xml` - Main model file (imports other XMLs)
     - `siteSearchRecords.xml` - Record class definitions
     - `*Queries.xml` - ID, vocab, attribute, and table queries

2. **Data Generation Scripts** (`Model/bin/`)
   - `dumpApiCommonWdkBatchesForSolr` - Dumps all genomics WDK record classes
   - `dumpOrthomclWdkBatchesForSolr` - Dumps OrthoMCL batches
   - `dumpEdaWdkBatchesForSolr` - Dumps EDA batches
   - `ssCreateWdkRecordsBatch` - Core batch creation (called by dump scripts)
   - `ssCreateDocumentCategoriesBatch` - Creates metadata batch for document types
   - `ssCreateDocumentFieldsBatch` - Creates metadata batch for document fields
   - `ssCreateWdkMetaBatch` - Creates batch for WDK searches metadata

3. **Data Loading Scripts** (`Model/bin/`)
   - `ssLoadBatch` - Loads a single batch into Solr with validation
   - `ssLoadMultipleBatches` - Recursively discovers and loads multiple batches
   - `ssCommitSuggesterIndex` - Commits the typeahead index

4. **Metadata** (`Model/data/`)
   - `documentTypeCategories.json` - Hard-coded metadata describing document types and categories
   - `nonWdkDocumentFields.json` - Field metadata for non-WDK documents (e.g., Jekyll documents)

5. **Configuration Templates** (`Model/config/`)
   - `gus.config.tmpl` - Template for GUS database configuration
   - `SiteSearchData/model.prop.tmpl` - Model properties template
   - `SiteSearchData/model-config.xml.tmpl` - Model database connections template

6. **Java Source** (`Model/src/main/java/org/eupathdb/sitesearch/`)
   - `wsfplugin/CommunityStudyIdsPlugin.java` - WSF plugin for community studies
   - `data/model/report/SolrLoaderReporter.java` - WDK reporter that generates Solr JSON

### Batch System

All data is dumped and loaded in **batches** to ensure validity and trackability. Each batch:
- Lives in a directory: `solr-json-batch_[batch-type]_[batch-name]_[timestamp]`
  - Example: `solr-json-batch_organism_pfal3D7_1234567890`
- Contains:
  - Multiple `[document-type].json` files with Solr documents
  - Single `batch.json` file describing the batch (metadata)
  - Single `DONE` file indicating completion
- Each document includes batch metadata (type, name, timestamp)

### WDK Model Rules (CRITICAL)

The Site Search WDK Model follows strict rules documented in `Model/lib/wdk/README.md`. Key requirements:

**Record Classes must:**
- Have exactly one associated `<Question>`
- Have `urlName` matching the parallel record class in the website's WDK model
- Include exactly one reporter: `SolrLoaderReporter`
- Use sentence case for `displayName`
- Have a `<propertyList>` with a "batch" property (from [enumsConfig.xml](https://github.com/VEuPathDB/SolrDeployment/blob/master/configsets/site-search/conf/enumsConfig.xml))
- Use only `<attributeQueryRef>`s and `<table>`s
- Include internal `project` attribute only if records are segmented by project in Solr
- Include internal `organismsForFilter` table only if searchable by organism
- Include internal `display_name` attribute

**QuerySets must:**
- Set `isCacheable="false"`

**AttributeQueryRefs must:**
- Only include `name` and `displayName` XML properties
- Never change `name` (invalidates UserDB strategies)
- Use sentence case for `displayName`
- May include property lists: `isSummary`, `isSubtitle`, `isSearchable`, `includeProjects`, `boost`

**Tables must:**
- Follow same rules as attributeQueryRefs
- Have `<columnAttribute>`s with only `name` property
- Only include text-searchable columns

**Questions must:**
- Have zero or one parameters

## Build and Deployment

### Building

```bash
# Maven build (compiles Java sources, packages JAR)
mvn clean install

# Ant build (installs to GUS_HOME)
ant SiteSearchData-Installation

# Docker build (builds container with dependencies)
make build
```

The build system depends on:
- FgpUtil (https://github.com/EuPathDB/FgpUtil.git)
- WDK (https://github.com/EuPathDB/WDK.git)
- WSF (https://github.com/EuPathDB/WSF.git)
- install (https://github.com/EuPathDB/install.git)

### Running Scripts

Scripts require GUS_HOME setup and the scripts directory in PATH:

```bash
export GUS_HOME=/path/to/gus_home
export PATH=$PATH:$GUS_HOME/bin
```

### Configuration

Before running, configure `$GUS_HOME/config/` with:
1. `gus.config` - Component database connection
2. `SiteSearchData/model-config.xml` - appDB, userDB, accountDB connections
3. `SiteSearchData/model.prop` - Model properties

Templates are in `Model/config/`.

### Testing

Unit test for `ssLoadBatch`:
```bash
cd Model/test
./test_ssLoadBatch [core_url]
```

Requires empty Solr core. Set `SOLR_USER` and `SOLR_PASSWORD` if using basic auth.

### Tagging

**IMPORTANT:** Create a new git tag every time the model is updated. This is required to rebuild the SiteSearchData container image via the `jenkins_presenter_updater` job.

## Common Workflows

### Dumping Data for a Site

```bash
# For genomics sites
dumpApiCommonWdkBatchesForSolr [organism_batch_name] [other_params]

# For OrthoMCL
dumpOrthomclWdkBatchesForSolr [params]

# For EDA sites
dumpEdaWdkBatchesForSolr [params]
```

### Creating Metadata Batches

```bash
# Document type categories
ssCreateDocumentCategoriesBatch [output_dir]

# Document fields
ssCreateDocumentFieldsBatch [wdk_service_url] [output_dir]

# WDK searches metadata
ssCreateWdkMetaBatch [site_url] [output_dir]
```

### Loading Data into Solr

```bash
# Single batch
ssLoadBatch [solr_core_url] [batch_dir] [--replace]

# Multiple batches (recursive discovery)
ssLoadMultipleBatches [solr_core_url] [root_dir]

# Commit suggester index
ssCommitSuggesterIndex [solr_core_url]
```

### Testing Loaded Data

```bash
# Test WDK record counts in Solr against component database
testSiteSearchWdkRecordCounts [site_url] [solr_core_url]

# Test all ApiCommon QA sites (must run from VEuPathDB server)
testApiCommonQaSites
```

## Local Development

See `local-loading-notes.adoc` for detailed instructions on:
- Setting up minimal GUS_HOME
- Running local Solr instance
- Loading batches from remote builds

## Dependencies

Maven dependencies include:
- WDK model and service
- FgpUtil (core, json, server)
- Jersey containers (Grizzly2, server)
- JSON processing
- Log4j

## File Locations

- WDK Model XMLs: `Model/lib/wdk/[cohort]/`
- Scripts: `Model/bin/`
- Java sources: `Model/src/main/java/org/eupathdb/sitesearch/`
- Metadata: `Model/data/`
- Config templates: `Model/config/`
- Tests: `Model/test/`
- Docker: `dockerfiles/`
