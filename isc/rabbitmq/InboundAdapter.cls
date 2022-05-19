Class isc.rabbitmq.InboundAdapter Extends (Ens.InboundAdapter, isc.rabbitmq.Common)
{

/// Stream class to store message body. Leave empty to use strings.
Property BodyClass As %Dictionary.CacheClassname;

/// Interval between fail connect and next reconnect
Property ReconnectInterval As %Numeric(MINVAL = 1) [ InitialExpression = 5 ];

Property origCallInterval As %Numeric [ Private ];

Parameter SETTINGS = "BodyClass:Basic,ReconnectInterval:Basic";

ClassMethod BodyClassIsValid(val) As %Status
{
  quit:val="" $$$OK
  quit:val="%Stream.GlobalCharacter" $$$OK
  quit $$$ERROR($$$GeneralError, "No")
}

/// Establish gateway connection and init java API.
Method OnInit() As %Status
{
  s ..origCallInterval = ..CallInterval
  d ..InitClasterHostList()
  
  Set sc = ..ConnectToRabbitMQ()
  Quit $$$OK
}

/// Close connection.
Method OnTearDown() As %Status
{
  // Disconnect API
  If $IsObject(..API) {
    Try {
      Do ..API.close()
    } Catch ex {}
  }
  
  // Disconnect JGW
  If $IsObject(..JGW) {
    Try {
      Do ..JGW.%Disconnect()
    } Catch ex {}
  }
    
  Quit $$$OK
}

/// Get Messages from RabbitMQ queue.
Method OnTask() As %Status
{
  Set sc = $$$OK
  
  // Check connection
  s sc = ..CheckConnectToRabbitMQ()
  
  // If Error set ReconnectInterval else return original CallInterval
  i $$$ISERR(sc) s ..CallInterval = ..ReconnectInterval 
  e  s ..CallInterval = ..origCallInterval
  
  Set messageCount = 1
  
  While $$$ISOK(sc) && (messageCount > 0) {
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
