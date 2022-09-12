@Library('pipelib')
import org.veupathdb.lib.Builder

node ('centos8') {

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
    sh 'cp -rt $WORKSPACE $WORKSPACE/project_home/SiteSearchData/dockerfiles $WORKSPACE/project_home/SiteSearchData/config'
  }

  def builder = new Builder(this)
  builder.buildContainers([
    [ name: 'site-search-data', dockerfile: 'dockerfiles/Dockerfile' ]
  ])

}
