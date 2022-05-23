Include Ensemble

Class isc.rabbitmq.Common Extends %RegisteredObject [ Abstract ]
{

/// Status last try  
Property lastStatus As %Status [ InitialExpression = {$$$OK}, Private ];

/// Either host or Connection URI: amqp:\\
/// If Connection URI is passed, then Port, Credentials and Virtual host properties are ignored.
Property Host As %VarString [ InitialExpression = "localhost" ];

Property Port As %Integer [ InitialExpression = -1 ];

/// List nodes of claster (node1:port,node2,..,nodeN:port)
/// if port not defined uses value of property Port
Property ClusterHostList As %String(MAXLEN = 1000);

Property ClusterHosts As list Of %String [ Private ];

Property ClusterPorts As list Of %Integer [ Private ];

Property VirtualHost As %String [ InitialExpression = "/" ];

/// Outbound adapter only (ignored for inbound adapter)
/// If Exchange is not set, then Queue name.
/// If Exchange is set, then Routing Key.
Property Queue As %String;

/// Exchange name.
/// Optional, empty by default.
/// If set, Queue becomes Routing Key.
Property Exchange As %String;

/// Config Name of the Java Gateway service controlling the Java Gateway server this item will use.
/// Alternatively use JGHost and JGPort Settings, to specify Java gateway outside of Ensemble scope.
Property JGService As %String;

/// Hostname of the Java Gateway server this item will use.
/// Alternatively use JGService Setting, to specify Java gateway inside Ensemble.
Property JGHost As %String;

/// Port of the Java Gateway server this item will use.
/// Alternatively use JGService Setting, to specify Java gateway inside Ensemble.
Property JGPort As %Integer;

/// Gateway connection
Property JGW As %Net.Remote.Gateway;

/// API object
Property API As isc.rabbitmq.API;

/// Encoding to convert message body. Leave empty to get/send as is.
Property Encoding As %String;

/// CLASSPATH containing the files required to be passed as an argument when starting the JVM.
/// The user should typically provide here the files containing the classes used via the Java Gateway. 
/// We assume that the user has properly quoted the classpath and supplied the correct separators for the platform
/// in case of multiple files. <br>
/// See property AdditionalPaths in that class.
Property ClassPath As %String(MAXLEN = 32000);

/// These are the production settings for this object
Parameter SETTINGS = "Host:Basic,Port:Basic,ClusterHostList:Basic,VirtualHost:Basic,Queue:Basic,Exchange:Basic,Credentials:Basic:credentialsSelector,JGHost:Java Gateway,JGPort:Java Gateway,JGService:Java Gateway:selector?context={Ens.ContextSearch/ProductionItems?targets=0&productionName=@productionId},ClassPath:Basic,Encoding:Basic";

Method InitClasterHostList() As %Status [ Private ]
{
  d ..ClusterHosts.Clear()
  d ..ClusterPorts.Clear()
  
  if ..ClusterHostList="" {
    d ..ClusterHosts.Insert(..Host)
    d ..ClusterPorts.Insert(..Port)
    
    q $$$OK
  }
  
  s lstNodes = $lfs(..ClusterHostList)
  s (host,port)=""
  
  f i=1:1:$ll(lstNodes) {
    s host = $lg(lstNodes,i)
    i $l(host,":")>1 s host=$p(host,":"),port=$p(host,":",2)
    e  s port=..Port
   
    d ..ClusterHosts.Insert(host)
    d ..ClusterPorts.Insert(port)
  }
  
  q $$$OK
}

/// Connect to running JGW 
Method Connect() As %Status
{
    Quit:((..JGService="") && ((..JGHost="") || (..JGPort = ""))) $$$ERROR($$$GeneralError,"Specify JGService setting or JGHost and JGPort settings")
    Quit:((..JGService'="") && '##class(Ens.Director).IsItemEnabled(..JGService)) $$$ERROR($$$GeneralError, $$$FormatText("Java Gateway Service: '%1' is down",..JGService))
    
    // Disconnect JGW
    If $IsObject(..JGW) {
      Try {
        Do ..JGW.%Disconnect()
      } Catch ex {}
      
      Set ..JGW = $$$NULLOREF
    }
      
    // connect to current namespace, use 2 second timeout
    Set sc = $$$OK
    Set timeout = 5
    Set classPath = ##class(%ListOfDataTypes).%New()
    Do classPath.Insert(..ClassPath)

    // get a connection handle and connect
    Set gateway = ##class(%Net.Remote.Gateway).%New()
    If ..JGService'="" {
      Set host = ##class(Ens.Director).GetHostSettingValue(..JGService, "Address")
      Set port = ##class(Ens.Director).GetHostSettingValue(..JGService, "Port")
    } Else {
      Set host = ..JGHost
      Set port = ..JGPort
    }
    
    $$$LOGINFO($$$FormatText("Connect to JavaGateway: %1:%2", host, port))
    Set sc = gateway.%Connect(host, port, $namespace, timeout, classPath)

    If $$$ISOK(sc) {
      Set ..JGW = gateway
      $$$LOGINFO("Connect to JavaGateway: OK")
    }
    else {
      $$$LOGWARNING($system.Status.GetErrorText(sc))
    }
    
    Quit sc
}

Method ConnectToRabbitMQ() As %Status
{
  Set sc = $$$OK
  
  If ..%CredentialsObj.Username'="" {
    Set user = ..%CredentialsObj.Username
    Set pass = ..%CredentialsObj.Password
  } Else {
    Set user = "guest"
    Set pass = "guest"
  }
  
  for i=1:1:..ClusterHosts.Count() { 
    s ..Host=..ClusterHosts.GetAt(i)
    s ..Port=..ClusterPorts.GetAt(i)
    
    Try {
      If $IsObject(..API) {
        Try {
          Do ..API.close()
        } Catch ex {}
      
        Set ..API = $$$NULLOREF
      }
      
      // Connect to running JGW
      Set sc = ..Connect()  continue:$$$ISERR(sc)
    
      $$$LOGINFO($$$FormatText("Connect to RabbitMQ: %1:%2, VirtualHost: %3, Queue: %4, Exchange: %5...", ..Host, ..Port, ..VirtualHost, ..Queue, ..Exchange))
        
      if ..Exchange]"" { Set ..API = ##class(isc.rabbitmq.API).%New(..JGW, ..Host, ..Port, user, pass, ..VirtualHost, ..Queue, ..Exchange) }
      else { Set ..API = ##class(isc.rabbitmq.API).%New(..JGW, ..Host, ..Port, user, pass, ..VirtualHost, ..Queue) }
    
      s:'$IsObject(..API) sc = $$$ERROR($$$GeneralError,"API.ConnectToRabbitMQ")
      s:($IsObject(..API)&&..API.isLastError()) sc = $$$ERROR($$$GeneralError, ..API.getLastErrorMessage())

    } Catch ex {
      Set sc = ..ExceptionToStatus(ex)
    }
    
    i $$$ISOK(sc) $$$LOGINFO("Connect to RabbitMQ: OK")
    e  $$$LOGWARNING($system.Status.GetErrorText(sc))
        
    q:$$$ISOK(sc)
  } // for
  
  Quit sc
}

/// Check connect and reconnect, if connection lost 
Method CheckConnectToRabbitMQ() As %Status
{
  Set sc = $$$OK
  
  Try {
    
    // Check open connection
    Try {
      s bIsOpen = ..API.isOpen()
      s:(..API.isLastError()||(bIsOpen'=1)) sc = $$$NOTOK
    } Catch ex {
      Set sc = ..ExceptionToStatus(ex)
    }
    q:$$$ISOK(sc)
      
    $$$LOGWARNING("Reconnect to RabbitMQ...")
    Set sc = ..ConnectToRabbitMQ()  q:$$$ISERR(sc)
    $$$LOGINFO("Connection to RabbitMQ restored")
  } Catch ex {
    Set sc = ..ExceptionToStatus(ex)
  }
  
  return sc
}

Method ExceptionToStatus(ex As %Exception.General) As %Status
{
  #Dim sc As %Status
  If ((ex.Name="<ZJGTW>") && $d(%objlasterror)) {
    Set sc = %objlasterror
  } Else {
    Set sc = ex.AsStatus()
  }
    Quit sc
}

/// Convert isc.rabbitmq.APIMessage (java) into isc.rabbitmq.Message (Ensemble)
/// set sc = ##class(isc.rabbitmq.Common).APIMessageToMessage(apiMessage, .message) 
ClassMethod APIMessageToMessage(apiMessage As isc.rabbitmq.APIMessage, ByRef message As isc.rabbitmq.Message, encoding As %String = "", bodyClass As %String = "") As %Status
{
  s sc = $$$OK
  
  q:'$IsObject(message) $$$ERROR($$$GeneralError,"Not is object [isc.rabbitmq.Message]")
    
  // BasicProperties
  Set message.ContentType = apiMessage.getContentType()
  Set message.ContentEncoding = apiMessage.getContentEncoding()
  Set message.CorrelationId = apiMessage.getCorrelationId()
  Set message.ReplyTo = apiMessage.getReplyTo()
  Set message.Expiration = apiMessage.getExpiration()
  Set message.MessageId = apiMessage.getMessageId()
  Set message.Type = apiMessage.getType()
  Set message.UserId = apiMessage.getUserId()
  Set message.AppId = apiMessage.getAppId()
  Set message.ClusterId = apiMessage.getClusterId()
  Set message.DeliveryMode = apiMessage.getDeliveryMode()
  Set message.Priority = apiMessage.getPriority()
  Set message.Timestamp = apiMessage.getTimestamp()
  
  // Headers
  s mapHeaders = apiMessage.getHeadersAsMap()
  //$$$TRACE(mapHeaders)
  #dim mapHeaders as java.util.Map
  
  #dim it as java.util.Iterator = mapHeaders.keySet().iterator()
  While (it.hasNext()) {
      Set key = it.next()
      Set value = mapHeaders.get(key)
      //$$$TRACE("key: "_key_", value: "_value)
    
    do message.Headers.SetAt(value, key)
   }
  
  // Body
  If bodyClass = "" {
    Set message.BodyString = ..DecodeMessageBody(apiMessage.getBodyString(), encoding)
  } 
  Else {
    #Dim tempStream As %Library.GlobalBinaryStream
    Set tempStream = apiMessage.getBodyStream()
          
    Set message.BodyStream = $classmethod(bodyClass, "%New")
    While 'tempStream.AtEnd {
      Do message.BodyStream.Write(..DecodeMessageBody(tempStream.Read($$$MaxStringLength), encoding))
    }
    
    Do message.BodyStream.Rewind()
  }
      
  Quit message
}

/// Convert isc.rabbitmq.Message (Ensemble) into isc.rabbitmq.APIMessage (java)
/// set sc = ##class(isc.rabbitmq.Common).MessageToAPIMessage(message, .apiMessage) 
ClassMethod MessageToAPIMessage(message As isc.rabbitmq.Message, ByRef apiMessage As isc.rabbitmq.APIMessage, encoding As %String = "UTF8") As %Status
{
  s sc = $$$OK
  
  q:'$IsObject(apiMessage) $$$ERROR($$$GeneralError,"Not is object [isc.rabbitmq.APIMessage]")
    
  // BasicProperties
  d apiMessage.setContentType(message.ContentType)
  d apiMessage.setContentEncoding(message.ContentEncoding)
  d apiMessage.setCorrelationId(message.CorrelationId)
  d apiMessage.setReplyTo(message.ReplyTo)
  d apiMessage.setExpiration(message.Expiration)
  d apiMessage.setMessageId(message.MessageId)
  d apiMessage.setType(message.Type)
  d apiMessage.setUserId(message.UserId)
  d apiMessage.setAppId(message.AppId)
  d apiMessage.setClusterId(message.ClusterId)
  d apiMessage.setDeliveryMode(message.DeliveryMode)
  d apiMessage.setPriority(message.Priority)
  d apiMessage.setTimestamp(message.Timestamp)
  
  // Headers
  #dim arHeaders as %ArrayOfDataTypes = message.Headers
  if arHeaders '= "" { 
    set key = ""
    for {
        set value = arHeaders.GetNext(.key)  quit:key=""
        do apiMessage.setHeader(key, value)
    }
  }
  
  // Body
  s bIsStream = $select($length(message.BodyString)>0:0,1:1)
  Set stream = ##class(%Library.GlobalBinaryStream).%New()
  
  If (bIsStream && $IsObject(message.BodyStream)) {
    If message.BodyStream.%IsA("%Library.GlobalBinaryStream")  {
      Set stream = message.BodyStream
    } 
    Else {
      While 'message.BodyStream.AtEnd {
        Do stream.Write(..EncodeMessageBody(message.BodyStream.Read($$$MaxStringLength), encoding))
      }
    }
  } 
  Else {
    Do stream.Write(..EncodeMessageBody(message.BodyString, encoding))
  }
    
    Do stream.Rewind()
    d apiMessage.setBodyStream(stream)
    
  Quit $$$OK
}

ClassMethod EncodeMessageBody(body As %String, encoding As %String = "") As %String
{
  If encoding '= "" {
    If $isObject(body) {
      // TODO streams
    } Else {
      Set body = $zcvt(body, "O", encoding)   
    }
  }
  Quit body
}

/// Decode message body. May be full body or only a piece. 
ClassMethod DecodeMessageBody(body As %String, encoding As %String) As %String
{
  Set:encoding'="" body = $zcvt(body, "I", encoding)
  Quit body
}

}
