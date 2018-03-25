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
    stage('Test 11.2') {
      steps {
        sh '''export DB_VERSION=11.2
rm -f test/dummy/log/test.log
export MANAGEMENT_PACK_LICENCSE=diagnostics_and_tuning_pack
export JRUBY_OPTS=-J-Xmx1024m
rake TESTOPTS="-v" test
#rake test TEST=test/controllers/dragnet_controller_test.rb
# test.log mit in Mail spoolen bei Fehler
echo "######################## test.log des letzten Tests ##########################"
cat test/dummy/log/test.log'''
      }
    }
  }
}