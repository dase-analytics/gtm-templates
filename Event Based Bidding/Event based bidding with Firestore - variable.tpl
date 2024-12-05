___INFO___

{
  "type": "MACRO",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Event based bidding with Firestore - variable",
  "description": "",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "projectID",
    "displayName": "Project ID",
    "simpleValueType": true
  }
]


___SANDBOXED_JS_FOR_SERVER___

/**
  Variable is part of the (Marcel's) solution for Event Based Bidding with Firestore. It retrieves event 
  values and session data. It processes the data and returns value of the session
**/

const Firestore = require('Firestore');
const Object = require('Object'); 
const getEventData = require('getEventData');
const Promise = require('Promise');
const log = require('logToConsole');

const eventName = getEventData('event_name');
const projectId = data.projectId;
const collectionName = 'session_id'; 
const sessionId = '1729887634'; // getEventData('ga_session_id');

// Firestore call to retrieve session data
const sessionDataPromise = Firestore.read(collectionName + '/' + sessionId, {
  projectId: projectId,
}).then(
  (result) => result.data,  
  () => null                
);

// Firestore call to retrieve event values
const eventValuesPromise = Firestore.read(collectionName + '/eventValues', {
  projectId: projectId,
}).then(
  (result) => result.data || {},  
  () => ({})                      
);

// Using Promise.all to process both Firestore calls once they are resolved
return Promise.all([sessionDataPromise, eventValuesPromise]).then((results) => { 
  var sessionData = results[0];
  var eventValues = results[1];

  if (!sessionData || !eventValues) {
    return null;
  }

  var occurrenceCounts = countOccurrences(sessionData);

  var valuesMapping = {};
  for (var key in occurrenceCounts) {
    if (eventValues.hasOwnProperty(key)) {
      valuesMapping[key] = occurrenceCounts[key] * eventValues[key];
    }
  }

  return Object.keys(valuesMapping).reduce((total, key) => total + valuesMapping[key], 0); 
  
}).catch((error) => { 
  log('Error in Firestore requests:', error);
  return null;
});

// Helper function to count occurrences
function countOccurrences(inputObject) {
  var occurrenceCounts = {};
  for (var key in inputObject) {
    var value = inputObject[key];
    occurrenceCounts[value] = (occurrenceCounts[value] || 0) + 1;
  }
  return occurrenceCounts;
}


___SERVER_PERMISSIONS___

[
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
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
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
                    "string": "read"
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
  }
]


___TESTS___

scenarios: []


___NOTES___

Created on 05/11/2024, 20:01:56


