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

// Type definition for a book order
type pickup {
    string customerName;
    string address;
    string phonenumber;
};

// Global variable containing all the available books
//json[] bookInventory = ["Tom Jones", "The Rainbow", "Lolita", "Atonement", "Hamlet"];

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
endpoint jms:QueueSender jmsTripDispatchOrder {
    session:jmsSession,
    queueName:"trip-dispatcher"
};

// Client endpoint to communicate with Airline reservation service
endpoint http:Client passengerMgtEP {
    url:"http://localhost:9091/passenger-management"
};


//@doker:Config {
//    registry:"ballerina.guides.io",
//    name:"bookstore_service",
 //   tag:"v1.0"
//}

//@docker:CopyFiles {
//    files:[{source:"/Users/dushan/workspace/wso2/ballerina/bbg/apache-activemq-5.13.0/lib/geronimo-j2ee-management_1.1_spec-1.0.1.jar",
 //           target:"/ballerina/runtime/bre/lib"},{source:"/Users/dushan/workspace/wso2/ballerina/bbg/apache-activemq-5.13.0/lib/activemq-client-5.13.0.jar",
 //           target:"/ballerina/runtime/bre/lib"}]
//}

//@docker:Expose{}
//endpoint http:Listener listener {
//    port:9090
//};

// Service endpoint
endpoint http:Listener listener {
    port:9090
};


// Book store service, which allows users to order books online for delivery
@http:ServiceConfig {basePath:"/trip-manager"}
service<http:Service> TripManagement bind listener {
    // Resource that allows users to place an order for a book
    @http:ResourceConfig { methods: ["POST"], consumes: ["application/json"],
        produces: ["application/json"], path : "/pickup" }
    pickup(endpoint caller, http:Request request) {
        http:Response response;
        pickup pickup;
        json reqPayload;

        // Try parsing the JSON payload from the request
        match request.getJsonPayload() {
            // Valid JSON payload
            json payload => reqPayload = payload;
            // NOT a valid JSON payload
            any => {
                response.statusCode = 400;
                response.setJsonPayload({"Message":"Invalid payload - Not a valid JSON payload"});
                _ = caller -> respond(response);
                done;
            }
        }

        json name = reqPayload.Name;
        json address = reqPayload.pickupaddr;
        json contact = reqPayload.ContactNumber;


        // If payload parsing fails, send a "Bad Request" message as the response
        if (name == null || address == null || contact == null) {
            response.statusCode = 400;
            response.setJsonPayload({"Message":"Bad Request - Invalid Trip Request payload"});
            _ = caller -> respond(response);
            done;
        }

        // Order details
        pickup.customerName = name.toString();
        pickup.address = address.toString();
        pickup.phonenumber = contact.toString();
    
        log:printInfo("Calling passenger management service:");
      
        // call passanger-management and get passagner orginization claims
        json responseMessage;
        http:Request passangermanagerReq;
        json pickupjson = check <json>pickup;
        passangermanagerReq.setJsonPayload(pickupjson);
        http:Response passangerResponse= check passengerMgtEP -> post("/claims", request = passangermanagerReq);
        json passangerResponseJSON = check passangerResponse.getJsonPayload();

        // Dispatch to the dispatcher service
        // Create a JMS message
        jms:Message queueMessage = check jmsSession.createTextMessage(passangerResponseJSON.toString());
            // Send the message to the JMS queue
        
        log:printInfo("Hand over to the trip dispatcher to coordinate driver and  passenger:");
        _ = jmsTripDispatchOrder -> send(queueMessage);

        //TODO get passager claims
        // CREATE TRIP
        // CALL DISPATCHER FOR CONTACT DRIVER and PASSANGER
        log:printInfo("passanger-magement response:"+passangerResponseJSON.toString());
        // Send response to the user
        responseMessage = {"Message":"Trip information received"};
        response.setJsonPayload(responseMessage);
        _ = caller -> respond(response);
    }

}
