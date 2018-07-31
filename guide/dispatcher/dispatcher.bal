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
endpoint http:Client courierEP {
    url:"http://localhost:9095/courier"
};

// Initialize a JMS session on top of the created connection
jms:Session jmsSession = new(conn, {
        // Optional property. Defaults to AUTO_ACKNOWLEDGE
        acknowledgementMode: "AUTO_ACKNOWLEDGE"
    });

// Initialize a queue receiver using the created session
endpoint jms:QueueReceiver jmsConsumer {
    session:jmsSession,
    queueName:"trip-dispatcher"
};



// Initialize a queue sender using the created session
endpoint jms:QueueSender jmsPassengerMgtNotifer {
    session:jmsSession,
    queueName:"trip-passenger-notify"
};

// Initialize a queue sender using the created session
endpoint jms:QueueSender jmsDriverMgtNotifer {
    session:jmsSession,
    queueName:"trip-driver-notify"
};

// JMS service that consumes messages from the JMS queue
// Bind the created consumer to the listener service
service<jms:Consumer> TripDispatcher bind jmsConsumer {
    // Triggered whenever an order is added to the 'OrderQueue'
    onMessage(endpoint consumer, jms:Message message) {
        log:printInfo("New Trip request ready to process from JMS Queue");
        http:Request orderToDeliver;
        // Retrieve the string payload using native function
        string personDetail = check message.getTextMessageContent();
        log:printInfo("person Details: " + personDetail);
        json person = <json>personDetail;
        orderToDeliver.setJsonPayload(untaint person);
        string name = person.name.toString();
        
        Trip trip;
        trip.person.name = "dushan";
        trip.person.address="1817";
        trip.person.phonenumber="0014089881345";
        trip. person.email="dushan@wso2.com";
        trip.person.registerID="AB0001222";
        trip.driver.driverID="driver001";
        trip.driver.drivername="Adeel Sign";
        trip.tripID="0001";
        trip.time="2018 Jan 6 10:10:20";

        json tripjson = check <json>trip;

        log:printInfo("Driver Contacted Trip notification dispatching " + tripjson.toString());

        jms:Message queueMessage = check jmsSession.createTextMessage(tripjson.toString());
         
        fork {
            worker passengerNotification {
                _ = jmsPassengerMgtNotifer -> send(queueMessage);
            }
            worker driverNotification {
               _ = jmsDriverMgtNotifer -> send(queueMessage);
            }

        } join (all) (map collector) {
    }

    }
    
}

