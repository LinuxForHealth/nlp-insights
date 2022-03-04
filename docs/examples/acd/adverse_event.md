# Adverse Events
When the nlp-insights service is configured to use ACD for NLP processing, the service will discover [AdverseEvent FHIR resources](https://www.hl7.org/fhir/adverseevent.html).

Within the FHIR standard, an adverse event is the result of an intervention that caused unintentional harm to a specific subject or group of subjects.

The nlp-insights service will detect adverse events that are **medication** related, such as a drug interaction.
> :point_right: The FHIR standard states that an [AdverseEvent resource should not be used when a more specific resource exists](https://www.hl7.org/fhir/adverseevent.html#bnr). This means that the adverse event should not be discovered for an allergic reaction to a medication, since FHIR defines an AllergyIntolerance resource that is more specific. The differentiation of an adverse event from other FHIR concepts such as allergies requires an advanced NLP engine such as ACD, since more language awareness is required than simple pattern matching can provide.

> :construction: Adverse events are characterized by the need to capture cause and effect, in addition to actuality, 
> severity and outcome. The nlp-insights service currently limits discovery to the detection of medication related
> adverse events. There is no support for creating cause/effect/outcome relationships with
> other resources that represent characteristics of the event. Standard codes such as SNOMED CT and MedDRA are NOT included 
> in the created AdverseEvent FHIR resource.
> While detection is a significant step forward, further contributions to this feature will be needed when more
> ACD support becomes available. :construction:

The capabilities of the nlp-insights service are best explained using an example.

> :raised_hand: Before using the nlp-insights service, it must be started and configured for ACD.  
> If the nlp-insights service has not been started and configured to use ACD, follow the steps [here](./configure_acd.md).


## Derive insights from a diagnostic report that describes an adverse event
Adverse Events are very challenging for NLP to recognize because they involve multiple concepts, temporal relationships and causality.

This example is typical; There is no single concept or span of text that indicates an Adverse Event happened. 

```
B64_REPORT_TEXT=$(echo "\
The patient's course was also complicated by mental status \
changes secondary to a combination of his narcotics and Neurontin, \
which had been given for his trigeminal neuralgia and chronic pain. \
The Neurontin was stopped and he received hemodialysis on consecutive days.\
" | base64 -w 0)
```

The diagnostic report is built and sent to the nlp-insights service for insight discovery. 
The returned resources are stored in a json file for future analysis. (The report text has alredy been converted to base64 encoding,
so that it can be attached to a diagnostic report).


```
curl  -w "\n%{http_code}\n" -s -o /tmp/output.json -XPOST localhost:5000/discoverInsights  -H 'Content-Type: application/json; charset=utf-8' --data-binary @- << EOF
{
    "resourceType": "Bundle",
    "id": "abc",
    "type": "transaction",
    "entry": [
        {
            "resource": {
                "id": "abcefg-1234567890",
                "status": "final",
                "code": {
                    "text": "Chief complaint Narrative - Reported"
                },
                "presentedForm": [
                    {
                        "contentType": "text",
                        "language": "en",
                        "data": "$B64_REPORT_TEXT",
                        "title": "ER VISIT",
                        "creation": "2020-08-02T12:44:55+08:00"
                    }
                ],
                "resourceType": "DiagnosticReport"
            },
            "request": {
                "method": "POST",
                "url": "DiagnosticReport"
            }
        }
    ]
}
EOF

```


## Adverse Event Resources
In addition to two conditions and a medication statement, the nlp-insights service has discovered adverse events associated with "narcotics" and "neurontin".

<!--
cat /tmp/output.json | jq -r '
["Resource Type", "Description"], 
["---", "---"] , 
(.entry[].resource | [.resourceType, .code.text // .event.text // .medicationCodeableConcept.text]) 
| @tsv' | column -t -o "|" -s $'\t'
-->


Resource Type      |Description
---                |---
DiagnosticReport   |Chief complaint Narrative - Reported
Condition          |trigeminal neuralgia
Condition          |chronic pain
MedicationStatement|Neurontin
AdverseEvent       |narcotics
AdverseEvent       |neurontin



The complete json for the two Adverse Events are included here, with the highlights being discussed in the next sections.

<!--
cat /tmp/output.json | jq '.entry[].resource | select(.resourceType=="AdverseEvent" and .event.text=="narcotics")'
-->

<details><summary>Adverse Event resource for "narcotics"</summary>

```json
{
  "meta": {
    "extension": [
      {
        "extension": [
          {
            "url": "http://ibm.com/fhir/cdm/StructureDefinition/insight-id",
            "valueIdentifier": {
              "system": "urn:alvearie.io/health_patterns/services/nlp_insights/acd",
              "value": "a129d489aea84c37b7377201e70cd416fe2b26ce3dc1d29f250fdfa1"
            }
          },
          {
            "url": "http://ibm.com/fhir/cdm/StructureDefinition/path",
            "valueString": "AdverseEvent"
          },
          {
            "extension": [
              {
                "url": "http://ibm.com/fhir/cdm/StructureDefinition/reference",
                "valueReference": {
                  "reference": "urn:uuid:7fbcf71d-44fe-466e-b8d1-bc51cedf000b"
                }
              },
              {
                "url": "http://ibm.com/fhir/cdm/StructureDefinition/reference-path",
                "valueString": "DiagnosticReport.presentedForm[0].data"
              },
              {
                "url": "http://ibm.com/fhir/cdm/StructureDefinition/evaluated-output",
                "valueAttachment": {
                  "contentType": "application/json",
                  "data": "eyJhdHRyaWJ1dGVWYWx1ZXMiOiBbeyJiZWdpbiI6IDEwNCwgImVuZCI6IDExMywgImNvdmVyZWRUZXh0IjogIm5hcmNvdGljcyIsICJuZWdhdGVkIjogZmFsc2UsICJwcmVmZXJyZWROYW1lIjogIm5hcmNvdGljcyIsICJ2YWx1ZXMiOiBbeyJ2YWx1ZSI6ICJuYXJjb3RpY3MifV0sICJzb3VyY2UiOiAiQ2xpbmljYWwgSW5zaWdodHMgLSBBdHRyaWJ1dGVzIiwgInNvdXJjZVZlcnNpb24iOiAidjEuMCIsICJjb25jZXB0IjogeyJ1aWQiOiA4fSwgIm5hbWUiOiAiTWVkaWNhdGlvbkFkdmVyc2VFdmVudCIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIlZBTElEIn0sICJpbnNpZ2h0TW9kZWxEYXRhIjogeyJtZWRpY2F0aW9uIjogeyJ1c2FnZSI6IHsidGFrZW5TY29yZSI6IDEuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMCwgImxhYk1lYXN1cmVtZW50U2NvcmUiOiAwLjB9LCAic3RhcnRlZEV2ZW50IjogeyJzY29yZSI6IDAuOTgyLCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAxLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fSwgImRvc2VDaGFuZ2VkRXZlbnQiOiB7InNjb3JlIjogMC4wMDEsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH19LCAic3RvcHBlZEV2ZW50IjogeyJzY29yZSI6IDAuMDAxLCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAwLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fSwgImFkdmVyc2VFdmVudCI6IHsic2NvcmUiOiAwLjk5OSwgImFsbGVyZ3lTY29yZSI6IDAuMCwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMC4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDEuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX19fX0sIHsiYmVnaW4iOiAxMTgsICJlbmQiOiAxMjcsICJjb3ZlcmVkVGV4dCI6ICJOZXVyb250aW4iLCAibmVnYXRlZCI6IGZhbHNlLCAicHJlZmVycmVkTmFtZSI6ICJuZXVyb250aW4iLCAidmFsdWVzIjogW3sidmFsdWUiOiAibmV1cm9udGluIn1dLCAic291cmNlIjogIkNsaW5pY2FsIEluc2lnaHRzIC0gQXR0cmlidXRlcyIsICJzb3VyY2VWZXJzaW9uIjogInYxLjAiLCAiY29uY2VwdCI6IHsidWlkIjogOX0sICJuYW1lIjogIk1lZGljYXRpb25BZHZlcnNlRXZlbnQiLCAicnhOb3JtSWQiOiAiMTk2NDk4IiwgImRpc2FtYmlndWF0aW9uRGF0YSI6IHsidmFsaWRpdHkiOiAiVkFMSUQifSwgImluc2lnaHRNb2RlbERhdGEiOiB7Im1lZGljYXRpb24iOiB7InVzYWdlIjogeyJ0YWtlblNjb3JlIjogMS4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wLCAibGFiTWVhc3VyZW1lbnRTY29yZSI6IDAuMH0sICJzdGFydGVkRXZlbnQiOiB7InNjb3JlIjogMC45OTgsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDEuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH19LCAiZG9zZUNoYW5nZWRFdmVudCI6IHsic2NvcmUiOiAwLjAwMiwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMC4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX0sICJzdG9wcGVkRXZlbnQiOiB7InNjb3JlIjogMC4wLCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAwLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fSwgImFkdmVyc2VFdmVudCI6IHsic2NvcmUiOiAwLjg5MSwgImFsbGVyZ3lTY29yZSI6IDAuMCwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMC4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuNjc4LCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fX19fSwgeyJiZWdpbiI6IDE2NSwgImVuZCI6IDE4NSwgImNvdmVyZWRUZXh0IjogInRyaWdlbWluYWwgbmV1cmFsZ2lhIiwgIm5lZ2F0ZWQiOiBmYWxzZSwgInByZWZlcnJlZE5hbWUiOiAidHJpZ2VtaW5hbCBuZXVyYWxnaWEiLCAidmFsdWVzIjogW3sidmFsdWUiOiAidHJpZ2VtaW5hbCBuZXVyYWxnaWEifV0sICJzb3VyY2UiOiAiQ2xpbmljYWwgSW5zaWdodHMgLSBBdHRyaWJ1dGVzIiwgInNvdXJjZVZlcnNpb24iOiAidjEuMCIsICJjb25jZXB0IjogeyJ1aWQiOiAxMH0sICJuYW1lIjogIkRpYWdub3NpcyIsICJpY2Q5Q29kZSI6ICIzNTAuMSIsICJpY2QxMENvZGUiOiAiRzUwLjAiLCAic25vbWVkQ29uY2VwdElkIjogIjMxNjgxMDA1IiwgImRpc2FtYmlndWF0aW9uRGF0YSI6IHsidmFsaWRpdHkiOiAiVkFMSUQifSwgImluc2lnaHRNb2RlbERhdGEiOiB7ImRpYWdub3NpcyI6IHsidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAxLjAsICJwYXRpZW50UmVwb3J0ZWRTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfSwgInN1c3BlY3RlZFNjb3JlIjogMC4wLCAic3ltcHRvbVNjb3JlIjogMC4wLCAidHJhdW1hU2NvcmUiOiAwLjAsICJmYW1pbHlIaXN0b3J5U2NvcmUiOiAwLjAwM319LCAiY2NzQ29kZSI6ICI5NSJ9LCB7ImJlZ2luIjogMTkwLCAiZW5kIjogMjAyLCAiY292ZXJlZFRleHQiOiAiY2hyb25pYyBwYWluIiwgIm5lZ2F0ZWQiOiBmYWxzZSwgInByZWZlcnJlZE5hbWUiOiAiY2hyb25pYyBwYWluIiwgInZhbHVlcyI6IFt7InZhbHVlIjogImNocm9uaWMgcGFpbiJ9XSwgInNvdXJjZSI6ICJDbGluaWNhbCBJbnNpZ2h0cyAtIEF0dHJpYnV0ZXMiLCAic291cmNlVmVyc2lvbiI6ICJ2MS4wIiwgImNvbmNlcHQiOiB7InVpZCI6IDExfSwgIm5hbWUiOiAiRGlhZ25vc2lzIiwgImljZDlDb2RlIjogIjMzOC4yOSIsICJpY2QxMENvZGUiOiAiUjUyLjIsUjUyIiwgInNub21lZENvbmNlcHRJZCI6ICI4MjQyMzAwMSIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIlZBTElEIn0sICJpbnNpZ2h0TW9kZWxEYXRhIjogeyJkaWFnbm9zaXMiOiB7InVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMS4wLCAicGF0aWVudFJlcG9ydGVkU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH0sICJzdXNwZWN0ZWRTY29yZSI6IDAuMCwgInN5bXB0b21TY29yZSI6IDAuMDIxLCAidHJhdW1hU2NvcmUiOiAwLjAsICJmYW1pbHlIaXN0b3J5U2NvcmUiOiAwLjB9fSwgImNjc0NvZGUiOiAiMjU5In1dLCAiY29uY2VwdHMiOiBbeyJ0eXBlIjogInVtbHMuTWVudGFsT3JCZWhhdmlvcmFsRHlzZnVuY3Rpb24iLCAiYmVnaW4iOiA1MiwgImVuZCI6IDczLCAiY292ZXJlZFRleHQiOiAibWVudGFsIHN0YXR1cyBjaGFuZ2VzIiwgIm5lZ2F0ZWQiOiBmYWxzZSwgImN1aSI6ICJDMDg1NjA1NCIsICJwcmVmZXJyZWROYW1lIjogIk1lbnRhbCBTdGF0dXMgQ2hhbmdlIiwgInNlbWFudGljVHlwZSI6ICJtb2JkIiwgInNvdXJjZSI6ICJ1bWxzIiwgInNvdXJjZVZlcnNpb24iOiAiMjAyMEFBIiwgImRpc2FtYmlndWF0aW9uRGF0YSI6IHsidmFsaWRpdHkiOiAiTk9fREVDSVNJT04ifSwgIm5jaUNvZGUiOiAiQzE1NzQzNSIsICJsb2luY0lkIjogIkxBNzQ1NS00IiwgInZvY2FicyI6ICJDSFYsTE5DLE5DSSxOQ0lfQ1BUQUMsTVRISUNEOSJ9LCB7InR5cGUiOiAidW1scy5GaW5kaW5nIiwgImJlZ2luIjogODksICJlbmQiOiAxMDAsICJjb3ZlcmVkVGV4dCI6ICJjb21iaW5hdGlvbiIsICJuZWdhdGVkIjogZmFsc2UsICJjdWkiOiAiQzM4MTE5MTAiLCAicHJlZmVycmVkTmFtZSI6ICJjb21iaW5hdGlvbiAtIGFuc3dlciB0byBxdWVzdGlvbiIsICJzZW1hbnRpY1R5cGUiOiAiZm5kZyIsICJzb3VyY2UiOiAidW1scyIsICJzb3VyY2VWZXJzaW9uIjogIjIwMjBBQSIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIk5PX0RFQ0lTSU9OIn0sICJsb2luY0lkIjogIkxBMTI3MDEtMSIsICJ2b2NhYnMiOiAiTVRILExOQyJ9LCB7InR5cGUiOiAidW1scy5IYXphcmRvdXNPclBvaXNvbm91c1N1YnN0YW5jZSIsICJiZWdpbiI6IDEwNCwgImVuZCI6IDExMywgImNvdmVyZWRUZXh0IjogIm5hcmNvdGljcyIsICJuZWdhdGVkIjogZmFsc2UsICJjdWkiOiAiQzAwMjc0MTUiLCAicHJlZmVycmVkTmFtZSI6ICJOYXJjb3RpY3MiLCAic2VtYW50aWNUeXBlIjogImhvcHMiLCAic291cmNlIjogInVtbHMiLCAic291cmNlVmVyc2lvbiI6ICIyMDIwQUEiLCAiZGlzYW1iaWd1YXRpb25EYXRhIjogeyJ2YWxpZGl0eSI6ICJOT19ERUNJU0lPTiJ9LCAibmNpQ29kZSI6ICJDMTUwNiIsICJtZXNoSWQiOiAiTTAwMTQ0ODEiLCAibG9pbmNJZCI6ICJNVEhVMDAzNDcwLExQMTgxNDktMiIsICJ2b2NhYnMiOiAiTENILExOQyxNVEgsQ0hWLENTUCxNU0gsTUVETElORVBMVVMsTENIX05XLE5DSSxOQ0lfTkNJLUdMT1NTIn0sIHsidHlwZSI6ICJ1bWxzLlBoYXJtYWNvbG9naWNTdWJzdGFuY2UiLCAidWlkIjogMiwgImJlZ2luIjogMTA0LCAiZW5kIjogMTEzLCAiY292ZXJlZFRleHQiOiAibmFyY290aWNzIiwgIm5lZ2F0ZWQiOiBmYWxzZSwgImN1aSI6ICJDMDAyNzQxNSIsICJwcmVmZXJyZWROYW1lIjogIk5hcmNvdGljcyIsICJzZW1hbnRpY1R5cGUiOiAicGhzdSIsICJzb3VyY2UiOiAidW1scyIsICJzb3VyY2VWZXJzaW9uIjogIjIwMjBBQSIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIk5PX0RFQ0lTSU9OIn0sICJuY2lDb2RlIjogIkMxNTA2IiwgIm1lc2hJZCI6ICJNMDAxNDQ4MSIsICJsb2luY0lkIjogIk1USFUwMDM0NzAsTFAxODE0OS0yIiwgInZvY2FicyI6ICJMQ0gsTE5DLE1USCxDSFYsQ1NQLE1TSCxNRURMSU5FUExVUyxMQ0hfTlcsTkNJLE5DSV9OQ0ktR0xPU1MiLCAiaW5zaWdodE1vZGVsRGF0YSI6IHsibWVkaWNhdGlvbiI6IHsidXNhZ2UiOiB7InRha2VuU2NvcmUiOiAxLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjAsICJsYWJNZWFzdXJlbWVudFNjb3JlIjogMC4wfSwgInN0YXJ0ZWRFdmVudCI6IHsic2NvcmUiOiAwLjk4MiwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMS4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX0sICJkb3NlQ2hhbmdlZEV2ZW50IjogeyJzY29yZSI6IDAuMDAxLCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAwLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fSwgInN0b3BwZWRFdmVudCI6IHsic2NvcmUiOiAwLjAwMSwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMC4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX0sICJhZHZlcnNlRXZlbnQiOiB7InNjb3JlIjogMC45OTksICJhbGxlcmd5U2NvcmUiOiAwLjAsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAxLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH19fX19LCB7InR5cGUiOiAidW1scy5PcmdhbmljQ2hlbWljYWwiLCAidWlkIjogNiwgImJlZ2luIjogMTE4LCAiZW5kIjogMTI3LCAiY292ZXJlZFRleHQiOiAiTmV1cm9udGluIiwgIm5lZ2F0ZWQiOiBmYWxzZSwgImN1aSI6ICJDMDY3ODE3NiIsICJwcmVmZXJyZWROYW1lIjogIk5ldXJvbnRpbiIsICJzZW1hbnRpY1R5cGUiOiAib3JjaCIsICJzb3VyY2UiOiAidW1scyIsICJzb3VyY2VWZXJzaW9uIjogIjIwMjBBQSIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIk5PX0RFQ0lTSU9OIn0sICJuY2lDb2RlIjogIkMxMTA4IiwgIm1lc2hJZCI6ICJNMDExOTQyMCIsICJyeE5vcm1JZCI6ICIxOTY0OTgiLCAidm9jYWJzIjogIkNIVixNU0gsTkNJLFJYTk9STSxQRFEifSwgeyJ0eXBlIjogInVtbHMuUGhhcm1hY29sb2dpY1N1YnN0YW5jZSIsICJ1aWQiOiAzLCAiYmVnaW4iOiAxMTgsICJlbmQiOiAxMjcsICJjb3ZlcmVkVGV4dCI6ICJOZXVyb250aW4iLCAibmVnYXRlZCI6IGZhbHNlLCAiY3VpIjogIkMwNjc4MTc2IiwgInByZWZlcnJlZE5hbWUiOiAiTmV1cm9udGluIiwgInNlbWFudGljVHlwZSI6ICJwaHN1IiwgInNvdXJjZSI6ICJ1bWxzIiwgInNvdXJjZVZlcnNpb24iOiAiMjAyMEFBIiwgImRpc2FtYmlndWF0aW9uRGF0YSI6IHsidmFsaWRpdHkiOiAiTk9fREVDSVNJT04ifSwgIm5jaUNvZGUiOiAiQzExMDgiLCAibWVzaElkIjogIk0wMTE5NDIwIiwgInJ4Tm9ybUlkIjogIjE5NjQ5OCIsICJ2b2NhYnMiOiAiQ0hWLE1TSCxOQ0ksUlhOT1JNLFBEUSIsICJpbnNpZ2h0TW9kZWxEYXRhIjogeyJtZWRpY2F0aW9uIjogeyJ1c2FnZSI6IHsidGFrZW5TY29yZSI6IDEuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMCwgImxhYk1lYXN1cmVtZW50U2NvcmUiOiAwLjB9LCAic3RhcnRlZEV2ZW50IjogeyJzY29yZSI6IDAuOTk4LCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAxLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fSwgImRvc2VDaGFuZ2VkRXZlbnQiOiB7InNjb3JlIjogMC4wMDIsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH19LCAic3RvcHBlZEV2ZW50IjogeyJzY29yZSI6IDAuMCwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMC4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX0sICJhZHZlcnNlRXZlbnQiOiB7InNjb3JlIjogMC44OTEsICJhbGxlcmd5U2NvcmUiOiAwLjAsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjY3OCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX19fX0sIHsidHlwZSI6ICJ1bWxzLkhlYWx0aENhcmVBY3Rpdml0eSIsICJiZWdpbiI6IDE0NiwgImVuZCI6IDE1NiwgImNvdmVyZWRUZXh0IjogInBlcnNjcmliZWQiLCAibmVnYXRlZCI6IGZhbHNlLCAiY3VpIjogIkMwMjc4MzI5IiwgInByZWZlcnJlZE5hbWUiOiAiUHJlc2NyaWJlZCIsICJzZW1hbnRpY1R5cGUiOiAiaGxjYSIsICJzb3VyY2UiOiAidW1scyIsICJzb3VyY2VWZXJzaW9uIjogIjIwMjBBQSIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIk5PX0RFQ0lTSU9OIn0sICJ2b2NhYnMiOiAiTVRILENIVixMQ0gifSwgeyJ0eXBlIjogInVtbHMuRGlzZWFzZU9yU3luZHJvbWUiLCAidWlkIjogNCwgImJlZ2luIjogMTY1LCAiZW5kIjogMTg1LCAiY292ZXJlZFRleHQiOiAidHJpZ2VtaW5hbCBuZXVyYWxnaWEiLCAibmVnYXRlZCI6IGZhbHNlLCAiY3VpIjogIkMwMDQwOTk3IiwgInByZWZlcnJlZE5hbWUiOiAiVHJpZ2VtaW5hbCBOZXVyYWxnaWEiLCAic2VtYW50aWNUeXBlIjogImRzeW4iLCAic291cmNlIjogInVtbHMiLCAic291cmNlVmVyc2lvbiI6ICIyMDIwQUEiLCAiZGlzYW1iaWd1YXRpb25EYXRhIjogeyJ2YWxpZGl0eSI6ICJOT19ERUNJU0lPTiJ9LCAiaWNkMTBDb2RlIjogIkIwMi4yLEc1MC4wLEc1My4wIiwgInNub21lZENvbmNlcHRJZCI6ICIzMTY4MTAwNSIsICJtZXNoSWQiOiAiTTAwMjE5NjYiLCAidm9jYWJzIjogIk1USCxDU1AsTVNILENTVCxIUE8sT01JTSxDT1NUQVIsSUNQQyxDSFYsTUVETElORVBMVVMsTENIX05XLFFNUixJQ0Q5Q00sU05PTUVEQ1RfVVMsRFhQLE1USElDRDkiLCAiaW5zaWdodE1vZGVsRGF0YSI6IHsiZGlhZ25vc2lzIjogeyJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDEuMCwgInBhdGllbnRSZXBvcnRlZFNjb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9LCAic3VzcGVjdGVkU2NvcmUiOiAwLjAsICJzeW1wdG9tU2NvcmUiOiAwLjAsICJ0cmF1bWFTY29yZSI6IDAuMCwgImZhbWlseUhpc3RvcnlTY29yZSI6IDAuMDAzfX19LCB7InR5cGUiOiAidW1scy5TaWduT3JTeW1wdG9tIiwgInVpZCI6IDUsICJiZWdpbiI6IDE5MCwgImVuZCI6IDIwMiwgImNvdmVyZWRUZXh0IjogImNocm9uaWMgcGFpbiIsICJuZWdhdGVkIjogZmFsc2UsICJjdWkiOiAiQzAxNTAwNTUiLCAicHJlZmVycmVkTmFtZSI6ICJDaHJvbmljIHBhaW4iLCAic2VtYW50aWNUeXBlIjogInNvc3kiLCAic291cmNlIjogInVtbHMiLCAic291cmNlVmVyc2lvbiI6ICIyMDIwQUEiLCAiZGlzYW1iaWd1YXRpb25EYXRhIjogeyJ2YWxpZGl0eSI6ICJOT19ERUNJU0lPTiJ9LCAiaWNkOUNvZGUiOiAiMzM4LjI5IiwgImljZDEwQ29kZSI6ICJSNTIsUjUyLjIiLCAibmNpQ29kZSI6ICJDMjY5NDAiLCAic25vbWVkQ29uY2VwdElkIjogIjgyNDIzMDAxIiwgIm1lc2hJZCI6ICJNMDU0OTgzNyIsICJsb2luY0lkIjogIk1USFUwMTMzODIsTEEyMjA5My0xIiwgInZvY2FicyI6ICJMTkMsTVRILE5DSV9OSUNIRCxDU1AsTVNILEhQTyxPTUlNLE5DSV9OQ0ktR0xPU1MsQ0hWLE1FRExJTkVQTFVTLExDSF9OVyxOQ0ksSUNEOUNNLFNOT01FRENUX1VTIiwgImluc2lnaHRNb2RlbERhdGEiOiB7ImRpYWdub3NpcyI6IHsidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAxLjAsICJwYXRpZW50UmVwb3J0ZWRTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfSwgInN1c3BlY3RlZFNjb3JlIjogMC4wLCAic3ltcHRvbVNjb3JlIjogMC4wMjEsICJ0cmF1bWFTY29yZSI6IDAuMCwgImZhbWlseUhpc3RvcnlTY29yZSI6IDAuMH19fSwgeyJ0eXBlIjogIklDTWVkaWNhdGlvbiIsICJiZWdpbiI6IDEwNCwgImVuZCI6IDExMywgImNvdmVyZWRUZXh0IjogIm5hcmNvdGljcyIsICJuZWdhdGVkIjogZmFsc2UsICJjdWkiOiAiQzAwMjc0MTUiLCAicHJlZmVycmVkTmFtZSI6ICJOYXJjb3RpY3MiLCAic291cmNlIjogIkNsaW5pY2FsIEluc2lnaHRzIC0gRGVyaXZlZCBDb25jZXB0cyIsICJzb3VyY2VWZXJzaW9uIjogInYxLjAiLCAiZGlzYW1iaWd1YXRpb25EYXRhIjogeyJ2YWxpZGl0eSI6ICJWQUxJRCJ9LCAibmNpQ29kZSI6ICJDMTUwNiIsICJtZXNoSWQiOiAiTTAwMTQ0ODEiLCAibG9pbmNJZCI6ICJNVEhVMDAzNDcwLExQMTgxNDktMiIsICJpbnNpZ2h0TW9kZWxEYXRhIjogeyJtZWRpY2F0aW9uIjogeyJ1c2FnZSI6IHsidGFrZW5TY29yZSI6IDEuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMCwgImxhYk1lYXN1cmVtZW50U2NvcmUiOiAwLjB9LCAic3RhcnRlZEV2ZW50IjogeyJzY29yZSI6IDAuOTgyLCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAxLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fSwgImRvc2VDaGFuZ2VkRXZlbnQiOiB7InNjb3JlIjogMC4wMDEsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH19LCAic3RvcHBlZEV2ZW50IjogeyJzY29yZSI6IDAuMDAxLCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAwLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fSwgImFkdmVyc2VFdmVudCI6IHsic2NvcmUiOiAwLjk5OSwgImFsbGVyZ3lTY29yZSI6IDAuMCwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMC4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDEuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX19fSwgInJ1bGVJZCI6ICI3ODYxYzAyNC1hZDFjLTQ3ZTYtYjQwZS1jOTBjYjdiMTllMjYiLCAiZGVyaXZlZEZyb20iOiBbeyJ1aWQiOiAyfV19LCB7InR5cGUiOiAiSUNOb3JtYWxpdHkiLCAiYmVnaW4iOiAxMDQsICJlbmQiOiAxMTMsICJjb3ZlcmVkVGV4dCI6ICJuYXJjb3RpY3MiLCAibmVnYXRlZCI6IGZhbHNlLCAiY3VpIjogIkMwMDI3NDE1IiwgInByZWZlcnJlZE5hbWUiOiAiTmFyY290aWNzIiwgInNvdXJjZSI6ICJDbGluaWNhbCBJbnNpZ2h0cyAtIERlcml2ZWQgQ29uY2VwdHMiLCAic291cmNlVmVyc2lvbiI6ICJ2MS4wIiwgImRpc2FtYmlndWF0aW9uRGF0YSI6IHsidmFsaWRpdHkiOiAiTk9fREVDSVNJT04ifSwgIm5jaUNvZGUiOiAiQzE1MDYiLCAibWVzaElkIjogIk0wMDE0NDgxIiwgImxvaW5jSWQiOiAiTVRIVTAwMzQ3MCxMUDE4MTQ5LTIiLCAiaW5zaWdodE1vZGVsRGF0YSI6IHt9LCAicnVsZUlkIjogImQwMDRkZjYyLWE2NWQtNDEzNi1hYTMyLTE2MWE0M2ViOTUwNiIsICJkZXJpdmVkRnJvbSI6IFt7InVpZCI6IDJ9XX0sIHsidHlwZSI6ICJJQ01lZGljYXRpb24iLCAiYmVnaW4iOiAxMTgsICJlbmQiOiAxMjcsICJjb3ZlcmVkVGV4dCI6ICJOZXVyb250aW4iLCAibmVnYXRlZCI6IGZhbHNlLCAiY3VpIjogIkMwNjc4MTc2IiwgInByZWZlcnJlZE5hbWUiOiAiTmV1cm9udGluIiwgInNvdXJjZSI6ICJDbGluaWNhbCBJbnNpZ2h0cyAtIERlcml2ZWQgQ29uY2VwdHMiLCAic291cmNlVmVyc2lvbiI6ICJ2MS4wIiwgImRpc2FtYmlndWF0aW9uRGF0YSI6IHsidmFsaWRpdHkiOiAiVkFMSUQifSwgIm5jaUNvZGUiOiAiQzExMDgiLCAibWVzaElkIjogIk0wMTE5NDIwIiwgInJ4Tm9ybUlkIjogIjE5NjQ5OCIsICJpbnNpZ2h0TW9kZWxEYXRhIjogeyJtZWRpY2F0aW9uIjogeyJ1c2FnZSI6IHsidGFrZW5TY29yZSI6IDEuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMCwgImxhYk1lYXN1cmVtZW50U2NvcmUiOiAwLjB9LCAic3RhcnRlZEV2ZW50IjogeyJzY29yZSI6IDAuOTk4LCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAxLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fSwgImRvc2VDaGFuZ2VkRXZlbnQiOiB7InNjb3JlIjogMC4wMDIsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH19LCAic3RvcHBlZEV2ZW50IjogeyJzY29yZSI6IDAuMCwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMC4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX0sICJhZHZlcnNlRXZlbnQiOiB7InNjb3JlIjogMC44OTEsICJhbGxlcmd5U2NvcmUiOiAwLjAsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjY3OCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX19fSwgInJ1bGVJZCI6ICI3ODYxYzAyNC1hZDFjLTQ3ZTYtYjQwZS1jOTBjYjdiMTllMjYiLCAiZGVyaXZlZEZyb20iOiBbeyJ1aWQiOiAzfV19LCB7InR5cGUiOiAiSUNOb3JtYWxpdHkiLCAiYmVnaW4iOiAxMTgsICJlbmQiOiAxMjcsICJjb3ZlcmVkVGV4dCI6ICJOZXVyb250aW4iLCAibmVnYXRlZCI6IGZhbHNlLCAiY3VpIjogIkMwNjc4MTc2IiwgInByZWZlcnJlZE5hbWUiOiAiTmV1cm9udGluIiwgInNvdXJjZSI6ICJDbGluaWNhbCBJbnNpZ2h0cyAtIERlcml2ZWQgQ29uY2VwdHMiLCAic291cmNlVmVyc2lvbiI6ICJ2MS4wIiwgImRpc2FtYmlndWF0aW9uRGF0YSI6IHsidmFsaWRpdHkiOiAiTk9fREVDSVNJT04ifSwgIm5jaUNvZGUiOiAiQzExMDgiLCAibWVzaElkIjogIk0wMTE5NDIwIiwgInJ4Tm9ybUlkIjogIjE5NjQ5OCIsICJpbnNpZ2h0TW9kZWxEYXRhIjoge30sICJydWxlSWQiOiAiZDAwNGRmNjItYTY1ZC00MTM2LWFhMzItMTYxYTQzZWI5NTA2IiwgImRlcml2ZWRGcm9tIjogW3sidWlkIjogM31dfSwgeyJ0eXBlIjogIklDTm9ybWFsaXR5IiwgImJlZ2luIjogMTE4LCAiZW5kIjogMTI3LCAiY292ZXJlZFRleHQiOiAiTmV1cm9udGluIiwgIm5lZ2F0ZWQiOiBmYWxzZSwgImN1aSI6ICJDMDY3ODE3NiIsICJwcmVmZXJyZWROYW1lIjogIk5ldXJvbnRpbiIsICJzb3VyY2UiOiAiQ2xpbmljYWwgSW5zaWdodHMgLSBEZXJpdmVkIENvbmNlcHRzIiwgInNvdXJjZVZlcnNpb24iOiAidjEuMCIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIk5PX0RFQ0lTSU9OIn0sICJpbnNpZ2h0TW9kZWxEYXRhIjoge30sICJydWxlSWQiOiAiMzQzZTYxNTgtMmMzMC00NzI2LWJlNzEtMzNhNTcwYjI4NzAzIiwgImRlcml2ZWRGcm9tIjogW3sidWlkIjogNn1dfSwgeyJ0eXBlIjogIklDRGlhZ25vc2lzIiwgImJlZ2luIjogMTY1LCAiZW5kIjogMTg1LCAiY292ZXJlZFRleHQiOiAidHJpZ2VtaW5hbCBuZXVyYWxnaWEiLCAibmVnYXRlZCI6IGZhbHNlLCAiY3VpIjogIkMwMDQwOTk3IiwgInByZWZlcnJlZE5hbWUiOiAiVHJpZ2VtaW5hbCBOZXVyYWxnaWEiLCAic291cmNlIjogIkNsaW5pY2FsIEluc2lnaHRzIC0gRGVyaXZlZCBDb25jZXB0cyIsICJzb3VyY2VWZXJzaW9uIjogInYxLjAiLCAiZGlzYW1iaWd1YXRpb25EYXRhIjogeyJ2YWxpZGl0eSI6ICJWQUxJRCJ9LCAiaWNkMTBDb2RlIjogIkIwMi4yLEc1MC4wLEc1My4wIiwgInNub21lZENvbmNlcHRJZCI6ICIzMTY4MTAwNSIsICJtZXNoSWQiOiAiTTAwMjE5NjYiLCAiaW5zaWdodE1vZGVsRGF0YSI6IHsiZGlhZ25vc2lzIjogeyJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDEuMCwgInBhdGllbnRSZXBvcnRlZFNjb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9LCAic3VzcGVjdGVkU2NvcmUiOiAwLjAsICJzeW1wdG9tU2NvcmUiOiAwLjAsICJ0cmF1bWFTY29yZSI6IDAuMCwgImZhbWlseUhpc3RvcnlTY29yZSI6IDAuMDAzfX0sICJydWxlSWQiOiAiNjk4ZjJiMTktMjdiNi00ZGFiLTkxNTAtN2Q3ZWYzYjAzYTVjIiwgImRlcml2ZWRGcm9tIjogW3sidWlkIjogNH1dfSwgeyJ0eXBlIjogIklDRGlhZ25vc2lzIiwgImJlZ2luIjogMTkwLCAiZW5kIjogMjAyLCAiY292ZXJlZFRleHQiOiAiY2hyb25pYyBwYWluIiwgIm5lZ2F0ZWQiOiBmYWxzZSwgImN1aSI6ICJDMDE1MDA1NSIsICJwcmVmZXJyZWROYW1lIjogIkNocm9uaWMgcGFpbiIsICJzb3VyY2UiOiAiQ2xpbmljYWwgSW5zaWdodHMgLSBEZXJpdmVkIENvbmNlcHRzIiwgInNvdXJjZVZlcnNpb24iOiAidjEuMCIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIlZBTElEIn0sICJpY2Q5Q29kZSI6ICIzMzguMjkiLCAiaWNkMTBDb2RlIjogIlI1MixSNTIuMiIsICJuY2lDb2RlIjogIkMyNjk0MCIsICJzbm9tZWRDb25jZXB0SWQiOiAiODI0MjMwMDEiLCAibWVzaElkIjogIk0wNTQ5ODM3IiwgImxvaW5jSWQiOiAiTVRIVTAxMzM4MixMQTIyMDkzLTEiLCAiaW5zaWdodE1vZGVsRGF0YSI6IHsiZGlhZ25vc2lzIjogeyJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDEuMCwgInBhdGllbnRSZXBvcnRlZFNjb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9LCAic3VzcGVjdGVkU2NvcmUiOiAwLjAsICJzeW1wdG9tU2NvcmUiOiAwLjAyMSwgInRyYXVtYVNjb3JlIjogMC4wLCAiZmFtaWx5SGlzdG9yeVNjb3JlIjogMC4wfX0sICJydWxlSWQiOiAiM2NmMzhlMjktNzdmMC00N2IzLTk5NTAtNGEwMjkyZjY0YzkzIiwgImRlcml2ZWRGcm9tIjogW3sidWlkIjogNX1dfV0sICJNZWRpY2F0aW9uSW5kIjogW3sidHlwZSI6ICJhY2kuTWVkaWNhdGlvbkluZCIsICJ1aWQiOiA4LCAiYmVnaW4iOiAxMDQsICJlbmQiOiAxMTMsICJjb3ZlcmVkVGV4dCI6ICJuYXJjb3RpY3MiLCAibmVnYXRlZCI6IGZhbHNlLCAiY3VpIjogIkMwMDI3NDE1IiwgImRydWciOiBbeyJjb3ZlcmVkVGV4dCI6ICJuYXJjb3RpY3MiLCAiY3VpIjogIkMwMDI3NDE1IiwgImNvbXBsZXgiOiAiZmFsc2UiLCAiZW5kIjogMTEzLCAidHlwZSI6ICJhY2kuSW5kX0RydWciLCAibmFtZTEiOiBbeyJjb3ZlcmVkVGV4dCI6ICJuYXJjb3RpY3MiLCAiY3VpIjogIkMwMDI3NDE1IiwgImRydWdTdXJmYWNlRm9ybSI6ICJuYXJjb3RpY3MiLCAiZHJ1Z05vcm1hbGl6ZWROYW1lIjogIm5hcmNvdGljcyIsICJlbmQiOiAxMTMsICJ0eXBlIjogImFjaS5EcnVnTmFtZSIsICJiZWdpbiI6IDEwNH1dLCAiYmVnaW4iOiAxMDR9XSwgImluc2lnaHRNb2RlbERhdGEiOiB7Im1lZGljYXRpb24iOiB7InVzYWdlIjogeyJ0YWtlblNjb3JlIjogMS4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wLCAibGFiTWVhc3VyZW1lbnRTY29yZSI6IDAuMH0sICJzdGFydGVkRXZlbnQiOiB7InNjb3JlIjogMC45ODIsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDEuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH19LCAiZG9zZUNoYW5nZWRFdmVudCI6IHsic2NvcmUiOiAwLjAwMSwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMC4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX0sICJzdG9wcGVkRXZlbnQiOiB7InNjb3JlIjogMC4wMDEsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH19LCAiYWR2ZXJzZUV2ZW50IjogeyJzY29yZSI6IDAuOTk5LCAiYWxsZXJneVNjb3JlIjogMC4wLCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAwLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMS4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fX19LCAiZGlzYW1iaWd1YXRpb25EYXRhIjogeyJ2YWxpZGl0eSI6ICJWQUxJRCIsICJjb21tZW50IjogIm1hcmtlZCBWQUxJRCBieSBjbGluaWNhbCBpbnNpZ2h0IG1vZGVscy4ifX0sIHsidHlwZSI6ICJhY2kuTWVkaWNhdGlvbkluZCIsICJ1aWQiOiA5LCAiYmVnaW4iOiAxMTgsICJlbmQiOiAxMjcsICJjb3ZlcmVkVGV4dCI6ICJOZXVyb250aW4iLCAibmVnYXRlZCI6IGZhbHNlLCAiY3VpIjogIkMwNjc4MTc2IiwgImRydWciOiBbeyJjb3ZlcmVkVGV4dCI6ICJOZXVyb250aW4iLCAiY3VpIjogIkMwNjc4MTc2IiwgImNvbXBsZXgiOiAiZmFsc2UiLCAiZW5kIjogMTI3LCAidHlwZSI6ICJhY2kuSW5kX0RydWciLCAibmFtZTEiOiBbeyJyeE5vcm1JRCI6ICIxOTY0OTgiLCAiY292ZXJlZFRleHQiOiAiTmV1cm9udGluIiwgImN1aSI6ICJDMDY3ODE3NiIsICJkcnVnU3VyZmFjZUZvcm0iOiAiTmV1cm9udGluIiwgImRydWdOb3JtYWxpemVkTmFtZSI6ICJuZXVyb250aW4iLCAiZW5kIjogMTI3LCAidHlwZSI6ICJhY2kuRHJ1Z05hbWUiLCAiYmVnaW4iOiAxMTh9XSwgImJlZ2luIjogMTE4fV0sICJpbnNpZ2h0TW9kZWxEYXRhIjogeyJtZWRpY2F0aW9uIjogeyJ1c2FnZSI6IHsidGFrZW5TY29yZSI6IDEuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMCwgImxhYk1lYXN1cmVtZW50U2NvcmUiOiAwLjB9LCAic3RhcnRlZEV2ZW50IjogeyJzY29yZSI6IDAuOTk4LCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAxLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fSwgImRvc2VDaGFuZ2VkRXZlbnQiOiB7InNjb3JlIjogMC4wMDIsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH19LCAic3RvcHBlZEV2ZW50IjogeyJzY29yZSI6IDAuMCwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMC4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX0sICJhZHZlcnNlRXZlbnQiOiB7InNjb3JlIjogMC44OTEsICJhbGxlcmd5U2NvcmUiOiAwLjAsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjY3OCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX19fSwgImRpc2FtYmlndWF0aW9uRGF0YSI6IHsidmFsaWRpdHkiOiAiVkFMSUQiLCAiY29tbWVudCI6ICJtYXJrZWQgVkFMSUQgYnkgY2xpbmljYWwgaW5zaWdodCBtb2RlbHMuIn19XSwgIlN5bXB0b21EaXNlYXNlSW5kIjogW3sidHlwZSI6ICJhY2kuU3ltcHRvbURpc2Vhc2VJbmQiLCAidWlkIjogMTAsICJiZWdpbiI6IDE2NSwgImVuZCI6IDE4NSwgImNvdmVyZWRUZXh0IjogInRyaWdlbWluYWwgbmV1cmFsZ2lhIiwgIm5lZ2F0ZWQiOiBmYWxzZSwgImN1aSI6ICJDMDA0MDk5NyIsICJpY2QxMENvZGUiOiAiRzUwLjAiLCAibW9kYWxpdHkiOiAicG90ZW50aWFsIiwgInN5bXB0b21EaXNlYXNlU3VyZmFjZUZvcm0iOiAidHJpZ2VtaW5hbCBuZXVyYWxnaWEiLCAic25vbWVkQ29uY2VwdElkIjogIjMxNjgxMDA1IiwgImNjc0NvZGUiOiAiOTUiLCAic3ltcHRvbURpc2Vhc2VOb3JtYWxpemVkTmFtZSI6ICJ0cmlnZW1pbmFsIG5ldXJhbGdpYSIsICJpY2Q5Q29kZSI6ICIzNTAuMSIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIlZBTElEIn0sICJpbnNpZ2h0TW9kZWxEYXRhIjogeyJkaWFnbm9zaXMiOiB7InVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMS4wLCAicGF0aWVudFJlcG9ydGVkU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH0sICJzdXNwZWN0ZWRTY29yZSI6IDAuMCwgInN5bXB0b21TY29yZSI6IDAuMCwgInRyYXVtYVNjb3JlIjogMC4wLCAiZmFtaWx5SGlzdG9yeVNjb3JlIjogMC4wMDN9fX0sIHsidHlwZSI6ICJhY2kuU3ltcHRvbURpc2Vhc2VJbmQiLCAidWlkIjogMTEsICJiZWdpbiI6IDE5MCwgImVuZCI6IDIwMiwgImNvdmVyZWRUZXh0IjogImNocm9uaWMgcGFpbiIsICJuZWdhdGVkIjogZmFsc2UsICJjdWkiOiAiQzAxNTAwNTUiLCAiaWNkMTBDb2RlIjogIlI1Mi4yLFI1MiIsICJtb2RhbGl0eSI6ICJwb3RlbnRpYWwiLCAic3ltcHRvbURpc2Vhc2VTdXJmYWNlRm9ybSI6ICJjaHJvbmljIHBhaW4iLCAic25vbWVkQ29uY2VwdElkIjogIjgyNDIzMDAxIiwgImNjc0NvZGUiOiAiMjU5IiwgInN5bXB0b21EaXNlYXNlTm9ybWFsaXplZE5hbWUiOiAiY2hyb25pYyBwYWluIiwgImljZDlDb2RlIjogIjMzOC4yOSIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIlZBTElEIn0sICJpbnNpZ2h0TW9kZWxEYXRhIjogeyJkaWFnbm9zaXMiOiB7InVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMS4wLCAicGF0aWVudFJlcG9ydGVkU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH0sICJzdXNwZWN0ZWRTY29yZSI6IDAuMCwgInN5bXB0b21TY29yZSI6IDAuMDIxLCAidHJhdW1hU2NvcmUiOiAwLjAsICJmYW1pbHlIaXN0b3J5U2NvcmUiOiAwLjB9fX1dLCAic3BlbGxpbmdDb3JyZWN0aW9ucyI6IFt7ImJlZ2luIjogMTQ2LCAiZW5kIjogMTU2LCAiY292ZXJlZFRleHQiOiAicGVyc2NyaWJlZCIsICJzdWdnZXN0aW9ucyI6IFt7InRleHQiOiAicHJlc2NyaWJlZCIsICJjb25maWRlbmNlIjogMC45LCAiYXBwbGllZCI6IHRydWV9LCB7InRleHQiOiAicHJvc2NyaWJlZCIsICJjb25maWRlbmNlIjogMC44MDMsICJhcHBsaWVkIjogZmFsc2V9LCB7InRleHQiOiAiZGVzY3JpYmVkIiwgImNvbmZpZGVuY2UiOiAwLjgwMiwgImFwcGxpZWQiOiBmYWxzZX0sIHsidGV4dCI6ICJwcmVzY3JpYmUiLCAiY29uZmlkZW5jZSI6IDAuODAxLCAiYXBwbGllZCI6IGZhbHNlfSwgeyJ0ZXh0IjogInByZXNjcmliZXIiLCAiY29uZmlkZW5jZSI6IDAuOCwgImFwcGxpZWQiOiBmYWxzZX1dfV0sICJzcGVsbENvcnJlY3RlZFRleHQiOiBbeyJjb3JyZWN0ZWRUZXh0IjogIlRoZSBwYXRpZW50J3MgY291cnNlIGNvdWxkIGhhdmUgYmVlbiBjb21wbGljYXRlZCBieSBtZW50YWwgc3RhdHVzIGNoYW5nZXMgc2Vjb25kYXJ5IHRvIGEgY29tYmluYXRpb24gb2YgbmFyY290aWNzIGFuZCBOZXVyb250aW4sIHdoaWNoIHdhcyBhbG1vc3QgcHJlc2NyaWJlZCBmb3IgaGlzIHRyaWdlbWluYWwgbmV1cmFsZ2lhIGFuZCBjaHJvbmljIHBhaW4uIFxuXG4ifV19"
                }
              },
              {
                "extension": [
                  {
                    "extension": [
                      {
                        "url": "http://ibm.com/fhir/cdm/StructureDefinition/covered-text",
                        "valueString": "narcotics"
                      },
                      {
                        "url": "http://ibm.com/fhir/cdm/StructureDefinition/offset-begin",
                        "valueInteger": 104
                      },
                      {
                        "url": "http://ibm.com/fhir/cdm/StructureDefinition/offset-end",
                        "valueInteger": 113
                      },
                      {
                        "extension": [
                          {
                            "url": "http://ibm.com/fhir/cdm/StructureDefinition/method",
                            "valueCodeableConcept": {
                              "coding": [
                                {
                                  "code": "Adverse_Event_Score",
                                  "system": "http://ibm.com/fhir/cdm/CodeSystem/1.0/acd-confidence-method"
                                }
                              ]
                            }
                          },
                          {
                            "url": "http://ibm.com/fhir/cdm/StructureDefinition/score",
                            "valueDecimal": 0.999
                          },
                          {
                            "url": "http://ibm.com/fhir/cdm/StructureDefinition/description",
                            "valueString": "Adverse Event Score"
                          }
                        ],
                        "url": "http://ibm.com/fhir/cdm/StructureDefinition/insight-confidence"
                      }
                    ],
                    "url": "http://ibm.com/fhir/cdm/StructureDefinition/span"
                  }
                ],
                "url": "http://ibm.com/fhir/cdm/StructureDefinition/insight-result"
              }
            ],
            "url": "http://ibm.com/fhir/cdm/StructureDefinition/insight-detail"
          }
        ],
        "url": "http://ibm.com/fhir/cdm/StructureDefinition/insight"
      }
    ]
  },
  "extension": [
    {
      "extension": [
        {
          "url": "http://ibm.com/fhir/cdm/StructureDefinition/insight-id",
          "valueIdentifier": {
            "system": "urn:alvearie.io/health_patterns/services/nlp_insights/acd",
            "value": "a129d489aea84c37b7377201e70cd416fe2b26ce3dc1d29f250fdfa1"
          }
        },
        {
          "url": "http://ibm.com/fhir/cdm/StructureDefinition/category",
          "valueCodeableConcept": {
            "coding": [
              {
                "code": "natural-language-processing",
                "display": "NLP",
                "system": "http://ibm.com/fhir/cdm/CodeSystem/insight-category-code-system"
              }
            ],
            "text": "NLP"
          }
        }
      ],
      "url": "http://ibm.com/fhir/cdm/StructureDefinition/insight-summary"
    }
  ],
  "actuality": "actual",
  "event": {
    "coding": [
      {
        "code": "C0027415",
        "system": "http://terminology.hl7.org/CodeSystem/umls"
      }
    ],
    "text": "narcotics"
  },
  "resourceType": "AdverseEvent"
}
```

</details>

<details><summary>Adverse Event for "neurontin"</summary>

```json
{
  "meta": {
    "extension": [
      {
        "extension": [
          {
            "url": "http://ibm.com/fhir/cdm/StructureDefinition/insight-id",
            "valueIdentifier": {
              "system": "urn:alvearie.io/health_patterns/services/nlp_insights/acd",
              "value": "1b32afb1d37b7a442c676f8f191800d89882c8d8163b6379d1c387f5"
            }
          },
          {
            "url": "http://ibm.com/fhir/cdm/StructureDefinition/path",
            "valueString": "AdverseEvent"
          },
          {
            "extension": [
              {
                "url": "http://ibm.com/fhir/cdm/StructureDefinition/reference",
                "valueReference": {
                  "reference": "urn:uuid:7fbcf71d-44fe-466e-b8d1-bc51cedf000b"
                }
              },
              {
                "url": "http://ibm.com/fhir/cdm/StructureDefinition/reference-path",
                "valueString": "DiagnosticReport.presentedForm[0].data"
              },
              {
                "url": "http://ibm.com/fhir/cdm/StructureDefinition/evaluated-output",
                "valueAttachment": {
                  "contentType": "application/json",
                  "data": "eyJhdHRyaWJ1dGVWYWx1ZXMiOiBbeyJiZWdpbiI6IDEwNCwgImVuZCI6IDExMywgImNvdmVyZWRUZXh0IjogIm5hcmNvdGljcyIsICJuZWdhdGVkIjogZmFsc2UsICJwcmVmZXJyZWROYW1lIjogIm5hcmNvdGljcyIsICJ2YWx1ZXMiOiBbeyJ2YWx1ZSI6ICJuYXJjb3RpY3MifV0sICJzb3VyY2UiOiAiQ2xpbmljYWwgSW5zaWdodHMgLSBBdHRyaWJ1dGVzIiwgInNvdXJjZVZlcnNpb24iOiAidjEuMCIsICJjb25jZXB0IjogeyJ1aWQiOiA4fSwgIm5hbWUiOiAiTWVkaWNhdGlvbkFkdmVyc2VFdmVudCIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIlZBTElEIn0sICJpbnNpZ2h0TW9kZWxEYXRhIjogeyJtZWRpY2F0aW9uIjogeyJ1c2FnZSI6IHsidGFrZW5TY29yZSI6IDEuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMCwgImxhYk1lYXN1cmVtZW50U2NvcmUiOiAwLjB9LCAic3RhcnRlZEV2ZW50IjogeyJzY29yZSI6IDAuOTgyLCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAxLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fSwgImRvc2VDaGFuZ2VkRXZlbnQiOiB7InNjb3JlIjogMC4wMDEsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH19LCAic3RvcHBlZEV2ZW50IjogeyJzY29yZSI6IDAuMDAxLCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAwLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fSwgImFkdmVyc2VFdmVudCI6IHsic2NvcmUiOiAwLjk5OSwgImFsbGVyZ3lTY29yZSI6IDAuMCwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMC4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDEuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX19fX0sIHsiYmVnaW4iOiAxMTgsICJlbmQiOiAxMjcsICJjb3ZlcmVkVGV4dCI6ICJOZXVyb250aW4iLCAibmVnYXRlZCI6IGZhbHNlLCAicHJlZmVycmVkTmFtZSI6ICJuZXVyb250aW4iLCAidmFsdWVzIjogW3sidmFsdWUiOiAibmV1cm9udGluIn1dLCAic291cmNlIjogIkNsaW5pY2FsIEluc2lnaHRzIC0gQXR0cmlidXRlcyIsICJzb3VyY2VWZXJzaW9uIjogInYxLjAiLCAiY29uY2VwdCI6IHsidWlkIjogOX0sICJuYW1lIjogIk1lZGljYXRpb25BZHZlcnNlRXZlbnQiLCAicnhOb3JtSWQiOiAiMTk2NDk4IiwgImRpc2FtYmlndWF0aW9uRGF0YSI6IHsidmFsaWRpdHkiOiAiVkFMSUQifSwgImluc2lnaHRNb2RlbERhdGEiOiB7Im1lZGljYXRpb24iOiB7InVzYWdlIjogeyJ0YWtlblNjb3JlIjogMS4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wLCAibGFiTWVhc3VyZW1lbnRTY29yZSI6IDAuMH0sICJzdGFydGVkRXZlbnQiOiB7InNjb3JlIjogMC45OTgsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDEuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH19LCAiZG9zZUNoYW5nZWRFdmVudCI6IHsic2NvcmUiOiAwLjAwMiwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMC4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX0sICJzdG9wcGVkRXZlbnQiOiB7InNjb3JlIjogMC4wLCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAwLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fSwgImFkdmVyc2VFdmVudCI6IHsic2NvcmUiOiAwLjg5MSwgImFsbGVyZ3lTY29yZSI6IDAuMCwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMC4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuNjc4LCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fX19fSwgeyJiZWdpbiI6IDE2NSwgImVuZCI6IDE4NSwgImNvdmVyZWRUZXh0IjogInRyaWdlbWluYWwgbmV1cmFsZ2lhIiwgIm5lZ2F0ZWQiOiBmYWxzZSwgInByZWZlcnJlZE5hbWUiOiAidHJpZ2VtaW5hbCBuZXVyYWxnaWEiLCAidmFsdWVzIjogW3sidmFsdWUiOiAidHJpZ2VtaW5hbCBuZXVyYWxnaWEifV0sICJzb3VyY2UiOiAiQ2xpbmljYWwgSW5zaWdodHMgLSBBdHRyaWJ1dGVzIiwgInNvdXJjZVZlcnNpb24iOiAidjEuMCIsICJjb25jZXB0IjogeyJ1aWQiOiAxMH0sICJuYW1lIjogIkRpYWdub3NpcyIsICJpY2Q5Q29kZSI6ICIzNTAuMSIsICJpY2QxMENvZGUiOiAiRzUwLjAiLCAic25vbWVkQ29uY2VwdElkIjogIjMxNjgxMDA1IiwgImRpc2FtYmlndWF0aW9uRGF0YSI6IHsidmFsaWRpdHkiOiAiVkFMSUQifSwgImluc2lnaHRNb2RlbERhdGEiOiB7ImRpYWdub3NpcyI6IHsidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAxLjAsICJwYXRpZW50UmVwb3J0ZWRTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfSwgInN1c3BlY3RlZFNjb3JlIjogMC4wLCAic3ltcHRvbVNjb3JlIjogMC4wLCAidHJhdW1hU2NvcmUiOiAwLjAsICJmYW1pbHlIaXN0b3J5U2NvcmUiOiAwLjAwM319LCAiY2NzQ29kZSI6ICI5NSJ9LCB7ImJlZ2luIjogMTkwLCAiZW5kIjogMjAyLCAiY292ZXJlZFRleHQiOiAiY2hyb25pYyBwYWluIiwgIm5lZ2F0ZWQiOiBmYWxzZSwgInByZWZlcnJlZE5hbWUiOiAiY2hyb25pYyBwYWluIiwgInZhbHVlcyI6IFt7InZhbHVlIjogImNocm9uaWMgcGFpbiJ9XSwgInNvdXJjZSI6ICJDbGluaWNhbCBJbnNpZ2h0cyAtIEF0dHJpYnV0ZXMiLCAic291cmNlVmVyc2lvbiI6ICJ2MS4wIiwgImNvbmNlcHQiOiB7InVpZCI6IDExfSwgIm5hbWUiOiAiRGlhZ25vc2lzIiwgImljZDlDb2RlIjogIjMzOC4yOSIsICJpY2QxMENvZGUiOiAiUjUyLjIsUjUyIiwgInNub21lZENvbmNlcHRJZCI6ICI4MjQyMzAwMSIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIlZBTElEIn0sICJpbnNpZ2h0TW9kZWxEYXRhIjogeyJkaWFnbm9zaXMiOiB7InVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMS4wLCAicGF0aWVudFJlcG9ydGVkU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH0sICJzdXNwZWN0ZWRTY29yZSI6IDAuMCwgInN5bXB0b21TY29yZSI6IDAuMDIxLCAidHJhdW1hU2NvcmUiOiAwLjAsICJmYW1pbHlIaXN0b3J5U2NvcmUiOiAwLjB9fSwgImNjc0NvZGUiOiAiMjU5In1dLCAiY29uY2VwdHMiOiBbeyJ0eXBlIjogInVtbHMuTWVudGFsT3JCZWhhdmlvcmFsRHlzZnVuY3Rpb24iLCAiYmVnaW4iOiA1MiwgImVuZCI6IDczLCAiY292ZXJlZFRleHQiOiAibWVudGFsIHN0YXR1cyBjaGFuZ2VzIiwgIm5lZ2F0ZWQiOiBmYWxzZSwgImN1aSI6ICJDMDg1NjA1NCIsICJwcmVmZXJyZWROYW1lIjogIk1lbnRhbCBTdGF0dXMgQ2hhbmdlIiwgInNlbWFudGljVHlwZSI6ICJtb2JkIiwgInNvdXJjZSI6ICJ1bWxzIiwgInNvdXJjZVZlcnNpb24iOiAiMjAyMEFBIiwgImRpc2FtYmlndWF0aW9uRGF0YSI6IHsidmFsaWRpdHkiOiAiTk9fREVDSVNJT04ifSwgIm5jaUNvZGUiOiAiQzE1NzQzNSIsICJsb2luY0lkIjogIkxBNzQ1NS00IiwgInZvY2FicyI6ICJDSFYsTE5DLE5DSSxOQ0lfQ1BUQUMsTVRISUNEOSJ9LCB7InR5cGUiOiAidW1scy5GaW5kaW5nIiwgImJlZ2luIjogODksICJlbmQiOiAxMDAsICJjb3ZlcmVkVGV4dCI6ICJjb21iaW5hdGlvbiIsICJuZWdhdGVkIjogZmFsc2UsICJjdWkiOiAiQzM4MTE5MTAiLCAicHJlZmVycmVkTmFtZSI6ICJjb21iaW5hdGlvbiAtIGFuc3dlciB0byBxdWVzdGlvbiIsICJzZW1hbnRpY1R5cGUiOiAiZm5kZyIsICJzb3VyY2UiOiAidW1scyIsICJzb3VyY2VWZXJzaW9uIjogIjIwMjBBQSIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIk5PX0RFQ0lTSU9OIn0sICJsb2luY0lkIjogIkxBMTI3MDEtMSIsICJ2b2NhYnMiOiAiTVRILExOQyJ9LCB7InR5cGUiOiAidW1scy5IYXphcmRvdXNPclBvaXNvbm91c1N1YnN0YW5jZSIsICJiZWdpbiI6IDEwNCwgImVuZCI6IDExMywgImNvdmVyZWRUZXh0IjogIm5hcmNvdGljcyIsICJuZWdhdGVkIjogZmFsc2UsICJjdWkiOiAiQzAwMjc0MTUiLCAicHJlZmVycmVkTmFtZSI6ICJOYXJjb3RpY3MiLCAic2VtYW50aWNUeXBlIjogImhvcHMiLCAic291cmNlIjogInVtbHMiLCAic291cmNlVmVyc2lvbiI6ICIyMDIwQUEiLCAiZGlzYW1iaWd1YXRpb25EYXRhIjogeyJ2YWxpZGl0eSI6ICJOT19ERUNJU0lPTiJ9LCAibmNpQ29kZSI6ICJDMTUwNiIsICJtZXNoSWQiOiAiTTAwMTQ0ODEiLCAibG9pbmNJZCI6ICJNVEhVMDAzNDcwLExQMTgxNDktMiIsICJ2b2NhYnMiOiAiTENILExOQyxNVEgsQ0hWLENTUCxNU0gsTUVETElORVBMVVMsTENIX05XLE5DSSxOQ0lfTkNJLUdMT1NTIn0sIHsidHlwZSI6ICJ1bWxzLlBoYXJtYWNvbG9naWNTdWJzdGFuY2UiLCAidWlkIjogMiwgImJlZ2luIjogMTA0LCAiZW5kIjogMTEzLCAiY292ZXJlZFRleHQiOiAibmFyY290aWNzIiwgIm5lZ2F0ZWQiOiBmYWxzZSwgImN1aSI6ICJDMDAyNzQxNSIsICJwcmVmZXJyZWROYW1lIjogIk5hcmNvdGljcyIsICJzZW1hbnRpY1R5cGUiOiAicGhzdSIsICJzb3VyY2UiOiAidW1scyIsICJzb3VyY2VWZXJzaW9uIjogIjIwMjBBQSIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIk5PX0RFQ0lTSU9OIn0sICJuY2lDb2RlIjogIkMxNTA2IiwgIm1lc2hJZCI6ICJNMDAxNDQ4MSIsICJsb2luY0lkIjogIk1USFUwMDM0NzAsTFAxODE0OS0yIiwgInZvY2FicyI6ICJMQ0gsTE5DLE1USCxDSFYsQ1NQLE1TSCxNRURMSU5FUExVUyxMQ0hfTlcsTkNJLE5DSV9OQ0ktR0xPU1MiLCAiaW5zaWdodE1vZGVsRGF0YSI6IHsibWVkaWNhdGlvbiI6IHsidXNhZ2UiOiB7InRha2VuU2NvcmUiOiAxLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjAsICJsYWJNZWFzdXJlbWVudFNjb3JlIjogMC4wfSwgInN0YXJ0ZWRFdmVudCI6IHsic2NvcmUiOiAwLjk4MiwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMS4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX0sICJkb3NlQ2hhbmdlZEV2ZW50IjogeyJzY29yZSI6IDAuMDAxLCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAwLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fSwgInN0b3BwZWRFdmVudCI6IHsic2NvcmUiOiAwLjAwMSwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMC4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX0sICJhZHZlcnNlRXZlbnQiOiB7InNjb3JlIjogMC45OTksICJhbGxlcmd5U2NvcmUiOiAwLjAsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAxLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH19fX19LCB7InR5cGUiOiAidW1scy5PcmdhbmljQ2hlbWljYWwiLCAidWlkIjogNiwgImJlZ2luIjogMTE4LCAiZW5kIjogMTI3LCAiY292ZXJlZFRleHQiOiAiTmV1cm9udGluIiwgIm5lZ2F0ZWQiOiBmYWxzZSwgImN1aSI6ICJDMDY3ODE3NiIsICJwcmVmZXJyZWROYW1lIjogIk5ldXJvbnRpbiIsICJzZW1hbnRpY1R5cGUiOiAib3JjaCIsICJzb3VyY2UiOiAidW1scyIsICJzb3VyY2VWZXJzaW9uIjogIjIwMjBBQSIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIk5PX0RFQ0lTSU9OIn0sICJuY2lDb2RlIjogIkMxMTA4IiwgIm1lc2hJZCI6ICJNMDExOTQyMCIsICJyeE5vcm1JZCI6ICIxOTY0OTgiLCAidm9jYWJzIjogIkNIVixNU0gsTkNJLFJYTk9STSxQRFEifSwgeyJ0eXBlIjogInVtbHMuUGhhcm1hY29sb2dpY1N1YnN0YW5jZSIsICJ1aWQiOiAzLCAiYmVnaW4iOiAxMTgsICJlbmQiOiAxMjcsICJjb3ZlcmVkVGV4dCI6ICJOZXVyb250aW4iLCAibmVnYXRlZCI6IGZhbHNlLCAiY3VpIjogIkMwNjc4MTc2IiwgInByZWZlcnJlZE5hbWUiOiAiTmV1cm9udGluIiwgInNlbWFudGljVHlwZSI6ICJwaHN1IiwgInNvdXJjZSI6ICJ1bWxzIiwgInNvdXJjZVZlcnNpb24iOiAiMjAyMEFBIiwgImRpc2FtYmlndWF0aW9uRGF0YSI6IHsidmFsaWRpdHkiOiAiTk9fREVDSVNJT04ifSwgIm5jaUNvZGUiOiAiQzExMDgiLCAibWVzaElkIjogIk0wMTE5NDIwIiwgInJ4Tm9ybUlkIjogIjE5NjQ5OCIsICJ2b2NhYnMiOiAiQ0hWLE1TSCxOQ0ksUlhOT1JNLFBEUSIsICJpbnNpZ2h0TW9kZWxEYXRhIjogeyJtZWRpY2F0aW9uIjogeyJ1c2FnZSI6IHsidGFrZW5TY29yZSI6IDEuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMCwgImxhYk1lYXN1cmVtZW50U2NvcmUiOiAwLjB9LCAic3RhcnRlZEV2ZW50IjogeyJzY29yZSI6IDAuOTk4LCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAxLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fSwgImRvc2VDaGFuZ2VkRXZlbnQiOiB7InNjb3JlIjogMC4wMDIsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH19LCAic3RvcHBlZEV2ZW50IjogeyJzY29yZSI6IDAuMCwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMC4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX0sICJhZHZlcnNlRXZlbnQiOiB7InNjb3JlIjogMC44OTEsICJhbGxlcmd5U2NvcmUiOiAwLjAsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjY3OCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX19fX0sIHsidHlwZSI6ICJ1bWxzLkhlYWx0aENhcmVBY3Rpdml0eSIsICJiZWdpbiI6IDE0NiwgImVuZCI6IDE1NiwgImNvdmVyZWRUZXh0IjogInBlcnNjcmliZWQiLCAibmVnYXRlZCI6IGZhbHNlLCAiY3VpIjogIkMwMjc4MzI5IiwgInByZWZlcnJlZE5hbWUiOiAiUHJlc2NyaWJlZCIsICJzZW1hbnRpY1R5cGUiOiAiaGxjYSIsICJzb3VyY2UiOiAidW1scyIsICJzb3VyY2VWZXJzaW9uIjogIjIwMjBBQSIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIk5PX0RFQ0lTSU9OIn0sICJ2b2NhYnMiOiAiTVRILENIVixMQ0gifSwgeyJ0eXBlIjogInVtbHMuRGlzZWFzZU9yU3luZHJvbWUiLCAidWlkIjogNCwgImJlZ2luIjogMTY1LCAiZW5kIjogMTg1LCAiY292ZXJlZFRleHQiOiAidHJpZ2VtaW5hbCBuZXVyYWxnaWEiLCAibmVnYXRlZCI6IGZhbHNlLCAiY3VpIjogIkMwMDQwOTk3IiwgInByZWZlcnJlZE5hbWUiOiAiVHJpZ2VtaW5hbCBOZXVyYWxnaWEiLCAic2VtYW50aWNUeXBlIjogImRzeW4iLCAic291cmNlIjogInVtbHMiLCAic291cmNlVmVyc2lvbiI6ICIyMDIwQUEiLCAiZGlzYW1iaWd1YXRpb25EYXRhIjogeyJ2YWxpZGl0eSI6ICJOT19ERUNJU0lPTiJ9LCAiaWNkMTBDb2RlIjogIkIwMi4yLEc1MC4wLEc1My4wIiwgInNub21lZENvbmNlcHRJZCI6ICIzMTY4MTAwNSIsICJtZXNoSWQiOiAiTTAwMjE5NjYiLCAidm9jYWJzIjogIk1USCxDU1AsTVNILENTVCxIUE8sT01JTSxDT1NUQVIsSUNQQyxDSFYsTUVETElORVBMVVMsTENIX05XLFFNUixJQ0Q5Q00sU05PTUVEQ1RfVVMsRFhQLE1USElDRDkiLCAiaW5zaWdodE1vZGVsRGF0YSI6IHsiZGlhZ25vc2lzIjogeyJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDEuMCwgInBhdGllbnRSZXBvcnRlZFNjb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9LCAic3VzcGVjdGVkU2NvcmUiOiAwLjAsICJzeW1wdG9tU2NvcmUiOiAwLjAsICJ0cmF1bWFTY29yZSI6IDAuMCwgImZhbWlseUhpc3RvcnlTY29yZSI6IDAuMDAzfX19LCB7InR5cGUiOiAidW1scy5TaWduT3JTeW1wdG9tIiwgInVpZCI6IDUsICJiZWdpbiI6IDE5MCwgImVuZCI6IDIwMiwgImNvdmVyZWRUZXh0IjogImNocm9uaWMgcGFpbiIsICJuZWdhdGVkIjogZmFsc2UsICJjdWkiOiAiQzAxNTAwNTUiLCAicHJlZmVycmVkTmFtZSI6ICJDaHJvbmljIHBhaW4iLCAic2VtYW50aWNUeXBlIjogInNvc3kiLCAic291cmNlIjogInVtbHMiLCAic291cmNlVmVyc2lvbiI6ICIyMDIwQUEiLCAiZGlzYW1iaWd1YXRpb25EYXRhIjogeyJ2YWxpZGl0eSI6ICJOT19ERUNJU0lPTiJ9LCAiaWNkOUNvZGUiOiAiMzM4LjI5IiwgImljZDEwQ29kZSI6ICJSNTIsUjUyLjIiLCAibmNpQ29kZSI6ICJDMjY5NDAiLCAic25vbWVkQ29uY2VwdElkIjogIjgyNDIzMDAxIiwgIm1lc2hJZCI6ICJNMDU0OTgzNyIsICJsb2luY0lkIjogIk1USFUwMTMzODIsTEEyMjA5My0xIiwgInZvY2FicyI6ICJMTkMsTVRILE5DSV9OSUNIRCxDU1AsTVNILEhQTyxPTUlNLE5DSV9OQ0ktR0xPU1MsQ0hWLE1FRExJTkVQTFVTLExDSF9OVyxOQ0ksSUNEOUNNLFNOT01FRENUX1VTIiwgImluc2lnaHRNb2RlbERhdGEiOiB7ImRpYWdub3NpcyI6IHsidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAxLjAsICJwYXRpZW50UmVwb3J0ZWRTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfSwgInN1c3BlY3RlZFNjb3JlIjogMC4wLCAic3ltcHRvbVNjb3JlIjogMC4wMjEsICJ0cmF1bWFTY29yZSI6IDAuMCwgImZhbWlseUhpc3RvcnlTY29yZSI6IDAuMH19fSwgeyJ0eXBlIjogIklDTWVkaWNhdGlvbiIsICJiZWdpbiI6IDEwNCwgImVuZCI6IDExMywgImNvdmVyZWRUZXh0IjogIm5hcmNvdGljcyIsICJuZWdhdGVkIjogZmFsc2UsICJjdWkiOiAiQzAwMjc0MTUiLCAicHJlZmVycmVkTmFtZSI6ICJOYXJjb3RpY3MiLCAic291cmNlIjogIkNsaW5pY2FsIEluc2lnaHRzIC0gRGVyaXZlZCBDb25jZXB0cyIsICJzb3VyY2VWZXJzaW9uIjogInYxLjAiLCAiZGlzYW1iaWd1YXRpb25EYXRhIjogeyJ2YWxpZGl0eSI6ICJWQUxJRCJ9LCAibmNpQ29kZSI6ICJDMTUwNiIsICJtZXNoSWQiOiAiTTAwMTQ0ODEiLCAibG9pbmNJZCI6ICJNVEhVMDAzNDcwLExQMTgxNDktMiIsICJpbnNpZ2h0TW9kZWxEYXRhIjogeyJtZWRpY2F0aW9uIjogeyJ1c2FnZSI6IHsidGFrZW5TY29yZSI6IDEuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMCwgImxhYk1lYXN1cmVtZW50U2NvcmUiOiAwLjB9LCAic3RhcnRlZEV2ZW50IjogeyJzY29yZSI6IDAuOTgyLCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAxLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fSwgImRvc2VDaGFuZ2VkRXZlbnQiOiB7InNjb3JlIjogMC4wMDEsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH19LCAic3RvcHBlZEV2ZW50IjogeyJzY29yZSI6IDAuMDAxLCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAwLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fSwgImFkdmVyc2VFdmVudCI6IHsic2NvcmUiOiAwLjk5OSwgImFsbGVyZ3lTY29yZSI6IDAuMCwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMC4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDEuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX19fSwgInJ1bGVJZCI6ICI3ODYxYzAyNC1hZDFjLTQ3ZTYtYjQwZS1jOTBjYjdiMTllMjYiLCAiZGVyaXZlZEZyb20iOiBbeyJ1aWQiOiAyfV19LCB7InR5cGUiOiAiSUNOb3JtYWxpdHkiLCAiYmVnaW4iOiAxMDQsICJlbmQiOiAxMTMsICJjb3ZlcmVkVGV4dCI6ICJuYXJjb3RpY3MiLCAibmVnYXRlZCI6IGZhbHNlLCAiY3VpIjogIkMwMDI3NDE1IiwgInByZWZlcnJlZE5hbWUiOiAiTmFyY290aWNzIiwgInNvdXJjZSI6ICJDbGluaWNhbCBJbnNpZ2h0cyAtIERlcml2ZWQgQ29uY2VwdHMiLCAic291cmNlVmVyc2lvbiI6ICJ2MS4wIiwgImRpc2FtYmlndWF0aW9uRGF0YSI6IHsidmFsaWRpdHkiOiAiTk9fREVDSVNJT04ifSwgIm5jaUNvZGUiOiAiQzE1MDYiLCAibWVzaElkIjogIk0wMDE0NDgxIiwgImxvaW5jSWQiOiAiTVRIVTAwMzQ3MCxMUDE4MTQ5LTIiLCAiaW5zaWdodE1vZGVsRGF0YSI6IHt9LCAicnVsZUlkIjogImQwMDRkZjYyLWE2NWQtNDEzNi1hYTMyLTE2MWE0M2ViOTUwNiIsICJkZXJpdmVkRnJvbSI6IFt7InVpZCI6IDJ9XX0sIHsidHlwZSI6ICJJQ01lZGljYXRpb24iLCAiYmVnaW4iOiAxMTgsICJlbmQiOiAxMjcsICJjb3ZlcmVkVGV4dCI6ICJOZXVyb250aW4iLCAibmVnYXRlZCI6IGZhbHNlLCAiY3VpIjogIkMwNjc4MTc2IiwgInByZWZlcnJlZE5hbWUiOiAiTmV1cm9udGluIiwgInNvdXJjZSI6ICJDbGluaWNhbCBJbnNpZ2h0cyAtIERlcml2ZWQgQ29uY2VwdHMiLCAic291cmNlVmVyc2lvbiI6ICJ2MS4wIiwgImRpc2FtYmlndWF0aW9uRGF0YSI6IHsidmFsaWRpdHkiOiAiVkFMSUQifSwgIm5jaUNvZGUiOiAiQzExMDgiLCAibWVzaElkIjogIk0wMTE5NDIwIiwgInJ4Tm9ybUlkIjogIjE5NjQ5OCIsICJpbnNpZ2h0TW9kZWxEYXRhIjogeyJtZWRpY2F0aW9uIjogeyJ1c2FnZSI6IHsidGFrZW5TY29yZSI6IDEuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMCwgImxhYk1lYXN1cmVtZW50U2NvcmUiOiAwLjB9LCAic3RhcnRlZEV2ZW50IjogeyJzY29yZSI6IDAuOTk4LCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAxLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fSwgImRvc2VDaGFuZ2VkRXZlbnQiOiB7InNjb3JlIjogMC4wMDIsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH19LCAic3RvcHBlZEV2ZW50IjogeyJzY29yZSI6IDAuMCwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMC4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX0sICJhZHZlcnNlRXZlbnQiOiB7InNjb3JlIjogMC44OTEsICJhbGxlcmd5U2NvcmUiOiAwLjAsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjY3OCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX19fSwgInJ1bGVJZCI6ICI3ODYxYzAyNC1hZDFjLTQ3ZTYtYjQwZS1jOTBjYjdiMTllMjYiLCAiZGVyaXZlZEZyb20iOiBbeyJ1aWQiOiAzfV19LCB7InR5cGUiOiAiSUNOb3JtYWxpdHkiLCAiYmVnaW4iOiAxMTgsICJlbmQiOiAxMjcsICJjb3ZlcmVkVGV4dCI6ICJOZXVyb250aW4iLCAibmVnYXRlZCI6IGZhbHNlLCAiY3VpIjogIkMwNjc4MTc2IiwgInByZWZlcnJlZE5hbWUiOiAiTmV1cm9udGluIiwgInNvdXJjZSI6ICJDbGluaWNhbCBJbnNpZ2h0cyAtIERlcml2ZWQgQ29uY2VwdHMiLCAic291cmNlVmVyc2lvbiI6ICJ2MS4wIiwgImRpc2FtYmlndWF0aW9uRGF0YSI6IHsidmFsaWRpdHkiOiAiTk9fREVDSVNJT04ifSwgIm5jaUNvZGUiOiAiQzExMDgiLCAibWVzaElkIjogIk0wMTE5NDIwIiwgInJ4Tm9ybUlkIjogIjE5NjQ5OCIsICJpbnNpZ2h0TW9kZWxEYXRhIjoge30sICJydWxlSWQiOiAiZDAwNGRmNjItYTY1ZC00MTM2LWFhMzItMTYxYTQzZWI5NTA2IiwgImRlcml2ZWRGcm9tIjogW3sidWlkIjogM31dfSwgeyJ0eXBlIjogIklDTm9ybWFsaXR5IiwgImJlZ2luIjogMTE4LCAiZW5kIjogMTI3LCAiY292ZXJlZFRleHQiOiAiTmV1cm9udGluIiwgIm5lZ2F0ZWQiOiBmYWxzZSwgImN1aSI6ICJDMDY3ODE3NiIsICJwcmVmZXJyZWROYW1lIjogIk5ldXJvbnRpbiIsICJzb3VyY2UiOiAiQ2xpbmljYWwgSW5zaWdodHMgLSBEZXJpdmVkIENvbmNlcHRzIiwgInNvdXJjZVZlcnNpb24iOiAidjEuMCIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIk5PX0RFQ0lTSU9OIn0sICJpbnNpZ2h0TW9kZWxEYXRhIjoge30sICJydWxlSWQiOiAiMzQzZTYxNTgtMmMzMC00NzI2LWJlNzEtMzNhNTcwYjI4NzAzIiwgImRlcml2ZWRGcm9tIjogW3sidWlkIjogNn1dfSwgeyJ0eXBlIjogIklDRGlhZ25vc2lzIiwgImJlZ2luIjogMTY1LCAiZW5kIjogMTg1LCAiY292ZXJlZFRleHQiOiAidHJpZ2VtaW5hbCBuZXVyYWxnaWEiLCAibmVnYXRlZCI6IGZhbHNlLCAiY3VpIjogIkMwMDQwOTk3IiwgInByZWZlcnJlZE5hbWUiOiAiVHJpZ2VtaW5hbCBOZXVyYWxnaWEiLCAic291cmNlIjogIkNsaW5pY2FsIEluc2lnaHRzIC0gRGVyaXZlZCBDb25jZXB0cyIsICJzb3VyY2VWZXJzaW9uIjogInYxLjAiLCAiZGlzYW1iaWd1YXRpb25EYXRhIjogeyJ2YWxpZGl0eSI6ICJWQUxJRCJ9LCAiaWNkMTBDb2RlIjogIkIwMi4yLEc1MC4wLEc1My4wIiwgInNub21lZENvbmNlcHRJZCI6ICIzMTY4MTAwNSIsICJtZXNoSWQiOiAiTTAwMjE5NjYiLCAiaW5zaWdodE1vZGVsRGF0YSI6IHsiZGlhZ25vc2lzIjogeyJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDEuMCwgInBhdGllbnRSZXBvcnRlZFNjb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9LCAic3VzcGVjdGVkU2NvcmUiOiAwLjAsICJzeW1wdG9tU2NvcmUiOiAwLjAsICJ0cmF1bWFTY29yZSI6IDAuMCwgImZhbWlseUhpc3RvcnlTY29yZSI6IDAuMDAzfX0sICJydWxlSWQiOiAiNjk4ZjJiMTktMjdiNi00ZGFiLTkxNTAtN2Q3ZWYzYjAzYTVjIiwgImRlcml2ZWRGcm9tIjogW3sidWlkIjogNH1dfSwgeyJ0eXBlIjogIklDRGlhZ25vc2lzIiwgImJlZ2luIjogMTkwLCAiZW5kIjogMjAyLCAiY292ZXJlZFRleHQiOiAiY2hyb25pYyBwYWluIiwgIm5lZ2F0ZWQiOiBmYWxzZSwgImN1aSI6ICJDMDE1MDA1NSIsICJwcmVmZXJyZWROYW1lIjogIkNocm9uaWMgcGFpbiIsICJzb3VyY2UiOiAiQ2xpbmljYWwgSW5zaWdodHMgLSBEZXJpdmVkIENvbmNlcHRzIiwgInNvdXJjZVZlcnNpb24iOiAidjEuMCIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIlZBTElEIn0sICJpY2Q5Q29kZSI6ICIzMzguMjkiLCAiaWNkMTBDb2RlIjogIlI1MixSNTIuMiIsICJuY2lDb2RlIjogIkMyNjk0MCIsICJzbm9tZWRDb25jZXB0SWQiOiAiODI0MjMwMDEiLCAibWVzaElkIjogIk0wNTQ5ODM3IiwgImxvaW5jSWQiOiAiTVRIVTAxMzM4MixMQTIyMDkzLTEiLCAiaW5zaWdodE1vZGVsRGF0YSI6IHsiZGlhZ25vc2lzIjogeyJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDEuMCwgInBhdGllbnRSZXBvcnRlZFNjb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9LCAic3VzcGVjdGVkU2NvcmUiOiAwLjAsICJzeW1wdG9tU2NvcmUiOiAwLjAyMSwgInRyYXVtYVNjb3JlIjogMC4wLCAiZmFtaWx5SGlzdG9yeVNjb3JlIjogMC4wfX0sICJydWxlSWQiOiAiM2NmMzhlMjktNzdmMC00N2IzLTk5NTAtNGEwMjkyZjY0YzkzIiwgImRlcml2ZWRGcm9tIjogW3sidWlkIjogNX1dfV0sICJNZWRpY2F0aW9uSW5kIjogW3sidHlwZSI6ICJhY2kuTWVkaWNhdGlvbkluZCIsICJ1aWQiOiA4LCAiYmVnaW4iOiAxMDQsICJlbmQiOiAxMTMsICJjb3ZlcmVkVGV4dCI6ICJuYXJjb3RpY3MiLCAibmVnYXRlZCI6IGZhbHNlLCAiY3VpIjogIkMwMDI3NDE1IiwgImRydWciOiBbeyJjb3ZlcmVkVGV4dCI6ICJuYXJjb3RpY3MiLCAiY3VpIjogIkMwMDI3NDE1IiwgImNvbXBsZXgiOiAiZmFsc2UiLCAiZW5kIjogMTEzLCAidHlwZSI6ICJhY2kuSW5kX0RydWciLCAibmFtZTEiOiBbeyJjb3ZlcmVkVGV4dCI6ICJuYXJjb3RpY3MiLCAiY3VpIjogIkMwMDI3NDE1IiwgImRydWdTdXJmYWNlRm9ybSI6ICJuYXJjb3RpY3MiLCAiZHJ1Z05vcm1hbGl6ZWROYW1lIjogIm5hcmNvdGljcyIsICJlbmQiOiAxMTMsICJ0eXBlIjogImFjaS5EcnVnTmFtZSIsICJiZWdpbiI6IDEwNH1dLCAiYmVnaW4iOiAxMDR9XSwgImluc2lnaHRNb2RlbERhdGEiOiB7Im1lZGljYXRpb24iOiB7InVzYWdlIjogeyJ0YWtlblNjb3JlIjogMS4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wLCAibGFiTWVhc3VyZW1lbnRTY29yZSI6IDAuMH0sICJzdGFydGVkRXZlbnQiOiB7InNjb3JlIjogMC45ODIsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDEuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH19LCAiZG9zZUNoYW5nZWRFdmVudCI6IHsic2NvcmUiOiAwLjAwMSwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMC4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX0sICJzdG9wcGVkRXZlbnQiOiB7InNjb3JlIjogMC4wMDEsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH19LCAiYWR2ZXJzZUV2ZW50IjogeyJzY29yZSI6IDAuOTk5LCAiYWxsZXJneVNjb3JlIjogMC4wLCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAwLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMS4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fX19LCAiZGlzYW1iaWd1YXRpb25EYXRhIjogeyJ2YWxpZGl0eSI6ICJWQUxJRCIsICJjb21tZW50IjogIm1hcmtlZCBWQUxJRCBieSBjbGluaWNhbCBpbnNpZ2h0IG1vZGVscy4ifX0sIHsidHlwZSI6ICJhY2kuTWVkaWNhdGlvbkluZCIsICJ1aWQiOiA5LCAiYmVnaW4iOiAxMTgsICJlbmQiOiAxMjcsICJjb3ZlcmVkVGV4dCI6ICJOZXVyb250aW4iLCAibmVnYXRlZCI6IGZhbHNlLCAiY3VpIjogIkMwNjc4MTc2IiwgImRydWciOiBbeyJjb3ZlcmVkVGV4dCI6ICJOZXVyb250aW4iLCAiY3VpIjogIkMwNjc4MTc2IiwgImNvbXBsZXgiOiAiZmFsc2UiLCAiZW5kIjogMTI3LCAidHlwZSI6ICJhY2kuSW5kX0RydWciLCAibmFtZTEiOiBbeyJyeE5vcm1JRCI6ICIxOTY0OTgiLCAiY292ZXJlZFRleHQiOiAiTmV1cm9udGluIiwgImN1aSI6ICJDMDY3ODE3NiIsICJkcnVnU3VyZmFjZUZvcm0iOiAiTmV1cm9udGluIiwgImRydWdOb3JtYWxpemVkTmFtZSI6ICJuZXVyb250aW4iLCAiZW5kIjogMTI3LCAidHlwZSI6ICJhY2kuRHJ1Z05hbWUiLCAiYmVnaW4iOiAxMTh9XSwgImJlZ2luIjogMTE4fV0sICJpbnNpZ2h0TW9kZWxEYXRhIjogeyJtZWRpY2F0aW9uIjogeyJ1c2FnZSI6IHsidGFrZW5TY29yZSI6IDEuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMCwgImxhYk1lYXN1cmVtZW50U2NvcmUiOiAwLjB9LCAic3RhcnRlZEV2ZW50IjogeyJzY29yZSI6IDAuOTk4LCAidXNhZ2UiOiB7ImV4cGxpY2l0U2NvcmUiOiAxLjAsICJjb25zaWRlcmluZ1Njb3JlIjogMC4wLCAiZGlzY3Vzc2VkU2NvcmUiOiAwLjB9fSwgImRvc2VDaGFuZ2VkRXZlbnQiOiB7InNjb3JlIjogMC4wMDIsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH19LCAic3RvcHBlZEV2ZW50IjogeyJzY29yZSI6IDAuMCwgInVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMC4wLCAiY29uc2lkZXJpbmdTY29yZSI6IDAuMCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX0sICJhZHZlcnNlRXZlbnQiOiB7InNjb3JlIjogMC44OTEsICJhbGxlcmd5U2NvcmUiOiAwLjAsICJ1c2FnZSI6IHsiZXhwbGljaXRTY29yZSI6IDAuMCwgImNvbnNpZGVyaW5nU2NvcmUiOiAwLjY3OCwgImRpc2N1c3NlZFNjb3JlIjogMC4wfX19fSwgImRpc2FtYmlndWF0aW9uRGF0YSI6IHsidmFsaWRpdHkiOiAiVkFMSUQiLCAiY29tbWVudCI6ICJtYXJrZWQgVkFMSUQgYnkgY2xpbmljYWwgaW5zaWdodCBtb2RlbHMuIn19XSwgIlN5bXB0b21EaXNlYXNlSW5kIjogW3sidHlwZSI6ICJhY2kuU3ltcHRvbURpc2Vhc2VJbmQiLCAidWlkIjogMTAsICJiZWdpbiI6IDE2NSwgImVuZCI6IDE4NSwgImNvdmVyZWRUZXh0IjogInRyaWdlbWluYWwgbmV1cmFsZ2lhIiwgIm5lZ2F0ZWQiOiBmYWxzZSwgImN1aSI6ICJDMDA0MDk5NyIsICJpY2QxMENvZGUiOiAiRzUwLjAiLCAibW9kYWxpdHkiOiAicG90ZW50aWFsIiwgInN5bXB0b21EaXNlYXNlU3VyZmFjZUZvcm0iOiAidHJpZ2VtaW5hbCBuZXVyYWxnaWEiLCAic25vbWVkQ29uY2VwdElkIjogIjMxNjgxMDA1IiwgImNjc0NvZGUiOiAiOTUiLCAic3ltcHRvbURpc2Vhc2VOb3JtYWxpemVkTmFtZSI6ICJ0cmlnZW1pbmFsIG5ldXJhbGdpYSIsICJpY2Q5Q29kZSI6ICIzNTAuMSIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIlZBTElEIn0sICJpbnNpZ2h0TW9kZWxEYXRhIjogeyJkaWFnbm9zaXMiOiB7InVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMS4wLCAicGF0aWVudFJlcG9ydGVkU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH0sICJzdXNwZWN0ZWRTY29yZSI6IDAuMCwgInN5bXB0b21TY29yZSI6IDAuMCwgInRyYXVtYVNjb3JlIjogMC4wLCAiZmFtaWx5SGlzdG9yeVNjb3JlIjogMC4wMDN9fX0sIHsidHlwZSI6ICJhY2kuU3ltcHRvbURpc2Vhc2VJbmQiLCAidWlkIjogMTEsICJiZWdpbiI6IDE5MCwgImVuZCI6IDIwMiwgImNvdmVyZWRUZXh0IjogImNocm9uaWMgcGFpbiIsICJuZWdhdGVkIjogZmFsc2UsICJjdWkiOiAiQzAxNTAwNTUiLCAiaWNkMTBDb2RlIjogIlI1Mi4yLFI1MiIsICJtb2RhbGl0eSI6ICJwb3RlbnRpYWwiLCAic3ltcHRvbURpc2Vhc2VTdXJmYWNlRm9ybSI6ICJjaHJvbmljIHBhaW4iLCAic25vbWVkQ29uY2VwdElkIjogIjgyNDIzMDAxIiwgImNjc0NvZGUiOiAiMjU5IiwgInN5bXB0b21EaXNlYXNlTm9ybWFsaXplZE5hbWUiOiAiY2hyb25pYyBwYWluIiwgImljZDlDb2RlIjogIjMzOC4yOSIsICJkaXNhbWJpZ3VhdGlvbkRhdGEiOiB7InZhbGlkaXR5IjogIlZBTElEIn0sICJpbnNpZ2h0TW9kZWxEYXRhIjogeyJkaWFnbm9zaXMiOiB7InVzYWdlIjogeyJleHBsaWNpdFNjb3JlIjogMS4wLCAicGF0aWVudFJlcG9ydGVkU2NvcmUiOiAwLjAsICJkaXNjdXNzZWRTY29yZSI6IDAuMH0sICJzdXNwZWN0ZWRTY29yZSI6IDAuMCwgInN5bXB0b21TY29yZSI6IDAuMDIxLCAidHJhdW1hU2NvcmUiOiAwLjAsICJmYW1pbHlIaXN0b3J5U2NvcmUiOiAwLjB9fX1dLCAic3BlbGxpbmdDb3JyZWN0aW9ucyI6IFt7ImJlZ2luIjogMTQ2LCAiZW5kIjogMTU2LCAiY292ZXJlZFRleHQiOiAicGVyc2NyaWJlZCIsICJzdWdnZXN0aW9ucyI6IFt7InRleHQiOiAicHJlc2NyaWJlZCIsICJjb25maWRlbmNlIjogMC45LCAiYXBwbGllZCI6IHRydWV9LCB7InRleHQiOiAicHJvc2NyaWJlZCIsICJjb25maWRlbmNlIjogMC44MDMsICJhcHBsaWVkIjogZmFsc2V9LCB7InRleHQiOiAiZGVzY3JpYmVkIiwgImNvbmZpZGVuY2UiOiAwLjgwMiwgImFwcGxpZWQiOiBmYWxzZX0sIHsidGV4dCI6ICJwcmVzY3JpYmUiLCAiY29uZmlkZW5jZSI6IDAuODAxLCAiYXBwbGllZCI6IGZhbHNlfSwgeyJ0ZXh0IjogInByZXNjcmliZXIiLCAiY29uZmlkZW5jZSI6IDAuOCwgImFwcGxpZWQiOiBmYWxzZX1dfV0sICJzcGVsbENvcnJlY3RlZFRleHQiOiBbeyJjb3JyZWN0ZWRUZXh0IjogIlRoZSBwYXRpZW50J3MgY291cnNlIGNvdWxkIGhhdmUgYmVlbiBjb21wbGljYXRlZCBieSBtZW50YWwgc3RhdHVzIGNoYW5nZXMgc2Vjb25kYXJ5IHRvIGEgY29tYmluYXRpb24gb2YgbmFyY290aWNzIGFuZCBOZXVyb250aW4sIHdoaWNoIHdhcyBhbG1vc3QgcHJlc2NyaWJlZCBmb3IgaGlzIHRyaWdlbWluYWwgbmV1cmFsZ2lhIGFuZCBjaHJvbmljIHBhaW4uIFxuXG4ifV19"
                }
              },
              {
                "extension": [
                  {
                    "extension": [
                      {
                        "url": "http://ibm.com/fhir/cdm/StructureDefinition/covered-text",
                        "valueString": "Neurontin"
                      },
                      {
                        "url": "http://ibm.com/fhir/cdm/StructureDefinition/offset-begin",
                        "valueInteger": 118
                      },
                      {
                        "url": "http://ibm.com/fhir/cdm/StructureDefinition/offset-end",
                        "valueInteger": 127
                      },
                      {
                        "extension": [
                          {
                            "url": "http://ibm.com/fhir/cdm/StructureDefinition/method",
                            "valueCodeableConcept": {
                              "coding": [
                                {
                                  "code": "Adverse_Event_Score",
                                  "system": "http://ibm.com/fhir/cdm/CodeSystem/1.0/acd-confidence-method"
                                }
                              ]
                            }
                          },
                          {
                            "url": "http://ibm.com/fhir/cdm/StructureDefinition/score",
                            "valueDecimal": 0.891
                          },
                          {
                            "url": "http://ibm.com/fhir/cdm/StructureDefinition/description",
                            "valueString": "Adverse Event Score"
                          }
                        ],
                        "url": "http://ibm.com/fhir/cdm/StructureDefinition/insight-confidence"
                      }
                    ],
                    "url": "http://ibm.com/fhir/cdm/StructureDefinition/span"
                  }
                ],
                "url": "http://ibm.com/fhir/cdm/StructureDefinition/insight-result"
              }
            ],
            "url": "http://ibm.com/fhir/cdm/StructureDefinition/insight-detail"
          }
        ],
        "url": "http://ibm.com/fhir/cdm/StructureDefinition/insight"
      }
    ]
  },
  "extension": [
    {
      "extension": [
        {
          "url": "http://ibm.com/fhir/cdm/StructureDefinition/insight-id",
          "valueIdentifier": {
            "system": "urn:alvearie.io/health_patterns/services/nlp_insights/acd",
            "value": "1b32afb1d37b7a442c676f8f191800d89882c8d8163b6379d1c387f5"
          }
        },
        {
          "url": "http://ibm.com/fhir/cdm/StructureDefinition/category",
          "valueCodeableConcept": {
            "coding": [
              {
                "code": "natural-language-processing",
                "display": "NLP",
                "system": "http://ibm.com/fhir/cdm/CodeSystem/insight-category-code-system"
              }
            ],
            "text": "NLP"
          }
        }
      ],
      "url": "http://ibm.com/fhir/cdm/StructureDefinition/insight-summary"
    }
  ],
  "actuality": "actual",
  "event": {
    "coding": [
      {
        "code": "C0678176",
        "system": "http://terminology.hl7.org/CodeSystem/umls"
      }
    ],
    "text": "neurontin"
  },
  "resourceType": "AdverseEvent"
}
```

</details>

## Codes
It's easy to see that each of our adverse event resources contains a single UMLS code for the event. 
These codes are associated with a surface form that caused the adverse event to be created.

:construction: A UMLS concept is not an ideal code for representing an Adverse Event. The FHIR standard recommends a SNOMED CT
[value set](https://www.hl7.org/fhir/valueset-adverse-event-type.html). Because adverse events often are of interest to regulators,
[MedDRA](https://www.meddra.org) codes are also highly desirable. These coding systems are not yet provided by ACD, but we hope to
add these codes if/when the NLP technology is available. :construction:

<!--
 cat /tmp/output.json | jq -r '
["Adverse Event Text", "Code", "System"], 
["---", "---", "---"] , 
(.entry[] | .resource | select(.resourceType=="AdverseEvent" and (.event.text=="neurontin" or .event.text=="narcotics")) | [.event.text, .event.coding[].code, .event.coding[].system ]) 
| @tsv' | column -t -o "|" -s $'\t'
-->

Adverse Event Text|Code    |System
---               |---     |---
narcotics         |C0027415|http://terminology.hl7.org/CodeSystem/umls
neurontin         |C0678176|http://terminology.hl7.org/CodeSystem/umls


## Actuality
While the FHIR standard distinguishes between potential (or near-miss) adverse events and actual events, the nlp-insights service creates
adverse event resources as actual, and does not distinguish between actual and potential events.

It is possible that the problem could be solved (in some cases) with a code change to nlp-insights.
For example, suppose the text passage was something similar to:

```
The patient's course could have been complicated by mental status \
changes secondary to a combination of narcotics and Neurontin, \
which was almost perscribed for his trigeminal neuralgia and chronic pain.
```

ACD would return confidences with a high value for the "considering" usage score:
```json
 "adverseEvent": {
    "score": 0.999,
    "allergyScore": 0,
    "usage": {
      "explicitScore": 0,
      "consideringScore": 1,
      "discussedScore": 0
    }
  },
```

This could be leveraged by nlp-insights to determine that the event did not actually happen.

In building the reference implementation, we did not have sufficient examples to determine 
if this approach would work well enough to be of value in practice, or what value of 
the consideringScore should be used as the decision boundary.
Another consideration was that additional functionality might someday be added to ACD that solves this problem in a better way.

:construction: The determination of actuality is therefore still an area of research and further contribution. :construction:

## Evidence
The available evidence is consistent with [other derived resource types](./derive_new_resources.md).

* The span will cover the surface form used to construct the UMLS code for the event.
* A confidence will be returned for the Adverse Event. No other confidences are returned at this time.