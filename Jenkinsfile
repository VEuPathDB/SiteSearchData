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

  stage('build') {
    sh 'cp -rt $WORKSPACE $WORKSPACE/project_home/SiteSearchData/dockerfiles $WORKSPACE/project_home/SiteSearchData/config'
  }

  stage('package') {

    // set tag to branch if it isn't master
    if (env.BRANCH_NAME != 'master') {
      tag = "${env.BRANCH_NAME}"
    }

    withCredentials([usernameColonPassword(credentialsId: '0f11d4d1-6557-423c-b5ae-693cc87f7b4b', variable: 'HUB_LOGIN')]) {
      // build the release container, which copies the built gus_home into it
      sh 'podman build --format=docker -t site-search-data -f $WORKSPACE/project_home/SiteSearchData/dockerfiles/Dockerfile .'

      // push to dockerhub (for now)
      sh "podman push --creds \"$HUB_LOGIN\" site-search-data docker://docker.io/veupathdb/site-search-data:${tag}"
    }
  }
}
