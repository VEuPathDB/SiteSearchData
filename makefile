.PHONY: build
build: project_home/FgpUtil project_home/install project_home/WDK project_home/WSF
	@mkdir -p project_home/SiteSearchData
	@cp -rt project_home/SiteSearchData $(shell find . -maxdepth 1 -not -iname project_home -not -iname .git -not -iname .)
	docker build -t site-search-data -f project_home/SiteSearchData/dockerfiles/Dockerfile .

project_home/FgpUtil:
	git clone -q https://github.com/EuPathDB/FgpUtil.git project_home/FgpUtil
project_home/install:
	git clone -q https://github.com/EuPathDB/install.git project_home/install
project_home/WDK:
	git clone -q https://github.com/EuPathDB/WDK.git project_home/WDK
project_home/WSF:
	git clone -q https://github.com/EuPathDB/WSF.git project_home/WSF
