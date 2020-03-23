node ('centos8') {

    // default tag to latest, only override if branch isn't master.  This
    // allows the tag to work outside of multibranch (it will just always be
    // latest in that case)
    def tag = "latest"

    stage('checkout') {
        dir('project_home/install') {
           checkout([$class: 'GitSCM',
           branches: [[name: '*/master']], 
           doGenerateSubmoduleConfigurations: false, 
           extensions: [], 
           submoduleCfg: [], 
           userRemoteConfigs: [[url: 'https://github.com/EuPathDB/install.git']]]
           )
        }

        dir('project_home/FgpUtil') {
           checkout([$class: 'GitSCM',
           branches: [[name: '*/master']], 
           doGenerateSubmoduleConfigurations: false, 
           extensions: [], 
           submoduleCfg: [], 
           userRemoteConfigs: [[url: 'https://github.com/EuPathDB/FgpUtil.git']]]
           )
        }

        dir('project_home/SiteSearchData') {
           checkout([$class: 'GitSCM',
           branches: [[name: env.BRANCH_NAME ]],
           doGenerateSubmoduleConfigurations: false, 
           extensions: [], 
           submoduleCfg: [], 
           userRemoteConfigs: [[url: 'https://github.com/EuPathDB/SiteSearchData.git']]]
           )
        }
        dir('project_home/WDK') {
           checkout([$class: 'GitSCM',
           branches: [[name: '*/master']],
           doGenerateSubmoduleConfigurations: false, 
           extensions: [], 
           submoduleCfg: [], 
           userRemoteConfigs: [[url: 'https://github.com/EuPathDB/WDK.git']]]
           )
        }
        dir('project_home/WSF') {
           checkout([$class: 'GitSCM',
           branches: [[name: '*/master']],
           doGenerateSubmoduleConfigurations: false, 
           extensions: [], 
           submoduleCfg: [], 
           userRemoteConfigs: [[url: 'https://github.com/EuPathDB/WSF.git']]]
           )
        }


    }

    stage('setup') {
        // need dummy gus.config
        sh 'mkdir -p gus_home/config'
        sh 'cp project_home/install/gus.config.sample gus_home/config/gus.config'

        // sadly, can't find another good way to get this into the build context
        sh 'cp project_home/SiteSearchData/dockerfiles/entrypoint.sh .'

        // create /tmp/.m2 for build caching
        sh 'mkdir /tmp/.m2/ || true'

        // only for debugging purposes
        sh 'env'
    }

    stage('build') {
        // build build container, could be removed it there is one made generally available
        sh 'podman build -t build_container_ssd -f $WORKSPACE/project_home/SiteSearchData/dockerfiles/Dockerfile.build .'
        // TODO: get build container pushed properly

        // build the service inside the build_container
        sh 'podman run --rm -v /tmp/.m2:/root/.m2:Z -v $WORKSPACE:/tmp/base_gus:Z --name builder build_container_ssd bld SiteSearchData'
        }

    stage('package') {

        // set tag to branch if it isn't master
        if (env.BRANCH_NAME != 'master') {
           tag = "${env.BRANCH_NAME}"
         }

      withCredentials([usernameColonPassword(credentialsId: '0f11d4d1-6557-423c-b5ae-693cc87f7b4b', variable: 'HUB_LOGIN')]) {
        // build the release container, which copies the built gus_home into it
	sh 'podman build --format=docker -t site-search-data -f $WORKSPACE/project_home/SiteSearchData/dockerfiles/Dockerfile.release .'

        // push to dockerhub (for now)
        sh "podman push --creds \"$HUB_LOGIN\" site-search-data docker://docker.io/veupathdb/site-search-data:${tag}"
        }
      }

    }
