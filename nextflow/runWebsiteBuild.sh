#!/bin/bash
set -euo pipefail

EFFECTIVE_COHORT="${COHORT}"
if [[ "${PROJECT_ID}" == "UniDB" ]]; then
  EFFECTIVE_COHORT="Portal"
fi

CLEANUP_ARG=""
if [[ -n "${CLEANUP:-}" ]]; then
  CLEANUP_ARG="--cleanupOnExit $CLEANUP"
fi

CONFINED_ARG=""
if [[ "${UNCONFINED:-true}" == "true"  ]]; then
  CONFINED_ARG="--security-opt label=disable"
fi

nextflow run websiteBuildFlow.nf \
  --containerImage "docker.io/veupathdb/site-search-data:$IMAGE_BRANCH" \
  --envFile "$ENV_FILE" \
  --podmanRunOptions "--sysctl net.ipv6.conf.all.disable_ipv6=1 --network=pasta:\"--map-host-loopback=169.254.1.2\" --add-host=${SOLR_DOMAIN}:169.254.1.2 --add-host=${SITE_DOMAIN}:169.254.1.2 ${CONFINED_ARG}" \
  --outputDir "$OUTPUT_DIR/ssnextflow" \
  --siteBaseUrl "$SITE_BASE_URL" \
  --cohort "$EFFECTIVE_COHORT" \
  --projectId "$PROJECT_ID" \
  --solrUrl "$SOLR_URL" \
  $CLEANUP_ARG

