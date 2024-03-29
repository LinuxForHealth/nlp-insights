# HTTP Endpoints

## Discover Insights
The discoverInsights API accepts an input bundle and returns an updated bundle with:

* Resources that have been enriched with additional codes
* Resources that have been derived from unstructured text (such as clinical notes) contained within the bundle's resources.
 
| Action | Method | Endpoint | Body | Returns on Success |
|:------:|:------:|:---------|:----:|:-------:|
| Add insights | `POST` | `/discoverInsights` | FHIR bundle | Enriched FHIR Bundle |

Derived and Enriched types are described in the tutorials.

* [Derive new resources with ACD](../examples/acd/derive_new_resources.md)
* [Enrich resources with ACD](../examples/acd/enrich.md)
* [Derive new resources with QuickUMLS](../examples/quickumls/derive_new_resources.md)
* [Enrich resources with QuickUmls](../examples/quickumls/enrich.md)

### Discover Insights and non-bundle resources

If the discoverInsights API is called with a FHIR resource that is *not* a bundle, then the returned data depends on the input type:
 
 Body Type | Returns 
 --- | ---
 DiagnosticReport or Document Reference | A bundle of derived resources, or an empty bundle if no resources were derived.
 Condition or AllergyIntolerance | The resource is returned with additional codes, or with no additional codes if no codes were derived.

Other resource types *may* return an error.

??? Warning ":warning: This is an experimental feature that requires resources to have a valid identifier."


    When posting a resource that is not a bundle, the resource __must__ have a valid identifier.
    The identifier allows references to the resource to be created. These references are critical for defining the source of an insight, and/or the subject (patient) that 
    resource is associated with. The identifier is assigned to a unique value by the FHIR server when the resource is created on the server.

    If a pipeline such as health-patterns invokes the discoverInsights API before creating the resources in thie FHIR server, then the resource's identifier has not been set yet. 
    This problem can be avoided by posting a bundle of resources.

    When a bundle is posted, the bundle contains a list of bundeEntry objects, with each object containing an optional fullUrl and a resource.
    nlp-insights uses the fullUrl property in the bundleEntry to indentify the resource when a reference is needed. The FHIR server will update the references to the fullUrl with the 
    actual ID when it assigns IDs for the resource.  If the fullUrl property is not set, then nlp-insights assigns a UUID to the property.
    This allows nlp-insights to process bundles *before* the FHIR server has assigned IDs for resources.

    The health-patterns ingestion pipline seeks to enrich the bundle with insights *before* creating resources on the FHIR server. For this reason, posting individual resources is not
    possible. Because health-patterns is the primary use of the service, posting individual resources is an experimential feature.

## Configuration
The app currently supports running two different NLP engine types: 

* [IBM's Annotator for Clinical Data (ACD)](https://www.ibm.com/cloud/watson-annotator-for-clinical-data) and 
* [open-source QuickUMLS](https://github.com/Georgetown-IR-Lab/QuickUMLS)

It is possible to configure as many different instances of these two engines as needed with different configuration details.

### Configuration Definition
The configuration definition jsons that are used by the APIs require a `name`, an `nlpServiceType` (either `acd` or `quickumls`), and config details specific to that type.

#### QuickUmls
For QuickUmls, an `endpoint` is required.

Sample configuration json:

```json
{
  "name": "quickconfig1",
  "nlpServiceType": "quickumls",
  "config": {
    "endpoint": "https://quickumls.wh-health-patterns.dev.watson-health.ibm.com/match"
  }
}
```

#### ACD
For ACD, an `endpoint`, an `apikey`, and a `flow` are required. The nlp-insights service is desgined to work with the
flow `wh_acd.ibm_clinical_insights_v1.0_standard_flow`, other flows may require code modifications.

Sample Configuration json:

```json
{
  "name": "acdconfig1",
  "nlpServiceType": "acd",
  "config": {
    "apikey": "***api key***",
    "endpoint": "https://<endpoint-url>/wh-acd/api",
    "flow": "wh_acd.ibm_clinical_insights_v1.0_standard_flow"
  }
}
```
### Configuration endpoints
These APIs are used for configuring the NLP engine that will be used to discover insights. Successful requests will return a 2xx status code. Requests using the GET method will also respond with a json object in the response body.

<table cellspacing=0 cellpadding=0 border=0>
<thead>
<tr align="left"><th> &nbsp; </th><th> Method &<BR/> Endpoint</th><th> Body </th><th> Response Body on Success </th></tr>
</thead>
<tbody>
<tr> <th colspan=4  align="left"> Config Definition</th></tr>

<tr><td> Get All Configs </td><td> GET <BR/><I><code>/all_configs</code></I></td><td></td><td> Config definition names: 

```json 
{
  "all_configs": [
    "acdconfig1",
    "quickconfig1"
  ]
}
``` 

</td></tr>

<tr><td> Add Named Config </td><td> PUT/POST <BR/><I><code>/config/definition</code></I></td><td> json config see:

<BR/>
<a href="#configuration-definition">Configuration Definition</a> 

</td><td>Status: <CODE>204 NO CONTENT</CODE></td></tr>

<tr><td> Delete Config </td><td> DELETE<BR/><I><code>/config/{configName}</code></I></td> <td></td><td>Status: <CODE>204 NO CONTENT</CODE></td></tr>

<tr><td> Get Config Details </td><td> GET <BR/><I><Code>/config/{configName}</CODE></I></td><td></td><td>
Configuration json (sensitive data will be masked):
<br/><br/>

QuickUmls Example:

```json
{
  "name": "quickconfig1",
  "nlpServiceType": "quickumls",
  "config": {
    "endpoint": "http://endpoint/match"
  }
}
```

ACD Example:

```json
{
  "name": "acdconfig1",
  "nlpServiceType": "acd",
  "config": {
    "apikey": "********************************************",
    "endpoint": "https://endpoint/api",
    "flow": "wh_acd.ibm_clinical_insights_v1.0_standard_flow"
  }
}

```

</td></tr>

</tbody>
<tbody>
<tr><th colspan=4 align="left"> Default NLP</th></tr>

<tr><td> Make Config default </td><td> POST/PUT <BR/><I><Code>/config/setDefault?name={configName}</CODE></I></td><td></td><td>Status: <CODE>204 NO CONTENT</CODE></td></tr>

<tr><td> Get Current Default Config </td><td> GET <BR/><I><Code>/config</Code></I></td><td></td><td> Current default configName:

```json
{
  "config": "acdconfig1"
}
```
</td></tr>

<tr><td> Clear default config </td><td> POST/PUT <BR/><I><CODE>/config/clearDefault</CODE></I></td><td> </td><td>Status: <CODE>204 NO CONTENT</CODE></td></tr>


</tbody><tbody>
<tr><th colspan=4 align="left"> Override NLP Engine for a resource </th></tr>

<tr><td>  Get all active overrides </td><td> GET <BR/><I><CODE>/config/resource</CODE></I> </td><td></td><td>
Dictionary of overrides:

```json
{
  "AllergyIntolerance": "acdconfig1",
  "Condition": "acdconfig1"
}
```

If no overrides are defined:

```json
{}
```

</td></tr>

<tr><td>Get the active override for a resource </td><td> GET <Br/><I><CODE>/config/resource/{resource}</CODE></I></td><td> </td><td>
Dictionary of override:

```json
{
  "Condition": "acdconfig1"
}
```

If no override is defined:

```json
{
  "AllergyIntolerance": null
}
```
</td></tr>
<tr><td>Add resource override</td><td>POST/PUT<br/><I><CODE>/config/resource/{resourcetype}/{configName}</CODE></I></td><td></td><td>Status: <CODE>204 NO CONTENT</CODE></td></tr>
<tr><td>Delete a resource override</td><td>DELETE<BR/><I><CODE>/config/resource/{resourcetype}</CODE></I></td><td></td><td>Status: <CODE>204 NO CONTENT</CODE></td></tr>
<tr><td>Delete all resource overrides</td><td>DELETE<br/><I><CODE>/config/resource</CODE></I></td><td></td><td>Status: <CODE>204 NO CONTENT</CODE></td></tr>
</tbody>
</table> 


# Error Responses
Responses with status codes in the 4xx range usually have a json body with a "message" property with a human readable description. Other details about the error may also be included in the structure.

## Example response when an invalid json is sent to the discoverInsights API:
* Status Code = 400

```json
{
  "message": "Resource was not valid json: Expecting property name enclosed in double quotes: line 29 column 10 (char 676)"
}
```

## Example response when an invalid FHIR resource is sent to the discoverInsights API
* Status Code = 400

```json
{
  "message": "Resource was not valid",
  "details": [
    {
      "loc": [
        "reaction",
        0,
        "manifestation",
        0,
        "text2"
      ],
      "msg": "extra fields not permitted",
      "type": "value_error.extra"
    }
  ]
}
```
