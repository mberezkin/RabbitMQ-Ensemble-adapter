# RabbitMQ-Ensemble-adapter
Ensemble adapter for RabbitMQ

## Installation

1. Install [java 1.8](http://www.oracle.com/technetwork/java/javase/downloads/jre8-downloads-2133155.html).

2. Get the JAR: build [RabbitMQ-Ensemble-javaapi](https://github.com/mberezkin/RabbitMQ-Ensemble-javaapi) or download [latest jar](https://github.com/mberezkin/RabbitMQ-Ensemble-javaapi/releases).

3. Create (or use any existing one) Java gateway for amqp-client. To create one go to SMP > System Administration > Configuration > Connectivity > Object Gateways. Remember the `Port` value.

4. Start Java Gateway. 

5. Import [RabbitMQ.xml](https://github.com/mberezkin/RabbitMQ-Ensemble-adapter/releases) and don't compile yet.

6. Compile one class isc.rabbitmq.Utils 

7. In a target namespace create temp Gateway for update jar (replace parameters with FULL paths) executing in terminal:
`Write $System.Status.GetErrorText(##class(isc.rabbitmq.Utils).CreateGateway())`

7. Import (update) isc.rabbitmq.API and isc.rabbitmq.APIMessage executing in terminal:
`Write $System.Status.GetErrorText(##class(isc.rabbitmq.Utils).UpdateJar())`

8. Compile all package *isc.rabbitmq*
   
9. For samples refer to the test production `isc.rabbitmq.Production`.

## Interoperability adapter

`isc.rabbitmq` package provides all traditional Interoperability components: Inbound and Outbound Adapters and Operation/Service.

For RabbitMQ to function Java Gateway is required. It can be run in three different ways:
- As Interoperability Service
- As Object Gateway from SMP
- From OS bash

For Interoperability production we recommend running Java Gateway as Interoperability Service. To do that add new `EnsLib.JavaGateway.Service` service to your production. In RabbitMQ production elements select Java Gateway Service name as a value for `JGService` setting.

ClassPath for all these elements must contain the paths to amqp jar and RabbitMQ-Ensemble-javaapi jar.

## Usage

Check `isc.rabbitmq.Utils` for sample code. The main class is `isc.rabbitmq.API`, class message is `isc.rabbitmq.APIMessage`.
It has the following methods:
* Connect
* GetAPI
* ReadMsg
* SendMsg
