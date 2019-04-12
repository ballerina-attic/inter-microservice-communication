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
import ballerina/io;
import ballerina/jms;
import ballerina/http;

type Trip record {
    string tripID;
    Driver driver;
    Person person;
    string time;
};

type Driver record {
    string driverID;
    string drivername;
};

type Person record {
    string name;
    string address;
    string phonenumber;
    string registerID;
    string email;
};

// Initialize a JMS connection with the provider
// 'Apache ActiveMQ' has been used as the message broker
jms:Connection conn = new({
        initialContextFactory: "org.apache.activemq.jndi.ActiveMQInitialContextFactory",
        providerUrl: "tcp://localhost:61616"
    });

// Client endpoint to communicate with Airline reservation service
http:Client courierEP = new("http://localhost:9095/courier");

// Initialize a JMS session on top of the created connection
jms:Session jmsSession = new(conn, {
        // Optional property. Defaults to AUTO_ACKNOWLEDGE
        acknowledgementMode: "AUTO_ACKNOWLEDGE"
    });

// Initialize a queue receiver using the created session
listener jms:QueueReceiver jmsConsumer = new (jmsSession, queueName = "trip-dispatcher");

// Initialize a queue sender using the created session
jms:QueueSender jmsPassengerMgtNotifer = new(jmsSession, queueName = "trip-passenger-notify");

// Initialize a queue sender using the created session
jms:QueueSender jmsDriverMgtNotifer = new(jmsSession, queueName = "trip-driver-notify");

// JMS service that consumes messages from the JMS queue
// Bind the created consumer to the listener service
service TripDispatcher on jmsConsumer {
    // Triggered whenever an order is added to the 'OrderQueue'
    resource function onMessage(jms:QueueReceiverCaller consumer, jms:Message message) returns error?{
        log:printInfo("New Trip request ready to process from JMS Queue");
        http:Request orderToDeliver = new;
        // Retrieve the string payload using native function
        string personDetail = check message.getTextMessageContent();
        log:printInfo("person Details: " + personDetail);
        json person = <json>personDetail;
        orderToDeliver.setJsonPayload(untaint person);
        string name = person.name.toString();
        
        Trip trip = {
            person: {
                name: "dushan",
                address: "1817",
                phonenumber: "0014089881345",
                email: "dushan@wso2.com",
                registerID: "AB0001222"
            },
            driver: {
                driverID: "driver001",
                drivername: "Adeel Sign"
            },
            tripID: "0001",
            time: "2018 Jan 6 10:10:20"
        };

        json tripjson = check json.convert(trip);

        log:printInfo("Driver Contacted Trip notification dispatching " + tripjson.toString());

        jms:Message queueMessage = check jmsSession.createTextMessage(tripjson.toString());
         
        fork {
            worker passengerNotification {
                checkpanic jmsPassengerMgtNotifer->send(queueMessage);
            }
            worker driverNotification {
                checkpanic jmsDriverMgtNotifer->send(queueMessage);
            }
        }
        _ = wait {passengerNotification, driverNotification};
        return;
    }
}
