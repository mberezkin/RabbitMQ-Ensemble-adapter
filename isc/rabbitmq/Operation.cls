Class isc.rabbitmq.Operation Extends Ens.BusinessOperation
{

Parameter ADAPTER = "isc.rabbitmq.OutboundAdapter";

Property Adapter As isc.rabbitmq.OutboundAdapter;

Method OnMessage(message As isc.rabbitmq.Message, response As Ens.Response) As %Status
{
	Set sc = ..Adapter.SendMessage(message)
	Quit sc
}

}
