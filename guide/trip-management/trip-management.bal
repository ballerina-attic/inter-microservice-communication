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

import ballerina/log;
import ballerina/http;
import ballerina/jms;
import ballerinax/docker;

// Type definition for a Pickup order
type Pickup record {
    string customerName;
    string address;
    string phonenumber;
};

// Initialize a JMS connection with the provider
// 'providerUrl' and 'initialContextFactory' vary based on the JMS provider you use
// 'Apache ActiveMQ' has been used as the message broker in this example
jms:Connection jmsConnection = new({
        initialContextFactory: "org.apache.activemq.jndi.ActiveMQInitialContextFactory",
        providerUrl: "tcp://localhost:61616"
    });

// Initialize a JMS session on top of the created connection
jms:Session jmsSession = new(jmsConnection, {
        acknowledgementMode: "AUTO_ACKNOWLEDGE"
    });

// Initialize a queue sender using the created session
jms:QueueSender jmsTripDispatchOrder = new(jmsSession, queueName = "trip-dispatcher");

// Client endpoint to communicate with Airline reservation service
http:Client passengerMgtEP = new("http://localhost:9091/passenger-management");


//@doker:Config {
//    registry:"ballerina.guides.io",
//    name:"trip_management_service",
 //   tag:"v1.0"
//}

//@docker:CopyFiles {
//    files:[{source:"/Users/dushan/workspace/wso2/ballerina/bbg/apache-activemq-5.13.0/lib/geronimo-j2ee-management_1.1_spec-1.0.1.jar",
 //           target:"/ballerina/runtime/bre/lib"},{source:"/Users/dushan/workspace/wso2/ballerina/bbg/apache-activemq-5.13.0/lib/activemq-client-5.13.0.jar",
 //           target:"/ballerina/runtime/bre/lib"}]
//}

//@docker:Expose{}
//listener http:Listener httpListener = new(9090);

// Service endpoint
listener http:Listener httpListener = new(9090);

// Trip manager service, which is managing trip requests received from the client 
@http:ServiceConfig {
    basePath:"/trip-manager"
}
service TripManagement on httpListener {
    // Resource that allows users to place an order for a pickup
    @http:ResourceConfig {
        path : "/pickup",
        methods: ["POST"],
        consumes: ["application/json"],
        produces: ["application/json"]
    }
    resource function pickup(http:Caller caller, http:Request request) returns error? {
        http:Response response = new;
        json reqPayload;

        // Try parsing the JSON payload from the request
        var payload = request.getJsonPayload();
        if (payload is json) {
            reqPayload = payload;
        } else {
            response.statusCode = 400;
            response.setJsonPayload({"Message":"Invalid payload - Not a valid JSON payload"});
            checkpanic caller->respond(response);
            return;
        }

        json name = reqPayload.Name;
        json address = reqPayload.pickupaddr;
        json contact = reqPayload.ContactNumber;


        // If payload parsing fails, send a "Bad Request" message as the response
        if (name == null || address == null || contact == null) {
            response.statusCode = 400;
            response.setJsonPayload({"Message":"Bad Request - Invalid Trip Request payload"});
            checkpanic caller->respond(response);
            return;
        }

        // Order details
        Pickup pickup = {
            customerName: name.toString(),
            address: address.toString(),
            phonenumber: contact.toString()
        };

        log:printInfo("Calling passenger management service:");
      
        // call passanger-management and get passegner orginization claims
        json responseMessage;
        http:Request passengerManagerReq = new;
        json pickupjson = check json.convert(pickup);
        passengerManagerReq.setJsonPayload(untaint pickupjson);
        http:Response passengerResponse=  check passengerMgtEP->post("/claims", passengerManagerReq);
        json passengerResponseJSON = check passengerResponse.getJsonPayload();

        // Dispatch to the dispatcher service
        // Create a JMS message
        jms:Message queueMessage = check jmsSession.createTextMessage(passengerResponseJSON.toString());
        // Send the message to the JMS queue
        
        log:printInfo("Hand over to the trip dispatcher to coordinate driver and  passenger:");
        checkpanic jmsTripDispatchOrder->send(queueMessage);

        // Creating Trip
        // call Dispatcher and contacting Driver and Passenger
        log:printInfo("passanger-magement response:"+passengerResponseJSON.toString());
        // Send response to the user
        responseMessage = {"Message":"Trip information received"};
        response.setJsonPayload(responseMessage);
        checkpanic caller->respond(response);
        return;
    }
}
