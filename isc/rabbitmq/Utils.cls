/// Various test methods
Class isc.rabbitmq.Utils
{

Parameter CLASS = "isc.rabbitmq.API,isc.rabbitmq.APIMessage";

Parameter CLASSPATH = "/usr/ensemblesys/mgr/java/rabbitmq/RabbitMQjava.jar,/usr/ensemblesys/mgr/java/rabbitmq/amqp-client-5.7.2.jar";

Parameter BUILDCLASSPATH = "/usr/ensemblesys/mgr/java/rabbitmq/RabbitMQjava.jar";

Parameter GATEWAY = "RabbitMQjava";

Parameter GATEWAYCLIENT = "RabbitMQclient";

Parameter QUEUE = "OutTest";

Parameter EXCHANGE;

Parameter JAVAHOME = "/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.322.b06-1.el7_9.x86_64";

// $SYSTEM.Util.GetEnviron("JAVA_HOME")

/// Create JGW. Java home must point to 1.8 jre.
/// Write $System.Status.GetErrorText(##class(isc.rabbitmq.Utils).CreateGateway())
ClassMethod CreateGateway(gatewayName = {..#GATEWAY}, javaHome = {..#JAVAHOME}, path As %String = {..#CLASSPATH}, port As %Integer = 55555)
{
  set sys = ##class(%Net.Remote.ObjectGateway).%New()
  set sys.Name = gatewayName
  set sys.Type = 1
  set sys.JavaHome = javaHome
  set sys.ClassPath = path
  set sys.Port = port
  quit sys.%Save()
}

/// Load Jar from path.
/// Write $System.Status.GetErrorText(##class(isc.rabbitmq.Utils).UpdateJar())
ClassMethod UpdateJar(gatewayName = {..#GATEWAY}, path As %String = {..#CLASSPATH})
{
  #Dim sc As %Status = $$$OK
  //Set sc = ##class(Ens.Director).StopProduction(, 1)
  Quit:$$$ISERR(sc) sc
  
  Set sc = ##class(%Net.Remote.Service).StartGateway(gatewayName)
  Quit:$$$ISERR(sc) sc

  Set gateway = ..Connect(gatewayName, path, .sc)
  Quit:$$$ISERR(sc) sc

  s listClass = $lfs(..#CLASS), cls = ""
  for i=1:1:$ll(listClass) {
    s cls = $lg(listClass, i)
    w "Import ["_cls_"]",!
      
    Set sc = gateway.%Import(cls)
    return:$$$ISERR(sc) sc
    Set:'##class(%Dictionary.CompiledClass).%ExistsId(cls) sc = $$$ERROR($$$GeneralError, $$$FormatText("Class '%1' does not exist",cls))
    return:$$$ISERR(sc) sc
  }
    
  Set sc = ##class(%Net.Remote.Service).StopGateway(gatewayName)
  
  //Set sc = ##class(Ens.Director).StartProduction()
  Quit sc
}

/// Get JGW object
ClassMethod Connect(gatewayName As %String = {..#GATEWAYCLIENT}, path As %String = {..#CLASSPATH}, Output sc As %Status) As %Net.Remote.Gateway
{
  Set gateway = ""
  Set sc = ##class(%Net.Remote.Service).OpenGateway(gatewayName, .gatewayConfig)
  Quit:$$$ISERR(sc) gateway
  Set sc = ##class(%Net.Remote.Service).ConnectGateway(gatewayConfig, .gateway, path, $$$YES)
  Quit gateway
}

/// Construct RabbitMQ API object.As isc.rabbitmq.API
ClassMethod GetAPI(gateway As %Net.Remote.Gateway)
{
  Set host = "localhost"
  Set port = 5672
  Set user = "guest"
  Set pass = "guest"
  Set virtualHost = "/"
  Set queue = ..#QUEUE
  Set exchange = ..#EXCHANGE
  
  if exchange]"" { 
    Set api = ##class(isc.rabbitmq.API).%New(gateway,  host, port, user, pass, virtualHost, queue, exchange)
  }
  else { 
    Set api = ##class(isc.rabbitmq.API).%New(gateway,  host, port, user, pass, virtualHost, queue)
  }
    
  Quit api
}

/// Read one message.
/// Write $System.Status.GetErrorText(##class(isc.rabbitmq.Utils).ReadMsg())
ClassMethod ReadMsg() As %Status
{
    #Dim gateway as %Net.Remote.Gateway

    Set sc = $$$OK
    Try {
      // Connect
        Set gateway = ..Connect()
        #Dim api As isc.rabbitmq.API = ..GetAPI(gateway)
        if api.isLastError() $$$ThrowStatus($$$ERROR($$$GeneralError, api.getLastErrorMessage()))
        
        // Read message
        #dim apiMessage as APIMessage = api.readMessage()
        if api.isLastError() $$$ThrowStatus($$$ERROR($$$GeneralError, api.getLastErrorMessage()))

        // Print RabbitMQ message
        w apiMessage.toString(),!
    
        // Convert isc.rabbitmq.APIMessage (java) into isc.rabbitmq.Message (Ensemble)
        Set message = ##class(isc.rabbitmq.Message).%New()
        $$$ThrowOnError(##class(isc.rabbitmq.Common).APIMessageToMessage(apiMessage, .message))
    
        w "message.MessageId: ",message.MessageId,!
        w "message.BodyString: ",message.BodyString,!
    
        // Save isc.rabbitmq.Message
        $$$ThrowOnError(message.%Save())
    
        // Disconnect
        do api.close()
            Set sc= gateway.%Disconnect()
    } Catch ex {
        Set sc = $$$ADDSC(ex.AsStatus(), $g(%objlasterror))
    }

    Quit sc
}

/// Send one message.
/// Write $System.Status.GetErrorText(##class(isc.rabbitmq.Utils).SendMsg())
ClassMethod SendMsg(msg = "356") As %Status
{
    #dim gateway as %Net.Remote.Gateway

    Set sc = $$$OK
    Try {
        // Connect
        Set gateway = ..Connect()
        #Dim api As isc.rabbitmq.API = ..GetAPI(gateway)
        if api.isLastError() $$$ThrowStatus($$$ERROR($$$GeneralError, api.getLastErrorMessage()))

        // Create isc.rabbitmq.Message
        Set message = ##class(isc.rabbitmq.Message).%New()
    
        // Set BasicProperties
        set message.MessageId = $zdt($h)
        set message.ContentType = "text/xml"
        set message.DeliveryMode = 1
        set message.Timestamp = $zdt($h,3,1) // "YYYY-MM-DD hh:mm:ss"
    
        // Set Headers (array of %String)
        do message.Headers.SetAt("MySystem", "system")
        do message.Headers.SetAt("test.server", "node-request")
        do message.Headers.SetAt("getClient", "service-name")
    
        // Set Body
        set message.BodyString = "<body>Test message</body>"
    
        // Save isc.rabbitmq.Message
        $$$ThrowOnError(message.%Save())
        
        // Convert isc.rabbitmq.Message (Ensemble) into isc.rabbitmq.APIMessage (java)
        s apiMessage = ##class(isc.rabbitmq.APIMessage).%New(gateway)
        $$$ThrowOnError(##class(isc.rabbitmq.Common).MessageToAPIMessage(message, .apiMessage))
        
        // Send message
        do api.sendMessage(apiMessage)
        if api.isLastError() $$$ThrowStatus($$$ERROR($$$GeneralError, api.getLastErrorMessage()))
        
        // Disconnect
        do api.close()
            Set sc = gateway.%Disconnect()
    } Catch ex {
        Set sc = $$$ADDSC(ex.AsStatus(), $g(%objlasterror))
    }

     Quit sc
}

}
