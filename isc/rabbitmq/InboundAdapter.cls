Class isc.rabbitmq.InboundAdapter Extends (Ens.InboundAdapter, isc.rabbitmq.Common)
{

/// Stream class to store message body. Leave empty to use strings.
Property BodyClass As %Dictionary.CacheClassname;

Parameter SETTINGS = "BodyClass:Basic";

ClassMethod BodyClassIsValid(val) As %Status
{
	quit:val="" $$$OK
	quit:val="%Stream.GlobalCharacter" $$$OK
	quit $$$ERROR($$$GeneralError, "No")
}

/// Establish gateway connection and init java API.
Method OnInit() As %Status
{
	Set sc = ..Connect()
	Quit:$$$ISERR(sc) sc
	
	Set sc = ..ConnectToRabbitMQ()
	Quit sc
}

/// Close connection.
Method OnTearDown() As %Status
{
	Try {
		Do ..API.close()
	} Catch ex {}
		
	Quit $$$OK
}

/// Get Messages from RabbitMQ queue.
Method OnTask() As %Status
{
	Set sc = $$$OK
	
	// Check connection
	s sc = ..CheckConnectToRabbitMQ()
	q:$$$ISERR(sc) sc
	
	Set messageCount = 1
	
	While messageCount > 0 {
	  	Try {	
			#dim apiMessage as APIMessage = ..API.readMessage()
			s:..API.isLastError() sc=$$$ERROR($$$GeneralError, ..API.getLastErrorMessage())
			q:$$$ISERR(sc)
		
			s:'$IsObject(apiMessage) sc = $$$ERROR($$$GeneralError,"Error get [isc.rabbitmq.APIMessage]")
			q:$$$ISERR(sc)
	
	 	 	Set messageLength = apiMessage.getBodyLength()
			Set messageCount = apiMessage.getMessageCount()
		
			If messageLength>0 {
				Set message = ##class(isc.rabbitmq.Message).%New()
				Set sc = ..APIMessageToMessage(apiMessage, .message, ..Encoding, ..BodyClass)
				q:$$$ISERR(sc)
				
				$$$LOGINFO(apiMessage.toString())
							
				// Send to Service
				Set sc = ..BusinessHost.ProcessInput(message)
			} Else {
				CONTINUE
			}		
			
			Quit:$$$ISERR(sc)
		
		} Catch ex {
		  	Set sc = ..ExceptionToStatus(ex)
	    }
	    
		Quit:$$$ISERR(sc)
	}
	
	Set ..BusinessHost.%WaitForNextCallInterval=1
	Quit sc
}

}
