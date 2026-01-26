.PHONY: build
build: project_home/FgpUtil project_home/install project_home/WDK project_home/WSF
	@docker build \
		-t veupathdb/site-search-data \
		-f project_home/SiteSearchData/dockerfiles/Dockerfile \
		--build-arg=GITHUB_USERNAME="$${GITHUB_USERNAME}" \
		--build-arg=GITHUB_TOKEN="$${GITHUB_TOKEN}" \
		.
