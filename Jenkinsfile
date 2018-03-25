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
      }
    }
  }
}