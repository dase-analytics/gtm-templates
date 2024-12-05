___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Event based bidding with Firestore - tag",
  "brand": {
    "id": "brand_dummy",
    "displayName": ""
  },
  "description": "",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[]


___SANDBOXED_JS_FOR_SERVER___

/**
  Tag is a part of (Marcel's) solution for Event Based Bidding with Firestore. It sends event names to Firestore. Events 
  are stored according to session ID. 
**/

const Firestore = require('Firestore');
const getEventData = require('getEventData');
const getTimestampMillis = require('getTimestampMillis');
const log = require('logToConsole');

const timestamp = getTimestampMillis();
const eventName = getEventData('event_name');
const sessionId = getEventData('ga_session_id');
let input = {};

if (sessionId) {
  const path = 'session_id/' + sessionId;
  input['_' + timestamp] = eventName; 

  Firestore.write(path, input, {
    merge: true,
  }).then(
    (id) => {
      log('Success: Data written to Firestore');
      data.gtmOnSuccess();
    },
    (error) => {
      log('Error: Failed to write data to Firestore');
      data.gtmOnFailure();
    }
  );
}


___SERVER_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "access_firestore",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedOptions",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "projectId"
                  },
                  {
                    "type": 1,
                    "string": "path"
                  },
                  {
                    "type": 1,
                    "string": "operation"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "*"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "read_event_data",
        "versionId": "1"
      },
      "param": [
        {
          "key": "eventDataAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "isRequired": true
  }
]


___TESTS___

scenarios: []


___NOTES___

Created on 05/11/2024, 20:02:18


