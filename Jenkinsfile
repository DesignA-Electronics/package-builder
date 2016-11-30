node {
	stage('SCM') {
		checkout scm
		sh 'git clean -fdx'
	}

	stage('Build') {
		sh './pbuild build-all minimal_packages_list'
	}

	stage('Archive') {
                archiveArtifacts artifacts: 'packages/*', fingerprint: true
                archiveArtifacts artifacts: 'scripts/*', fingerprint: true
                archiveArtifacts artifacts: 'support_files/*', fingerprint: true
                archiveArtifacts artifacts: 'helpers/*', fingerprint: true
                archiveArtifacts artifacts: 'pbuild', fingerprint: true
                archiveArtifacts artifacts: 'config', fingerprint: true
	}
}
