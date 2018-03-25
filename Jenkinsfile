pipeline {
  agent any
  stages {
    stage('Prepare') {
      steps {
        sh 'rm -f Gemfile.lock'
        sh 'rm -rf client_info.store'
        sh 'rm -f Usage.log'
        sh 'rvm list'
        sh 'bundle install'
        sh 'rm -f test/dummy/log/test.log'
      }
    }
    stage('Test diagnostics_and_tuning_pack') {
      environment {
        MANAGEMENT_PACK_LICENCSE = 'diagnostics_and_tuning_pack'
      }
      parallel {
        stage('Test 11.2') {
          environment {
            DB_VERSION = '11.2'
          }
          steps {
            sh 'docker start oracle112'
            sleep 20
            sh 'rake TESTOPTS="-v" test'
          }
        }
        stage('Test 12.1') {
          environment {
            DB_VERSION = '12.1'
          }
          steps {
            sh 'docker start oracle121'
            sleep 20
            sh 'rake TESTOPTS="-v" test'
          }
        }
      }
    }
    stage('Test without tuning pack') {
      steps {
        sleep 1
      }
    }
  }
  environment {
    JRUBY_OPTS = '-J-Xmx1024m'
  }
}