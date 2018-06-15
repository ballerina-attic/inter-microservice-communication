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

type Person {
    string name;
    string address;
    string phonenumber;
    string registerID;
    string email;
};

endpoint http:Listener listener {
    port:9091
};

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
endpoint jms:QueueReceiver jmsConsumer {
    session:jmsSession,
    queueName:"trip-passanger-notify"
};


@http:ServiceConfig { basePath: "/passenger-management" }
service<http:Service> PassengerManagement bind listener {
    @http:ResourceConfig {
        path : "/claims",
        methods : ["POST"]
    }
    claims (endpoint caller, http:Request request) {
        Person person;
        // create an empty response object 
        http:Response res = new;
        // check will cause the service to send back an error 
        // if the payload is not JSON
        json responseMessage;
        json passangerInfoJSON = check request.getJsonPayload();
        
        log:printInfo("JSON :::" + passangerInfoJSON.toString());
        
        string customerName = passangerInfoJSON.customerName.toString();
        string address = passangerInfoJSON.address.toString();
        string contact = passangerInfoJSON.phonenumber.toString();

        person.name = customerName;
        person.address=address;
        person.phonenumber=contact;
        person.email="dushan@wso2.com";
        person.registerID="AB0001222";
        
        log:printInfo("customerName:" + customerName);
        log:printInfo("address:" + address);
        log:printInfo("contact:" + contact);

        //TODO prepare client response
        json personjson = check <json>person;
        responseMessage = personjson;
        log:printInfo("Passanger claims included in the response:" + personjson.toString());
        res.setJsonPayload(personjson);
        _ = caller -> respond (res);
    }
}


// JMS service that consumes messages from the JMS queue
// Bind the created consumer to the listener service
service<jms:Consumer> PassengerNotificationService bind jmsConsumer {
    // Triggered whenever an order is added to the 'OrderQueue'
    onMessage(endpoint consumer, jms:Message message) {
        log:printInfo("Trip information received passenger notification service notifying to the client");
        http:Request orderToDeliver;
        // Retrieve the string payload using native function
        string personDetail = check message.getTextMessageContent();
        log:printInfo("Trip Details:" + personDetail);
       
    }
    
}




