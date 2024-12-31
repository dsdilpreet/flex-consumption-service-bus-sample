A sample repo to reproduce service bus delay issue with flex consumption azure functions.
Related to issues:
https://github.com/Azure/azure-functions-host/issues/10706
https://github.com/Azure/azure-functions-dotnet-worker/issues/2902

## Infra

Update `main.bicepparam` as required.

Deploy using below command.
`az deployment sub create --name sbflextest1 --location australiaeast --template-file main.bicep --parameters main.bicepparam`

Once all done, add this environment variable in both functions.
```
Key: ServiceBusConnectionString
Value: <replace this with connection string from your service bus>
```


## Functions

There are 2 function apps, one running consumption plan and another running flex consumption plan. Each function app has a service bus trigger which subscribe to the same topic using different subscriptions.


Deploy / Publish these functionsn using visual studio to the appropriate function app. 

```
FuncSbFlexConsumption -> func-sbflexcons-aue
FuncSbConsumptionTest -> func-sbcons-aue
```