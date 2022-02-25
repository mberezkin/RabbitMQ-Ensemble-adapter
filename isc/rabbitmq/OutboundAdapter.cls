Class isc.rabbitmq.OutboundAdapter Extends (Ens.OutboundAdapter, isc.rabbitmq.Common)
{

/// Establish gateway connection and init java API.
Method OnInit() As %Status
{
	Set sc = ..Connect()
	Quit:$$$ISERR(sc) sc
	
	Set sc = ..ConnectToRabbitMQ()
	Quit sc
}

/// Close connection
Method OnTearDown() As %Status
{
	Try {
		Do ..API.close()
	} Catch ex {}
		
	Quit $$$OK
}

/// Send message
Method SendMessage(message As isc.rabbitmq.Message) As %Status
{
	Set sc = $$$OK
	
	q:'$IsObject(message) $$$ERROR($$$GeneralError,"Not object [isc.rabbitmq.Message]")
				
	Try {
		// Check connection
		s sc = ..CheckConnectToRabbitMQ()
		q:$$$ISERR(sc)
		
		s apiMessage = ##class(isc.rabbitmq.APIMessage).%New(..JGW)
		s sc = ..MessageToAPIMessage(message, .apiMessage, ..Encoding)
		q:$$$ISERR(sc)
		
		$$$LOGINFO(apiMessage.toString())
		
		do ..API.sendMessage(apiMessage)
		s:..API.isLastError() sc=$$$ERROR($$$GeneralError, ..API.getLastErrorMessage())
		q:$$$ISERR(sc)
	} 
	Catch ex {
		Set sc = ..ExceptionToStatus(ex)
	}
	
	Quit sc
}

}
