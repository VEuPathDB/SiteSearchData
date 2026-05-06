#!/bin/bash
set -euo pipefail

CLEANUP_ARG=""
if [[ -n "${CLEANUP:-}" ]]; then
  CLEANUP_ARG="--cleanupOnExit $CLEANUP"
fi

nextflow run nightlyFlow.nf \
  --containerImage "docker.io/veupathdb/site-search-data:$IMAGE_BRANCH" \
  --envFile "$ENV_FILE" \
  --podmanRunOptions "--sysctl net.ipv6.conf.all.disable_ipv6=1 --network=pasta:\"--map-host-loopback=169.254.1.2\" --add-host=${SOLR_DOMAIN}:169.254.1.2 --security-opt label=disable" \
  --outputDir "$OUTPUT_DIR/ssnextflow" \
  --solrBaseUrl "$SOLR_BASE_URL" \
  $CLEANUP_ARG

