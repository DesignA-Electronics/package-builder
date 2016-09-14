try {
	node {
		stage 'SCM'
		checkout scm

		stage 'Build'
		sh './pbuild build-all minimal_packages_list'

		stage 'Archive'
		archiveArtifacts('packages/*')
	}
} catch (err) {
	currentBuild.result = "FAILURE"
	mail body: "Full logs available here: ${env.BUILD_URL}",
            from: 'logbot@designa-electroics.com',
            subject: 'Autobuild of ${env.JOB_NAME} failed',
            to: 'developers@designa-electronics.com'

	throw err
}
