pipeline {
  agent any
  stages {
    stage('prepare') {
      steps {
        sh '''rm -f Gemfile.lock
rm -rf client_info.store
rm -f Usage.log'''
        sh '''rvm list
bundle install'''
        sh '''docker start oracle112
docker start oracle121
docker start oracle121se'''
      }
    }
  }
}