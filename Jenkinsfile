pipeline {
  agent any
  environment {
    JRUBY_OPTS = '-J-Xmx1024m'
  }
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

    stage('Docker start 12.1') {
      steps {
         sh 'docker start oracle121'
         sleep 20
       }
    }
    stage('Test 12.1 diagnostics_and_tuning_pack') {
      environment {
        DB_VERSION = '12.1'
        MANAGEMENT_PACK_LICENSE = 'diagnostics_and_tuning_pack'
      }
      steps {
         sh 'rake TESTOPTS="-v" test'
      }
    }
    stage('Test 12.1 without tuning pack') {
      environment {
        DB_VERSION = '12.1'
        MANAGEMENT_PACK_LICENSE = 'diagnostics_pack'
      }
      steps {
         sh 'rake TESTOPTS="-v" test'
      }
    }
    stage('Test 12.1 without diagnostics and tuning pack') {
      environment {
        DB_VERSION = '12.1'
        MANAGEMENT_PACK_LICENSE = 'none'
      }
      steps {
         sh 'rake TESTOPTS="-v" test'
      }
    }
    stage('Docker stop 12.1') {
      steps {
         sh '#docker stop oracle121'
         sleep 20
       }
    }

    stage('Docker start 11.2') {
      steps {
         sh 'docker start oracle112'
         sleep 20
       }
    }
    stage('Test 11.2 diagnostics_and_tuning_pack') {
      environment {
        DB_VERSION = '11.2'
        MANAGEMENT_PACK_LICENSE = 'diagnostics_and_tuning_pack'
      }
      steps {
         sh 'rake TESTOPTS="-v" test'
      }
    }
    stage('Test 11.2 without tuning pack') {
      environment {
        DB_VERSION = '11.2'
        MANAGEMENT_PACK_LICENSE = 'diagnostics_pack'
      }
      steps {
         sh 'rake TESTOPTS="-v" test'
      }
    }
    stage('Test 11.2 without diagnostics and tuning pack') {
      environment {
        DB_VERSION = '11.2'
        MANAGEMENT_PACK_LICENSE = 'none'
      }
      steps {
         sh 'rake TESTOPTS="-v" test'
      }
    }
    stage('Docker stop 11.2') {
      steps {
         sh '#docker stop oracle112'
         sleep 20
       }
    }

    stage('Docker start 12.1 SE') {
      steps {
         sh 'docker start oracle121se'
         sleep 20
       }
    }
    stage('Test 12.1 SE without diagnostics and tuning pack') {
      environment {
        DB_VERSION = '12.1_SE'
        MANAGEMENT_PACK_LICENSE = 'none'
      }
      steps {
         sh 'rake TESTOPTS="-v" test'
      }
    }
    stage('Docker stop 12.1 SE') {
      steps {
         sh '#docker stop oracle121SE'
         sleep 20
       }
    }
  }
}