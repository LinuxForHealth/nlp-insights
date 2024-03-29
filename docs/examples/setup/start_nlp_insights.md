# Starting the nlp-insights service by pulling a container from our repository 
If you have no need to modify source code, you can run the nlp-insights service by pulling the container image.

The tag of the container image is always associated with the release tag for the git repo.
In other words, to run the service for release `v0.0.6` on local port 8998, you could execute:

```
docker login quay.io
docker run -p 8998:5000 quay.io/alvearie/nlp-insights:0.0.6
```

:information_source: The container's tag does not include a leading "v". We currently use quay.io as our container registry, and the available tags can be accessed [here](https://quay.io/repository/alvearie/nlp-insights?tab=tags). We recommend loading images with tags that are associated with GitHub releases.

# Starting the nlp-insights service using source code
Another option is to run the service by building the container from the source. This is the best way to test changes to the source.

The nlp-insights service uses a gradle build to validate the source code, build the docker image, and start the service in a docker container.

## Prereqs
* You must have a container runtime installed on your machine (such as podman or docker)
* You must have a python 3.9 and pip distribution
* The tutorials use curl to submit REST requests to the service
* The tutorials use jq version 1.5 for formatting and processing the json
* The tutorials were run in a bash shell.

### Start the nlp-insights service
Set the current working directory to the root of a clone of our GitHub repo.

Use gradle to start the service in a docker container on port 5000. `<user-id>` should be the user id for your local repository.
Windows users should use `./gradlew.bat` instead of `./gradlew`.

`./gradlew checkSource dockerStop dockerRemoveContainer dockerRun -PdockerUser=<user-id> -PdockerLocalPort=5000`

The tasks run in left to right order:

- `checkSource` performs unit tests and static source code checks on the source. It is optional when not making changes.
- `dockerStop` stops the container if it is running. This is necessary if the service is already started.
- `dockerRemoveContainer` removes the container from your container registry. This is necessary if container has been previously registered.
- `dockerRun` starts the container

The `dockerUser` property should be your docker user id.
The `dockerLocalPort` is the port the service runs on. The default is 5000, but you can change this if you have other local services already running on port 5000.

<details><summary>output</summary>

```
> Task :dockerRunStatus
Docker container 'nlp-insights' is RUNNING.

BUILD SUCCESSFUL in 1m 16s
```

</details>

The service will now be running on port 5000.

`docker container ls`

<details><summary>output</summary>

```
CONTAINER ID  IMAGE                             COMMAND               CREATED        STATUS            PORTS                   NAMES

592aeac44fca  localhost/ntl/nlp-insights:0.0.2  python3 -m flask ...  2 minutes ago  Up 2 minutes ago  0.0.0.0:5000->5000/tcp  nlp-insights
```

</details>
