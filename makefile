.PHONY: build
build:
	@docker build \
		-t veupathdb/site-search-data \
		-f project_home/SiteSearchData/dockerfiles/Dockerfile \
		--build-arg=GITHUB_USERNAME="$${GITHUB_USERNAME}" \
		--build-arg=GITHUB_TOKEN="$${GITHUB_TOKEN}" \
		.
