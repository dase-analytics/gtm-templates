// https://developers.facebook.com/docs/marketing-api/conversions-api/best-practices
// v.1.0.2

// Sandbox JavaScript imports and initializations
const getAllEventData = require('getAllEventData');
const getEventData = require('getEventData');
const sendHttpRequest = require('sendHttpRequest');
const JSON = require('JSON');
const Math = require('Math');
const getTimestampMillis = require('getTimestampMillis');
const sha256Sync = require('sha256Sync');
const getCookieValues = require('getCookieValues');
const setCookie = require('setCookie');
const decodeUriComponent = require('decodeUriComponent');
const parseUrl = require('parseUrl');
const computeEffectiveTldPlusOne = require('computeEffectiveTldPlusOne');
const makeTableMap = require('makeTableMap');
const Object = require('Object');
const generateRandom = require('generateRandom');
const BigQuery = require('BigQuery'); 
const queryPermission = require('queryPermission'); 

const log = require('logToConsole'); 

// Constants and initial event data retrieval
const API_ENDPOINT = 'https://graph.facebook.com';
const API_VERSION = 'v20.0';
const PARTNER_AGENT = 'mxl-1.0.0-0.0.1'; 
const eventData = getAllEventData();
let user = getEventData('user_data');
const items = getEventData('items');
const consent = getEventData('x-ga-gcs') || 'G100';
const fbDataObject = eventData.fb_data ? JSON.parse(eventData.fb_data) : {};

/*
- - - - - - - - - - - - - - - - - - - -
  HELPERS
- - - - - - - - - - - - - - - - - - - -
*/
// Merging two objects
const mergeObj = (obj, obj2) => {
  Object.keys(obj2).forEach((key) => {
    if (obj2.hasOwnProperty(key)) {
      obj[key] = obj2[key];
    }
  });
  return obj;
};

// Hashing function for user data
function hashFunction(val) {
    if (!val) { return undefined; }
    if (isHashed(val)) { return val; }
    return sha256Sync(val.trim().toLowerCase(), { outputEncoding: 'hex' });
}

// Check if a value is already hashed
function isHashed(val){
  return val && val.match("^[A-Fa-f0-9]{64}$") != null;
}

// Setting FB cookies to browser
function setFbCookieToBrowser(name, value, consent) {
  if(consent[2] === '1') {
    setCookie(name, value, {
        domain: 'auto',
        path: '/',
        samesite: 'Lax',
        secure: true,
        'max-age': 7776000, // 90 days (in seconds)
        httpOnly: false
    });
  }
}

// Phone number formatting 
function phoneNumberFormatting(phoneNumber) {
  if (!phoneNumber) {
    return '';
  }
  
  // remove plus sign at the beginning of the phone number
  if (phoneNumber.charAt(0) === '+') {
    return phoneNumber.slice(1); 
  }
  return phoneNumber; 
}


/*
- - - - - - - - - - - - - - - - - - - -
  MAIN FUNCTIONS
- - - - - - - - - - - - - - - - - - - -
*/
// EVENT NAME - transform GA4 event names to FB event names, with custom event mapping
function getFBEventName(gaEventName, data) {
  const ga4ToStandardEvents = {
    "add_payment_info": "AddPaymentInfo",
    "add_to_cart": "AddToCart",
    "add_to_wishlist": "AddToWishlist",
    "sign_up": "CompleteRegistration",
    "contact": "Contact", 
    "customize_product": "CustomizeProduct", 
    "donate": "Donate", 
    "find_location": "FindLocation",
    "begin_checkout": "InitiateCheckout",
    "generate_lead": "Lead",
    "purchase": "Purchase",
    "schedule": "Schedule",
    "search": "Search",
    "start_trial": "StartTrial",
    "submit_application": "SubmitApplication",
    "subscribe": "Subscribe",
    "view_item": "ViewContent",
    "page_view": "PageView",
    "gtm.dom": "PageView"
  };
  
  if (data.cemEnabled) { 
    const customEventObj = data.customEventList && data.customEventList.length ? makeTableMap(data.customEventList, 'name', 'value') : {};
    const mergedEventNameObj = mergeObj(ga4ToStandardEvents, customEventObj);
    return mergedEventNameObj[gaEventName] || gaEventName;
  }
  
  return ga4ToStandardEvents[gaEventName] || gaEventName;
}

// USER DATA - map GA4 user data to FB user data, including hashing personal information 
function setUserData(event, user) {
  event.user_data.em =  hashFunction(user.email);
  event.user_data.ph = hashFunction(phoneNumberFormatting(user.phone_number));
  if (user.address) {
    if (user.address[0]) { user.address = user.address[0]; }
    event.user_data.fn = hashFunction(user.address.first_name);
    event.user_data.ln = hashFunction(user.address.last_name);
    event.user_data.ct = hashFunction(user.address.city);
    event.user_data.st = hashFunction(user.address.region);
    event.user_data.zp = hashFunction(user.address.postal_code);
    event.user_data.country = hashFunction(user.address.country);
  }
  
  return event.user_data;
}

// COOKIES - set Facebook cookies if they are not already present, generating them if needed
function setFBCookies(event, data) {
  let _fbc = getCookieValues('_fbc', true)[0];
  let _fbp = getCookieValues('_fbp', true)[0];
  const url = eventData.page_location;
  const subDomainIndex = computeEffectiveTldPlusOne(url).split('.').length - 1;
  
  if (!_fbc) {
    if (url) {
        const parsedUrl = parseUrl(url);
        const fbclid = parsedUrl.searchParams ? parsedUrl.searchParams.fbclid : null;
        if (fbclid) {
          event.user_data.fbc = 'fb.' + subDomainIndex + '.' + 
                                 getTimestampMillis() + '.' + decodeUriComponent(fbclid);
        }
    } else { event.user_data.fbc = null; }
  } else { event.user_data.fbc = _fbc; }
  
  if (!_fbp) {
  event.user_data.fbp = 'fb.' + subDomainIndex + '.' +
                        getTimestampMillis() + '.' + generateRandom(1000000000, 2000000000);
} else { event.user_data.fbp = _fbp; }
  
  return event.user_data;
}

// ECOMMERCE - map GA4 ecommerce items to Facebook's expected format
function ga4ItemObjectMapping(event, data) {
  const contentTypeValidEvents = {
    'AddToCart': true,
    'Search': true,
    'ViewContent': true,
    'AddToWishlist': true
  };
  
  const numItemsValidEvents = {
    'InitiateCheckout': true,
    'Purchase': true
  };
  // content IDs
  event.custom_data.content_ids = items.map(item => item.item_id);
  
  // contents
  event.custom_data.contents = items.map(item => {
        return {
            'id': item.item_id  || item.item_name,
            'item_price': item.price,
            'quantity': item.quantity,
        };
    });
  
  // content_type - add_to_cart, search, view_content, 'add_to_wishlist'
  if (contentTypeValidEvents[event.event_name]) {
    event.custom_data.content_type = data.contentType ? 'product_group' : 'product';
    event.custom_data.content_name = items[0].item_name;
    event.custom_data.content_category = items[0].item_category;
  }
  
  // num_items - begin_checkout, purchase
  if (numItemsValidEvents[event.event_name]) {
    event.custom_data.num_items = event.custom_data.content_ids.length;
  }
  
  // other parameters
  event.custom_data.currency = eventData.currency || 'EUR';
  event.custom_data.order_id = eventData.transaction_id;
  
  return event.custom_data;
}

// USER DATA - handle user data parameters and merge them into the event's user data
function customUserDataMapping(event, data) {
  const customUserDataObj = data.customUserDataList && data.customUserDataList.length ? makeTableMap(data.customUserDataList, 'name', 'value') : {};
  event.user_data = mergeObj(event.user_data, customUserDataObj);
  
  return event.user_data;
}

// CUSTOM DATA - handle custom data parameters and merge them into the event's custom data
function customDataMapping(event, data) {
  const customDataObj = data.customDataList && data.customDataList.length ? makeTableMap(data.customDataList, 'name', 'value') : {};
  event.custom_data = mergeObj(event.custom_data, customDataObj);
  
  return event.custom_data;
}

// FB DATA OBJECT - add additional Facebook data from the client GTM to the event
function addFBDataObject(event, fbData, dataType) {
    if (dataType === 'user_data' && fbData.user_data) { 
      event.user_data = mergeObj(event.user_data, fbData.user_data);
      return event.user_data;
    }
  
   if (dataType === 'custom_data') {
      event.custom_data = mergeObj(event.custom_data, fbData.custom_data);
      return event.custom_data;
   }
   
}

/*
- - - - - - - - - - - - - - - - - - - -
  MAIN LOGIC
- - - - - - - - - - - - - - - - - - - -
*/
// Initialize event object and populate it with event details
let event = {};
event.event_name = getFBEventName(eventData.event_name, data);
event.event_time = eventData.event_time || (Math.round(getTimestampMillis() / 1000));
event.event_id = eventData.event_id;
event.event_source_url = eventData.page_location;
event.action_source = eventData.action_source ? eventData.action_source : 'website';
event.referrer_url = eventData.page_referrer;
if (data.optEnabled && consent) { event.opt_out = consent[2] === '0'; }

// User data parameters
event.user_data = {};
if (user) { event.user_data = setUserData(event, user); }
if (data.extendCookies) { event.user_data = setFBCookies(event, data); }
event.user_data.client_ip_address = eventData.ip_override;
event.user_data.client_user_agent = eventData.user_agent;
if (data.cfoEnabled && fbDataObject.user_data) { event.user_data = addFBDataObject(event, fbDataObject, 'user_data'); }
if (data.udEnabled) { event.user_data = customUserDataMapping(event, data); }

// Custom data parameters
event.custom_data = {};
event.custom_data.value = eventData.value;
event.custom_data.currency = eventData.currency;
if (eventData.items) { event.custom_data = ga4ItemObjectMapping(event, data); }
event.custom_data.search_string = eventData.search_term;
if (data.cfoEnabled && fbDataObject.custom_data) { event.custom_data = addFBDataObject(event, fbDataObject, 'custom_data'); }
if (data.cdEnabled) { event.custom_data = customDataMapping(event, data); }

// Prepare the event request for sending to Facebook's Conversions API, including setting the test event code if applicable
const eventRequest = {data: [event], partner_agent: PARTNER_AGENT};
if (eventData.test_event_code || data.testEventCode) {
  eventRequest.test_event_code = eventData.test_event_code ? eventData.test_event_code : data.testEventCode;
}

// POST the event data to the Facebook Conversions API, handling the response and setting cookies if needed
const routeParams = 'events?access_token=' + data.apiAccessToken;
const graphEndpoint = [API_ENDPOINT,
                       API_VERSION,
                       data.pixelId,
                       routeParams].join('/');

const requestHeaders = {headers: {'content-type': 'application/json'}, method: 'POST'};
sendHttpRequest(
  graphEndpoint,
  (statusCode, headers, response) => {
    if (statusCode >= 200 && statusCode < 300) {
      if (data.extendCookies && event.user_data.fbc) {
        setFbCookieToBrowser('_fbc', event.user_data.fbc, consent);
      }

      if (data.extendCookies && event.user_data.fbp) {
        setFbCookieToBrowser('_fbp', event.user_data.fbp, consent);
      }
      
      if (data.bqEnabled) { bigQuery(data, statusCode, response); }
      data.gtmOnSuccess();
    } else {
      if (data.bqEnabled) { bigQuery(data, statusCode, response); }
      data.gtmOnFailure();
    }
  },
  requestHeaders,
  JSON.stringify(eventRequest)
);


/*
- - - - - - - - - - - - - - - - - - - -
  BIGQUERY MONITORING
- - - - - - - - - - - - - - - - - - - -
*/
function bigQuery(data, statusCode, response) {
  if (data.projectId && data.datasetId && data.tableId) {
    const bqEvent = {};
    bqEvent.event_time = event.event_time;
    bqEvent.channel_name = "facebook";
    bqEvent.pixel_id = data.pixelId;
    bqEvent.event_name = event.event_name;
    bqEvent.event_id = event.event_id;
    bqEvent.status_code = statusCode.toString();
    bqEvent.response = response;
    bqEvent.action_source = event.action_source;
    bqEvent.page_location = event.event_source_url;
    bqEvent.referrer = event.referrer_url;
    bqEvent.user_agent = event.user_data.client_user_agent;
    bqEvent.fbp = event.user_data.fbp;
    bqEvent.fbc = event.user_data.fbc;
    bqEvent.user_data = data.udToBQEnabled ? JSON.stringify(event.user_data) : null;
    bqEvent.custom_data = JSON.stringify(event.custom_data);
    bqEvent.consent = consent;

    const connectionInfo = {
      projectId: data.projectId,
      datasetId: data.datasetId,
      tableId: data.tableId,
    };
    
    BigQuery.insert(
      connectionInfo,
      [bqEvent], {}, () => {
        log('BigQuery Success');
      }, (errors) => {
        log('BigQuery Failure');
        log(JSON.stringify(errors));
      });
  }
}