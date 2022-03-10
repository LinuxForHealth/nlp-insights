# NLP Insights
A reference implementation of a rest service to update bundles of FHIR resources with discovered insights.
The service is implemented as a Flask API within a docker container.

## Purpose
The primary purpose of the discover insights API is to accept a bundle of FHIR resources and to return an updated bundle that includes discovered insights.
* Resources in the bundle may have been enriched by adding additional codes. 
  - For example an AllergyIntolerance resource for a peanut allergy might have UMLS code C0559470 or SNOMED-CT code 91935009 added to it.
* New resources may have been derived from unstructured text (such as clinical notes) contained within the bundle's resources. 
  - For example a DiagnosticReport that says *the patient had a myocardial infarction* might result in a derived Condition resource being added to the bundle.

## Quick Start
You can pull the latest release from quay.io. 

The tag of the container image is always associated with the release tag for the git repo.
In other words, to run the service for release v0.0.6 on local port 8998, you could execute:

```
docker login quay.io
docker run -p 8998:5000 quay.io/alvearie/nlp-insights:0.0.6
```

The container's tag does not include a leading "v". The available tags can be accessed [here](https://quay.io/repository/alvearie/nlp-insights?tab=tags). We recommend loading images with tags that are associated with tagged releases in GitHub.

Example use cases, APIs, and buid documentation can be found in our official product [documentation](#documentation).

It's also very easy to build the container from source code, and the directions to do that can be found in the documentation.

## Documentation
The official documentation is located [here](https://linuxforhealth.github.io/nlp-insights)

## Contributing
We welcome contributions! Please look at our [documentation](#documentation) for details on how to begin.


## License
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0) 
