node {
	stage 'SCM'
	checkout scm

	stage 'Build'
	./pbuild build-all minimal_packages_list

	stage 'Archive'
	archiveArtifacts artifacts: 'packages/*'
}
