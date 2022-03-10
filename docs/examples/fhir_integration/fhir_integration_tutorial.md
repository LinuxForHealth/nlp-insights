```python
%load_ext lab_black
```

# Integration of nlp-insights with a FHIR Server
---

Although nlp-insights can be used as a standalone service, the primary intent of the service is to use it to enhance a bundle or resources, prior to posting those resources to a FHIR server.
This notebook contains a demonstration of posting enriched resources to a FHIR server, and retrieving enriched insights and evidence for the insight.

<img src='../fhir_integration.png' width="75%" height="75%"></img>


# Setup
---
This notebook was created with jupyter-lab 3.1.11 and python 3.9.6. Using a [virtual envirnoment](https://www.zainrizvi.io/blog/jupyter-notebooks-best-practices-use-virtual-environments/)  is recommended. Python source code is formatted with [Black](https://pypi.org/project/nb-black/).

## Start and configure the nlp-insights service
The examples have been written with the assumption that ACD is configured as the NLP backend for the nlp-insight service. You need to [start](../setup/start_nlp_insights.md) and [confgure](../acd/configure_acd.md) the nlp-insights service. Configuring the server to use [QuickUMLS](../quickumls/configure_quickumls.md) is also an option, although the discovered insights will differ.

## Start a local FHIR server
Although health patterns defines a much more sophisticated architecture for ingestion pipelines, these examples use the [IBM FHIR server](https://ibm.github.io/FHIR/) running locally in a container. This keeps things simple, and allows us to focus on the value of the nlp-insights server.

The server can be started locally by running the command:

`docker run -p 9443:9443 -e BOOTSTRAP_DB=true ibmcom/ibm-fhir-server`

## Load FHIRPath Jars
[FHIRPath](https://www.hl7.org/fhir/fhirpath.html) is an HL7 standard for navigating and extracting parts of FHIR resources. These examples evaluate FHIRPath expressions by utilizing [Java code](https://github.com/IBM/FHIR/tree/main/fhir-path) built for the IBM FHIR Server. The advantage to using FHIRPath is that the FHIRPath language is aware of features specific to FHIR resources, which makes the queries simpiler in many cases. The python interface provided in this notebook does not provide full functionality, but it is complete enough for the examples.

You need to download the jars from maven centeral, and store them in the local directory indicated by FHIR_PATH_JARS (defined in a future cell).

These are steps to do that (You may need to install [Apache Maven](https://maven.apache.org/) 3.5.4 or newer):
* Download the pom for the project `curl https://repo1.maven.org/maven2/com/ibm/fhir/fhir-path/4.10.2/fhir-path-4.10.2.pom > pom.xml`
* Download the jars `mvn -DoutputDirectory=. -Dartifact="com.ibm.fhir:fhir-path:4.10.0" dependency:copy dependency:copy-dependencies`

## Third party libraries
The examples depend on a few other libraries to make processing easier. jpype1 is used to call Java code when evaluating FHIRPath expressions.


```python
!pip install --upgrade pip
!pip install pandas==1.3.5
!pip install fhir.resources==6.1.0
!pip install jpype1==1.3.0
```

    Requirement already satisfied: pip in ./nlp-insights/lib/python3.9/site-packages (21.3.1)
    Requirement already satisfied: pandas==1.3.5 in ./nlp-insights/lib/python3.9/site-packages (1.3.5)
    Requirement already satisfied: pytz>=2017.3 in ./nlp-insights/lib/python3.9/site-packages (from pandas==1.3.5) (2021.3)
    Requirement already satisfied: numpy>=1.17.3 in ./nlp-insights/lib/python3.9/site-packages (from pandas==1.3.5) (1.22.0)
    Requirement already satisfied: python-dateutil>=2.7.3 in ./nlp-insights/lib/python3.9/site-packages (from pandas==1.3.5) (2.8.2)
    Requirement already satisfied: six>=1.5 in ./nlp-insights/lib/python3.9/site-packages (from python-dateutil>=2.7.3->pandas==1.3.5) (1.16.0)
    Requirement already satisfied: fhir.resources==6.1.0 in ./nlp-insights/lib/python3.9/site-packages (6.1.0)
    Requirement already satisfied: pydantic[email]>=1.7.2 in ./nlp-insights/lib/python3.9/site-packages (from fhir.resources==6.1.0) (1.9.0)
    Requirement already satisfied: typing-extensions>=3.7.4.3 in ./nlp-insights/lib/python3.9/site-packages (from pydantic[email]>=1.7.2->fhir.resources==6.1.0) (4.0.1)
    Requirement already satisfied: email-validator>=1.0.3 in ./nlp-insights/lib/python3.9/site-packages (from pydantic[email]>=1.7.2->fhir.resources==6.1.0) (1.1.3)
    Requirement already satisfied: dnspython>=1.15.0 in ./nlp-insights/lib/python3.9/site-packages (from email-validator>=1.0.3->pydantic[email]>=1.7.2->fhir.resources==6.1.0) (2.1.0)
    Requirement already satisfied: idna>=2.0.0 in ./nlp-insights/lib/python3.9/site-packages (from email-validator>=1.0.3->pydantic[email]>=1.7.2->fhir.resources==6.1.0) (3.3)
    Requirement already satisfied: jpype1==1.3.0 in ./nlp-insights/lib/python3.9/site-packages (1.3.0)



```python
import requests
import base64
import json
import urllib3
import os
import base64

import pandas as pd
import numpy as np
```


```python
pd.set_option("display.max_colwidth", None)
```

## Wrapper code to Evaluate FHIRPath expression

This code is used to call into the Java FHIRPath evaluation code. The details of how it works are outside the scope of nlp-insights examples. If you need more details jpype is well [documented](https://pypi.org/project/JPype1/) and the Java code and documentation is available [here](https://github.com/IBM/FHIR/tree/main/fhir-path).  This seemed to be the easiest way to evaluate an expression from Python, although not all expressions are supported. If you would like to try a different implementation of FHIRPath, there are a few listed on the [HL7 wiki](https://wiki.hl7.org/index.php?title=FHIRPath_Implementations).


```python
###
# CHANGE THIS TO THE DIRECTORY WHERE YOU DOWNLOADED THE FHIRPath JARS!!!!!
###
FHIR_PATH_JARS = "/home/ntl/fhir/fhir-path/*"
```


```python
import jpype
import jpype.imports
from jpype.types import *

print(f"looking for FHIRPath jars in {FHIR_PATH_JARS}")
if not jpype.isJVMStarted():
    jpype.startJVM(classpath=[FHIR_PATH_JARS])
```

    looking for FHIRPath jars in /home/ntl/fhir/fhir-path/*



```python
from java.io import ByteArrayInputStream
import java.util.Collection
import java.lang.String
import java.lang.Integer
import java.math.BigDecimal

from com.ibm.fhir.path.evaluator import FHIRPathEvaluator
from com.ibm.fhir.model.parser import FHIRParser
from com.ibm.fhir.model.format import Format

import com.ibm.fhir.path.FHIRPathElementNode
import com.ibm.fhir.path.FHIRPathResourceNode

import com.ibm.fhir.path.exception.FHIRPathException as FHIRPathException

from json import JSONDecodeError


def convert_obj(java_obj):
    """Converts a FHIRPath Java Object to a python object"""
    if java_obj is None:
        return None

    if isinstance(java_obj, com.ibm.fhir.path.FHIRPathResourceNode):
        return str(java_obj.resource().toString())

    if isinstance(java_obj, com.ibm.fhir.path.FHIRPathElementNode):
        node = java_obj.element()
        if node.hasValue():
            node = node.getValue()
            if isinstance(node, java.lang.String):
                return str(node)
            if isinstance(node, java.lang.Integer):
                return int(node)
            if isinstance(node, java.math.BigDecimal):
                return int(node)
            if isinstance(node, JArray):
                return str(node)
        try:
            return json.loads(str(node.toString()))
        except JSONDecodeError:
            return str(node.toString())
    elif isinstance(java_obj, java.util.Collection):
        return [convert_obj(obj) for obj in java_obj]
    else:
        try:
            return json.loads(str(java_obj.toString()))
        except JSONDecodeError:
            return str(java_obj.toString())

    raise IllegalArgumentError(str((type(node), str(node))))


def evaluate_fhir_path(json_str, expr_str):
    """Evaluates an expression agains a FHIR Resource

    Args:
         json_str - FHIR resource as a json string
         expr_str - FHIRPath expression to evaluate

    Returns: Results of the evaluation, usually a list of String values.
             May return None if no results were found
    """
    resource = FHIRParser.parser(Format.JSON).parse(
        ByteArrayInputStream(json_str.encode("utf-8"))
    )
    try:
        nodes = FHIRPathEvaluator.evaluator().evaluate(resource, expr_str)
    except FHIRPathException as ex:
        raise RuntimeError(str(ex) + "\nWith expression:\n" + expr_str)

    return convert_obj(nodes)
```

## Local Server URLs and Ports


```python
# We can be trusting of certificates for a local container
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

fhir_server = "https://fhiruser:change-password@localhost:9443/fhir-server/api/v4"
nlp_insights_server = "http://localhost:5000"
```

## Health Checks


```python
fhir_health_check = requests.get(f"{fhir_server}/$healthcheck", verify=False)
fhir_health_check.raise_for_status()

insights_health_check = requests.get(f"{nlp_insights_server}/config")
insights_health_check.raise_for_status()
```

# POST Bundle with insights into FHIR Server
---
The input bundle is in a json file that can be viewed [here](./input_bundle.json).

The bundle is loaded, sent to the nlp-insights service for enrichment, and then posted to the FHIR server.

## Load Bundle (without insights)


```python
with open("./input_bundle.json", "r") as f:
    bundle_json = json.load(f)
```

### Input bundle Summary
We can get a rough idea of what is our input bundle using json_normalize to build a data frame. Using dataframes will make it easier to view the insights. Deeply nested JSON documents that represent FHIR resources are hard to look at; rows and columns are more familiar for human readers. Another reason for using rows and columns is that Ground Truth, or the insights that humans expect to be discovered, is often stored as rows and columns. The nlp-insights service does not include ground truth, nor is accuracy discussed in the documentation or tutorials - but accuracy must be measured for real use cases. Working with rows and columns here makes it easier to transition to other these types of analysis.

Using the data frame, it's easy to see which resources and text are in the initial bundle. Also be aware that there are no code values for in the Condition and AllergyIntolerance resources.


```python
df = pd.json_normalize(bundle_json, record_path=["entry"])
df["report_text"] = df["resource.presentedForm"].apply(
    lambda f: base64.b64decode(f[0]["data"]).decode("utf-8")
    if not pd.isnull(f)
    else np.NaN
)

# assert that columns for codes do not exist
assert "resource.medicationCodeableConcept.coding" not in df.columns
assert "resource.code.coding" not in df.columns

# print resource types and code text
df.loc[:, ["resource.resourceType", "resource.code.text", "report_text"]]
```




<div>
<style scoped>
    .dataframe tbody tr th:only-of-type {
        vertical-align: middle;
    }

    .dataframe tbody tr th {
        vertical-align: top;
    }

    .dataframe thead th {
        text-align: right;
    }
</style>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>resource.resourceType</th>
      <th>resource.code.text</th>
      <th>report_text</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>0</th>
      <td>Patient</td>
      <td>NaN</td>
      <td>NaN</td>
    </tr>
    <tr>
      <th>1</th>
      <td>DiagnosticReport</td>
      <td>Chief complaint Narrative - Reported</td>
      <td>The patient had a myocardial infarction in 2015 and was prescribed Losartan.The patient is taking Losartan exactly as prescribed and has had no side effects.</td>
    </tr>
    <tr>
      <th>2</th>
      <td>Condition</td>
      <td>diabetes</td>
      <td>NaN</td>
    </tr>
    <tr>
      <th>3</th>
      <td>AllergyIntolerance</td>
      <td>peanut</td>
      <td>NaN</td>
    </tr>
    <tr>
      <th>4</th>
      <td>AllergyIntolerance</td>
      <td>amoxicillin</td>
      <td>NaN</td>
    </tr>
  </tbody>
</table>
</div>



## Discover insights

The nlp-insights service is used to discover insights.


```python
nlp_insights_response = requests.post(
    f"http://localhost:5000/discoverInsights",
    headers={"Content-Type": "application/fhir+json"},
    json=bundle_json,
)
nlp_insights_response.raise_for_status()
enriched_bundle_json = json.loads(nlp_insights_response.text)
```

### Enriched Bundle Summary

A quick summary of the updated bundle that was returned from the nlp-insights service verifies that a few new resources have been derived, and the prior condition and AllergyIntolerance resources have been enriched with additional codes.


```python
df = pd.json_normalize(enriched_bundle_json, record_path=["entry"])
df["report_text"] = df["resource.presentedForm"].apply(
    lambda f: base64.b64decode(f[0]["data"]).decode("utf-8")
    if not pd.isnull(f)
    else np.NaN
)
df.loc[df["resource.resourceType"] != "MedicationStatement", "codes"] = df.loc[
    df["resource.resourceType"] != "MedicationStatement", "resource.code.coding"
].apply(
    lambda codes: [(code["system"], code["code"]) for code in codes]
    if isinstance(codes, list)
    else np.NaN
)
df.loc[df["resource.resourceType"] == "MedicationStatement", "codes"] = df.loc[
    df["resource.resourceType"] == "MedicationStatement",
    "resource.medicationCodeableConcept.coding",
].apply(
    lambda codes: [(code["system"], code["code"]) for code in codes]
    if isinstance(codes, list)
    else np.NaN
)
df["code_text"] = df.loc[:, "resource.code.text"].combine_first(
    df.loc[:, "resource.medicationCodeableConcept.text"]
)
df.loc[
    :,
    [
        "resource.resourceType",
        "code_text",
        "codes",
    ],
]
```




<div>
<style scoped>
    .dataframe tbody tr th:only-of-type {
        vertical-align: middle;
    }

    .dataframe tbody tr th {
        vertical-align: top;
    }

    .dataframe thead th {
        text-align: right;
    }
</style>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>resource.resourceType</th>
      <th>code_text</th>
      <th>codes</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>0</th>
      <td>Patient</td>
      <td>NaN</td>
      <td>NaN</td>
    </tr>
    <tr>
      <th>1</th>
      <td>DiagnosticReport</td>
      <td>Chief complaint Narrative - Reported</td>
      <td>NaN</td>
    </tr>
    <tr>
      <th>2</th>
      <td>Condition</td>
      <td>diabetes</td>
      <td>[(http://terminology.hl7.org/CodeSystem/umls, C0011849), (http://snomed.info/sct, 73211009), (http://hl7.org/fhir/sid/icd-9-cm, 250.00), (http://hl7.org/fhir/sid/icd-10-cm, E14.9)]</td>
    </tr>
    <tr>
      <th>3</th>
      <td>AllergyIntolerance</td>
      <td>peanut</td>
      <td>[(http://terminology.hl7.org/CodeSystem/umls, C0559470), (http://snomed.info/sct, 91935009), (http://hl7.org/fhir/sid/icd-9-cm, 995.3), (http://hl7.org/fhir/sid/icd-10-cm, Z91.010), (http://hl7.org/fhir/sid/icd-10-cm, Z91.0)]</td>
    </tr>
    <tr>
      <th>4</th>
      <td>AllergyIntolerance</td>
      <td>amoxicillin</td>
      <td>[(http://terminology.hl7.org/CodeSystem/umls, C0571417), (http://snomed.info/sct, 294505008), (http://hl7.org/fhir/sid/icd-9-cm, E930.0), (http://hl7.org/fhir/sid/icd-9-cm, 995.27), (http://hl7.org/fhir/sid/icd-10-cm, Z88.0)]</td>
    </tr>
    <tr>
      <th>5</th>
      <td>Condition</td>
      <td>myocardial infarction</td>
      <td>[(http://terminology.hl7.org/CodeSystem/umls, C0027051), (http://snomed.info/sct, 22298006), (http://hl7.org/fhir/sid/icd-9-cm, 410.90), (http://hl7.org/fhir/sid/icd-10-cm, I21.9)]</td>
    </tr>
    <tr>
      <th>6</th>
      <td>MedicationStatement</td>
      <td>Losartan</td>
      <td>[(http://terminology.hl7.org/CodeSystem/umls, C0126174), (http://www.nlm.nih.gov/research/umls/rxnorm, 52175)]</td>
    </tr>
  </tbody>
</table>
</div>



## Post resources with insights to the FHIR server
Posting the updated bundle creates the resources on the FHIR server. This also assigns identifier values to the resources. We will retrieve the patient location from the response, so that we can retrieve the resources from the server.


```python
fhir_server_response = requests.post(
    f"{fhir_server}/",
    headers={"Content-Type": "application/fhir+json"},
    json=enriched_bundle_json,
    verify=False,
)
fhir_server_response.raise_for_status()
```


```python
patient_loc = evaluate_fhir_path(
    fhir_server_response.text,
    "Bundle.entry.response.location.where(startsWith('Patient')).getValue()",
)[0]
print(f"The patient's location in the FHIR Server is: {patient_loc}")
```

    The patient's location in the FHIR Server is: Patient/17e9d5ddf75-824e1c98-1484-4079-8330-63141202c23b/_history/1


# Search for all the patient's resources
In the real world, there will be many resources. The sever may respond with a page at a time, and we might be interested in only a subset of resources. For this example, we'll retrieve everything for the patient; the number of resources is small enough that paging and performance cost is not a consideration.


```python
all_resources_response = requests.get(
    f"{fhir_server}/{patient_loc}/$everything",
    headers={"Accept": "application/fhir+json"},
    verify=False,
)
all_resources_response.raise_for_status()
```

## Convert the search bundle into a DataFrame

The bundle is split into rows, where each row represents a resource in the bundle.


```python
from fhir.resources.bundle import Bundle

resources_df = pd.DataFrame(
    [
        {
            "resource_id": entry.resource.id,
            "resource_type": type(entry.resource).__name__,
            "resource_json": entry.resource.json(),
        }
        for entry in Bundle.parse_raw(all_resources_response.text).entry
    ]
)

pd.set_option("display.max_colwidth", 75)
display(resources_df)
pd.set_option("display.max_colwidth", None)
original_resources_df = resources_df  # save for later
```


<div>
<style scoped>
    .dataframe tbody tr th:only-of-type {
        vertical-align: middle;
    }

    .dataframe tbody tr th {
        vertical-align: top;
    }

    .dataframe thead th {
        text-align: right;
    }
</style>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>resource_id</th>
      <th>resource_type</th>
      <th>resource_json</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>0</th>
      <td>17e9d5ddf75-824e1c98-1484-4079-8330-63141202c23b</td>
      <td>Patient</td>
      <td>{"id": "17e9d5ddf75-824e1c98-1484-4079-8330-63141202c23b", "meta": {"la...</td>
    </tr>
    <tr>
      <th>1</th>
      <td>17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance</td>
      <td>{"id": "17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720", "meta": {"ex...</td>
    </tr>
    <tr>
      <th>2</th>
      <td>17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance</td>
      <td>{"id": "17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be", "meta": {"ex...</td>
    </tr>
    <tr>
      <th>3</th>
      <td>17e9d5ddf76-2a1b470e-3808-442d-a1af-857b7532b740</td>
      <td>MedicationStatement</td>
      <td>{"id": "17e9d5ddf76-2a1b470e-3808-442d-a1af-857b7532b740", "meta": {"ex...</td>
    </tr>
    <tr>
      <th>4</th>
      <td>17e9d5ddf75-b3eb69d7-fd03-4caf-8fe6-d8e4f2a73b2c</td>
      <td>DiagnosticReport</td>
      <td>{"id": "17e9d5ddf75-b3eb69d7-fd03-4caf-8fe6-d8e4f2a73b2c", "meta": {"la...</td>
    </tr>
    <tr>
      <th>5</th>
      <td>17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition</td>
      <td>{"id": "17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119", "meta": {"ex...</td>
    </tr>
    <tr>
      <th>6</th>
      <td>17e9d5ddf76-f5a481e8-1c92-4179-bb4d-2c668cc9bd66</td>
      <td>Condition</td>
      <td>{"id": "17e9d5ddf76-f5a481e8-1c92-4179-bb4d-2c668cc9bd66", "meta": {"ex...</td>
    </tr>
  </tbody>
</table>
</div>


# Retrieve Evidence for Derived Resources
---

This section describes how to identify derived resources, and how to determine what information was used to derive the resource.

## Extension URLs
All insight related data is stored in FHIR extensions. These extensions are defined in the [Alvearie Implementation Guide](https://alvearie.io/alvearie-fhir-ig/index.html).
The type of extension is defined by the URL for the extension.


```python
summary_ext_url = "http://ibm.com/fhir/cdm/StructureDefinition/insight-summary"
category_ext_url = "http://ibm.com/fhir/cdm/StructureDefinition/category"
insight_id_ext_url = "http://ibm.com/fhir/cdm/StructureDefinition/insight-id"
insight_ext_url = "http://ibm.com/fhir/cdm/StructureDefinition/insight"
insight_detail_ext = "http://ibm.com/fhir/cdm/StructureDefinition/insight-detail"
insight_reference_ext = "http://ibm.com/fhir/cdm/StructureDefinition/reference"
insight_reference_path = "http://ibm.com/fhir/cdm/StructureDefinition/reference-path"
insight_result_ext = "http://ibm.com/fhir/cdm/StructureDefinition/insight-result"
insight_span_ext = "http://ibm.com/fhir/cdm/StructureDefinition/span"
insight_offset_begin_ext = "http://ibm.com/fhir/cdm/StructureDefinition/offset-begin"
insight_offset_end_ext = "http://ibm.com/fhir/cdm/StructureDefinition/offset-end"
```

## Function to pretty print a data frame
Some dataframes have muliple lines of text in a column. This function prints those nicer for human readers.


```python
from IPython.display import display, HTML


def print_df(df):
    """This function prints a dataframe
    that has newline characters in a column a little nicer in a notebook"""
    # https://stackoverflow.com/questions/50644066/pandas-dataframe-and-multi-line-values
    return display(HTML(df.to_html().replace("\\n", "<br>")))
```

## Function to get the code text
This function evaluates a FHIRPath expression against a resource to return the text associated with the code. We use this to provide a quick idea of what this resource is about.


```python
def get_code_text(resource) -> str:
    if txt := evaluate_fhir_path(
        resource,
        "Condition.code.text | "
        "AllergyIntolerance.code.text | "
        "MedicationStatement.medication.text",
    ):
        return txt[0]
    return np.NaN
```

## Retrieve Derived Resources

When nlp-insights creates a derived resource, it adds an insight summary extension to the resource. The summary extension contains the insight id for the insight that created the resource. We need this ID to locate the details of the insight (The details are stored in the resource's meta element). The insight identifier's system and value will be used together to uniquely identify the insight.

### Function Retrieve Insight Identifier from summary extension
This function evaluates a FHIRPath exrpression to compute the insight id's system and value in the summary extension.


```python
def get_derived_resource_insight_id(resource):
    """returns a string value with 'system, value' for the insight id."""
    expr_str = (
        f"extension('{summary_ext_url}').where("
        f"    extension('{category_ext_url}').value.coding.code = 'natural-language-processing'"
        f")"
        f".extension('{insight_id_ext_url}').value.select(system + ',' + value)"
    )
    insights = evaluate_fhir_path(resource, expr_str)
    return insights if insights else np.NaN
```

### Construct Data Frame

This dataframe contains rows for **derived** resources. The insight identifier's system and value are included as columns. We'll use this information to reteive the evidence for the insight that caused the resource to be derived.

In addition, the *acd* in the identifier's system URI tells us that these resources were derived using ACD.


```python
resources_df["text"] = resources_df.loc[:, "resource_json"].apply(get_code_text)

resources_df["derived_by_insight"] = resources_df.loc[:, "resource_json"].apply(
    get_derived_resource_insight_id
)
resources_df = resources_df.explode("derived_by_insight")
resources_df[["insight_id_system", "insight_id_value"]] = resources_df[
    "derived_by_insight"
].str.split(",", expand=True)
resources_df = resources_df.drop(labels=["derived_by_insight"], axis="columns")
resources_df.dropna(subset=["insight_id_system"], inplace=True)
print_df(
    resources_df.loc[
        :,
        [
            "resource_id",
            "resource_type",
            "text",
            "insight_id_system",
            "insight_id_value",
        ],
    ]
)
```


<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>resource_id</th>
      <th>resource_type</th>
      <th>text</th>
      <th>insight_id_system</th>
      <th>insight_id_value</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>3</th>
      <td>17e9d5ddf76-2a1b470e-3808-442d-a1af-857b7532b740</td>
      <td>MedicationStatement</td>
      <td>Losartan</td>
      <td>urn:alvearie.io/health_patterns/services/nlp_insights/acd</td>
      <td>2c3514d1168072dcf3bb4a5992c76e7c37e6d7ea98cac9c169d29d12</td>
    </tr>
    <tr>
      <th>6</th>
      <td>17e9d5ddf76-f5a481e8-1c92-4179-bb4d-2c668cc9bd66</td>
      <td>Condition</td>
      <td>myocardial infarction</td>
      <td>urn:alvearie.io/health_patterns/services/nlp_insights/acd</td>
      <td>dc5541f39215bb39dd3619539d2655e172978ce61da98b0fa2206fe9</td>
    </tr>
  </tbody>
</table>


## Retrieve source text that was used to derive resources

In this section, we will use the insight extension in the meta of the Resource to determine what was used to derive the resource.

### Function to Retrieve Reference and Path
This function evaluates a FHIRPath expression to retrieve the resource containing the text that was used to derive this resource, and the path to that text. This information can be used to load the source text. These are refered to as the "reference" and "reference path" in alvearie.


```python
def get_derived_from(resource, insight_id_system, insight_id_value):
    """Returns reference;path  (separated by a semicolon)"""

    # Reference and path are in the insight detail extension of the insight
    # that we are interested in
    expr_str = (
        f"meta"
        f".extension('{insight_ext_url}').where("
        f"    extension('{insight_id_ext_url}').value.where("
        f"        system = '{insight_id_system}' and "
        f"        value = '{insight_id_value}'"
        f"    ).exists()"
        f")"
        f".extension('{insight_detail_ext}')"
        f".select("
        f"    extension('{insight_reference_ext}').value.reference + ';' "
        f"    + extension('{insight_reference_path}').value "
        f")"
    )

    return evaluate_fhir_path(resource, expr_str)
```

### Construct Data Frame
This builds a dataframe for each resource and includes the resource and path that the insight was derived from.


```python
resources_df["from"] = resources_df.apply(
    lambda row: get_derived_from(
        row["resource_json"], row["insight_id_system"], row["insight_id_value"]
    ),
    axis=1,
)
resources_df = resources_df.explode("from")
resources_df[["derived_from_resource", "derived_from_path"]] = resources_df[
    "from"
].str.split(";", expand=True)
resources_df.drop(labels=["from"], axis="columns", inplace=True)

print_df(
    resources_df.loc[
        :,
        [
            "resource_id",
            "resource_type",
            "text",
            "derived_from_resource",
            "derived_from_path",
        ],
    ]
)
```


<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>resource_id</th>
      <th>resource_type</th>
      <th>text</th>
      <th>derived_from_resource</th>
      <th>derived_from_path</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>3</th>
      <td>17e9d5ddf76-2a1b470e-3808-442d-a1af-857b7532b740</td>
      <td>MedicationStatement</td>
      <td>Losartan</td>
      <td>DiagnosticReport/17e9d5ddf75-b3eb69d7-fd03-4caf-8fe6-d8e4f2a73b2c</td>
      <td>DiagnosticReport.presentedForm[0].data</td>
    </tr>
    <tr>
      <th>6</th>
      <td>17e9d5ddf76-f5a481e8-1c92-4179-bb4d-2c668cc9bd66</td>
      <td>Condition</td>
      <td>myocardial infarction</td>
      <td>DiagnosticReport/17e9d5ddf75-b3eb69d7-fd03-4caf-8fe6-d8e4f2a73b2c</td>
      <td>DiagnosticReport.presentedForm[0].data</td>
    </tr>
  </tbody>
</table>


### Retrieve source text
In this example, both resources were derived from the same source text in the diagnostic report. The source resource can be easily retrieved from the FHIR server, and the path expression evaluated to get the text.


```python
source_resource, source_path = (
    resources_df.loc[:, ["derived_from_resource", "derived_from_path"]]
    .drop_duplicates()
    .iloc[0]
)
```


```python
def get_source_text(resource_loc, text_path):
    """Retrieve the resource from the FHIR server and resolve the path to the text"""
    source_resource_fhir = requests.get(
        f"{fhir_server}/{resource_loc}",
        headers={"Accept": "application/fhir+json"},
        verify=False,
    )
    source_resource_fhir.raise_for_status()
    return evaluate_fhir_path(source_resource_fhir.text, source_path)[0]
```


```python
get_source_text(source_resource, source_path)
```




    'The patient had a myocardial infarction in 2015 and was prescribed Losartan.The patient is taking Losartan exactly as prescribed and has had no side effects.'



## Retrieve spans
Clinical notes are usually longer than a few sentences. It is helpful to know which words and phrases in the text caused an insight to be derived. This section shows how to retrieve the spans associated with the insight for a derived resource.

### Function to retrieve spans
This function retrieves spans for a specific reference & path within an insight. The spans are returned as a list of (start-offset, end-offset) string values.


```python
def get_spans(resource, insight_id_system, insight_id_value, reference, path):
    # spans are within
    # -> Insight (must match expected system and id)
    #    -> insight detail (must match reference & path)
    #       -> insight result
    #          -> span (may repeat)
    expr_str = (
        f"meta"
        f".extension('{insight_ext_url}').where("
        f"    extension('{insight_id_ext_url}').value.where("
        f"        system = '{insight_id_system}' and value = '{insight_id_value}'"
        f"    ).exists()"
        f" )"
        f".extension('{insight_detail_ext}').where("
        f"    extension('{insight_reference_ext}').value.reference = '{reference}' and "
        f"    extension('{insight_reference_path}').value = '{path}'"
        f")"
        f".extension('{insight_result_ext}')"
        f".extension('{insight_span_ext}')"
        f".select("
        f"        extension('{insight_offset_begin_ext}').value.toString()  + ',' +"
        f"        extension('{insight_offset_end_ext}').value.toString() "
        f" )"
    )
    return evaluate_fhir_path(resource, expr_str)
```

### Construct Data Frame
There will be multiple rows for some insights/resources in this data frame, because there are mutliple spans that caused the resource to be derived.


```python
resources_df["spans"] = resources_df.apply(
    lambda row: get_spans(
        row["resource_json"],
        row["insight_id_system"],
        row["insight_id_value"],
        row["derived_from_resource"],
        row["derived_from_path"],
    ),
    axis=1,
)
resources_df = resources_df.explode("spans")

resources_df[["span_begin", "span_end"]] = resources_df["spans"].str.split(
    ",", expand=True
)
resources_df.drop(labels=["spans"], axis="columns", inplace=True)
resources_df.loc[
    :,
    [
        "resource_id",
        "resource_type",
        "text",
        "derived_from_resource",
        "derived_from_path",
        "span_begin",
        "span_end",
    ],
]
```




<div>
<style scoped>
    .dataframe tbody tr th:only-of-type {
        vertical-align: middle;
    }

    .dataframe tbody tr th {
        vertical-align: top;
    }

    .dataframe thead th {
        text-align: right;
    }
</style>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>resource_id</th>
      <th>resource_type</th>
      <th>text</th>
      <th>derived_from_resource</th>
      <th>derived_from_path</th>
      <th>span_begin</th>
      <th>span_end</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>3</th>
      <td>17e9d5ddf76-2a1b470e-3808-442d-a1af-857b7532b740</td>
      <td>MedicationStatement</td>
      <td>Losartan</td>
      <td>DiagnosticReport/17e9d5ddf75-b3eb69d7-fd03-4caf-8fe6-d8e4f2a73b2c</td>
      <td>DiagnosticReport.presentedForm[0].data</td>
      <td>67</td>
      <td>75</td>
    </tr>
    <tr>
      <th>3</th>
      <td>17e9d5ddf76-2a1b470e-3808-442d-a1af-857b7532b740</td>
      <td>MedicationStatement</td>
      <td>Losartan</td>
      <td>DiagnosticReport/17e9d5ddf75-b3eb69d7-fd03-4caf-8fe6-d8e4f2a73b2c</td>
      <td>DiagnosticReport.presentedForm[0].data</td>
      <td>98</td>
      <td>106</td>
    </tr>
    <tr>
      <th>6</th>
      <td>17e9d5ddf76-f5a481e8-1c92-4179-bb4d-2c668cc9bd66</td>
      <td>Condition</td>
      <td>myocardial infarction</td>
      <td>DiagnosticReport/17e9d5ddf75-b3eb69d7-fd03-4caf-8fe6-d8e4f2a73b2c</td>
      <td>DiagnosticReport.presentedForm[0].data</td>
      <td>18</td>
      <td>39</td>
    </tr>
  </tbody>
</table>
</div>



### Display source text with spans highlighted

Once the previous dataframe has been created, it's not hard to group by the source resource and path, and display the text from that location the spans highlighted.
In this example, the spans related to medication statements are in bold, and spans related to conditions are in italics.

This type of processing is important for an application that needs to present the information that was derived from some text to a user.


```python
def group_of_spans_to_html(group_rows):
    """Custom aggregate of the a data frame with "resource_type", "span_begin" and "span_end"
    columns. The group name is a tuple of (derived_resource_location, derived_from_text_path)
    """
    source_text = get_source_text(group_rows.name[0], group_rows.name[1])

    markup_points = []

    # Points is a series of (resource_type, begin or end, offset) tuples
    # sorted in offset ascending order
    points = (
        resources_df.apply(
            lambda row: [
                (row["resource_type"], "begin", int(row["span_begin"])),
                (row["resource_type"], "end", int(row["span_end"])),
            ],
            axis=1,
        )
        .explode()
        .sort_values(key=lambda series: [e[2] for e in series], ascending=True)
    )

    # tags is used to to figure out what type of HTML to insert at a given point
    tags = {
        "Condition": {"begin": '<I><span style="color: green">', "end": "</span></I>"},
        "MedicationStatement": {
            "begin": '<B><span style="color: blue">',
            "end": "</span></B>",
        },
    }

    # build the result string
    result = []
    cur_end = 0
    for pt in points:
        result.append(source_text[cur_end : pt[2]])
        result.append(tags[pt[0]][pt[1]])
        cur_end = pt[2]
    result.append(source_text[cur_end:])

    return "".join(result)
```


```python
sources = resources_df.groupby(by=["derived_from_resource", "derived_from_path"]).apply(
    group_of_spans_to_html
)

sources = sources.to_frame().reset_index().rename(columns={0: "text"})
display(HTML(pd.DataFrame(sources).to_html(escape=False)))
```


<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>derived_from_resource</th>
      <th>derived_from_path</th>
      <th>text</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>0</th>
      <td>DiagnosticReport/17e9d5ddf75-b3eb69d7-fd03-4caf-8fe6-d8e4f2a73b2c</td>
      <td>DiagnosticReport.presentedForm[0].data</td>
      <td>The patient had a <I><span style="color: green">myocardial infarction</span></I> in 2015 and was prescribed <B><span style="color: blue">Losartan</span></B>.The patient is taking <B><span style="color: blue">Losartan</span></B> exactly as prescribed and has had no side effects.</td>
    </tr>
  </tbody>
</table>


# Retrieve Evidence for enriched resources
---

When nlp-insights derives an additional code for a resource's codings, it adds a summary extension to the code element. We'll use this extension to find the derived codes, and the evidence for those codes


```python
# reset datafram to all resources for the patient
resources_df = original_resources_df
resources_df["text"] = resources_df.loc[:, "resource_json"].apply(get_code_text)
```

## Define a function to retrieve codes

This FHIRPath expression returns all the codes on a resource, derived or not. The result is a list of "system,code" strings.


```python
def get_all_codes(resource):
    # returns system,code  for code
    expr_str = f"Condition.code.coding.select(system + ',' + code) | AllergyIntolerance.code.coding.select(system + ',' + code)"
    return evaluate_fhir_path(resource, expr_str)
```

## Define a function to retrieve the summary extension for a code

This uses a FHIRPath expression to look for the insight summary extension on a code, and retrieve a string "insight-id-system,insight-id-value"


```python
def get_summary_extension_for_code(resource, code_system, code_value):
    expr_str = (
        f"(Condition | AllergyIntolerance).code.coding.where("
        f"    system = '{code_system}' and code = '{code_value}'"
        f")"
        f".extension('{summary_ext_url}').where("
        f"    extension('{category_ext_url}').value.coding.code = 'natural-language-processing'"
        f" )"
        f".extension('{insight_id_ext_url}').value.select(system + ',' + value)"
    )
    return evaluate_fhir_path(resource, expr_str)
```

## Construct a data frame of Derived codes

This code constructs a dataframe that contains columns with the insight id system and insight id value...we can use this information to determine where the code was derived from.

The *acd* in the insight id system tells us that ACD was used to derive the code.


```python
# Dataframe for All codes
resources_df["code"] = resources_df.apply(
    lambda row: get_all_codes(row["resource_json"]), axis=1
)
resources_df = resources_df.explode("code")
resources_df.dropna(subset=["code"], inplace=True)
resources_df[["code_system", "code_value"]] = resources_df["code"].str.split(
    ",", expand=True
)
resources_df.drop(labels=["code"], axis="columns", inplace=True)
```


```python
# Filter to only include codes with associated insights
resources_df["summary"] = resources_df.apply(
    lambda row: get_summary_extension_for_code(
        row["resource_json"], row["code_system"], row["code_value"]
    ),
    axis=1,
)
resources_df = resources_df.explode("summary")
resources_df.dropna(subset=["summary"], inplace=True)
resources_df[["insight_id_system", "insight_id_value"]] = resources_df[
    "summary"
].str.split(",", expand=True)
resources_df.loc[
    :,
    [
        "resource_id",
        "resource_type",
        "text",
        "code_system",
        "code_value",
        "insight_id_system",
        "insight_id_value",
    ],
]
```




<div>
<style scoped>
    .dataframe tbody tr th:only-of-type {
        vertical-align: middle;
    }

    .dataframe tbody tr th {
        vertical-align: top;
    }

    .dataframe thead th {
        text-align: right;
    }
</style>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>resource_id</th>
      <th>resource_type</th>
      <th>text</th>
      <th>code_system</th>
      <th>code_value</th>
      <th>insight_id_system</th>
      <th>insight_id_value</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>1</th>
      <td>17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance</td>
      <td>peanut</td>
      <td>http://terminology.hl7.org/CodeSystem/umls</td>
      <td>C0559470</td>
      <td>urn:alvearie.io/health_patterns/services/nlp_insights/acd</td>
      <td>31d8f5eaf30190bba2cab9a18c95306901c197f3e14a6fc68f9dc276</td>
    </tr>
    <tr>
      <th>1</th>
      <td>17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance</td>
      <td>peanut</td>
      <td>http://snomed.info/sct</td>
      <td>91935009</td>
      <td>urn:alvearie.io/health_patterns/services/nlp_insights/acd</td>
      <td>31d8f5eaf30190bba2cab9a18c95306901c197f3e14a6fc68f9dc276</td>
    </tr>
    <tr>
      <th>1</th>
      <td>17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance</td>
      <td>peanut</td>
      <td>http://hl7.org/fhir/sid/icd-9-cm</td>
      <td>995.3</td>
      <td>urn:alvearie.io/health_patterns/services/nlp_insights/acd</td>
      <td>31d8f5eaf30190bba2cab9a18c95306901c197f3e14a6fc68f9dc276</td>
    </tr>
    <tr>
      <th>1</th>
      <td>17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance</td>
      <td>peanut</td>
      <td>http://hl7.org/fhir/sid/icd-10-cm</td>
      <td>Z91.010</td>
      <td>urn:alvearie.io/health_patterns/services/nlp_insights/acd</td>
      <td>31d8f5eaf30190bba2cab9a18c95306901c197f3e14a6fc68f9dc276</td>
    </tr>
    <tr>
      <th>1</th>
      <td>17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance</td>
      <td>peanut</td>
      <td>http://hl7.org/fhir/sid/icd-10-cm</td>
      <td>Z91.0</td>
      <td>urn:alvearie.io/health_patterns/services/nlp_insights/acd</td>
      <td>31d8f5eaf30190bba2cab9a18c95306901c197f3e14a6fc68f9dc276</td>
    </tr>
    <tr>
      <th>2</th>
      <td>17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance</td>
      <td>amoxicillin</td>
      <td>http://terminology.hl7.org/CodeSystem/umls</td>
      <td>C0571417</td>
      <td>urn:alvearie.io/health_patterns/services/nlp_insights/acd</td>
      <td>6134e9e926a775975004b69d42e225f467b50690aa4992d98922715e</td>
    </tr>
    <tr>
      <th>2</th>
      <td>17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance</td>
      <td>amoxicillin</td>
      <td>http://snomed.info/sct</td>
      <td>294505008</td>
      <td>urn:alvearie.io/health_patterns/services/nlp_insights/acd</td>
      <td>6134e9e926a775975004b69d42e225f467b50690aa4992d98922715e</td>
    </tr>
    <tr>
      <th>2</th>
      <td>17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance</td>
      <td>amoxicillin</td>
      <td>http://hl7.org/fhir/sid/icd-9-cm</td>
      <td>E930.0</td>
      <td>urn:alvearie.io/health_patterns/services/nlp_insights/acd</td>
      <td>6134e9e926a775975004b69d42e225f467b50690aa4992d98922715e</td>
    </tr>
    <tr>
      <th>2</th>
      <td>17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance</td>
      <td>amoxicillin</td>
      <td>http://hl7.org/fhir/sid/icd-9-cm</td>
      <td>995.27</td>
      <td>urn:alvearie.io/health_patterns/services/nlp_insights/acd</td>
      <td>6134e9e926a775975004b69d42e225f467b50690aa4992d98922715e</td>
    </tr>
    <tr>
      <th>2</th>
      <td>17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance</td>
      <td>amoxicillin</td>
      <td>http://hl7.org/fhir/sid/icd-10-cm</td>
      <td>Z88.0</td>
      <td>urn:alvearie.io/health_patterns/services/nlp_insights/acd</td>
      <td>6134e9e926a775975004b69d42e225f467b50690aa4992d98922715e</td>
    </tr>
    <tr>
      <th>5</th>
      <td>17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition</td>
      <td>diabetes</td>
      <td>http://terminology.hl7.org/CodeSystem/umls</td>
      <td>C0011849</td>
      <td>urn:alvearie.io/health_patterns/services/nlp_insights/acd</td>
      <td>ba6da20b9ef2b1b4ed2eb1b064fb96a00126b1aacc8e9a5519df1050</td>
    </tr>
    <tr>
      <th>5</th>
      <td>17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition</td>
      <td>diabetes</td>
      <td>http://snomed.info/sct</td>
      <td>73211009</td>
      <td>urn:alvearie.io/health_patterns/services/nlp_insights/acd</td>
      <td>ba6da20b9ef2b1b4ed2eb1b064fb96a00126b1aacc8e9a5519df1050</td>
    </tr>
    <tr>
      <th>5</th>
      <td>17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition</td>
      <td>diabetes</td>
      <td>http://hl7.org/fhir/sid/icd-9-cm</td>
      <td>250.00</td>
      <td>urn:alvearie.io/health_patterns/services/nlp_insights/acd</td>
      <td>ba6da20b9ef2b1b4ed2eb1b064fb96a00126b1aacc8e9a5519df1050</td>
    </tr>
    <tr>
      <th>5</th>
      <td>17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition</td>
      <td>diabetes</td>
      <td>http://hl7.org/fhir/sid/icd-10-cm</td>
      <td>E14.9</td>
      <td>urn:alvearie.io/health_patterns/services/nlp_insights/acd</td>
      <td>ba6da20b9ef2b1b4ed2eb1b064fb96a00126b1aacc8e9a5519df1050</td>
    </tr>
  </tbody>
</table>
</div>



## Determine how the code was derived

The insight extension in the meta contains the information about where the code was derived from. In the case of enrichment, this information is pretty simple. The code is always derived from the text associated with the enclosing code structure. The reference resource is always the same resource as the one being enriched. However these facts are explicitly stated in the insight extension.

We can verify this with the get_derived_from method that we created earlier for the derived resources example.

### Construct a Data Frame with reference resource and path


```python
resources_df["from"] = resources_df.apply(
    lambda row: get_derived_from(
        row["resource_json"], row["insight_id_system"], row["insight_id_value"]
    ),
    axis=1,
)
resources_df = resources_df.explode("from")
resources_df[["derived_from_resource", "derived_from_path"]] = resources_df[
    "from"
].str.split(";", expand=True)
resources_df.drop(labels=["from"], axis="columns", inplace=True)
resources_df.loc[
    :,
    [
        "resource_id",
        "resource_type",
        "text",
        "code_system",
        "code_value",
        "derived_from_resource",
        "derived_from_path",
    ],
]
```




<div>
<style scoped>
    .dataframe tbody tr th:only-of-type {
        vertical-align: middle;
    }

    .dataframe tbody tr th {
        vertical-align: top;
    }

    .dataframe thead th {
        text-align: right;
    }
</style>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>resource_id</th>
      <th>resource_type</th>
      <th>text</th>
      <th>code_system</th>
      <th>code_value</th>
      <th>derived_from_resource</th>
      <th>derived_from_path</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>1</th>
      <td>17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance</td>
      <td>peanut</td>
      <td>http://terminology.hl7.org/CodeSystem/umls</td>
      <td>C0559470</td>
      <td>AllergyIntolerance/17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance.code.text</td>
    </tr>
    <tr>
      <th>1</th>
      <td>17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance</td>
      <td>peanut</td>
      <td>http://snomed.info/sct</td>
      <td>91935009</td>
      <td>AllergyIntolerance/17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance.code.text</td>
    </tr>
    <tr>
      <th>1</th>
      <td>17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance</td>
      <td>peanut</td>
      <td>http://hl7.org/fhir/sid/icd-9-cm</td>
      <td>995.3</td>
      <td>AllergyIntolerance/17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance.code.text</td>
    </tr>
    <tr>
      <th>1</th>
      <td>17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance</td>
      <td>peanut</td>
      <td>http://hl7.org/fhir/sid/icd-10-cm</td>
      <td>Z91.010</td>
      <td>AllergyIntolerance/17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance.code.text</td>
    </tr>
    <tr>
      <th>1</th>
      <td>17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance</td>
      <td>peanut</td>
      <td>http://hl7.org/fhir/sid/icd-10-cm</td>
      <td>Z91.0</td>
      <td>AllergyIntolerance/17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance.code.text</td>
    </tr>
    <tr>
      <th>2</th>
      <td>17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance</td>
      <td>amoxicillin</td>
      <td>http://terminology.hl7.org/CodeSystem/umls</td>
      <td>C0571417</td>
      <td>AllergyIntolerance/17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance.code.text</td>
    </tr>
    <tr>
      <th>2</th>
      <td>17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance</td>
      <td>amoxicillin</td>
      <td>http://snomed.info/sct</td>
      <td>294505008</td>
      <td>AllergyIntolerance/17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance.code.text</td>
    </tr>
    <tr>
      <th>2</th>
      <td>17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance</td>
      <td>amoxicillin</td>
      <td>http://hl7.org/fhir/sid/icd-9-cm</td>
      <td>E930.0</td>
      <td>AllergyIntolerance/17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance.code.text</td>
    </tr>
    <tr>
      <th>2</th>
      <td>17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance</td>
      <td>amoxicillin</td>
      <td>http://hl7.org/fhir/sid/icd-9-cm</td>
      <td>995.27</td>
      <td>AllergyIntolerance/17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance.code.text</td>
    </tr>
    <tr>
      <th>2</th>
      <td>17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance</td>
      <td>amoxicillin</td>
      <td>http://hl7.org/fhir/sid/icd-10-cm</td>
      <td>Z88.0</td>
      <td>AllergyIntolerance/17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance.code.text</td>
    </tr>
    <tr>
      <th>5</th>
      <td>17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition</td>
      <td>diabetes</td>
      <td>http://terminology.hl7.org/CodeSystem/umls</td>
      <td>C0011849</td>
      <td>Condition/17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition.code.text</td>
    </tr>
    <tr>
      <th>5</th>
      <td>17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition</td>
      <td>diabetes</td>
      <td>http://snomed.info/sct</td>
      <td>73211009</td>
      <td>Condition/17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition.code.text</td>
    </tr>
    <tr>
      <th>5</th>
      <td>17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition</td>
      <td>diabetes</td>
      <td>http://hl7.org/fhir/sid/icd-9-cm</td>
      <td>250.00</td>
      <td>Condition/17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition.code.text</td>
    </tr>
    <tr>
      <th>5</th>
      <td>17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition</td>
      <td>diabetes</td>
      <td>http://hl7.org/fhir/sid/icd-10-cm</td>
      <td>E14.9</td>
      <td>Condition/17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition.code.text</td>
    </tr>
  </tbody>
</table>
</div>



### Retrieve source text
We can use the path from the previous data frame to retrieve the source text. While we could use the source resource's id to retrieve the source resource from the FHIR server, we know that this is always going to be the same resource as the enriched one, so for simplicity and performance we won't retrieve the resource (although we could if we wanted to).

Finding the source text is then a simple matter of evaluating the derived_from_path in the previous data frame against the enriched resource.



```python
resources_df["source_text"] = resources_df.apply(
    lambda row: evaluate_fhir_path(row["resource_json"], row["derived_from_path"]),
    axis=1,
)
resources_df = resources_df.explode("source_text")
resources_df.loc[
    :,
    [
        "resource_id",
        "resource_type",
        "text",
        "code_system",
        "code_value",
        "derived_from_resource",
        "derived_from_path",
        "source_text",
    ],
]
```




<div>
<style scoped>
    .dataframe tbody tr th:only-of-type {
        vertical-align: middle;
    }

    .dataframe tbody tr th {
        vertical-align: top;
    }

    .dataframe thead th {
        text-align: right;
    }
</style>
<table border="1" class="dataframe">
  <thead>
    <tr style="text-align: right;">
      <th></th>
      <th>resource_id</th>
      <th>resource_type</th>
      <th>text</th>
      <th>code_system</th>
      <th>code_value</th>
      <th>derived_from_resource</th>
      <th>derived_from_path</th>
      <th>source_text</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th>1</th>
      <td>17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance</td>
      <td>peanut</td>
      <td>http://terminology.hl7.org/CodeSystem/umls</td>
      <td>C0559470</td>
      <td>AllergyIntolerance/17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance.code.text</td>
      <td>peanut</td>
    </tr>
    <tr>
      <th>1</th>
      <td>17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance</td>
      <td>peanut</td>
      <td>http://snomed.info/sct</td>
      <td>91935009</td>
      <td>AllergyIntolerance/17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance.code.text</td>
      <td>peanut</td>
    </tr>
    <tr>
      <th>1</th>
      <td>17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance</td>
      <td>peanut</td>
      <td>http://hl7.org/fhir/sid/icd-9-cm</td>
      <td>995.3</td>
      <td>AllergyIntolerance/17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance.code.text</td>
      <td>peanut</td>
    </tr>
    <tr>
      <th>1</th>
      <td>17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance</td>
      <td>peanut</td>
      <td>http://hl7.org/fhir/sid/icd-10-cm</td>
      <td>Z91.010</td>
      <td>AllergyIntolerance/17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance.code.text</td>
      <td>peanut</td>
    </tr>
    <tr>
      <th>1</th>
      <td>17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance</td>
      <td>peanut</td>
      <td>http://hl7.org/fhir/sid/icd-10-cm</td>
      <td>Z91.0</td>
      <td>AllergyIntolerance/17e9d5ddf75-bc72c640-739c-4c48-b26f-774fa5446720</td>
      <td>AllergyIntolerance.code.text</td>
      <td>peanut</td>
    </tr>
    <tr>
      <th>2</th>
      <td>17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance</td>
      <td>amoxicillin</td>
      <td>http://terminology.hl7.org/CodeSystem/umls</td>
      <td>C0571417</td>
      <td>AllergyIntolerance/17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance.code.text</td>
      <td>amoxicillin</td>
    </tr>
    <tr>
      <th>2</th>
      <td>17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance</td>
      <td>amoxicillin</td>
      <td>http://snomed.info/sct</td>
      <td>294505008</td>
      <td>AllergyIntolerance/17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance.code.text</td>
      <td>amoxicillin</td>
    </tr>
    <tr>
      <th>2</th>
      <td>17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance</td>
      <td>amoxicillin</td>
      <td>http://hl7.org/fhir/sid/icd-9-cm</td>
      <td>E930.0</td>
      <td>AllergyIntolerance/17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance.code.text</td>
      <td>amoxicillin</td>
    </tr>
    <tr>
      <th>2</th>
      <td>17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance</td>
      <td>amoxicillin</td>
      <td>http://hl7.org/fhir/sid/icd-9-cm</td>
      <td>995.27</td>
      <td>AllergyIntolerance/17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance.code.text</td>
      <td>amoxicillin</td>
    </tr>
    <tr>
      <th>2</th>
      <td>17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance</td>
      <td>amoxicillin</td>
      <td>http://hl7.org/fhir/sid/icd-10-cm</td>
      <td>Z88.0</td>
      <td>AllergyIntolerance/17e9d5ddf76-7293ecc8-8b6a-497a-881c-b6eeed1250be</td>
      <td>AllergyIntolerance.code.text</td>
      <td>amoxicillin</td>
    </tr>
    <tr>
      <th>5</th>
      <td>17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition</td>
      <td>diabetes</td>
      <td>http://terminology.hl7.org/CodeSystem/umls</td>
      <td>C0011849</td>
      <td>Condition/17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition.code.text</td>
      <td>diabetes</td>
    </tr>
    <tr>
      <th>5</th>
      <td>17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition</td>
      <td>diabetes</td>
      <td>http://snomed.info/sct</td>
      <td>73211009</td>
      <td>Condition/17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition.code.text</td>
      <td>diabetes</td>
    </tr>
    <tr>
      <th>5</th>
      <td>17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition</td>
      <td>diabetes</td>
      <td>http://hl7.org/fhir/sid/icd-9-cm</td>
      <td>250.00</td>
      <td>Condition/17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition.code.text</td>
      <td>diabetes</td>
    </tr>
    <tr>
      <th>5</th>
      <td>17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition</td>
      <td>diabetes</td>
      <td>http://hl7.org/fhir/sid/icd-10-cm</td>
      <td>E14.9</td>
      <td>Condition/17e9d5ddf75-51cfac33-b53e-4b65-95e3-781549aab119</td>
      <td>Condition.code.text</td>
      <td>diabetes</td>
    </tr>
  </tbody>
</table>
</div>



## Spans
For enrichment, there are no span extensions stored in the insight detail extensions. 

That's because the entire text is used for the insight, along with the context of the text. (For example 'peanut' in an AllergyIntolerance should result in peanut allergy codes, not a code for a plant or food.)

These text fragments contain only information related to the derived codes and the context is defined by the resource. As a result span and confidence values are not interesting.

# Summary
---
In this tutorial we:

* Created a bundle
* Enriched the bundle using the nlp-insights service
* Posted the resources to a FHIR Server
* Retrieved resources derived by NLP and determined what caused them to be derived
* Retrieved derived codes for enriched resources and determined what caused them to be derived
