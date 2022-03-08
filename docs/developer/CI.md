# Continuous Integration

This project uses Github actions to perform continuous integration tasks. 
The ultimate goal of the CI pipeline is to ensure that when code is merged into the main branch:

- The code being merged is of high quality (tests pass)
- A release is created in git.
- There is a container image in a registry (currently [quay.io](https://quay.io/repository/alvearie/nlp-insights?tab=tags)) that was built using the release, the image tag matches the release.
- All commits in the merge satisfy the [DCO](https://github.com/apps/dco) requirements.
- The documentation has valid page links, and is built to the gh-pages branch. The branch is published to gh-pages. 

This makes it easy to find the latest release, the associated container image, and the latest documentation.

Actions run at multiple points in the development lifecycle.

1. Push new commits to a user branch
1. Pull request
1. Push commits to main (The result of merging a pull request)

## Push new commits to a user branch
When new commits are pushed to a user branch, the `nlp-insights-push-validation.yml` workflow is invoked. The purpose of this workflow is to provide fast validation of the code that was pushed. It performs the following high level tasks.

- Unit test
- Static Code Analysis
- Docker Lint

A coverage report from the unit tests is included in the build artifacts.

> :point_right: The unit test and static code analysis can be run locally with `./gradlew checkSource` (Linux) or `./gradlew.bat checkSource` (windows)

## Pull request
A new (candidate) release is created each time a pull request is made. 
A candidate release means that the docker image is built, and charts in the branch are updated to point at that image as part of the build.
The tag for the release is created later, when the pull is merged, and the release tag will be consistent with the tag of the docker image.

> :warning: A pull request must be made from a branch, a pull request from a fork is not supported.
> The workaround is to first merge your changes into a branch of the target repo, and then make the pull request from the branch.

If documentation changes have been made, the documentation for the release is built for validation, but is NOT published to the gh-pages branch until the pull
request is merged.

The prepare release workflow has TWO workflow files associated with it.

* *prepare-release.yml* defines a flow that runs when any non-documentation part changes. This builds the docker image and pushes it to the container repo.
* *prepare-doc-release.yml* defines a flow that runs when any documentation part changes. This validates the markdown used in documentation.

:information_source: These flows define the same "Prepare release" job name. The job name is registered as a required check that must pass before merging a pull request.
There are two jobs because if a pull request includes only documentation, we don't want to build a new container. They have the same name because of the problem
described [in the github documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/troubleshooting-required-status-checks#handling-skipped-but-required-checks). It is possible that one or both of these actions may run on a pull request.

The `prepare-release.yml` workflow file includes the logic to build and tag the container image.
This includes the following actions.

- Determine the release version number
- Update repository files with version number and location of the docker image
- Quality Verification (tests)
- Build & Push Docker Image
- Commit repository changes to Git

The `prepare-doc-release.yml` is much simpler. It builds the documentation with the `strict` option. 
This workflow is simple validation, the documentation is not pushed anywhere.

### Configuration
`prepare-release.yml` depends on several configuration settings.

The environment of the workflow file indicates the server, org, and repo
 where the image will be stored. Changing these requires making a pull request that includes a new version of
 the workflow with updated values (which will create an image at the new location).
 
```yaml
   jobs:
     prepare-release:
      name: Prepare release
      runs-on: ubuntu-latest
  
      env:
        docker_server: quay.io
        docker_org: alvearie
        docker_repo: nlp-insights
```

The username and password that are used to log into the docker server are stored as Github secrets.
An admin can set these by navigating to the `settings` tab, and choosing `Secrets` -> `Actions` from the left hand panel.

The username and password are stored in the `DOCKER_USERNAME` and `DOCKER_PASSWORD` repository secrets.

### Determine release version

  A release version has the format _major_._minor_._patch_, where major, minor, and patch are integers 
  A unique version number is determined by incrementing the most recent release version (including pre-releases) of the Git repo.
  If an image exists in the container repository with the same tag as the release, the version's patch level is incremented 
  until a unused release version is found.
  
  > :point_right: A label can be added to the pull request to indicate that the pull should create a Major, Minor, or Patch release.
  > If no label is added, patch is the default.  Valid labels are: `release-major`, `release-minor`, and `release-patch`
  
### Update Repository files
Several files in the branch need to be updated with the URL for the image's org, repo and tag for the docker image.

These files are:

- values.yaml
- chart.yaml

The helm charts are then packaged into a *.tgz file and stored in the docs/charts directory. This makes them accessible from github.io after
the branch is merged into main. Once packaged, a repo index is performed on docs/charts to create an index.yaml for all charts that exist in
the directory.

The version in gradle.properties is updated to the release version. This version is used when building the docker image. It is also used when merging 
the pull to determine what release number should be created for the merge.

The changes are not committed until the end of the build.

### Quality verification
The build will run unit tests and perform linting and static code analysis.

### Build and Push Docker image
The docker image is built and pushed to the container registry

### Commit release updates to Git
The prior changes to the branch are committed to Git.

> :warning: Making a pull request results in an additional commit from within an action,
a developer will have to do a fetch and rebase to see the latest changes for these files.

## Push commits to main (Merge the pull request)
Merging the pull request results in pushing the commits in the pull to the main branch.

### Create release tag
When a commit is pushed to main, the `release.yml` workflow will create a release tag for the commit.
The value of the release tag is determined from the version in the `gradle.properties` file.

### Build and publish documentation
When a commit is pushed to main, the `build-docs.yml` workflow will run MkDocs to build the documentation and push to the gh-pages branch (root folder).

The push to the gh-pages branch will trigger the "pages build and deployment" github action. MkDocs creates the branch with a .nojekyll file so that github will deploy only, rather than build. The documentation is then available via github pages.

In order for the documentation process to work the repo needs to be configured for gh-pages.
Under Settings -> Pages, the site should be built from gh-pages / (root)

It may be necessary to do an initial deploy to create the branch if it does not already exist. If there is already a deployment, you might have to first
change the source to none, and after the gh-pages branch is created, set the pages source to the branch.

MkDocs creates the branch with a `.nojekyll` file, which tells github that it should not try to render the markdown as HTML using jekyll.

The `build-docs.yml` workflow renders the content in the gh-pages branch. This branch should not be changed directly as changes will be lost on the next deploy.

For testing documentation changes, you can [install](https://www.mkdocs.org/getting-started/) MkDocs locally, and use `mkdocs serve` to view the built pages.

