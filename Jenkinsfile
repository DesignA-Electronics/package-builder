try {
	node {
		stage 'SCM'
		checkout scm
		sh 'git clean -fdx'

		stage 'Build'
		sh './pbuild build-all minimal_packages_list'

		stage 'Archive'
		archiveArtifacts('packages/*')
	}
} catch (err) {
	echo "Caught: ${err}"

	currentBuild.result = "FAILURE"
	mail	subject: 'Build ${env.BUILD_NUMBER} of ${env.JOB_NAME} failed',
		body: "Full logs available here: ${env.BUILD_URL}",
		from: 'logbot@designa-electroics.com',
		to: 'developers@designa-electronics.com',
		replyTo: 'developers@designa-electronics.com'

	throw err
}
