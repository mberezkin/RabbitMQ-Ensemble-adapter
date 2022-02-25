Class isc.rabbitmq.Service Extends Ens.BusinessService
{

Parameter ADAPTER = "isc.rabbitmq.InboundAdapter";

Property Adapter As isc.rabbitmq.InboundAdapter;

Method OnProcessInput(message As isc.rabbitmq.Message) As %Status
{
	// quit message.%Save()
	s sc = message.%Save()
	
	// Test send input message to !!! ANOTHER QUEUE !!! by operation
	*/s mesResponse = message.%ConstructClone()
	s mesResponse.CorrelationId = message.MessageId
	s sc = mesResponse.%Save()
	
	set sc=..SendRequestAsync("ATB.RabbitMQ.Operation", mesResponse)/*
	return sc
}

/// Async dispatch 
Method OnResponse(request As %Library.Persistent, ByRef response As AWGW.AWAMessage, callrequest As %Library.Persistent, callresponse As %Library.Persistent, pCompletionKey As %String) As %Status
{
 q $$$OK
}

}
