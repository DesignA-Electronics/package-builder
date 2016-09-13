node {
	stage 'SCM'
	checkout scm

	stage 'Build'
	sh './pbuild build-all minimal_packages_list'

	stage 'Archive'
	archiveArtifacts('packages/*')
}
