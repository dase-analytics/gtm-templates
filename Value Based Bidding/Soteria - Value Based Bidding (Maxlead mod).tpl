___INFO___

{
  "type": "MACRO",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Soteria - Value Based Bidding (Maxlead mod)",
  "description": "Variable that retrieves values from Firestore for each item_id in the items array of the event data.\n\nFor more information head over to: https://github.com/google/gps_soteria",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "gcpProjectId",
    "displayName": "GCP Project ID (Where Firestore is located)",
    "simpleValueType": true,
    "notSetText": "GOOGLE_CLOUD_PROJECT",
    "help": "Google Cloud Project ID where the Firestore database with margin data is located, leave empty to read from GOOGLE_CLOUD_PROJECT environment variable",
    "canBeEmptyString": true
  },
  {
    "type": "TEXT",
    "name": "collectionId",
    "displayName": "Firestore Collection ID",
    "simpleValueType": true,
    "defaultValue": "products",
    "help": "The collection in Firestore that contains the products"
  },
  {
    "type": "TEXT",
    "name": "valueField",
    "displayName": "Value Field",
    "simpleValueType": true,
    "defaultValue": "profit",
    "help": "Field in the Firestore Document that holds the value data for the item",
    "notSetText": "Please set the Firestore document field for value data"
  },
  {
    "type": "SELECT",
    "name": "valueCalculation",
    "displayName": "Value Calculation",
    "macrosInSelect": false,
    "selectItems": [
      {
        "value": "valueQuantity",
        "displayValue": "Value"
      },
      {
        "value": "returnRate",
        "displayValue": "Return Rate"
      },
      {
        "value": "valueWithDiscount",
        "displayValue": "Value with Discount"
      }
    ],
    "simpleValueType": true,
    "defaultValue": "valueQuantity",
    "help": "How to calculate the value for each item.\nSee this page for more information: https://github.com/google-marketing-solutions/gps_soteria/tree/main/docs#value-calculation"
  },
  {
    "type": "TEXT",
    "name": "returnRateField",
    "displayName": "Return Rate Field",
    "simpleValueType": true,
    "enablingConditions": [
      {
        "paramName": "valueCalculation",
        "paramValue": "returnRate",
        "type": "EQUALS"
      }
    ],
    "help": "Field in the Firestore Document that holds the return rate data for the item",
    "defaultValue": "return_rate",
    "notSetText": "Please set the Firestore document field for return rate data"
  },
  {
    "type": "GROUP",
    "name": "fallback",
    "displayName": "Fallback Value if Product Not Found",
    "groupStyle": "NO_ZIPPY",
    "subParams": [
      {
        "type": "SELECT",
        "name": "fallbackValueIfNotFound",
        "displayName": "Fallback Value Calculation",
        "macrosInSelect": false,
        "selectItems": [
          {
            "value": "zero",
            "displayValue": "Zero"
          },
          {
            "value": "revenue",
            "displayValue": "Revenue"
          },
          {
            "value": "percent",
            "displayValue": "Percent"
          }
        ],
        "simpleValueType": true,
        "help": "Set what the default should be if the product isn\u0027t found in Firestore.",
        "defaultValue": "percent"
      },
      {
        "type": "TEXT",
        "name": "fallBackPercent",
        "displayName": "Percentage",
        "simpleValueType": true,
        "defaultValue": 0.1,
        "valueValidators": [
          {
            "type": "NON_EMPTY"
          },
          {
            "type": "DECIMAL"
          }
        ],
        "help": "The percentage of the item price to use as the fallback value. This should be between 0 \u0026 1, so 10% \u003d 0.1.",
        "enablingConditions": [
          {
            "paramName": "fallbackValueIfNotFound",
            "paramValue": "percent",
            "type": "EQUALS"
          }
        ]
      }
    ]
  },
  {
    "type": "GROUP",
    "name": "varTriggers",
    "displayName": "Variable Trigger Events",
    "groupStyle": "NO_ZIPPY",
    "subParams": [
      {
        "type": "SIMPLE_TABLE",
        "name": "varTriggersTable",
        "displayName": "",
        "simpleTableColumns": [
          {
            "defaultValue": "",
            "displayName": "",
            "name": "value",
            "type": "TEXT"
          }
        ],
        "help": "Enter the event names which trigger the variable."
      }
    ]
  }
]


___SANDBOXED_JS_FOR_SERVER___

// Modification of the sGTM Pantheon tag Soteria - value based bidding. The variable retrieves data from // Firestore and returns final value (e.g. profit)
// https://github.com/google-marketing-solutions/gps_soteria/tree/main

const Firestore = require("Firestore");
const Promise = require("Promise");
const getEventData = require("getEventData");
const logToConsole = require("logToConsole");
const makeNumber = require("makeNumber");
const makeString = require("makeString");
const Math = require("Math");
const getType = require("getType");

const eventName = getEventData("event_name");
const triggersArray = data.varTriggersTable;

// Sums numeric values in the given array.
function sumValues(values) {
  let total = 0;
  for (const value of values) {
    if (getType(value) === "number") {
      total += value;
    } else {
      logToConsole("Non-numeric value encountered");
    }
  }
  return makeString(total);
}


// Retrieves item values from Firestore based on event data.
function getItemValues(items) {
  const valueRequests = items.map(item => getFirestoreValue(item));
  return Promise.all(valueRequests);
}


// Returns a default value for an item based on configuration.
function getDefaultValue(item) {
  let value;
  const quantity = item.hasOwnProperty("quantity") ? item.quantity : 1;

  switch (data.fallbackValueIfNotFound) {
    case "zero":
      value = 0;
      break;
    case "revenue":
      value = makeNumber(item.price) * makeNumber(quantity);
      break;
    case "percent":
      const percent = makeNumber(data.fallBackPercent);
      value = roundValue(makeNumber(item.price) * percent * quantity);
      break;
  }
  return value;
}


// Calculates item value based on Firestore data and configuration.
function calculateValue(item, fsDocument) {
  let value;
  const quantity = item.hasOwnProperty("quantity") ? item.quantity : 1;
  const documentValue = makeNumber(fsDocument.data[data.valueField]);

  switch (data.valueCalculation) {
    case "valueQuantity":
      value = documentValue * makeNumber(quantity);
      break;
    case "returnRate":
      const returnRate = makeNumber(fsDocument.data[data.returnRateField]);
      value = roundValue((1 - returnRate) * documentValue * quantity);
      break;
    case "valueWithDiscount":
      const discount = item.hasOwnProperty("discount") ? item.discount : 0;
      value = (documentValue - discount) * quantity;
      break;
  }
  return value;
}

// Rounds a number to 2 decimal places to handle floating-point precision.
function roundValue(value) {
  return Math.round(value * 100) / 100;
}

// Retrieves or calculates the item value from Firestore.
function getFirestoreValue(item) {
  let value = getDefaultValue(item);

  if (!item.item_id) {
    logToConsole("No item ID in item");
    return value;
  }

  const path = data.collectionId + "/" + item.item_id;

  // Mock API for tests within the function
  let firestore = Firestore;
  if (getType(Firestore) === "function"){
    firestore = Firestore();
  }

  return Promise.create((resolve) => {
    return firestore.read(path, { projectId: data.gcpProjectId })
      .then((fsDocument) => {
        value = calculateValue(item, fsDocument, value);
      })
      .catch((error) => {
        logToConsole(
          "Error retrieving Firestore document `" + path + "`", error);
      })
      .finally(() => {
        resolve(value);
      });
  });
}

// Entry point
if (triggersArray.some(event => event.value === eventName)) {
    const items = getEventData("items");
    logToConsole("Items", items);
  return getItemValues(items)
    .then(sumValues)
    .catch((error) => {
      logToConsole("Error", error);
  });
}

return null;


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
                    "string": "GOOGLE_CLOUD_PROJECT"
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

scenarios:
- name: Test collectionID used in request to Firestore
  code: |
    const mockData = {
      collectionId: "test-products",
      valueCalculation: "valueQuantity",
      valueField: "profit",
      fallbackValueIfNotFound: "percent",
    };

    addMockEventData([
      {"item_id": "sku1", "quantity": 2, "price": 50}
    ]);

    mock("Firestore", () => {
      return {
        "read": (path, options) => {
          assertThat(path).isEqualTo("test-products/sku1");
          return Promise.create((resolve) => {
            resolve({"data": {"profit": 100}});
          });
        }
      };
    });

    runCode(mockData);
- name: Test valueField used when parsing value from Firestore
  code: |
    const mockData = {
      collectionId: "products",
      valueCalculation: "valueQuantity",
      valueField: "profit",
      fallbackValueIfNotFound: "percent",
    };

    addMockEventData([
      {"item_id": "sku1", "quantity": 1, "price": 150},
    ]);

    addMockFirestore({
      "sku1": {"data": {"profit": 100}}
    });

    runCode(mockData).then((resp) => {
      assertThat(resp).isString();
      assertThat(resp).isEqualTo("100");
    });
- name: Test valueCalculation for valueQuantity
  code: |
    const mockData = {
      collectionId: "products",
      valueCalculation: "valueQuantity",
      valueField: "profit",
      fallbackValueIfNotFound: "percent",
      eventName: "purchase",
    };

    addMockEventData([
      {"item_id": "sku1", "quantity": 2, "price": 150},
      {"item_id": "sku2", "quantity": 1, "price": 50},
    ]);

    addMockFirestore({
      "sku1": {"data": {"profit": 100}},
      "sku2": {"data": {"profit": 10}}
    });


    runCode(mockData).then((resp) => {
      assertThat(resp).isString();
      assertThat(resp).isEqualTo("210");
    });
- name: Test valueCalculation for returnRate
  code: |
    const mockData = {
      collectionId: "products",
      returnRateField: "return_rate",
      valueCalculation: "returnRate",
      valueField: "profit",
      fallbackValueIfNotFound: "percent",
    };

    addMockEventData([
      {"item_id": "sku1", "quantity": 2, "price": 150},
      {"item_id": "sku2", "quantity": 1, "price": 50},
    ]);

    addMockFirestore({
      "sku1": {"data": {"profit": 100, "return_rate": 0.5}},
      "sku2": {"data": {"profit": 10, "return_rate": 0.25}}
    });

    runCode(mockData).then((resp) => {
      assertThat(resp).isString();
      assertThat(resp).isEqualTo("107.5");
    });
- name: Test valueCalculation for valueWithDiscount
  code: |
    const mockData = {
      collectionId: "products",
      valueCalculation: "valueWithDiscount",
      valueField: "profit",
      fallbackValueIfNotFound: "percent",
    };

    addMockEventData([
      {"item_id": "sku1", "quantity": 2, "price": 150, "discount": 20},
      {"item_id": "sku2", "quantity": 1, "price": 50},
    ]);

    addMockFirestore({
      "sku1": {"data": {"profit": 100}},
      "sku2": {"data": {"profit": 10}}
    });


    runCode(mockData).then((resp) => {
      assertThat(resp).isString();
      assertThat(resp).isEqualTo("170");
    });
- name: Test fallback percent
  code: |
    const mockData = {
      collectionId: "products",
      valueCalculation: "valueQuantity",
      valueField: "profit",
      fallbackValueIfNotFound: "percent",
      fallBackPercent: 0.1,
    };

    addMockEventData([
      {"item_id": "sku1", "quantity": 1, "price": 150}
    ]);

    addMockFirestore({
      "sku2": {"data": {"profit": 100}}
    });


    runCode(mockData).then((resp) => {
      assertThat(resp).isString();
      assertThat(resp).isEqualTo("15");
    });
- name: Test fallback revenue
  code: |
    const mockData = {
      collectionId: "products",
      valueCalculation: "valueQuantity",
      valueField: "profit",
      fallbackValueIfNotFound: "revenue",
    };

    addMockEventData([
      {"item_id": "sku1", "quantity": 1, "price": 150}
    ]);

    addMockFirestore({
      "sku2": {"data": {"profit": 100}}
    });


    runCode(mockData).then((resp) => {
      assertThat(resp).isString();
      assertThat(resp).isEqualTo("150");
    });
- name: Test fallback zero
  code: |
    const mockData = {
      collectionId: "products",
      valueCalculation: "valueQuantity",
      valueField: "profit",
      fallbackValueIfNotFound: "zero",
    };

    addMockEventData([
      {"item_id": "sku1", "quantity": 1, "price": 150}
    ]);

    addMockFirestore({
      "sku2": {"data": {"profit": 100}}
    });


    runCode(mockData).then((resp) => {
      assertThat(resp).isString();
      assertThat(resp).isEqualTo("0");
    });
- name: Test rounding to 2 decimal places with fallback value
  code: |
    const mockData = {
      collectionId: "products",
      valueCalculation: "valueQuantity",
      valueField: "profit",
      fallbackValueIfNotFound: "percent",
      fallBackPercent: 0.17,
    };

    addMockEventData([
      {"item_id": "sku1", "quantity": 1, "price": 37.123456}
    ]);

    addMockFirestore({
      "sku2": {"data": {"profit": 10}}
    });


    runCode(mockData).then((resp) => {
      assertThat(resp).isString();
      assertThat(resp).isEqualTo("6.31");
    });
setup: |-
  const Promise = require("Promise");

  /**
   * Add mock getEventData to the test.
   * @param {!Array<!Object>} items an array of items from the datalayer.
   */
  function addMockEventData(items){
    mock("getEventData", (data) => {
      if (data === "items") {
        return items;
      }
    });
  }

  /**
   * Add mock Firestore library to the test.
   * @param {!Object} firestoreDocs an object representing the firestore response.
   */
  function addMockFirestore(firestoreDocs){
    mock("Firestore", () => {
      return {
        "read": (path, options) => {
          const sku = path.replace(mockData.collectionId + "/", "");
          const doc = firestoreDocs[sku];
          return Promise.create((resolve) => {
            resolve(doc);
          });
        }
      };
    });
  }


___NOTES___

Created on 8/3/2022, 3:02:04 PM


