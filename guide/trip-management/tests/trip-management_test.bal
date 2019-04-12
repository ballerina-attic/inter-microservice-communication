// Copyright (c) 2018 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/test;

@test:BeforeSuite
function beforeFunc() {
    // Start services before running the test
    //_ = test:startServices("trip-management");
    _ = test:startServices("dispatcher");
    _ = test:startServices("driver-management");
    _ = test:startServices("passenger-management");
}

// Client endpoint
http:Client clientEP = new("http://localhost:9090/trip-manager");

// Function to test 'pickup' resource
@test:Config
function testResourcePickup() returns error? {
    // Initialize the empty http request
    http:Request req = new;
    // Construct a request payload
    json payload = {"Name":"Dushan", "pickupaddr":"1817, Anchor Way, San Jose, US",
   "ContactNumber":"0014089881345"};
    req.setJsonPayload(payload);
    // Send a 'post' request and obtain the response
    http:Response response = check clientEP->post("/pickup", req);
    // Expected response code is 200
    test:assertEquals(response.statusCode, 200, msg = "pickup service did not respond with 200 OK signal!");
    // Check whether the response is as expected
    json resPayload = check response.getJsonPayload();
    json expected = {"Message":"Trip information received"};
    test:assertEquals(resPayload, expected, msg = "Response mismatch!");
}

@test:AfterSuite
function afterFunc() {
    // shutdown services
    //_ = test:stopServices("trip-management");
    _ = test:stopServices("dispatcher");
    _ = test:stopServices("driver-management");
    _ = test:stopServices("passenger-management");
}
