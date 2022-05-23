Class isc.rabbitmq.OutboundAdapter Extends (Ens.OutboundAdapter, isc.rabbitmq.Common)
{

/// Establish gateway connection and init java API.
Method OnInit() As %Status
{
  d ..InitClasterHostList()
  
  Set ..lastStatus = ..ConnectToRabbitMQ()
  Quit $$$OK
}

/// Close connection
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

/// Send message
Method SendMessage(message As isc.rabbitmq.Message) As %Status
{
  Set sc = $$$OK
  
  q:'$IsObject(message) $$$ERROR($$$GeneralError,"Not object [isc.rabbitmq.Message]")
        
  Try {
    // if last try was fail then forced connect else check
    s sc=$s($$$ISERR(..lastStatus):..ConnectToRabbitMQ(),1:..CheckConnectToRabbitMQ())
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
  
  s ..lastStatus = sc
  Quit sc
}

}
