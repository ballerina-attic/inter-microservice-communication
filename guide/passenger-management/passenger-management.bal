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
import ballerina/log;
import ballerina/jms;

type Person record {
    string name;
    string address;
    string phonenumber;
    string registerID;
    string email;
};

listener http:Listener httpListener = new(9091);

// Initialize a JMS connection with the provider
// 'Apache ActiveMQ' has been used as the message broker
jms:Connection conn = new({
        initialContextFactory: "org.apache.activemq.jndi.ActiveMQInitialContextFactory",
        providerUrl: "tcp://localhost:61616"
    });

// Initialize a JMS session on top of the created connection
jms:Session jmsSession = new(conn, {
        // Optional property. Defaults to AUTO_ACKNOWLEDGE
        acknowledgementMode: "AUTO_ACKNOWLEDGE"
    });

// Initialize a queue receiver using the created session
listener jms:QueueReceiver jmsConsumer = new(jmsSession, queueName = "trip-passenger-notify");

@http:ServiceConfig {
    basePath: "/passenger-management"
}
service PassengerManagement on httpListener {
    @http:ResourceConfig {
        path : "/claims",
        methods : ["POST"]
    }
    resource function claims(http:Caller caller, http:Request request) returns error? {
        // create an empty response object
        http:Response res = new;
        // check will cause the service to send back an error 
        // if the payload is not JSON
        json responseMessage;
        json passengerInfoJSON = check request.getJsonPayload();
        
        log:printInfo("JSON :::" + passengerInfoJSON.toString());
        
        string customerName = passengerInfoJSON.customerName.toString();
        string address = passengerInfoJSON.address.toString();
        string contact = passengerInfoJSON.phonenumber.toString();

        Person person = {
            name: customerName,
            address: address,
            phonenumber: contact,
            email: "dushan@wso2.com",
            registerID: "AB0001222"
        };

        log:printInfo("customerName:" + customerName);
        log:printInfo("address:" + address);
        log:printInfo("contact:" + contact);

        json personjson = check json.convert(person);
        responseMessage = personjson;
        log:printInfo("Passanger claims included in the response:" + personjson.toString());
        res.setJsonPayload(untaint personjson);
        checkpanic caller->respond(res);
        return;
    }
}


// JMS service that consumes messages from the JMS queue
// Bind the created consumer to the listener service
service PassengerNotificationService on jmsConsumer {
    // Triggered whenever an order is added to the 'OrderQueue'
    resource function onMessage(jms:QueueReceiverCaller consumer, jms:Message message) returns error? {
        log:printInfo("Trip information received passenger notification service notifying to the client");
        http:Request orderToDeliver = new;
        // Retrieve the string payload using native function
        string personDetail = check message.getTextMessageContent();
        log:printInfo("Trip Details:" + personDetail);
        return;
    }   
}
