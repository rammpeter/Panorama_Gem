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
    stage('Test') {
      environment {
        JRUBY_OPTS = '-J-Xmx1024m'
      }
      parallel {
        stage('Test 11.2') {
          environment {
            DB_VERSION = '11.2'
            MANAGEMENT_PACK_LICENCSE = 'diagnostics_and_tuning_pack'
          }
          steps {
            sh 'rake TESTOPTS="-v" test'
          }
        }
        stage('Test 12.1') {
          steps {
            sh 'docker start oracle121'
            sleep 20
            sh '''export DB_VERSION=12.1
rm -f test/dummy/log/test.log
export JRUBY_OPTS=-J-Xmx1024m
export MANAGEMENT_PACK_LICENCSE=diagnostics_and_tuning_pack
rake TESTOPTS="-v" test
# test.log mit in Mail spoolen bei Fehler
echo "######################## test.log des letzten Tests ##########################"
cat test/dummy/log/test.log'''
          }
        }
      }
    }
  }
}