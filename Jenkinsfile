node {
	stage('SCM') {
		checkout scm
		sh 'git clean -fdx'
	}

	stage('Build') {
		sh './pbuild build-all minimal_packages_list'
	}

	stage('Archive') {
                archiveArtifacts artifacts: '*', excludes: 'build/*', fingerprint: true
	}
}
