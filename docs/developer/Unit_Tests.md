# Unit tests
New contributions should include unit tests that test the behavior of the new function.
    
## Types of unit tests
This project uses two industry standard test frameworks.

* Examples contained within Python docstrings are written and tested using [Doctest](https://docs.python.org/3.9/library/doctest.html).
* Behaviors of nlp-insights are tested using [pytest](https://docs.pytest.org/en/7.0.x/).

## Running tests
The Gradle build for the project will run unit tests before creating the docker image, or tests can be run directly by executing `./gradlew test` (Linux) or `/gradlew.bat test` (Windows).

### IDE Test Runners
All Python IDEs support running unit tests, and most allow the developer to choose which test runner to use. For example, you can setup Eclipse to use the Py.test runner. This runner is equivalent to the pytest tool that Gradle uses, and allows tests to be run under debug, which can be very valuable.

The Py.test runner will not run doc tests.

If you want to run doctests from within Eclipse, you can configure a launcher to run the "test_documentation" test using the *pyDev* runner. The `test_documentation.py` module exists in the package `src/test/py/test_nlp_insights`. The testcase will run doctests as unit tests ONLY when using a unittest like (not py.test) runner. The Pytest runner does not understand the mechanism that is used to load/create doctests as a unit test, and will not use this testcase. The Gradle build executes doctest directly, and does not use the test_documentation module.

## Coverage
When the Gradle build runs unit tests, a coverage report is output to ./build/reports/coverage/index.html. This report is also supplied as a build artifact when pushes are made to any branch (other than main) of the git repo.

The coverage report provides insight into areas of source code that are covered by unit tests. It does not include the coverage of doc tests. The report should be used during code reviews to assess the test coverage of new function.

> :information_source: The build does not require a specific percent of coverage to be considered a successful build.


## Adding tests for NLP function
Being able to quickly test NLP related function is very important for rapid/agile development. The test pattern used by our tests enables fast development by:

1. Mocking an NLP Serivce (Such as ACD or QuickUMLS)
1. Using a Flask [test_client](https://flask.palletsprojects.com/en/2.0.x/testing/) to submit (mock) REST requests to the nlp-insights service and retrieve a response.
1. Asserting that the response from the nlp-insights service matches the expected response.


### Mocking an NLP Service
The pattern is to replace (in the global application) the built-in class for the NLP service that we want to mock with a class derived from the built-in. Instead of making a REST request to the NLP service, the derived class will load the NLP responses from a JSON file. 

The class replacement happens in the setUp method of the test.

After the NLP service class is replaced by the test setup, tests can issue (mock) REST requests to nlp-insights to configure the NLP service, followed by discovery of insights. The mock NLP service will be used in place of the built-in. Because the mock service is derived from the built-in, the code flow is as close to identical as possible.

### Mock NLP service response file
When a mock NLP service is constructed, a path to a json file is supplied. The keys of the json file are unstructured text strings that would ordinally be sent to the 'real' NLP service. The values associated with those keys are json objects that will be the response of the mock NLP service.

For example the following file instructs the mock service to return an empty object when it is sent "amoxicillin allergy" or "peanut allergy" for processing. In practice we need to use the JSON object returned by ACD for those strings, rather than empty dictionary.

```json
{
"amoxicillin allergy": {},
"peanut allergy" : {}
}
```

The keys in the mock file must exactly match the text sent to the mock NLP service. (case sensitive, and including any adjustment text).

### Assert that the response matches the expected output
Responses from the mock service are compared to the expected result using the `test_nlp_insights.util.compare_actual_to_expected` method. The method takes the expected_path and actual_resource as parameters. The expected path is usually computed using `expected_output_path()` which will return a value of `test/resources/expected_results/<class-name>/<test-name>.json`.

If the expected result file does not exist, then `compare_acutal_to_expected` will create the file from the actual results and the test will pass.

> :point_right: You can test your code quickly by writing a new unit test; the test will create the expected result file on its first run using the actual results. Once the result file has been verified to be correct, it can be checked into Git with the test. All future test runs will then assert that the test continues to produce the expected result.

> :point_right: If an intended code change impacts one or more expected results, simply delete the impacted result files and re-run the unit tests. The expected results will be recreated with the new behavior. Once verified as correct, the updated expected result files can be checked into Git along with the code changes.


### Example test case

It is usually simple to add a new test method to an existing test class, however this an example of how to build such a class from scratch.


```python  
import importlib

from fhir.resources.bundle import Bundle

from nlp_insights import app # (1)
from test_nlp_insights.util import unstructured_text # (2)
from test_nlp_insights.util.compare import compare_actual_to_expected
from test_nlp_insights.util.fhir import ( # (3)
    make_docref_report,
    make_attachment,
    make_bundle,
    make_patient_reference,
)
from test_nlp_insights.util.mock_service import ( # (4)
    make_mock_acd_service_class,
    configure_acd,
    make_mock_quick_umls_service_class,
    configure_quick_umls,
)
from test_nlp_insights.util.resources import UnitTestUsingExternalResource


class TestClassWithMockACD(UnitTestUsingExternalResource): # (5)
    """Example class that mocks ACD service by 
       loading responses from ResponseFile.json"""

    def setUp(self) -> None:
        # The application (app) is defined globally in the module, "reload"
        # is a (dubious) way of reseting the application state between
        # test cases. It should work "well-enough" in most cases.
        importlib.reload(app)
        
        # This method call replaces the built in handler for the "acd"
        # nlpServiceType with a mock instance that instead of making a 
        # REST request to an ACD service, loads ACD responses from json.
        app.config.set_mock_nlp_service_class(
            "acd",
            make_mock_acd_service_class(
                self.resource_path + "/acd/TestReportResponses.json"
            ),
        )

    def test_when_something_then_expected_result(self):
        # First build a Bundle resource that we will send to nlp-insights
        # The text defined in TEXT_FOR_MULTIPLE_CONDITIONS must be a key
        # in {self.resource_path}/acd/TestReportResponses.json,
        # with the value of that key being the expected ACD response.
        bundle = make_bundle(
            [
                make_docref_report(
                    subject=make_patient_reference(),
                    attachments=[
                        make_attachment(
                            unstructured_text.TEXT_FOR_MULTIPLE_CONDITIONS
                        )
                    ],
                )
            ]
        )

        with app.app.test_client() as service: # (6)
            # configure_acd is a helper method to:
            #   Create config definition for ACD (7)
            #   Set default NLP to ACD (8)
            configure_acd(service)
            
            # This is the call to discoverInsights that needs to be
            # tested.
            insight_resp = service.post("/discoverInsights",
                                        data=bundle.json())
            self.assertEqual(200, insight_resp.status_code)

            # Validate the results are as expected
            actual_bundle = Bundle.parse_obj(insight_resp.get_json()) # (9)
            
            # This compare is json aware. The order of keys does not
            # matter. If the expected results file does not exist,
            # The results from the service are written to file and
            # the test will pass. The result file should be verified
            # as part of the review process.
            cmp = compare_actual_to_expected(
                expected_path=self.expected_output_path(), # (10)
                actual_resource=actual_bundle,
            )
            self.assertFalse(cmp, cmp.pretty())
```

1. The root application is `nlp_insights.app.app` (`app` is in the `app` package), The application is a global singleton, we don't use Flask blueprints. The `app` package contains functions for working with that global app.
1. `test_nlp_insights.util.unstructured_text` defines constants for text that will be used for source text in reports.
1. Functions in `test_nlp_insights.util.fhir` make it easier to construct a bundle of FHIR resources to send to nlp-insights.
1. Functions for creating mock ACD and QuickUmls services are in the `test_nlp_insights.util.mock_service` package.
1. The `UnitTestUsingExternalResource` parent class defines the directory where resource files exist. It also defines where the expected output files for tests are stored and what their names are. (The name is computed from the testcase method).
1. `with app.app.test_client() as service` makes serive a test_client that we can send mock REST requests to.
1. Creating a config definition for ACD is implemented as:
    
    ```python
    rsp = service.post("/config/definition",
                       json={
                             "name": "acdconfig1",
                             "nlpServiceType": "acd",
                             "config": {
                                 "apikey": "**un-needed**",
                                 "endpoint": "https://none.org",
                                 "flow": "not_used",
                             },
                            },
                      )
        
    if rsp.status_code not in (200, 204):
        raise RuntimeError()
    ```
    
1. Setting the default NLP to ACD is implemented as:
    
    ```python
    rsp = service.post(f"/config/setDefault?name=acdconfig1")
    if rsp.status_code not in (200, 204):
        raise RuntimeError()
    ```

1. Parsing the response from nlp-insights has found errors in the past. For example the service could construct a condition without a subject. This would fail even the very limited FHIR validation that happens with the parse that is used here.
1. The expected path is calculated from  the testcase name and class name. e.g. `test/resources/expected_results/TestClassWithMockACD/test_when_something_then_expected_result.json`

### Error reporting
If a compare fails, an explanation of what the difference was appears in the message.
The information includes the path from the root of the json document to the difference, and the changed values.

```
values_changed at path root['entry'][1]['resource']['code']['coding'][0]['code'] 
    EXPECTED=C0027051
    ACTUAL  =<something-else>
```

